import 'dart:async';

enum DownloadState { idle, resolving, downloading, completed, error, cancelled }

class DownloadProgress {
  final DownloadState state;
  final double progress;
  final int? totalBytes;
  final int? receivedBytes;
  final String? errorMessage;

  const DownloadProgress({
    this.state = DownloadState.idle,
    this.progress = 0.0,
    this.totalBytes,
    this.receivedBytes,
    this.errorMessage,
  });

  DownloadProgress copyWith({
    DownloadState? state,
    double? progress,
    int? totalBytes,
    int? receivedBytes,
    String? errorMessage,
  }) {
    return DownloadProgress(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      errorMessage: errorMessage,
    );
  }

  bool get isDownloading =>
      state == DownloadState.resolving || state == DownloadState.downloading;
}

abstract class DownloadService {
  /// Stream of real-time download progress updates.
  Stream<DownloadProgress> get progressStream;

  /// The currently active download's progress, or null if idle.
  DownloadProgress? get activeDownload;

  /// Downloads a YouTube audio track as a WebM file (Opus codec, ~64 kbps).
  ///
  /// Accepts a YouTube video ID or full URL. The file is saved to the
  /// application documents directory with a sanitized filename.
  ///
  /// Throws [YouTubeFailure] if the video is unavailable or has no audio streams.
  /// Throws [NetworkFailure] on connectivity or rate-limit errors.
  /// Throws [StorageFailure] on disk space or permission issues.
  Future<String> downloadYoutubeSong(
    String videoIdOrUrl, {
    required String title,
    required String artist,
  });

  /// Cancels the active download and cleans up partial files.
  Future<void> cancelDownload();

  /// Deletes a previously downloaded song file from local storage.
  Future<void> deleteSong(String filePath);

  /// Returns the number of free bytes available in the documents directory.
  Future<int> getAvailableStorageBytes();
}
