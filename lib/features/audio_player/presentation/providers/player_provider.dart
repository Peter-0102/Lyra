import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/audio_player_service.dart';

class MusicPlayerState {
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;
  final Song? currentSong;
  final double volume;
  final double speed;
  final LoopMode loopMode;
  final bool shuffleModeEnabled;
  final int? currentIndex;
  final int queueLength;
  final String? errorMessage;

  const MusicPlayerState({
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration,
    this.bufferedPosition = Duration.zero,
    this.currentSong,
    this.volume = 1.0,
    this.speed = 1.0,
    this.loopMode = LoopMode.off,
    this.shuffleModeEnabled = false,
    this.currentIndex,
    this.queueLength = 0,
    this.errorMessage,
  });

  MusicPlayerState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    Song? currentSong,
    double? volume,
    double? speed,
    LoopMode? loopMode,
    bool? shuffleModeEnabled,
    int? currentIndex,
    int? queueLength,
    String? errorMessage,
  }) {
    return MusicPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      currentSong: currentSong ?? this.currentSong,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      loopMode: loopMode ?? this.loopMode,
      shuffleModeEnabled: shuffleModeEnabled ?? this.shuffleModeEnabled,
      currentIndex: currentIndex ?? this.currentIndex,
      queueLength: queueLength ?? this.queueLength,
      errorMessage: errorMessage,
    );
  }

  bool get hasTrack => currentSong != null;

  double get progress {
    if (duration == null || duration!.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration!.inMilliseconds).clamp(0.0, 1.0);
  }

  double get bufferedProgress {
    if (duration == null || duration!.inMilliseconds == 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration!.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  bool get hasNext {
    if (queueLength <= 1) return false;
    return currentIndex != null && currentIndex! < queueLength - 1;
  }

  bool get hasPrevious {
    if (queueLength <= 1) return false;
    return currentIndex != null && currentIndex! > 0;
  }
}

class PlayerNotifier extends StateNotifier<MusicPlayerState> {
  final AudioPlayerService _service;
  final List<StreamSubscription> _subscriptions = [];

  PlayerNotifier(this._service) : super(const MusicPlayerState()) {
    _initStreams();
  }

  void _initStreams() {
    _subscriptions.addAll([
      _service.playerStateStream.listen((playerState) {
        state = state.copyWith(
          isPlaying: playerState.playing,
          isBuffering:
              playerState.processingState == ProcessingState.buffering ||
                  playerState.processingState == ProcessingState.loading,
          isCompleted: playerState.processingState == ProcessingState.completed,
          errorMessage: null,
        );
      }),

      _service.positionStream.listen((position) {
        state = state.copyWith(position: position);
      }),

      _service.durationStream.listen((duration) {
        state = state.copyWith(duration: duration);
      }),

      _service.bufferedPositionStream.listen((buffered) {
        state = state.copyWith(bufferedPosition: buffered);
      }),

      _service.sequenceStateStream.listen((seqState) {
        if (seqState == null) return;
        state = state.copyWith(
          currentIndex: seqState.currentIndex,
          queueLength: seqState.sequence.length,
        );
      }),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Single-track playback
  // ---------------------------------------------------------------------------

  Future<void> playSong(Song song) async {
    state = state.copyWith(
      currentSong: song,
      isCompleted: false,
      position: Duration.zero,
      errorMessage: null,
    );

    await _service.playLocalFile(
      song.filePath,
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: 'Mispoti',
      artUri: song.thumbnailUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // Queue / playlist playback
  // ---------------------------------------------------------------------------

  /// Loads a list of songs as a queue and starts playing from [startIndex].
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;

    final children = songs
        .map(
          (song) => AudioSource.file(
            song.filePath,
            tag: MediaItem(
              id: song.id,
              album: 'Mispoti',
              title: song.title,
              artist: song.artist,
              artUri: song.thumbnailUrl != null
                  ? Uri.parse(song.thumbnailUrl!)
                  : null,
            ),
          ),
        )
        .toList();

    final concatenated = ConcatenatingAudioSource(children: children);

    state = state.copyWith(
      currentSong: songs[startIndex],
      isCompleted: false,
      position: Duration.zero,
      queueLength: songs.length,
      currentIndex: startIndex,
      errorMessage: null,
    );

    await _service.setAudioSource(concatenated);
    await _service.skipToQueueItem(startIndex);
    await _service.play();
  }

  // ---------------------------------------------------------------------------
  // Transport controls
  // ---------------------------------------------------------------------------

  Future<void> play() async {
    try {
      await _service.play();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> pause() async {
    try {
      await _service.pause();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> togglePlayPause() async {
    try {
      await _service.togglePlayPause();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> stop() async {
    try {
      await _service.stop();
      state = const MusicPlayerState();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Seek
  // ---------------------------------------------------------------------------

  Future<void> seek(Duration position) async {
    try {
      await _service.seek(position);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> seekToProgress(double progress) async {
    if (state.duration != null) {
      final target = Duration(
        milliseconds: (state.duration!.inMilliseconds * progress).round(),
      );
      await seek(target);
    }
  }

  Future<void> seekForward([Duration step = const Duration(seconds: 10)]) async {
    try {
      await _service.seekForward(step);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> seekBackward([Duration step = const Duration(seconds: 10)]) async {
    try {
      await _service.seekBackward(step);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Skip (queue navigation)
  // ---------------------------------------------------------------------------

  Future<void> skipToNext() async {
    try {
      await _service.skipToNext();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> skipToPrevious() async {
    try {
      await _service.skipToPrevious();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> skipToQueueItem(int index) async {
    try {
      await _service.skipToQueueItem(index);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Volume & speed
  // ---------------------------------------------------------------------------

  Future<void> setVolume(double volume) async {
    try {
      await _service.setVolume(volume);
      state = state.copyWith(volume: volume);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _service.setSpeed(speed);
      state = state.copyWith(speed: speed);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Loop / shuffle
  // ---------------------------------------------------------------------------

  Future<void> setLoopMode(LoopMode mode) async {
    try {
      await _service.setLoopMode(mode);
      state = state.copyWith(loopMode: mode);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> cycleLoopMode() async {
    final next = switch (state.loopMode) {
      LoopMode.off => LoopMode.one,
      LoopMode.one => LoopMode.all,
      LoopMode.all => LoopMode.off,
    };
    await setLoopMode(next);
  }

  Future<void> toggleShuffle() async {
    try {
      final next = !state.shuffleModeEnabled;
      await _service.setShuffleModeEnabled(next);
      state = state.copyWith(shuffleModeEnabled: next);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

// =============================================================================
// Riverpod providers
// =============================================================================

final playerServiceProvider = Provider<AudioPlayerService>((ref) {
  return sl<AudioPlayerService>();
});

final playerProvider =
    StateNotifierProvider<PlayerNotifier, MusicPlayerState>((ref) {
  final service = ref.watch(playerServiceProvider);
  return PlayerNotifier(service);
});
