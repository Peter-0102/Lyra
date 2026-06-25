import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/download_provider.dart';

class DownloadTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const DownloadTile({
    super.key,
    required this.item,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case DownloadState.idle:
      case DownloadState.resolving:
      case DownloadState.downloading:
        return _ActiveDownloadTile(item: item, onCancel: onCancel);
      case DownloadState.completed:
        return _CompletedDownloadTile(item: item);
      case DownloadState.error:
        return _FailedDownloadTile(item: item, onRetry: onRetry);
      case DownloadState.cancelled:
        return _FailedDownloadTile(item: item, onRetry: onRetry);
    }
  }
}

class _ActiveDownloadTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;
  const _ActiveDownloadTile({required this.item, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isPending = item.queuePosition != null;
    final progress = item.progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.downloadActive.withAlpha(77),
                          AppColors.downloadActive.withAlpha(51),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: isPending
                        ? const Icon(Icons.hourglass_empty_rounded,
                            color: AppColors.downloadQueued, size: 22)
                        : const Icon(Icons.download_rounded,
                            color: AppColors.downloadActive, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.artist,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isPending)
                    Text(
                      '#${item.queuePosition}',
                      style: const TextStyle(
                        color: AppColors.downloadQueued,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondaryDark, size: 20),
                    onPressed: onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!isPending) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.status == DownloadState.resolving ? null : progress,
                    backgroundColor: AppColors.playerProgressBackground,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.downloadActive),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      item.status == DownloadState.resolving
                          ? 'Resolving...'
                          : Formatters.formatProgress(progress),
                      style: const TextStyle(
                        color: AppColors.downloadActive,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (item.receivedBytes != null && item.totalBytes != null)
                      Text(
                        '${Formatters.formatFileSize(item.receivedBytes!)} / ${Formatters.formatFileSize(item.totalBytes!)}',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ] else
                Text(
                  'Waiting...',
                  style: const TextStyle(
                    color: AppColors.downloadQueued,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedDownloadTile extends StatelessWidget {
  final DownloadItem item;
  const _CompletedDownloadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.success.withAlpha(30),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.artist,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.totalBytes != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatFileSize(item.totalBytes!),
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedDownloadTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onRetry;
  const _FailedDownloadTile({required this.item, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.error.withAlpha(30),
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (item.errorMessage != null)
                      Text(
                        item.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.downloadError,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondaryDark, size: 20),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
