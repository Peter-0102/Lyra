import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/audio_player_service.dart';

class AudioPlayerServiceImpl implements AudioPlayerService {
  final AudioPlayer _player;

  AudioPlayerServiceImpl({required AudioPlayer player}) : _player = player;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<MediaItem?> get mediaItemStream => _player.sequenceStateStream.map(
        (state) {
          final tag = state?.currentSource?.tag;
          if (tag is MediaItem) return tag;
          return null;
        },
      );

  @override
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  // ---------------------------------------------------------------------------
  // Synchronous getters
  // ---------------------------------------------------------------------------

  @override
  bool get isPlaying => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  double get volume => _player.volume;

  @override
  double get speed => _player.speed;

  @override
  LoopMode get loopMode => _player.loopMode;

  @override
  bool get shuffleModeEnabled => _player.shuffleModeEnabled;

  @override
  int? get currentIndex => _player.currentIndex;

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> playLocalFile(
    String filePath, {
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUri,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const AudioPlaybackFailure('Audio file not found on device.');
      }

      final audioSource = AudioSource.file(
        filePath,
        tag: MediaItem(
          id: id,
          album: album ?? 'Mispoti',
          title: title,
          artist: artist,
          artUri: artUri != null ? Uri.parse(artUri) : null,
        ),
      );

      await _player.setAudioSource(audioSource);
      await _player.play();
    } on AudioPlaybackFailure {
      rethrow;
    } catch (e) {
      throw AudioPlaybackFailure('Failed to load audio file: $e');
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      throw AudioPlaybackFailure('Play command failed: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      throw AudioPlaybackFailure('Pause command failed: $e');
    }
  }

  @override
  Future<void> togglePlayPause() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e) {
      throw AudioPlaybackFailure('Toggle play/pause failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      throw AudioPlaybackFailure('Stop command failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Seek controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> seek(Duration position) async {
    try {
      final total = _player.duration;
      if (total != null && position.isNegative) {
        await _player.seek(Duration.zero);
      } else if (total != null && position > total) {
        await _player.seek(total);
      } else {
        await _player.seek(position);
      }
    } catch (e) {
      throw AudioPlaybackFailure('Seek command failed: $e');
    }
  }

  @override
  Future<void> seekForward(Duration duration) async {
    try {
      final current = _player.position;
      final total = _player.duration ?? Duration.zero;
      final target = current + duration;
      await _player.seek(target > total ? total : target);
    } catch (e) {
      throw AudioPlaybackFailure('Seek forward failed: $e');
    }
  }

  @override
  Future<void> seekBackward(Duration duration) async {
    try {
      final current = _player.position;
      final target = current - duration;
      await _player.seek(target.isNegative ? Duration.zero : target);
    } catch (e) {
      throw AudioPlaybackFailure('Seek backward failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Volume & speed
  // ---------------------------------------------------------------------------

  @override
  Future<void> setVolume(double volume) async {
    try {
      final clamped = volume.clamp(0.0, 1.0);
      await _player.setVolume(clamped);
    } catch (e) {
      throw AudioPlaybackFailure('Set volume failed: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      // just_audio accepts 0.5 to 2.0 on most platforms
      final clamped = speed.clamp(0.5, 2.0);
      await _player.setSpeed(clamped);
    } catch (e) {
      throw AudioPlaybackFailure('Set speed failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Loop / shuffle
  // ---------------------------------------------------------------------------

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    try {
      await _player.setLoopMode(mode);
    } catch (e) {
      throw AudioPlaybackFailure('Set loop mode failed: $e');
    }
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    try {
      await _player.setShuffleModeEnabled(enabled);
    } catch (e) {
      throw AudioPlaybackFailure('Set shuffle mode failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Playlist / queue
  // ---------------------------------------------------------------------------

  @override
  Future<void> setAudioSource(AudioSource source) async {
    try {
      await _player.setAudioSource(source);
    } catch (e) {
      throw AudioPlaybackFailure('Set audio source failed: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
      }
    } catch (e) {
      throw AudioPlaybackFailure('Skip to next failed: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
      }
    } catch (e) {
      throw AudioPlaybackFailure('Skip to previous failed: $e');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      final sequence = _player.sequence;
      if (sequence != null && index >= 0 && index < sequence.length) {
        await _player.seek(Duration.zero, index: index);
      }
    } catch (e) {
      throw AudioPlaybackFailure('Skip to queue item failed: $e');
    }
  }

  @override
  Future<void> insertIntoQueue(int index, AudioSource source) async {
    try {
      final audioSource = _player.audioSource;
      if (audioSource is ConcatenatingAudioSource) {
        await audioSource.insert(index, source);
      }
    } catch (e) {
      throw AudioPlaybackFailure('Insert into queue failed: $e');
    }
  }

  @override
  Future<void> removeFromQueue(int index) async {
    try {
      final audioSource = _player.audioSource;
      if (audioSource is ConcatenatingAudioSource) {
        await audioSource.removeAt(index);
      }
    } catch (e) {
      throw AudioPlaybackFailure('Remove from queue failed: $e');
    }
  }

  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    try {
      final audioSource = _player.audioSource;
      if (audioSource is ConcatenatingAudioSource) {
        await audioSource.move(oldIndex, newIndex);
      }
    } catch (e) {
      throw AudioPlaybackFailure('Move in queue failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {
      // Best-effort cleanup
    }
  }
}
