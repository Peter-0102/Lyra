import 'dart:async';

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
const int _max429Retries = 3;

class DownloadServiceImpl implements DownloadService {
  final Dio _dio;
  final String _baseUrl;
  CancelToken? _cancelToken;

  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  DownloadProgress? _activeDownload;
  String? _currentDownloadingFilePath;

  DownloadServiceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

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

      final metadata = await _pollStatus(videoId, jobId);

      final filePath = await _buildFilePath(title, artist);

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

  Future<String> _requestExtraction(String videoId) async {
    for (var attempt = 0; attempt <= _max429Retries; attempt++) {
      try {
        final response = await _dio.post(
          '$_baseUrl/api/audio/request',
          data: {'videoId': videoId},
          cancelToken: _cancelToken,
        );

        print('[FRONTEND] POST /api/audio/request => statusCode=${response.statusCode}');
        print('[FRONTEND] Response data: ${response.data}');

        if (response.statusCode == 200 && response.data['status'] == 'ready') {
          print('[FRONTEND] Job already cached! jobId=${response.data['jobId']}, title=${response.data['title']}, artist=${response.data['artist']}, duration=${response.data['durationSec']}s, fileSize=${response.data['fileSize']}B, format=${response.data['format']}');
          return response.data['jobId'];
        }

        if (response.statusCode == 202) {
          print('[FRONTEND] Job queued. jobId=${response.data['jobId']}');
          return response.data['jobId'];
        }

        throw NetworkFailure('Unexpected response: ${response.statusCode}');
      } on DioException catch (e) {
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
        throw NetworkFailure('Failed to request extraction: ${e.message}');
      }
    }
    throw const NetworkFailure('Rate limited. Try again later.');
  }

  Future<_AudioMetadata> _pollStatus(String videoId, String jobId) async {
    final deadline = DateTime.now().add(_pollTimeout);
    int retries = 0;

    while (DateTime.now().isBefore(deadline)) {
      if (_cancelToken?.isCancelled == true) throw const StorageFailure('Download cancelled by user.');

      try {
        final response = await _dio.get(
          '$_baseUrl/api/audio/status/$jobId',
          cancelToken: _cancelToken,
        );

        print('[FRONTEND] GET /api/audio/status/$jobId => statusCode=${response.statusCode}');
        print('[FRONTEND] Status data: ${response.data}');

        retries = 0;
        final data = response.data;
        final status = data['status'] as String;
        print('[FRONTEND] Status: $status, progress: ${data['progress']}, fileSize: ${data['fileSize']}, format: ${data['format']}, title: ${data['title']}, artist: ${data['artist']}');

        switch (status) {
          case 'ready':
            print('[FRONTEND] Ready! Metadata => videoId=$videoId, fileSize=${data['fileSize']}, format=${data['format']}');
            return _AudioMetadata(
              videoId: videoId,
              fileSize: data['fileSize'] as int? ?? 0,
              format: data['format'] as String? ?? 'm4a',
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
          '$_baseUrl/api/audio/file/$videoId',
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

  Future<String> _buildFilePath(String title, String artist) async {
    final dir = await getApplicationDocumentsDirectory();
    final sanitizedTitle = _sanitizeFilename(title);
    final sanitizedArtist = _sanitizeFilename(artist);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${sanitizedArtist}_${sanitizedTitle}_$timestamp.m4a';
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
