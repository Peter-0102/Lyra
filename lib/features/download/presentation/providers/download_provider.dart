import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/download_service.dart';

export '../../domain/repositories/download_service.dart'
    show DownloadState, DownloadProgress;

const Duration _queueDelay = Duration(seconds: 2);

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
  final int? queuePosition;

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
    this.queuePosition,
  });

  DownloadItem copyWith({
    DownloadState? status,
    double? progress,
    int? totalBytes,
    int? receivedBytes,
    String? filePath,
    String? errorMessage,
    int? queuePosition,
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
      queuePosition: queuePosition,
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
  final List<DownloadItem> pendingQueue;

  const DownloadQueueState({
    this.activeDownloads = const {},
    this.completedDownloads = const [],
    this.failedDownloads = const [],
    this.pendingQueue = const [],
  });

  DownloadQueueState copyWith({
    Map<String, DownloadItem>? activeDownloads,
    List<DownloadItem>? completedDownloads,
    List<DownloadItem>? failedDownloads,
    List<DownloadItem>? pendingQueue,
  }) {
    return DownloadQueueState(
      activeDownloads: activeDownloads ?? this.activeDownloads,
      completedDownloads: completedDownloads ?? this.completedDownloads,
      failedDownloads: failedDownloads ?? this.failedDownloads,
      pendingQueue: pendingQueue ?? this.pendingQueue,
    );
  }

  int get totalActive => activeDownloads.length;
  int get totalCompleted => completedDownloads.length;
  int get totalFailed => failedDownloads.length;
  int get totalPending => pendingQueue.length;
  bool get isBusy => activeDownloads.isNotEmpty;

  bool isBusyOrDone(String videoId) =>
      activeDownloads.containsKey(videoId) ||
      completedDownloads.any((d) => d.videoId == videoId) ||
      pendingQueue.any((d) => d.videoId == videoId);
}

class DownloadNotifier extends StateNotifier<DownloadQueueState> {
  final DownloadService _downloadService;
  StreamSubscription<DownloadProgress>? _progressSub;
  String? _currentTrackingVideoId;
  bool _isProcessing = false;

  DownloadNotifier(this._downloadService) : super(const DownloadQueueState()) {
    _initProgressListener();
  }

  void _initProgressListener() {
    _progressSub = _downloadService.progressStream.listen((downloadProgress) {
      final videoId = _currentTrackingVideoId;
      if (videoId == null) return;

      final current = state.activeDownloads[videoId];
      if (current == null) return;

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
    if (state.isBusyOrDone(videoId)) return;

    final item = DownloadItem(
      videoId: videoId,
      title: title,
      artist: artist,
      status: DownloadState.idle,
      progress: 0.0,
    );

    if (state.isBusy) {
      final queuePos = state.pendingQueue.length + 1;
      final queuedItem = item.copyWith(
        status: DownloadState.idle,
        queuePosition: queuePos,
      );
      state = state.copyWith(
        pendingQueue: [...state.pendingQueue, queuedItem],
      );
      return;
    }

    await _runDownload(item);
  }

  Future<void> _runDownload(DownloadItem item) async {
    _currentTrackingVideoId = item.videoId;
    _isProcessing = true;

    final activeItem = item.copyWith(status: DownloadState.resolving, queuePosition: null);
    final newMap = Map<String, DownloadItem>.from(state.activeDownloads);
    newMap[item.videoId] = activeItem;
    state = state.copyWith(activeDownloads: newMap);

    try {
      final filePath = await _downloadService.downloadYoutubeSong(
        item.videoId,
        title: item.title,
        artist: item.artist,
      );

      final completedItem = activeItem.copyWith(
        status: DownloadState.completed,
        progress: 1.0,
        filePath: filePath,
      );

      final updatedMap = Map<String, DownloadItem>.from(state.activeDownloads);
      updatedMap.remove(item.videoId);

      state = state.copyWith(
        activeDownloads: updatedMap,
        completedDownloads: [...state.completedDownloads, completedItem],
      );
    } on Failure catch (e) {
      final failedItem = activeItem.copyWith(
        status: DownloadState.error,
        errorMessage: e.message,
      );

      final updatedMap = Map<String, DownloadItem>.from(state.activeDownloads);
      updatedMap.remove(item.videoId);

      state = state.copyWith(
        activeDownloads: updatedMap,
        failedDownloads: [...state.failedDownloads, failedItem],
      );
    } finally {
      if (_currentTrackingVideoId == item.videoId) {
        _currentTrackingVideoId = null;
      }
      _isProcessing = false;
      _reindexQueue();
      await _processNext();
    }
  }

  void _reindexQueue() {
    final reindexed = <DownloadItem>[];
    for (var i = 0; i < state.pendingQueue.length; i++) {
      reindexed.add(state.pendingQueue[i].copyWith(queuePosition: i + 1));
    }
    state = state.copyWith(pendingQueue: reindexed);
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    if (state.pendingQueue.isEmpty) return;

    await Future.delayed(_queueDelay);

    final next = state.pendingQueue.first;
    final remaining = state.pendingQueue.sublist(1);
    state = state.copyWith(pendingQueue: remaining);

    await _runDownload(next);
  }

  Future<void> cancelAllDownloads() async {
    await _downloadService.cancelDownload();

    final cancelledItems = state.activeDownloads.values
        .map((item) => item.copyWith(status: DownloadState.cancelled))
        .toList();

    state = state.copyWith(
      activeDownloads: {},
      pendingQueue: [],
      failedDownloads: [...state.failedDownloads, ...cancelledItems],
    );

    _currentTrackingVideoId = null;
    _isProcessing = false;
  }

  Future<void> retryDownload(String videoId) async {
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
