import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:disk_usage/disk_usage.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/download_service.dart';

const int _minFreeBytes = 5 * 1024 * 1024;
const int _minValidFileSize = 10 * 1024;
const Duration _pollInterval = Duration(seconds: 4);
const Duration _pollTimeout = Duration(minutes: 10);
const Duration _sseTimeout = Duration(seconds: 30);
const int _max429Retries = 3;

class DownloadServiceImpl implements DownloadService {
  final Dio _dio;
  CancelToken? _cancelToken;

  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  DownloadProgress? _activeDownload;
  String? _currentDownloadingFilePath;

  DownloadServiceImpl({
    required Dio dio,
  })  : _dio = dio;

  @override
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  @override
  DownloadProgress? get activeDownload => _activeDownload;

  @override
  Future<String> downloadYoutubeSong(
    String videoIdOrUrl, {
    required String title,
    required String artist,
  }) async {
    _cancelToken = CancelToken();

    try {
      final videoId = _extractVideoId(videoIdOrUrl);

      _emitProgress(state: DownloadState.resolving, progress: 0.0);

      final jobId = await _requestExtraction(videoId);

      final metadata = await _ssePollStatus(videoId, jobId);

      final filePath = await _buildFilePath(videoId, title, artist);

      await _assertDiskSpace(metadata.fileSize);

      await _downloadFile(videoId, filePath, metadata.fileSize);

      await _validateFile(filePath);

      _emitProgress(state: DownloadState.completed, progress: 1.0);
      final resultPath = filePath;
      _resetState();
      return resultPath;
    } on Failure {
      await _cleanupPartialFile();
      _emitProgress(state: DownloadState.error, progress: 0.0, errorMessage: 'Download failed');
      rethrow;
    } catch (e) {
      await _cleanupPartialFile();
      _emitProgress(state: DownloadState.error, progress: 0.0, errorMessage: e.toString());
      if (e is Failure) rethrow;
      throw UnknownFailure('Unexpected download error: $e');
    }
  }

  String _extractVideoId(String videoIdOrUrl) {
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoIdOrUrl)) {
      return videoIdOrUrl;
    }
    final match = RegExp(r'(?:v=|youtu\.be/)([a-zA-Z0-9_-]{11})').firstMatch(videoIdOrUrl);
    if (match != null) return match.group(1)!;
    throw const YouTubeFailure('Invalid YouTube video ID or URL.');
  }

  Map<String, dynamic> _safeData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return {};
  }

  String _safeString(Map<String, dynamic> map, String key, {String fallback = ''}) {
    final v = map[key];
    if (v is String) return v;
    if (v is num) return v.toString();
    return fallback;
  }

  int _safeInt(Map<String, dynamic> map, String key, {int fallback = 0}) {
    final v = map[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  Future<String> _requestExtraction(String videoId) async {
    for (var attempt = 0; attempt <= _max429Retries; attempt++) {
      try {
        final response = await _dio.post(
          '/api/audio/request',
          data: {'videoId': videoId},
          cancelToken: _cancelToken,
        );

        final data = _safeData(response.data);
        final status = _safeString(data, 'status');

        if (response.statusCode == 200 && status == 'ready') {
          return _safeString(data, 'jobId', fallback: videoId);
        }

        if (response.statusCode == 202) {
          return _safeString(data, 'jobId', fallback: videoId);
        }

        throw NetworkFailure('Unexpected response: ${response.statusCode}');
      }       on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          throw const StorageFailure('Download cancelled by user.');
        }
        if (e.response?.statusCode == 422) {
          final message = e.response?.data?['message'] ?? 'Video unavailable';
          throw YouTubeFailure(message);
        }
        if (e.response?.statusCode == 429 && attempt < _max429Retries) {
          final delaySec = 5 * (attempt + 1);
          await Future.delayed(Duration(seconds: delaySec));
          continue;
        }
        final isTransient = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        if (isTransient && attempt < _max429Retries) {
          await Future.delayed(Duration(seconds: 5 * (attempt + 1)));
          continue;
        }
        throw NetworkFailure('Failed to request extraction: ${e.message}');
      }
    }
    throw const NetworkFailure('Rate limited. Try again later.');
  }

  Future<_AudioMetadata> _ssePollStatus(String videoId, String jobId) async {
    try {
      return await _sseWaitForStatus(videoId, jobId);
    } catch (e) {
      print('[FRONTEND] SSE failed, falling back to polling: $e');
      return _pollStatus(videoId, jobId);
    }
  }

  Future<_AudioMetadata> _sseWaitForStatus(String videoId, String jobId) async {
    final completer = Completer<_AudioMetadata>();
    final deadline = DateTime.now().add(_sseTimeout);
    bool completed = false;

    try {
      final response = await _dio.get(
        '/api/audio/status/$jobId/stream',
        options: Options(
          responseType: ResponseType.stream,
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final stream = response.data as ResponseBody;
      String buffer = '';
      String? currentEvent;

      stream.stream.cast<List<int>>().transform(utf8.decoder).listen(
        (chunk) {
          if (completed) return;

          buffer += chunk;
          final lines = buffer.split('\n');
          buffer = lines.last;

          for (final line in lines.take(lines.length - 1)) {
            if (line.startsWith('event: ')) {
              currentEvent = line.substring(7);
            } else if (line.startsWith('data: ') && currentEvent == 'status') {
              final data = line.substring(6);
              try {
                final json = jsonDecode(data) as Map<String, dynamic>;
                final status = json['status'] as String?;

                final progress = (json['progress'] as num?)?.toDouble();
                if (progress != null) {
                  _emitProgress(
                    state: DownloadState.resolving,
                    progress: progress,
                  );
                }

                if (status == 'ready' && !completed) {
                  completed = true;
                  completer.complete(_AudioMetadata(
                    videoId: videoId,
                    fileSize: json['fileSize'] as int? ?? 0,
                    format: json['format'] as String? ?? 'm4a',
                  ));
                } else if (status == 'error' && !completed) {
                  completed = true;
                  completer.completeError(
                    YouTubeFailure(json['errorMessage'] as String? ?? 'Unknown error'),
                  );
                }
              } catch (_) {}
            } else if (line.isEmpty) {
              currentEvent = null;
            }
          }
        },
        onError: (err) {
          if (!completed) {
            completed = true;
            completer.completeError(err);
          }
        },
        onDone: () {
          if (!completed && DateTime.now().isBefore(deadline)) {
            completer.completeError(TimeoutException('SSE stream ended early'));
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (!completed) {
        completed = true;
        rethrow;
      }
    }

    final result = await completer.future.timeout(_sseTimeout);
    return result;
  }

  Future<_AudioMetadata> _pollStatus(String videoId, String jobId) async {
    final deadline = DateTime.now().add(_pollTimeout);
    int retries = 0;

    while (DateTime.now().isBefore(deadline)) {
      if (_cancelToken?.isCancelled == true) throw const StorageFailure('Download cancelled by user.');

      try {
        final response = await _dio.get(
          '/api/audio/status/$jobId',
          cancelToken: _cancelToken,
        );

        print('[FRONTEND] GET /api/audio/status/$jobId => statusCode=${response.statusCode}');
        print('[FRONTEND] Status data: ${response.data}');

        retries = 0;
        final data = _safeData(response.data);
        final status = _safeString(data, 'status');

        switch (status) {
          case 'ready':
            return _AudioMetadata(
              videoId: videoId,
              fileSize: _safeInt(data, 'fileSize'),
              format: _safeString(data, 'format', fallback: 'm4a'),
            );
          case 'error':
            throw YouTubeFailure(data['errorMessage'] ?? 'Unknown error');
          case 'processing':
          case 'queued':
            _emitProgress(
              state: DownloadState.resolving,
              progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
            );
            break;
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          throw const StorageFailure('Download cancelled by user.');
        }
        if (e.response?.statusCode == 429) {
          if (retries < _max429Retries) {
            retries++;
            await Future.delayed(Duration(seconds: 5 * retries));
            continue;
          }
          throw NetworkFailure('Rate limited during status check. Try again later.');
        }
        final isTransient = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        if (isTransient && retries < _max429Retries) {
          retries++;
          await Future.delayed(_pollInterval * retries);
          continue;
        }
        throw NetworkFailure('Status check failed: ${e.message}');
      }

      await Future.delayed(_pollInterval);
    }

    throw const YouTubeFailure('Extraction timed out. Please try again.');
  }

  Future<void> _downloadFile(String videoId, String filePath, int totalBytes) async {
    print('[FRONTEND] _downloadFile: videoId=$videoId, filePath=$filePath, totalBytes=$totalBytes');
    _emitProgress(
      state: DownloadState.downloading,
      progress: 0.0,
      totalBytes: totalBytes,
    );

    for (var attempt = 0; attempt <= _max429Retries; attempt++) {
      try {
        await _dio.download(
          '/api/audio/file/$videoId',
          filePath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
            if (received == total && total > 0) {
              print('[FRONTEND] File download complete! received=$received, total=$total');
            }
            _emitProgress(
              state: DownloadState.downloading,
              progress: progress,
              totalBytes: total,
              receivedBytes: received,
            );
          },
        );
        return;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          throw const StorageFailure('Download cancelled by user.');
        }
        if (e.response?.statusCode == 429 && attempt < _max429Retries) {
          final delaySec = 5 * (attempt + 1);
          await Future.delayed(Duration(seconds: delaySec));
          continue;
        }
        if (e.response?.statusCode == 404) {
          throw const YouTubeFailure('Audio file not found. Please request extraction again.');
        }
        if (e.response?.statusCode == 410) {
          throw const YouTubeFailure('Audio file expired. Please request extraction again.');
        }
        final isTransient = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        if (isTransient && attempt < _max429Retries) {
          await Future.delayed(Duration(seconds: 5 * (attempt + 1)));
          continue;
        }
        throw NetworkFailure('Download failed: ${e.message}');
      }
    }
  }

  @override
  Future<void> cancelDownload() async {
    _cancelToken?.cancel();
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

  Future<String> _buildFilePath(String videoId, String title, String artist) async {
    final dir = await getApplicationDocumentsDirectory();
    final sanitizedTitle = _sanitizeFilename(title);
    final sanitizedArtist = _sanitizeFilename(artist);
    final fileName = '${videoId}_${sanitizedArtist}_${sanitizedTitle}.m4a';
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
      final freeSpace = await DiskUsage.freeSpace(dir.path);
      if (freeSpace != null && freeSpace < _minFreeBytes) {
        throw const StorageFailure(
          'Insufficient storage space. Free up at least 5 MB and try again.',
        );
      }
      if (freeSpace != null && requiredBytes > freeSpace) {
        throw StorageFailure(
          'Not enough space for this download. Need ${(requiredBytes / 1024).toStringAsFixed(1)} KB but only ${(freeSpace / 1024).toStringAsFixed(1)} KB available.',
        );
      }
    } catch (e) {
      if (e is Failure) rethrow;
    }
  }

  Future<void> _validateFile(String filePath) async {
    final file = File(filePath);
    print('[FRONTEND] _validateFile: Checking file at $filePath');

    if (!await file.exists()) {
      print('[FRONTEND] _validateFile: File does NOT exist on disk!');
      throw const StorageFailure('Downloaded file not found on disk.');
    }

    final fileSize = await file.length();
    print('[FRONTEND] _validateFile: File size = $fileSize bytes');

    if (fileSize == 0) {
      print('[FRONTEND] _validateFile: File is EMPTY, deleting');
      await file.delete();
      throw const StorageFailure('Downloaded file is empty (0 bytes).');
    }

    if (fileSize < _minValidFileSize) {
      print('[FRONTEND] _validateFile: File too small ($fileSize < $_minValidFileSize), deleting');
      await file.delete();
      throw StorageFailure(
        'Downloaded file is too small ($fileSize bytes). '
        'The stream may be corrupted or the video is unavailable.',
      );
    }

    print('[FRONTEND] _validateFile: File OK!');
  }

  Future<void> _cleanupPartialFile() async {
    final path = _currentDownloadingFilePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
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

  void dispose() {
    _cancelToken?.cancel();
    _progressController.close();
  }
}

class _AudioMetadata {
  final String videoId;
  final int fileSize;
  final String format;

  const _AudioMetadata({
    required this.videoId,
    required this.fileSize,
    required this.format,
  });
}
