import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/download_provider.dart';
import '../widgets/download_tile.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadProvider);
    final notifier = ref.read(downloadProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            'Downloads',
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            _buildSubtitle(state),
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: 'Active (${state.totalActive + state.totalPending})'),
            Tab(text: 'Completed (${state.totalCompleted})'),
            Tab(text: 'Failed (${state.totalFailed})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveTab(state, notifier),
              _buildCompletedTab(state, notifier),
              _buildFailedTab(state, notifier),
            ],
          ),
        ),
      ],
    );
  }

  String _buildSubtitle(DownloadQueueState state) {
    final parts = <String>[];
    final active = state.totalActive + state.totalPending;
    if (active > 0) parts.add('$active active');
    if (state.totalCompleted > 0) parts.add('${state.totalCompleted} completed');
    if (state.totalFailed > 0) parts.add('${state.totalFailed} failed');
    return parts.isEmpty ? 'No downloads yet' : parts.join(' · ');
  }

  Widget _buildActiveTab(DownloadQueueState state, DownloadNotifier notifier) {
    final items = [
      ...state.activeDownloads.values,
      ...state.pendingQueue,
    ];

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_rounded,
                color: AppColors.textSecondaryDark, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No active downloads',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Downloads will appear here when\nthey start',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 20, 4),
              child: TextButton.icon(
                onPressed: () => notifier.cancelAllDownloads(),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel all'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.downloadError,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return DownloadTile(
                item: item,
                onCancel: () => notifier.cancelAllDownloads(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTab(
      DownloadQueueState state, DownloadNotifier notifier) {
    if (state.completedDownloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.textSecondaryDark, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No completed downloads',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Successfully downloaded songs\nwill appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 20, 4),
            child: TextButton.icon(
              onPressed: () => notifier.clearCompleted(),
              icon: const Icon(Icons.delete_sweep_rounded, size: 16),
              label: const Text('Clear all'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: state.completedDownloads.length,
            itemBuilder: (context, index) {
              return DownloadTile(item: state.completedDownloads[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFailedTab(DownloadQueueState state, DownloadNotifier notifier) {
    if (state.failedDownloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textSecondaryDark, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No failed downloads',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Failed downloads will appear here\nfor retry',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 20, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () {
                    for (final item in state.failedDownloads) {
                      notifier.retryDownload(item.videoId);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry all'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.downloadActive,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => notifier.clearFailed(),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: state.failedDownloads.length,
            itemBuilder: (context, index) {
              final item = state.failedDownloads[index];
              return DownloadTile(
                item: item,
                onRetry: () => notifier.retryDownload(item.videoId),
              );
            },
          ),
        ),
      ],
    );
  }
}
