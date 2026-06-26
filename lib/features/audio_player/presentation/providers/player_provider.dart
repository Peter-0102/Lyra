import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/audio_player_service.dart';
import '../../../history/domain/repositories/history_repository.dart';

class MusicPlayerState {
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;
  final Song? currentSong;
  final List<Song> songs;
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
    this.songs = const [],
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
    List<Song>? songs,
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
      songs: songs ?? this.songs,
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
    bool wasCompleted = false;
    bool wasPlaying = false;

    _subscriptions.addAll([
      _service.playerStateStream.listen((playerState) {
        final bool nowCompleted =
            playerState.processingState == ProcessingState.completed;
        final bool nowPlaying = playerState.playing;

        if (wasPlaying &&
            !nowPlaying &&
            playerState.processingState == ProcessingState.idle &&
            state.hasNext) {
          _autoSkipToNext();
        }

        if (nowCompleted && !wasCompleted && state.currentSong != null) {
          _recordPlay(state.currentSong!);
        }
        wasCompleted = nowCompleted;
        wasPlaying = nowPlaying;

        state = state.copyWith(
          isPlaying: nowPlaying,
          isBuffering:
              playerState.processingState == ProcessingState.buffering ||
                  playerState.processingState == ProcessingState.loading,
          isCompleted: nowCompleted,
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
        final newIndex = seqState.currentIndex;
        final newQueueLength = seqState.sequence.length;

        // Sync currentSong from the queue when the index changes
        Song? updatedSong = state.currentSong;
        if (newIndex >= 0 && newIndex < state.songs.length) {
          updatedSong = state.songs[newIndex];
        }

        state = state.copyWith(
          currentIndex: newIndex,
          queueLength: newQueueLength,
          currentSong: updatedSong,
        );
      }),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Single-track playback
  // ---------------------------------------------------------------------------

  Future<void> playSong(Song song, {List<Song>? allSongs}) async {
    final songs = allSongs ?? [song];
    final startIndex = songs.indexWhere((s) => s.id == song.id);
    await playQueue(songs, startIndex: startIndex >= 0 ? startIndex : 0);
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
      songs: songs,
      isCompleted: false,
      position: Duration.zero,
      queueLength: songs.length,
      currentIndex: startIndex,
      errorMessage: null,
    );

    try {
      await _service.setAudioSource(concatenated);
      await _service.skipToQueueItem(startIndex);
      await _service.play();
    } catch (e) {
      if (startIndex < songs.length - 1) {
        await playQueue(songs, startIndex: startIndex + 1);
      } else {
        state = state.copyWith(errorMessage: 'Playback failed: $e');
      }
    }
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

  void _recordPlay(Song song) {
    try {
      final historyRepo = sl<HistoryRepository>();
      historyRepo.recordPlay(
        songId: song.id,
        title: song.title,
        artist: song.artist,
        filePath: song.filePath,
        durationSec: song.duration.inSeconds,
        playedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<void> _autoSkipToNext() async {
    await _service.reset();
    if (state.currentIndex != null && state.currentIndex! < state.songs.length - 1) {
      final nextIndex = state.currentIndex! + 1;
      await playQueue(state.songs, startIndex: nextIndex);
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
  // Queue management
  // ---------------------------------------------------------------------------

  /// Adds a song to the end of the current queue.
  Future<void> addToQueue(Song song) async {
    if (state.songs.isEmpty) {
      await playSong(song);
      return;
    }

    try {
      final source = AudioSource.file(
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
      );

      final insertIndex = state.songs.length;
      await _service.insertIntoQueue(insertIndex, source);

      final updatedSongs = List<Song>.from(state.songs)..add(song);
      state = state.copyWith(
        songs: updatedSongs,
        queueLength: updatedSongs.length,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Inserts a song right after the currently playing track.
  Future<void> playNext(Song song) async {
    if (state.songs.isEmpty) {
      await playSong(song);
      return;
    }

    try {
      final source = AudioSource.file(
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
      );

      final insertIndex = (state.currentIndex ?? 0) + 1;
      await _service.insertIntoQueue(insertIndex, source);

      final updatedSongs = List<Song>.from(state.songs);
      updatedSongs.insert(insertIndex, song);
      state = state.copyWith(
        songs: updatedSongs,
        queueLength: updatedSongs.length,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Removes a song at [index] from the current queue.
  Future<void> removeFromQueue(int index) async {
    try {
      // Don't remove the currently playing song
      if (index == state.currentIndex) return;

      // Update state FIRST so Dismissible disappears immediately
      final updatedSongs = List<Song>.from(state.songs)..removeAt(index);

      int newCurrentIndex = state.currentIndex ?? 0;
      if (index < newCurrentIndex) {
        newCurrentIndex--;
      }

      state = state.copyWith(
        songs: updatedSongs,
        queueLength: updatedSongs.length,
        currentIndex: newCurrentIndex,
      );

      // Then sync with the audio service
      await _service.removeFromQueue(index);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Moves a song from [oldIndex] to [newIndex] in the queue.
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    try {
      await _service.moveInQueue(oldIndex, newIndex);

      final updatedSongs = List<Song>.from(state.songs);
      final song = updatedSongs.removeAt(oldIndex);
      updatedSongs.insert(newIndex, song);

      // Adjust currentIndex to follow the currently playing song
      int newCurrentIndex = state.currentIndex ?? 0;
      if (oldIndex == newCurrentIndex) {
        newCurrentIndex = newIndex;
      } else if (oldIndex < newCurrentIndex && newIndex >= newCurrentIndex) {
        newCurrentIndex--;
      } else if (oldIndex > newCurrentIndex && newIndex <= newCurrentIndex) {
        newCurrentIndex++;
      }

      state = state.copyWith(
        songs: updatedSongs,
        currentIndex: newCurrentIndex,
      );
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
