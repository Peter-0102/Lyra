import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../../audio_player/domain/entities/song.dart';

class PlaylistsState {
  final List<Playlist> playlists;
  final bool isLoading;
  final String? error;

  const PlaylistsState({
    this.playlists = const [],
    this.isLoading = false,
    this.error,
  });

  PlaylistsState copyWith({
    List<Playlist>? playlists,
    bool? isLoading,
    String? error,
  }) {
    return PlaylistsState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PlaylistNotifier extends StateNotifier<PlaylistsState> {
  final PlaylistRepository _repository;

  PlaylistNotifier(this._repository)
      : super(const PlaylistsState(isLoading: true)) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final playlists = await _repository.getAllPlaylists();
      state = state.copyWith(playlists: playlists, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load playlists: $e',
      );
    }
  }

  Future<String?> createPlaylist(String name, {String? description}) async {
    try {
      final now = DateTime.now();
      final playlist = Playlist(
        id: '',
        name: name,
        description: description,
        createdAt: now,
        updatedAt: now,
      );
      final id = await _repository.createPlaylist(playlist);
      await loadPlaylists();
      return id;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create playlist: $e');
      return null;
    }
  }

  Future<void> renamePlaylist(String id, String newName) async {
    try {
      final existing = state.playlists.firstWhere((p) => p.id == id);
      await _repository.updatePlaylist(
        existing.copyWith(name: newName, updatedAt: DateTime.now()),
      );
      await loadPlaylists();
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename playlist: $e');
    }
  }

  Future<void> deletePlaylist(String id) async {
    try {
      await _repository.deletePlaylist(id);
      await loadPlaylists();
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete playlist: $e');
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    try {
      await _repository.addSongToPlaylist(playlistId, song);
      await loadPlaylists();
    } catch (e) {
      state = state.copyWith(error: 'Failed to add song to playlist: $e');
    }
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    try {
      await _repository.removeSongFromPlaylist(playlistId, songId);
      await loadPlaylists();
    } catch (e) {
      state =
          state.copyWith(error: 'Failed to remove song from playlist: $e');
    }
  }

  Future<void> reorderSongs(
      String playlistId, int oldIndex, int newIndex) async {
    try {
      await _repository.reorderSongs(playlistId, oldIndex, newIndex);
      await loadPlaylists();
    } catch (e) {
      state = state.copyWith(error: 'Failed to reorder songs: $e');
    }
  }
}

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return sl<PlaylistRepository>();
});

final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, PlaylistsState>((ref) {
  final repository = ref.watch(playlistRepositoryProvider);
  return PlaylistNotifier(repository);
});
