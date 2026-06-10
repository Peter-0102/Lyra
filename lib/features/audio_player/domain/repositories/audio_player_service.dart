import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Abstraction over [AudioPlayer] that the presentation layer depends on.
///
/// All methods are safe to call from any state — the implementation wraps
/// every call in try-catch and translates native exceptions into [AudioPlaybackFailure].
abstract class AudioPlayerService {
  // ---------------------------------------------------------------------------
  // Streams (broadcast — safe to listen from multiple widgets)
  // ---------------------------------------------------------------------------

  /// Current playback state: playing, buffering, completed, etc.
  Stream<PlayerState> get playerStateStream;

  /// Live playhead position, emits roughly every 200 ms.
  Stream<Duration> get positionStream;

  /// Total duration of the loaded track. Emits `null` until a track is loaded.
  Stream<Duration?> get durationStream;

  /// Buffered position — how far ahead has been downloaded/buffered.
  Stream<Duration> get bufferedPositionStream;

  /// The [MediaItem] metadata of the currently loaded track (lock-screen / notification).
  Stream<MediaItem?> get mediaItemStream;

  /// Sequence state for playlist contexts (current index + sequence list).
  Stream<SequenceState?> get sequenceStateStream;

  // ---------------------------------------------------------------------------
  // Synchronous getters (snapshot of the latest value)
  // ---------------------------------------------------------------------------

  bool get isPlaying;

  Duration get position;

  Duration? get duration;

  Duration get bufferedPosition;

  double get volume;

  double get speed;

  LoopMode get loopMode;

  bool get shuffleModeEnabled;

  int? get currentIndex;

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  /// Loads and plays a local audio file (native format or .webm).
  ///
  /// The [tag] metadata is displayed on the OS lock screen and notification shade.
  Future<void> playLocalFile(
    String filePath, {
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUri,
  });

  /// Resumes playback or starts the loaded source.
  Future<void> play();

  /// Pauses playback without losing position.
  Future<void> pause();

  /// Toggles between play and pause.
  Future<void> togglePlayPause();

  /// Stops playback entirely and releases the current source.
  Future<void> stop();

  // ---------------------------------------------------------------------------
  // Seek controls
  // ---------------------------------------------------------------------------

  /// Seeks the playhead to an absolute [position].
  Future<void> seek(Duration position);

  /// Moves the playhead forward by [duration] (clamped to track end).
  Future<void> seekForward(Duration duration);

  /// Moves the playhead backward by [duration] (clamped to 0).
  Future<void> seekBackward(Duration duration);

  // ---------------------------------------------------------------------------
  // Volume & speed
  // ---------------------------------------------------------------------------

  /// Sets volume. 0.0 = mute, 1.0 = full.
  Future<void> setVolume(double volume);

  /// Sets playback speed. 1.0 = normal, 0.5 = half, 2.0 = double.
  Future<void> setSpeed(double speed);

  // ---------------------------------------------------------------------------
  // Loop / shuffle
  // ---------------------------------------------------------------------------

  /// Sets the loop mode (one, all, off).
  Future<void> setLoopMode(LoopMode mode);

  /// Enables or disables shuffle mode.
  Future<void> setShuffleModeEnabled(bool enabled);

  // ---------------------------------------------------------------------------
  // Playlist / queue
  // ---------------------------------------------------------------------------

  /// Loads a concatenated audio source for sequential playback.
  Future<void> setAudioSource(AudioSource source);

  /// Jumps to the next track in the sequence.
  Future<void> skipToNext();

  /// Jumps to the previous track in the sequence.
  Future<void> skipToPrevious();

  /// Jumps to a specific index in the current sequence.
  Future<void> skipToQueueItem(int index);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Releases all native resources. Call when the service is no longer needed.
  Future<void> dispose();
}
