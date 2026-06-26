import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../audio_player/presentation/providers/player_provider.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../providers/playlist_provider.dart';
import '../widgets/create_playlist_dialog.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final playlistsState = ref.watch(playlistProvider);
    final playlist = playlistsState.playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;

    if (playlist == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Playlist not found',
              style: TextStyle(color: AppColors.textSecondaryDark)),
        ),
      );
    }

    final songs = playlist.songs;
    final notifier = ref.read(playlistProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondaryDark),
            color: AppColors.cardDark,
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  final result = await showCreatePlaylistDialog(context,
                      initialName: playlist.name);
                  if (result != null) {
                    notifier.renamePlaylist(playlist.id, result.name);
                  }
                case 'delete':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.cardDark,
                      title: const Text('Delete playlist?',
                          style:
                              TextStyle(color: AppColors.textPrimaryDark)),
                      content: Text(
                        'Remove "${playlist.name}" and all its songs?',
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
                    notifier.deletePlaylist(playlist.id);
                    if (context.mounted) context.pop();
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit_rounded,
                      color: AppColors.textPrimaryDark),
                  title: Text('Rename',
                      style: TextStyle(color: AppColors.textPrimaryDark)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_rounded,
                      color: AppColors.error),
                  title: Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                // Playlist icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                    size: 48,
                  ),
                ),
                const SizedBox(width: 20),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (playlist.description != null &&
                          playlist.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          playlist.description!,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${songs.length} songs · ${Formatters.formatDuration(playlist.totalDuration)}',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Play all button
          if (songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(playerProvider.notifier).playQueue(songs);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text('Play All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          // Song list
          Expanded(
            child: songs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_add_rounded,
                            color: AppColors.textSecondaryDark,
                            size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No songs in this playlist',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: songs.length,
                    onReorder: (oldIndex, newIndex) {
                      notifier.reorderSongs(
                          playlist.id, oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return Dismissible(
                        key: ValueKey('${song.id}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.error,
                          child: const Icon(Icons.delete_rounded,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.cardDark,
                              title: const Text('Remove song?',
                                  style: TextStyle(
                                      color:
                                          AppColors.textPrimaryDark)),
                              content: Text(
                                'Remove "${song.title}" from this playlist?',
                                style: const TextStyle(
                                    color:
                                        AppColors.textSecondaryDark),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(true),
                                  child: const Text('Remove',
                                      style: TextStyle(
                                          color: AppColors.error)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          notifier.removeSongFromPlaylist(
                              playlist.id, song.id);
                        },
                        child: Row(
                          key: ValueKey('${song.id}_$index'),
                          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, right: 4),
                child: Icon(Icons.drag_handle_rounded,
                    color: AppColors.textSecondaryDark, size: 20),
              ),
            ),
                            Expanded(
                              child: SongListTile(
                                song: song,
                                index: index,
                                allSongs: songs,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
