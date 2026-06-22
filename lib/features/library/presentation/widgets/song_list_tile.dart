import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../../audio_player/presentation/providers/player_provider.dart';
import '../../../playlists/presentation/providers/playlist_provider.dart';
import '../../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../../../playlists/presentation/widgets/create_playlist_dialog.dart';

class SongListTile extends ConsumerWidget {
  final Song song;
  final int? index;
  final bool isPlaying;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<Song>? allSongs;

  const SongListTile({
    super.key,
    required this.song,
    this.index,
    this.isPlaying = false,
    this.onTap,
    this.trailing,
    this.allSongs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final active = playerState.currentSong?.id == song.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            () {
              ref.read(playerProvider.notifier).playSong(
                    song,
                    allSongs: allSongs,
                  );
            },
        onLongPress: () => _showSongOptions(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Index or playing indicator
              SizedBox(
                width: 36,
                child: active && playerState.isPlaying
                    ? const Icon(
                        Icons.equalizer_rounded,
                        color: AppColors.primary,
                        size: 20,
                      )
                    : Text(
                        '${(index ?? 0) + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: active
                              ? AppColors.primary
                              : AppColors.textSecondaryDark,
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Album art placeholder
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
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
                  Icons.music_note_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        color: active
                            ? AppColors.primary
                            : AppColors.textPrimaryDark,
                        fontSize: 15,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
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
              // Duration
              Text(
                _formatDuration(song.duration),
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  void _showSongOptions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);

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
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.textSecondaryDark.withAlpha(102),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Song info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
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
                      Icons.music_note_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
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
                          song.artist,
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
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceDark, height: 1),
            // Options
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.textPrimaryDark),
              title: const Text('Play',
                  style: TextStyle(color: AppColors.textPrimaryDark)),
              onTap: () {
                Navigator.of(ctx).pop();
                notifier.playSong(song, allSongs: allSongs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_rounded,
                  color: AppColors.textPrimaryDark),
              title: const Text('Add to queue',
                  style: TextStyle(color: AppColors.textPrimaryDark)),
              onTap: () {
                Navigator.of(ctx).pop();
                notifier.addToQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added to queue: ${song.title}'),
                    backgroundColor: AppColors.cardDark,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next_rounded,
                  color: AppColors.textPrimaryDark),
              title: const Text('Play next',
                  style: TextStyle(color: AppColors.textPrimaryDark)),
              onTap: () {
                Navigator.of(ctx).pop();
                notifier.playNext(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing next: ${song.title}'),
                    backgroundColor: AppColors.cardDark,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded,
                  color: AppColors.textPrimaryDark),
              title: const Text('Add to playlist',
                  style: TextStyle(color: AppColors.textPrimaryDark)),
              onTap: () async {
                final currentContext = context;

                var state = ref.read(playlistProvider);
                if (state.isLoading) return;

                if (state.playlists.isEmpty) {
                  final result =
                      await showCreatePlaylistDialog(currentContext);
                  if (result == null) return;
                  final id = await ref
                      .read(playlistProvider.notifier)
                      .createPlaylist(result.name,
                          description: result.description);
                  if (id == null) {
                    if (currentContext.mounted) {
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content:
                              const Text('Failed to create playlist'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }
                  state = ref.read(playlistProvider);
                }

                if (ctx.mounted) Navigator.of(ctx).pop();

                if (!currentContext.mounted) return;

                await Future.delayed(Duration.zero);

                if (!currentContext.mounted) return;

                final updatedPlaylists =
                    ref.read(playlistProvider).playlists;
                if (updatedPlaylists.isEmpty) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(
                      content: const Text('Create a playlist first'),
                      backgroundColor: AppColors.cardDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                showPlaylistPicker(
                    currentContext, ref, updatedPlaylists, song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
