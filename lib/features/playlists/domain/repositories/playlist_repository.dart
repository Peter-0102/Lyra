import '../../domain/entities/playlist.dart';
import '../../../audio_player/domain/entities/song.dart';

abstract class PlaylistRepository {
  Future<void> initialize();
  Future<List<Playlist>> getAllPlaylists();
  Future<Playlist?> getPlaylist(String id);
  Future<String> createPlaylist(Playlist playlist);
  Future<void> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addSongToPlaylist(String playlistId, Song song);
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
  Future<void> reorderSongs(String playlistId, int oldIndex, int newIndex);
}
