import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/playlist.dart';
import '../providers/playlist_provider.dart';
import '../widgets/create_playlist_dialog.dart';
import 'playlist_detail_screen.dart';

class PlaylistListScreen extends ConsumerWidget {
  const PlaylistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistProvider);
    final notifier = ref.read(playlistProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Playlists',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded,
                    color: AppColors.primary, size: 28),
                onPressed: () async {
                  final result = await showCreatePlaylistDialog(context);
                  if (result != null) {
                    await notifier.createPlaylist(result.name,
                        description: result.description);
                  }
                },
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              state.error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        Expanded(
          child: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : state.playlists.isEmpty
                  ? _buildEmptyState(context, notifier)
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.cardDark,
                      onRefresh: () => notifier.loadPlaylists(),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: state.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = state.playlists[index];
                          return _PlaylistCard(playlist: playlist);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      BuildContext context, PlaylistNotifier notifier) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_add_rounded,
              color: AppColors.textSecondaryDark, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No playlists yet',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a playlist to organize\nyour music',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await showCreatePlaylistDialog(context);
              if (result != null) {
                await notifier.createPlaylist(result.name,
                    description: result.description);
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends ConsumerWidget {
  final Playlist playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = playlist;
    final name = p.name;
    final description = p.description;
    final songs = p.songs;
    final id = p.id;
    final totalDuration = p.totalDuration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(playlistId: id),
              ),
            );
          },
          onLongPress: () => _showOptions(context, ref, id, name),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Playlist icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withAlpha(77),
                        AppColors.primaryVariant.withAlpha(51),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.playlist_play_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${songs.length} songs · ${Formatters.formatDuration(totalDuration)}',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondaryDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(
      BuildContext context, WidgetRef ref, String id, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.textSecondaryDark.withAlpha(102),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                name,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(color: AppColors.surfaceDark, height: 1),
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: AppColors.textPrimaryDark),
              title: const Text('Rename',
                  style: TextStyle(color: AppColors.textPrimaryDark)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final result = await showCreatePlaylistDialog(context,
                    initialName: name);
                if (result != null) {
                  ref
                      .read(playlistProvider.notifier)
                      .renamePlaylist(id, result.name);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded,
                  color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.cardDark,
                    title: const Text('Delete playlist?',
                        style:
                            TextStyle(color: AppColors.textPrimaryDark)),
                    content: Text(
                      'Remove "$name" and all its songs?',
                      style: const TextStyle(
                          color: AppColors.textSecondaryDark),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(playlistProvider.notifier).deletePlaylist(id);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
