import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../../audio_player/domain/repositories/audio_repository.dart';
import '../../../audio_player/data/repositories/audio_repository_impl.dart';

class LibraryState {
  final List<Song> songs;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const LibraryState({
    this.songs = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  LibraryState copyWith({
    List<Song>? songs,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return LibraryState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Song> get filteredSongs {
    if (searchQuery.isEmpty) return songs;
    final lowerQuery = searchQuery.toLowerCase();
    return songs.where((song) {
      return song.title.toLowerCase().contains(lowerQuery) ||
          song.artist.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final AudioRepository _audioRepository;

  LibraryNotifier(this._audioRepository) : super(const LibraryState()) {
    loadSongs();
  }

  Future<void> loadSongs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final songs = await _audioRepository.getLocalSongs();
      state = state.copyWith(songs: songs, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load library: ${e.toString()}',
      );
    }
  }

  Future<void> refreshSongs() async {
    await loadSongs();
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> deleteSong(String filePath) async {
    try {
      await _audioRepository.deleteSong(filePath);
      final updatedSongs = List<Song>.from(state.songs)
        ..removeWhere((s) => s.filePath == filePath);
      state = state.copyWith(songs: updatedSongs);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete song: ${e.toString()}');
    }
  }
}

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepositoryImpl();
});

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final audioRepository = ref.watch(audioRepositoryProvider);
  return LibraryNotifier(audioRepository);
});
