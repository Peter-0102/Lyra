import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/player_provider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    ref.listen<MusicPlayerState>(playerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _TopBar(title: 'Mispoti'),
            // Album art
            Expanded(
              child: Center(
                child: _AlbumArt(
                  isPlaying: state.isPlaying,
                  artUri: state.currentSong?.thumbnailUrl,
                ),
              ),
            ),
            // Song info
            _SongInfo(
              title: state.currentSong?.title ?? 'No track',
              artist: state.currentSong?.artist ?? '',
            ),
            const SizedBox(height: 16),
            // Seek bar
            _SeekBar(
              position: state.position,
              duration: state.duration ?? Duration.zero,
              bufferedProgress: state.bufferedProgress,
              onSeek: (pos) => notifier.seek(pos),
            ),
            const SizedBox(height: 8),
            // Main controls
            _MainControls(
              isPlaying: state.isPlaying,
              hasNext: state.hasNext,
              hasPrevious: state.hasPrevious,
              onPlayPause: () => notifier.togglePlayPause(),
              onNext: () => notifier.skipToNext(),
              onPrevious: () => notifier.skipToPrevious(),
            ),
            const SizedBox(height: 16),
            // Secondary controls
            _SecondaryControls(
              loopMode: state.loopMode,
              shuffleEnabled: state.shuffleModeEnabled,
              volume: state.volume,
              speed: state.speed,
              onCycleLoop: () => notifier.cycleLoopMode(),
              onToggleShuffle: () => notifier.toggleShuffle(),
              onSetVolume: (v) => notifier.setVolume(v),
              onSetSpeed: (s) => notifier.setSpeed(s),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textPrimaryDark, size: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'PLAYING FROM',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondaryDark, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final bool isPlaying;
  final String? artUri;
  const _AlbumArt({required this.isPlaying, this.artUri});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: MediaQuery.of(context).size.width * 0.72,
      height: MediaQuery.of(context).size.width * 0.72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isPlaying ? 24 : 16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(isPlaying ? 60 : 30),
            blurRadius: isPlaying ? 40 : 20,
            spreadRadius: isPlaying ? 4 : 0,
          ),
        ],
        gradient: const LinearGradient(
          colors: [Color(0xFF1DB954), Color(0xFF134E2B), Color(0xFF0D3318)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.onPrimary,
          size: 80,
        ),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  final String title;
  final String artist;
  const _SongInfo({required this.title, required this.artist});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final double bufferedProgress;
  final ValueChanged<Duration> onSeek;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.bufferedProgress,
    required this.onSeek,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  double get _progress {
    if (widget.duration.inMilliseconds == 0) return 0.0;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final displayProgress = _isDragging ? _dragValue : _progress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppColors.playerProgress,
              inactiveTrackColor: AppColors.playerProgressBackground,
              thumbColor: AppColors.playerProgress,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayColor: AppColors.primary.withAlpha(51),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: displayProgress.clamp(0.0, 1.0),
              onChangeStart: (value) {
                setState(() {
                  _isDragging = true;
                  _dragValue = value;
                });
              },
              onChanged: (value) {
                setState(() {
                  _dragValue = value;
                });
              },
              onChangeEnd: (value) {
                setState(() {
                  _isDragging = false;
                });
                final target = Duration(
                  milliseconds:
                      (widget.duration.inMilliseconds * value).round(),
                );
                widget.onSeek(target);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Formatters.formatDuration(
                    _isDragging
                        ? Duration(
                            milliseconds:
                                (widget.duration.inMilliseconds * _dragValue)
                                    .round())
                        : widget.position,
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11,
                  ),
                ),
                Text(
                  Formatters.formatDuration(widget.duration),
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainControls extends StatelessWidget {
  final bool isPlaying;
  final bool hasNext;
  final bool hasPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const _MainControls({
    required this.isPlaying,
    required this.hasNext,
    required this.hasPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.skip_previous_rounded,
              color: hasPrevious
                  ? AppColors.textPrimaryDark
                  : AppColors.textSecondaryDark,
              size: 36,
            ),
            onPressed: hasPrevious ? onPrevious : null,
          ),
          // Play/Pause button
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(77),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: AppColors.onPrimary,
                size: 40,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.skip_next_rounded,
              color: hasNext
                  ? AppColors.textPrimaryDark
                  : AppColors.textSecondaryDark,
              size: 36,
            ),
            onPressed: hasNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  final LoopMode loopMode;
  final bool shuffleEnabled;
  final double volume;
  final double speed;
  final VoidCallback onCycleLoop;
  final VoidCallback onToggleShuffle;
  final ValueChanged<double> onSetVolume;
  final ValueChanged<double> onSetSpeed;

  const _SecondaryControls({
    required this.loopMode,
    required this.shuffleEnabled,
    required this.volume,
    required this.speed,
    required this.onCycleLoop,
    required this.onToggleShuffle,
    required this.onSetVolume,
    required this.onSetSpeed,
  });

  IconData _loopIcon() {
    return switch (loopMode) {
      LoopMode.one => Icons.repeat_one_rounded,
      LoopMode.all => Icons.repeat_rounded,
      LoopMode.off => Icons.repeat_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: shuffleEnabled
                  ? AppColors.primary
                  : AppColors.textSecondaryDark,
              size: 22,
            ),
            onPressed: onToggleShuffle,
          ),
          // Volume
          IconButton(
            icon: Icon(
              volume == 0
                  ? Icons.volume_off_rounded
                  : volume < 0.5
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
              color: AppColors.textSecondaryDark,
              size: 22,
            ),
            onPressed: () => _showVolumeSlider(context),
          ),
          // Loop
          IconButton(
            icon: Icon(
              _loopIcon(),
              color: loopMode != LoopMode.off
                  ? AppColors.primary
                  : AppColors.textSecondaryDark,
              size: 22,
            ),
            onPressed: onCycleLoop,
          ),
          // Speed
          TextButton(
            onPressed: () => _showSpeedPicker(context),
            child: Text(
              '${speed}x',
              style: TextStyle(
                color: speed != 1.0
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVolumeSlider(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Volume',
                style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Slider(
              value: volume,
              onChanged: (v) => onSetVolume(v),
              activeColor: AppColors.playerProgress,
              inactiveColor: AppColors.playerProgressBackground,
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedPicker(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Playback Speed',
                style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: speeds
                  .map(
                    (s) => ChoiceChip(
                      label: Text('${s}x'),
                      selected: speed == s,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceDark,
                      labelStyle: TextStyle(
                        color: speed == s
                            ? AppColors.onPrimary
                            : AppColors.textSecondaryDark,
                      ),
                      onSelected: (_) {
                        onSetSpeed(s);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
