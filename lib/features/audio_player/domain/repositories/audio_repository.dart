import '../entities/song.dart';

abstract class AudioRepository {
  /// Scans the local application documents directory for audio files
  /// and returns a list of Song entities.
  Future<List<Song>> getLocalSongs();

  /// Scans local storage and filters songs by the given query string.
  Future<List<Song>> searchLocalSongs(String query);

  /// Deletes a downloaded song file from local storage.
  Future<void> deleteSong(String filePath);

  /// Checks if a specific song file exists on local storage.
  Future<bool> songExists(String filePath);
}
