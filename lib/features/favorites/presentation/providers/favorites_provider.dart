import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../domain/repositories/favorites_repository.dart';

class FavoritesState {
  final List<Song> favorites;
  final Set<String> favoriteIds;
  final bool isLoading;

  const FavoritesState({
    this.favorites = const [],
    this.favoriteIds = const {},
    this.isLoading = false,
  });

  FavoritesState copyWith({
    List<Song>? favorites,
    Set<String>? favoriteIds,
    bool? isLoading,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final FavoritesRepository _repository;

  FavoritesNotifier(this._repository) : super(const FavoritesState()) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true);
    try {
      final favorites = await _repository.getAllFavorites();
      final ids = favorites.map((s) => s.id).toSet();
      state = state.copyWith(
        favorites: favorites,
        favoriteIds: ids,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleFavorite(Song song) async {
    if (state.favoriteIds.contains(song.id)) {
      await _repository.removeFavorite(song.id);
      final updated = state.favorites.where((s) => s.id != song.id).toList();
      final ids = Set<String>.from(state.favoriteIds)..remove(song.id);
      state = state.copyWith(favorites: updated, favoriteIds: ids);
    } else {
      await _repository.addFavorite(song);
      final updated = [song, ...state.favorites];
      final ids = Set<String>.from(state.favoriteIds)..add(song.id);
      state = state.copyWith(favorites: updated, favoriteIds: ids);
    }
  }

  Future<bool> isFavorite(String songId) async {
    if (state.favoriteIds.contains(songId)) return true;
    final result = await _repository.isFavorite(songId);
    return result;
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return sl<FavoritesRepository>();
});

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  final repository = ref.watch(favoritesRepositoryProvider);
  return FavoritesNotifier(repository);
});
