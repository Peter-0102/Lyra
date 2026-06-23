import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../../audio_player/presentation/providers/player_provider.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../playlists/presentation/providers/playlist_provider.dart';
import '../../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../../../playlists/presentation/widgets/create_playlist_dialog.dart';

class SongListTile extends ConsumerStatefulWidget {
  final Song song;
  final int? index;
  final bool isPlaying;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<Song>? allSongs;
  final bool showHeart;

  const SongListTile({
    super.key,
    required this.song,
    this.index,
    this.isPlaying = false,
    this.onTap,
    this.trailing,
    this.allSongs,
    this.showHeart = true,
  });

  @override
  ConsumerState<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends ConsumerState<SongListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  int _singleTapCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 50),
    ]).animate(_animController);
    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final action = widget.onTap ??
        () {
          ref.read(playerProvider.notifier).playSong(
                widget.song,
                allSongs: widget.allSongs,
              );
        };
    action();

    if (_singleTapCount < 3) {
      _singleTapCount++;
      _showDoubleTapHint();
    }
  }

  void _handleDoubleTap() {
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.song);
    _animController.forward(from: 0.0);
    HapticFeedback.lightImpact();
  }

  void _showDoubleTapHint() {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Toca dos veces para agregar a favoritos'),
        backgroundColor: AppColors.cardDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.15,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final favoritesState = ref.watch(favoritesProvider);
    final isFav = favoritesState.favoriteIds.contains(widget.song.id);
    final active = playerState.currentSong?.id == widget.song.id;

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          onLongPress: _showSongOptions,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: active && playerState.isPlaying
                          ? const Icon(
                              Icons.equalizer_rounded,
                              color: AppColors.primary,
                              size: 20,
                            )
                          : Text(
                              '${(widget.index ?? 0) + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.textSecondaryDark,
                                fontSize: 14,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
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
                            widget.song.title,
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
                            widget.song.artist,
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
                    Text(
                      _formatDuration(widget.song.duration),
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                    if (widget.showHeart) ...[
                      const SizedBox(width: 8),
                      Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? AppColors.primary : AppColors.textSecondaryDark,
                        size: 20,
                      ),
                    ],
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 4),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
              if (_animController.isAnimating || _animController.value > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnim.value,
                          child: Transform.scale(
                            scale: _scaleAnim.value,
                            child: Center(
                              child: Icon(
                                Icons.favorite_rounded,
                                color: AppColors.primary,
                                size: 80,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
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

  void _showSongOptions() {
    final notifier = ref.read(playerProvider.notifier);
    final favoritesState = ref.read(favoritesProvider);
    final isFav = favoritesState.favoriteIds.contains(widget.song.id);

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
                          widget.song.title,
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
                          widget.song.artist,
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
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.textPrimaryDark),
              title: const Text('Play',
                  style: TextStyle(color: AppColors.textPrimaryDark)),
              onTap: () {
                Navigator.of(ctx).pop();
                notifier.playSong(widget.song, allSongs: widget.allSongs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_rounded,
                  color: AppColors.textPrimaryDark),
              title: const Text('Add to queue',
                  style: TextStyle(color: AppColors.textPrimaryDark)),
              onTap: () {
                Navigator.of(ctx).pop();
                notifier.addToQueue(widget.song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added to queue: ${widget.song.title}'),
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
                notifier.playNext(widget.song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing next: ${widget.song.title}'),
                    backgroundColor: AppColors.cardDark,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? AppColors.primary : AppColors.textPrimaryDark,
              ),
              title: Text(
                isFav ? 'Remove from Favorites' : 'Add to Favorites',
                style: const TextStyle(color: AppColors.textPrimaryDark),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(favoritesProvider.notifier).toggleFavorite(widget.song);
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
                    currentContext, ref, updatedPlaylists, widget.song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
