import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/player_provider.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        title: const Text(
          'Queue',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (state.songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              onPressed: () {
                _showClearQueueDialog(
                    context, notifier, state.currentIndex, state.songs.length);
              },
            ),
        ],
      ),
      body: state.songs.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music_rounded,
                      color: AppColors.textSecondaryDark, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Queue is empty',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Play a song to start a queue',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: state.songs.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex--;
                notifier.reorderQueue(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final song = state.songs[index];
                final isCurrent = index == state.currentIndex;

                return _QueueTile(
                  key: ValueKey(song.id),
                  song: song,
                  index: index,
                  isCurrent: isCurrent,
                  isPlaying: isCurrent && state.isPlaying,
                  onTap: () => notifier.skipToQueueItem(index),
                  onDelete: isCurrent
                      ? null
                      : () => notifier.removeFromQueue(index),
                );
              },
            ),
    );
  }

  void _showClearQueueDialog(
    BuildContext context,
    PlayerNotifier notifier,
    int? currentIndex,
    int songsLength,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text(
          'Clear queue?',
          style: TextStyle(color: AppColors.textPrimaryDark),
        ),
        content: const Text(
          'This will remove all songs except the currently playing one.',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearQueue(notifier, currentIndex, songsLength);
            },
            child: const Text('Clear',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _clearQueue(PlayerNotifier notifier, int? currentIndex, int songsLength) {
    if (currentIndex == null) return;
    for (int i = songsLength - 1; i > currentIndex; i--) {
      notifier.removeFromQueue(i);
    }
    for (int i = currentIndex - 1; i >= 0; i--) {
      notifier.removeFromQueue(i);
    }
  }
}

class _QueueTile extends StatelessWidget {
  final dynamic song;
  final int index;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: const Text('Remove from queue?',
                style: TextStyle(color: AppColors.textPrimaryDark)),
            content: Text(
              'Remove "${song.title}" from the queue?',
              style: const TextStyle(color: AppColors.textSecondaryDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Remove',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete?.call(),
      child: Material(
        color: isCurrent
            ? AppColors.primary.withAlpha(26)
            : Colors.transparent,
        child: ListTile(
          onTap: onTap,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrent && isPlaying)
                const Icon(Icons.equalizer_rounded,
                    color: AppColors.primary, size: 20)
              else if (isCurrent)
                const Icon(Icons.play_arrow_rounded,
                    color: AppColors.primary, size: 20)
              else
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            song.title,
            style: TextStyle(
              color: isCurrent
                  ? AppColors.primary
                  : AppColors.textPrimaryDark,
              fontSize: 15,
              fontWeight:
                  isCurrent ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song.artist,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.formatDuration(song.duration),
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.drag_handle_rounded,
                  color: AppColors.textSecondaryDark, size: 20),
            ],
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),
      ),
    );
  }
}
