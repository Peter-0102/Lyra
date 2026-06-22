import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../domain/entities/playlist.dart';
import '../providers/playlist_provider.dart';
import 'create_playlist_dialog.dart';

Future<void> showPlaylistPicker(
  BuildContext context,
  WidgetRef ref,
  List<Playlist> playlists,
  Song song,
) async {
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Add to Playlist',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(color: AppColors.surfaceDark, height: 1),
          ...playlists.map((playlist) {
            final alreadyIn =
                playlist.songs.any((s) => s.id == song.id);
            return ListTile(
              leading: Icon(
                Icons.playlist_play_rounded,
                color: alreadyIn
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
              ),
              title: Text(
                playlist.name,
                style: const TextStyle(color: AppColors.textPrimaryDark),
              ),
              subtitle: Text(
                '${playlist.songs.length} songs',
                style: const TextStyle(color: AppColors.textSecondaryDark),
              ),
              trailing: alreadyIn
                  ? const Icon(Icons.check,
                      color: AppColors.primary, size: 20)
                  : null,
              onTap: () async {
                if (alreadyIn) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Already in "${playlist.name}"'),
                        backgroundColor: AppColors.cardDark,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }
                if (playlist.id.isEmpty) return;
                await ref
                    .read(playlistProvider.notifier)
                    .addSongToPlaylist(playlist.id, song);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Added to "${playlist.name}"'),
                      backgroundColor: AppColors.cardDark,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> showAddToPlaylistSheet(
    BuildContext context, WidgetRef ref, Song song) async {
  final playlists = ref.read(playlistProvider).playlists;

  if (playlists.isEmpty) {
    final result = await showCreatePlaylistDialog(context);
    if (result == null) return;
    final id = await ref
        .read(playlistProvider.notifier)
        .createPlaylist(result.name, description: result.description);
    if (id == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create playlist'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
  }

  if (!context.mounted) return;

  final updatedPlaylists = ref.read(playlistProvider).playlists;
  if (updatedPlaylists.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Create a playlist first'),
        backgroundColor: AppColors.cardDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  showPlaylistPicker(context, ref, updatedPlaylists, song);
}


