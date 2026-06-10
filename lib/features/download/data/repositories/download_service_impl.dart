import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:disk_usage/disk_usage.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/download_service.dart';

const int _minFreeBytes = 5 * 1024 * 1024; // 5 MB minimum free space
const int _minValidFileSize = 10 * 1024; // 10 KB minimum for a valid download

class DownloadServiceImpl implements DownloadService {
  final YoutubeExplode _yt;

  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  bool _isCancelled = false;
  DownloadProgress? _activeDownload;
  String? _currentDownloadingFilePath;

  DownloadServiceImpl({required YoutubeExplode yt}) : _yt = yt;

  @override
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  @override
  DownloadProgress? get activeDownload => _activeDownload;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  @override
  Future<String> downloadYoutubeSong(
    String videoIdOrUrl, {
    required String title,
    required String artist,
  }) async {
    print('[DOWNLOAD] ====== STARTING DOWNLOAD ======');
    print('[DOWNLOAD] Step 0: Input params => videoIdOrUrl="$videoIdOrUrl", title="$title", artist="$artist"');
    _isCancelled = false;
    _emitProgress(state: DownloadState.resolving, progress: 0.0);

    try {
      // 1. Resolve video metadata and stream manifest
      print('[DOWNLOAD] Step 1: Resolving video metadata...');
      final Video video;
      final StreamManifest manifest;
      try {
        video = await _yt.videos.get(videoIdOrUrl);
        print('[DOWNLOAD] Step 1a: Video resolved => id="${video.id}", title="${video.title}", duration=${video.duration}');
        manifest = await _yt.videos.streamsClient.getManifest(video.id);
        print('[DOWNLOAD] Step 1b: Manifest resolved => audioOnly=${manifest.audioOnly.length}, muxed=${manifest.muxed.length}');
      } on VideoUnplayableException catch (e) {
        print('[DOWNLOAD] ERROR Step 1: VideoUnplayableException => $e');
        throw const YouTubeFailure(
          'This video is unavailable, private, or region-locked.',
        );
      } catch (e) {
        print('[DOWNLOAD] ERROR Step 1: Failed to fetch metadata => $e');
        throw YouTubeFailure('Failed to fetch video metadata: $e');
      }

      // 2. Select the best audio-only WebM/Opus stream
      print('[DOWNLOAD] Step 2: Selecting audio stream...');
      final AudioOnlyStreamInfo streamInfo = _selectAudioStream(manifest);
      print('[DOWNLOAD] Step 2a: Stream selected => codec="${streamInfo.audioCodec}", bitrate="${streamInfo.bitrate.bitsPerSecond} bps", container="${streamInfo.container.name}", size=${streamInfo.size.totalBytes} bytes');

      // 3. Build a safe local file path
      print('[DOWNLOAD] Step 3: Building file path...');
      final String filePath = await _buildFilePath(title, artist);
      print('[DOWNLOAD] Step 3a: File path => "$filePath"');

      // 4. Check disk space
      print('[DOWNLOAD] Step 4: Checking disk space (required=${streamInfo.size.totalBytes} bytes)...');
      await _assertDiskSpace(streamInfo.size.totalBytes.toInt());
      print('[DOWNLOAD] Step 4a: Disk space check passed');

      // 5. Download using youtube_explode's stream (NOT dio)
      print('[DOWNLOAD] Step 5: Starting stream download...');
      _emitProgress(
        state: DownloadState.downloading,
        progress: 0.0,
        totalBytes: streamInfo.size.totalBytes.toInt(),
      );

      await _downloadStream(streamInfo, filePath);

      // 6. Validate the written file
      print('[DOWNLOAD] Step 6: Validating downloaded file...');
      await _validateFile(filePath);
      print('[DOWNLOAD] Step 6a: File validation passed');

      print('[DOWNLOAD] Step 7: Download COMPLETED successfully => "$filePath"');
      _emitProgress(state: DownloadState.completed, progress: 1.0);
      final resultPath = filePath;
      _resetState();
      return resultPath;
    } on Failure catch (e) {
      print('[DOWNLOAD] ERROR (Failure): ${e.runtimeType} => ${e.message}');
      await _cleanupPartialFile();
      _emitProgress(
        state: DownloadState.error,
        progress: 0.0,
        errorMessage: 'Download failed',
      );
      rethrow;
    } catch (e) {
      print('[DOWNLOAD] ERROR (catch-all): ${e.runtimeType} => $e');
      await _cleanupPartialFile();
      _emitProgress(
        state: DownloadState.error,
        progress: 0.0,
        errorMessage: e.toString(),
      );
      if (e is Failure) rethrow;
      throw UnknownFailure('Unexpected download error: $e');
    }
  }

  @override
  Future<void> cancelDownload() async {
    print('[DOWNLOAD] cancelDownload: Cancelling active download...');
    _isCancelled = true;
    await _cleanupPartialFile();
    _emitProgress(state: DownloadState.cancelled, progress: 0.0);
    _resetState();
    print('[DOWNLOAD] cancelDownload: Done');
  }

  @override
  Future<void> deleteSong(String filePath) async {
    print('[DOWNLOAD] deleteSong: Deleting file at "$filePath"');
    final file = File(filePath);
    if (await file.exists()) {
      try {
        await file.delete();
        print('[DOWNLOAD] deleteSong: File deleted successfully');
      } catch (e) {
        print('[DOWNLOAD] ERROR deleteSong: Failed to delete => $e');
        throw StorageFailure('Failed to delete file: $e');
      }
    } else {
      print('[DOWNLOAD] deleteSong: File does not exist, skipping');
    }
  }

  @override
  Future<int> getAvailableStorageBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await dir.stat();
      if (Platform.isAndroid || Platform.isIOS) {
        final parentDir = Directory(dir.path).parent;
        final parentStat = await parentDir.stat();
        return parentStat.size;
      }
      return stat.size;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Stream selection logic
  // ---------------------------------------------------------------------------

  AudioOnlyStreamInfo _selectAudioStream(StreamManifest manifest) {
    final audioOnly = manifest.audioOnly;
    print('[DOWNLOAD] _selectAudioStream: total audio-only streams = ${audioOnly.length}');
    for (var i = 0; i < audioOnly.length; i++) {
      final s = audioOnly[i];
      print('[DOWNLOAD]   Stream[$i]: codec="${s.audioCodec}", bitrate=${s.bitrate.bitsPerSecond}bps, container="${s.container.name}", size=${s.size.totalBytes}B');
    }

    if (audioOnly.isEmpty) {
      print('[DOWNLOAD] ERROR _selectAudioStream: No audio streams available');
      throw const YouTubeFailure('No audio streams available for this video.');
    }

    // Strategy: find the lowest-bitrate WebM/Opus stream first (minimizes size).
    final webmOpus = audioOnly.where(
      (s) =>
          s.container.name.toLowerCase().contains('webm') &&
          s.audioCodec.toLowerCase().contains('opus'),
    );

    if (webmOpus.isNotEmpty) {
      print('[DOWNLOAD] _selectAudioStream: Found ${webmOpus.length} WebM/Opus streams, picking lowest bitrate');
      return webmOpus.reduce(
        (a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b,
      );
    }

    // Fallback: any WebM container
    final webm = audioOnly.where(
      (s) => s.container.name.toLowerCase().contains('webm'),
    );
    if (webm.isNotEmpty) {
      print('[DOWNLOAD] _selectAudioStream: No WebM/Opus, fallback to ${webm.length} WebM streams');
      return webm.reduce(
        (a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b,
      );
    }

    // Last resort: highest bitrate audio
    print('[DOWNLOAD] _selectAudioStream: No WebM, last resort => highest bitrate audio');
    return audioOnly.withHighestBitrate();
  }

  // ---------------------------------------------------------------------------
  // Download using youtube_explode stream (correct method)
  // ---------------------------------------------------------------------------

  Future<void> _downloadStream(
    AudioOnlyStreamInfo streamInfo,
    String filePath,
  ) async {
    final totalBytes = streamInfo.size.totalBytes.toInt();
    int receivedBytes = 0;
    int chunkCount = 0;

    print('[DOWNLOAD] _downloadStream: Opening stream...');
    final stream = _yt.videos.streams.get(streamInfo);
    final file = File(filePath);
    final sink = file.openWrite();

    try {
      print('[DOWNLOAD] _downloadStream: Starting chunk iteration...');
      await for (final chunk in stream) {
        if (_isCancelled) {
          print('[DOWNLOAD] _downloadStream: Cancelled mid-download at $receivedBytes/$totalBytes bytes');
          break;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;
        chunkCount++;

        if (chunkCount % 50 == 0 || receivedBytes == totalBytes) {
          final progress = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;
          print('[DOWNLOAD] _downloadStream: Progress ${(progress * 100).toStringAsFixed(1)}% ($receivedBytes/$totalBytes bytes, chunks=$chunkCount)');
        }

        final progress = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;

        _emitProgress(
          state: DownloadState.downloading,
          progress: progress,
          totalBytes: totalBytes,
          receivedBytes: receivedBytes,
        );
      }

      print('[DOWNLOAD] _downloadStream: Stream ended. Flushing sink...');
      await sink.flush();
      await sink.close();
      print('[DOWNLOAD] _downloadStream: Sink closed. Total received: $receivedBytes bytes ($chunkCount chunks)');

      if (_isCancelled) {
        throw const StorageFailure('Download cancelled by user.');
      }
    } catch (e) {
      print('[DOWNLOAD] ERROR _downloadStream: $e');
      await sink.close();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // File path and validation
  // ---------------------------------------------------------------------------

  Future<String> _buildFilePath(String title, String artist) async {
    print('[DOWNLOAD] _buildFilePath: Getting application documents directory...');
    final dir = await getApplicationDocumentsDirectory();
    print('[DOWNLOAD] _buildFilePath: Documents dir => "${dir.path}"');
    final sanitizedTitle = _sanitizeFilename(title);
    final sanitizedArtist = _sanitizeFilename(artist);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${sanitizedArtist}_${sanitizedTitle}_$timestamp.webm';
    final filePath = '${dir.path}/$fileName';
    _currentDownloadingFilePath = filePath;
    print('[DOWNLOAD] _buildFilePath: Built path => "$filePath"');
    return filePath;
  }

  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  Future<void> _assertDiskSpace(int requiredBytes) async {
    print('[DOWNLOAD] _assertDiskSpace: requiredBytes=$requiredBytes');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final freeSpace = await DiskUsage.freeSpace(dir.path);
      print('[DOWNLOAD] _assertDiskSpace: freeSpace=$freeSpace bytes, _minFreeBytes=$_minFreeBytes');
      if (freeSpace != null && freeSpace < _minFreeBytes) {
        print('[DOWNLOAD] ERROR _assertDiskSpace: INSUFFICIENT SPACE ($freeSpace < $_minFreeBytes)');
        throw const StorageFailure(
          'Insufficient storage space. Free up at least 5 MB and try again.',
        );
      }
      if (freeSpace != null && requiredBytes > freeSpace) {
        print('[DOWNLOAD] ERROR _assertDiskSpace: NOT ENOUGH for download ($requiredBytes > $freeSpace)');
        throw StorageFailure(
          'Not enough space for this download. Need ${(requiredBytes / 1024).toStringAsFixed(1)} KB but only ${(freeSpace / 1024).toStringAsFixed(1)} KB available.',
        );
      }
      print('[DOWNLOAD] _assertDiskSpace: OK (free=$freeSpace, required=$requiredBytes)');
    } catch (e) {
      if (e is Failure) rethrow;
      print('[DOWNLOAD] _assertDiskSpace: non-Failure exception caught: $e');
    }
  }

  Future<void> _validateFile(String filePath) async {
    print('[DOWNLOAD] _validateFile: Checking file at "$filePath"');
    final file = File(filePath);

    if (!await file.exists()) {
      print('[DOWNLOAD] ERROR _validateFile: File does NOT exist!');
      throw const StorageFailure('Downloaded file not found on disk.');
    }

    final fileSize = await file.length();
    print('[DOWNLOAD] _validateFile: File size = $fileSize bytes');

    if (fileSize == 0) {
      print('[DOWNLOAD] ERROR _validateFile: File is EMPTY (0 bytes), deleting...');
      await file.delete();
      throw const StorageFailure('Downloaded file is empty (0 bytes).');
    }

    if (fileSize < _minValidFileSize) {
      print('[DOWNLOAD] ERROR _validateFile: File too small ($fileSize < $_minValidFileSize), deleting...');
      await file.delete();
      throw StorageFailure(
        'Downloaded file is too small ($fileSize bytes). '
        'The stream may be corrupted or the video is unavailable.',
      );
    }
    print('[DOWNLOAD] _validateFile: File OK');
  }

  // ---------------------------------------------------------------------------
  // Cleanup and state management
  // ---------------------------------------------------------------------------

  Future<void> _cleanupPartialFile() async {
    final path = _currentDownloadingFilePath;
    print('[DOWNLOAD] _cleanupPartialFile: path="$path"');
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
          print('[DOWNLOAD] _cleanupPartialFile: Partial file deleted');
        } catch (e) {
          print('[DOWNLOAD] _cleanupPartialFile: Failed to delete partial file: $e');
        }
      }
      _currentDownloadingFilePath = null;
    }
  }

  void _emitProgress({
    required DownloadState state,
    required double progress,
    int? totalBytes,
    int? receivedBytes,
    String? errorMessage,
  }) {
    _activeDownload = DownloadProgress(
      state: state,
      progress: progress,
      totalBytes: totalBytes,
      receivedBytes: receivedBytes,
      errorMessage: errorMessage,
    );
    _progressController.add(_activeDownload!);
  }

  void _resetState() {
    _isCancelled = false;
    _currentDownloadingFilePath = null;
    _activeDownload = null;
  }

  void dispose() {
    _isCancelled = true;
    _progressController.close();
  }
}
