import '../../../audio_player/domain/entities/song.dart';

abstract class FavoritesRepository {
  Future<List<Song>> getAllFavorites();
  Future<void> addFavorite(Song song);
  Future<void> removeFavorite(String songId);
  Future<bool> isFavorite(String songId);
}
