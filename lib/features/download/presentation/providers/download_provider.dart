import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/download_service.dart';

// Re-export domain types for convenience in UI layer
export '../../domain/repositories/download_service.dart'
    show DownloadState, DownloadProgress;

class DownloadItem {
  final String videoId;
  final String title;
  final String artist;
  final DownloadState status;
  final double progress;
  final int? totalBytes;
  final int? receivedBytes;
  final String? filePath;
  final String? errorMessage;

  const DownloadItem({
    required this.videoId,
    required this.title,
    required this.artist,
    this.status = DownloadState.idle,
    this.progress = 0.0,
    this.totalBytes,
    this.receivedBytes,
    this.filePath,
    this.errorMessage,
  });

  DownloadItem copyWith({
    DownloadState? status,
    double? progress,
    int? totalBytes,
    int? receivedBytes,
    String? filePath,
    String? errorMessage,
  }) {
    return DownloadItem(
      videoId: videoId,
      title: title,
      artist: artist,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage,
    );
  }

  String? get formattedSize {
    if (totalBytes == null) return null;
    if (totalBytes! < 1024) return '$totalBytes B';
    if (totalBytes! < 1024 * 1024) {
      return '${(totalBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String? get formattedReceived {
    if (receivedBytes == null) return null;
    if (receivedBytes! < 1024) return '$receivedBytes B';
    if (receivedBytes! < 1024 * 1024) {
      return '${(receivedBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(receivedBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DownloadQueueState {
  final Map<String, DownloadItem> activeDownloads;
  final List<DownloadItem> completedDownloads;
  final List<DownloadItem> failedDownloads;

  const DownloadQueueState({
    this.activeDownloads = const {},
    this.completedDownloads = const [],
    this.failedDownloads = const [],
  });

  DownloadQueueState copyWith({
    Map<String, DownloadItem>? activeDownloads,
    List<DownloadItem>? completedDownloads,
    List<DownloadItem>? failedDownloads,
  }) {
    return DownloadQueueState(
      activeDownloads: activeDownloads ?? this.activeDownloads,
      completedDownloads: completedDownloads ?? this.completedDownloads,
      failedDownloads: failedDownloads ?? this.failedDownloads,
    );
  }

  int get totalActive => activeDownloads.length;
  int get totalCompleted => completedDownloads.length;
  int get totalFailed => failedDownloads.length;
  bool get isBusy => activeDownloads.isNotEmpty;

  /// Returns true if the given videoId is currently downloading or completed.
  bool isBusyOrDone(String videoId) =>
      activeDownloads.containsKey(videoId) ||
      completedDownloads.any((d) => d.videoId == videoId);
}

class DownloadNotifier extends StateNotifier<DownloadQueueState> {
  final DownloadService _downloadService;
  StreamSubscription<DownloadProgress>? _progressSub;
  String? _currentTrackingVideoId;

  DownloadNotifier(this._downloadService) : super(const DownloadQueueState()) {
    _initProgressListener();
  }

  void _initProgressListener() {
    print('[DOWNLOAD] DownloadNotifier: Initializing progress listener');
    _progressSub = _downloadService.progressStream.listen((downloadProgress) {
      final videoId = _currentTrackingVideoId;
      print('[DOWNLOAD] DownloadNotifier: Progress event => state=${downloadProgress.state}, progress=${downloadProgress.progress}, videoId=$videoId');
      if (videoId == null) {
        print('[DOWNLOAD] DownloadNotifier: No active tracking videoId, ignoring progress');
        return;
      }

      final current = state.activeDownloads[videoId];
      if (current == null) {
        print('[DOWNLOAD] DownloadNotifier: No active download item for videoId=$videoId, ignoring');
        return;
      }

      final updated = current.copyWith(
        status: downloadProgress.state,
        progress: downloadProgress.progress,
        totalBytes: downloadProgress.totalBytes,
        receivedBytes: downloadProgress.receivedBytes,
        errorMessage: downloadProgress.errorMessage,
      );

      final newMap = Map<String, DownloadItem>.from(state.activeDownloads);
      newMap[videoId] = updated;
      state = state.copyWith(activeDownloads: newMap);
    });
  }

  Future<void> startDownload(String videoId, String title, String artist) async {
    print('[DOWNLOAD] DownloadNotifier: startDownload called => videoId="$videoId", title="$title", artist="$artist"');

    // Prevent duplicate downloads
    if (state.isBusyOrDone(videoId)) {
      print('[DOWNLOAD] DownloadNotifier: Duplicate download blocked for videoId="$videoId" (isBusyOrDone=true)');
      return;
    }

    _currentTrackingVideoId = videoId;

    final item = DownloadItem(
      videoId: videoId,
      title: title,
      artist: artist,
      status: DownloadState.resolving,
      progress: 0.0,
    );

    final newMap = Map<String, DownloadItem>.from(state.activeDownloads);
    newMap[videoId] = item;
    state = state.copyWith(activeDownloads: newMap);
    print('[DOWNLOAD] DownloadNotifier: Added to activeDownloads map');

    try {
      print('[DOWNLOAD] DownloadNotifier: Calling downloadService.downloadYoutubeSong...');
      final filePath = await _downloadService.downloadYoutubeSong(
        videoId,
        title: title,
        artist: artist,
      );
      print('[DOWNLOAD] DownloadNotifier: Download succeeded! filePath="$filePath"');

      final completedItem = item.copyWith(
        status: DownloadState.completed,
        progress: 1.0,
        filePath: filePath,
      );

      final updatedMap = Map<String, DownloadItem>.from(state.activeDownloads);
      updatedMap.remove(videoId);

      state = state.copyWith(
        activeDownloads: updatedMap,
        completedDownloads: [...state.completedDownloads, completedItem],
      );
      print('[DOWNLOAD] DownloadNotifier: Moved to completedDownloads');
    } on Failure catch (e) {
      print('[DOWNLOAD] DownloadNotifier: Download FAILED with Failure => ${e.runtimeType}: ${e.message}');
      final failedItem = item.copyWith(
        status: DownloadState.error,
        errorMessage: e.message,
      );

      final updatedMap = Map<String, DownloadItem>.from(state.activeDownloads);
      updatedMap.remove(videoId);

      state = state.copyWith(
        activeDownloads: updatedMap,
        failedDownloads: [...state.failedDownloads, failedItem],
      );
      print('[DOWNLOAD] DownloadNotifier: Moved to failedDownloads');
    } finally {
      if (_currentTrackingVideoId == videoId) {
        _currentTrackingVideoId = null;
        print('[DOWNLOAD] DownloadNotifier: Cleared _currentTrackingVideoId');
      }
    }
  }

  Future<void> cancelAllDownloads() async {
    print('[DOWNLOAD] DownloadNotifier: cancelAllDownloads called');
    await _downloadService.cancelDownload();

    final cancelledItems = state.activeDownloads.values
        .map((item) => item.copyWith(status: DownloadState.cancelled))
        .toList();

    state = state.copyWith(
      activeDownloads: {},
      failedDownloads: [...state.failedDownloads, ...cancelledItems],
    );

    _currentTrackingVideoId = null;
    print('[DOWNLOAD] DownloadNotifier: All downloads cancelled');
  }

  Future<void> retryDownload(String videoId) async {
    print('[DOWNLOAD] DownloadNotifier: retryDownload called for videoId="$videoId"');
    final failed = state.failedDownloads.firstWhere(
      (d) => d.videoId == videoId,
      orElse: () => throw StateError('No failed download found for $videoId'),
    );

    final updatedFailed =
        state.failedDownloads.where((d) => d.videoId != videoId).toList();
    state = state.copyWith(failedDownloads: updatedFailed);

    await startDownload(videoId, failed.title, failed.artist);
  }

  void clearFailed() {
    state = state.copyWith(failedDownloads: []);
  }

  void clearCompleted() {
    state = state.copyWith(completedDownloads: []);
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return sl<DownloadService>();
});

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadQueueState>((ref) {
  final downloadService = ref.watch(downloadServiceProvider);
  return DownloadNotifier(downloadService);
});
