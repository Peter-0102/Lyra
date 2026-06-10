import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../../audio_player/presentation/providers/player_provider.dart';

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
}
