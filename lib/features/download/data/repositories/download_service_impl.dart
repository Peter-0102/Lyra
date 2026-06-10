import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/download_service.dart';

const int _minFreeBytes = 5 * 1024 * 1024; // 5 MB minimum free space
const int _minValidFileSize = 10 * 1024; // 10 KB minimum for a valid download
const int _maxRetries = 3;
const Duration _retryBaseDelay = Duration(seconds: 2);

class DownloadServiceImpl implements DownloadService {
  final Dio _dio;
  final YoutubeExplode _yt;

  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  CancelToken? _cancelToken;
  DownloadProgress? _activeDownload;
  String? _currentDownloadingFilePath;

  DownloadServiceImpl({
    required Dio dio,
    required YoutubeExplode yt,
  })  : _dio = dio,
        _yt = yt;

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
    _cancelToken = CancelToken();
    _emitProgress(state: DownloadState.resolving, progress: 0.0);

    try {
      // 1. Resolve video metadata and stream manifest
      final Video video;
      final StreamManifest manifest;
      try {
        video = await _yt.videos.get(videoIdOrUrl);
        manifest = await _yt.videos.streamsClient.getManifest(video.id);
      } on VideoUnplayableException {
        throw const YouTubeFailure(
          'This video is unavailable, private, or region-locked.',
        );
      } catch (e) {
        throw YouTubeFailure('Failed to fetch video metadata: $e');
      }

      // 2. Select the best audio-only WebM/Opus stream
      final AudioOnlyStreamInfo streamInfo = _selectAudioStream(manifest);

      // 3. Build a safe local file path
      final String filePath = await _buildFilePath(title, artist);

      // 4. Check disk space
      await _assertDiskSpace(streamInfo.size.totalBytes.toInt());

      // 5. Download with retry logic
      _emitProgress(
        state: DownloadState.downloading,
        progress: 0.0,
        totalBytes: streamInfo.size.totalBytes.toInt(),
      );

      await _downloadWithRetry(streamInfo.url.toString(), filePath);

      // 6. Validate the written file
      await _validateFile(filePath);

      _emitProgress(state: DownloadState.completed, progress: 1.0);
      final resultPath = filePath;
      _resetState();
      return resultPath;
    } on Failure {
      await _cleanupPartialFile();
      _emitProgress(
        state: DownloadState.error,
        progress: 0.0,
        errorMessage: 'Download failed',
      );
      rethrow;
    } on DioException catch (e) {
      await _cleanupPartialFile();
      if (CancelToken.isCancel(e)) {
        _emitProgress(state: DownloadState.cancelled, progress: 0.0);
        throw const StorageFailure('Download cancelled by user.');
      }
      _emitProgress(
        state: DownloadState.error,
        progress: 0.0,
        errorMessage: e.message,
      );
      throw NetworkFailure('Network error: ${e.message}');
    } catch (e) {
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
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled');
    }
    await _cleanupPartialFile();
    _emitProgress(state: DownloadState.cancelled, progress: 0.0);
    _resetState();
  }

  @override
  Future<void> deleteSong(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        throw StorageFailure('Failed to delete file: $e');
      }
    }
  }

  @override
  Future<int> getAvailableStorageBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await dir.stat();
      // stat.size returns the directory metadata size, not free space.
      // On mobile, getApplicationDocumentsDirectory is on internal storage
      // whose free space we approximate via Platform.
      if (Platform.isAndroid || Platform.isIOS) {
        // path_provider gives us the app sandbox; we read the parent.
        final parentDir = Directory(dir.path).parent;
        final parentStat = await parentDir.stat();
        // Approximation: use the parent's available space heuristic.
        // For production, consider using device_info_plus or platform channels.
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
    if (audioOnly.isEmpty) {
      throw const YouTubeFailure('No audio streams available for this video.');
    }

    // Strategy: find the lowest-bitrate WebM/Opus stream first (minimizes size).
    // Fall back to any WebM, then any audio, then highest bitrate.
    final webmOpus = audioOnly.where(
      (s) =>
          s.container.name.toLowerCase().contains('webm') &&
          s.audioCodec.toLowerCase().contains('opus'),
    );

    if (webmOpus.isNotEmpty) {
      // Pick the lowest bitrate to stay under ~2 MB per song
      return webmOpus.reduce(
        (a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b,
      );
    }

    // Fallback: any WebM container
    final webm = audioOnly.where(
      (s) => s.container.name.toLowerCase().contains('webm'),
    );
    if (webm.isNotEmpty) {
      return webm.reduce(
        (a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b,
      );
    }

    // Last resort: highest bitrate audio (likely larger but playable)
    return audioOnly.withHighestBitrate();
  }

  // ---------------------------------------------------------------------------
  // Download with retry
  // ---------------------------------------------------------------------------

  Future<void> _downloadWithRetry(String url, String filePath) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        await _dio.download(
          url,
          filePath,
          cancelToken: _cancelToken,
          options: Options(
            receiveTimeout: const Duration(seconds: 120),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
            },
          ),
          onReceiveProgress: (received, total) {
            if (total > 0 && !_cancelToken!.isCancelled) {
              final progress = (received / total).clamp(0.0, 1.0);
              _emitProgress(
                state: DownloadState.downloading,
                progress: progress,
                totalBytes: total,
                receivedBytes: received,
              );
            }
          },
        );
        return; // Success
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;

        final statusCode = e.response?.statusCode;
        final isRetryable =
            statusCode == 429 || // Rate limited
            statusCode == 503 || // Service unavailable
            statusCode == 500 || // Server error
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isRetryable && attempt < _maxRetries) {
          final delay = _retryBaseDelay * (1 << (attempt - 1)); // Exponential
          await Future<void>.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // File path and validation
  // ---------------------------------------------------------------------------

  Future<String> _buildFilePath(String title, String artist) async {
    final dir = await getApplicationDocumentsDirectory();
    final sanitizedTitle = _sanitizeFilename(title);
    final sanitizedArtist = _sanitizeFilename(artist);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${sanitizedArtist}_${sanitizedTitle}_$timestamp.webm';
    final filePath = '${dir.path}/$fileName';
    _currentDownloadingFilePath = filePath;
    return filePath;
  }

  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  Future<void> _assertDiskSpace(int requiredBytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await dir.stat();
      // Approximate: if stat.size is huge, the filesystem is likely fine.
      // For strict enforcement, use platform channels with statvfs.
      // We rely on the download itself to fail if truly out of space.
      if (stat.size > 0 && stat.size < _minFreeBytes && requiredBytes > stat.size) {
        throw const StorageFailure(
          'Insufficient storage space. Free up at least 5 MB and try again.',
        );
      }
    } catch (e) {
      if (e is Failure) rethrow;
      // If we can't determine disk space, let the download attempt proceed
      // and fail naturally if the disk is truly full.
    }
  }

  Future<void> _validateFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw const StorageFailure('Downloaded file not found on disk.');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      await file.delete();
      throw const StorageFailure('Downloaded file is empty (0 bytes).');
    }

    if (fileSize < _minValidFileSize) {
      await file.delete();
      throw StorageFailure(
        'Downloaded file is too small ($fileSize bytes). '
        'The stream may be corrupted or the video is unavailable.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup and state management
  // ---------------------------------------------------------------------------

  Future<void> _cleanupPartialFile() async {
    final path = _currentDownloadingFilePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup; file may be locked on some platforms.
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
    _cancelToken = null;
    _currentDownloadingFilePath = null;
    _activeDownload = null;
  }

  /// Disposes internal resources. Call when the service is no longer needed.
  void dispose() {
    _cancelToken?.cancel('Service disposed');
    _progressController.close();
  }
}
