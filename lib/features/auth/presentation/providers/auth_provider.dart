import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../playlists/domain/repositories/playlist_repository.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final isAuth = await _repository.isAuthenticated();
      if (isAuth) {
        final user = await _repository.getCurrentUser();
        state = AuthState(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
      } else {
        state = const AuthState(isLoading: false);
      }
    } catch (e) {
      print('[Auth] _init error: $e');
      state = const AuthState(isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.login(email, password);
      state = AuthState(user: user, isAuthenticated: true, isLoading: false);
      _migrateLocalData();
      return true;
    } catch (e) {
      print('[Auth] Login error: $e');
      print('[Auth] Login error type: ${e.runtimeType}');
      state = state.copyWith(
        isLoading: false,
        error: _parseAuthError(e),
      );
      return false;
    }
  }

  Future<bool> register(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.register(email, password, username);
      state = AuthState(user: user, isAuthenticated: true, isLoading: false);
      _migrateLocalData();
      return true;
    } catch (e) {
      print('[Auth] Register error: $e');
      print('[Auth] Register error type: ${e.runtimeType}');
      state = state.copyWith(
        isLoading: false,
        error: _parseAuthError(e),
      );
      return false;
    }
  }

  String _parseAuthError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Could not connect to server. Check your internet connection.';
      }
      if (error.response?.data is Map) {
        final data = error.response!.data as Map;
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) return 'Invalid email or password.';
      if (statusCode == 409) return 'An account with this email already exists.';
      if (statusCode == 422) return 'Invalid input. Please check your information.';
      if (statusCode != null && statusCode >= 500) {
        return 'Server error. Please try again later.';
      }
    }
    if (error is TypeError) {
      print('[Auth] TypeError details: $error');
      print('[Auth] Stack trace: ${StackTrace.current}');
      return 'Unexpected response from server. Please try again.';
    }
    print('[Auth] Unhandled error type: ${error.runtimeType}');
    return 'Something went wrong. Please try again.';
  }

  Future<void> _migrateLocalData() async {
    try {
      final favoritesRepo = sl<FavoritesRepository>();
      final playlistsRepo = sl<PlaylistRepository>();

      final localFavorites = await favoritesRepo.getAllFavorites();
      if (localFavorites.isNotEmpty) {
        final favoritesJson = localFavorites
            .map((s) => s.toJson())
            .toList();
        await _repository.syncFavorites(favoritesJson);
      }

      final localPlaylists = await playlistsRepo.getAllPlaylists();
      if (localPlaylists.isNotEmpty) {
        final playlistsJson = localPlaylists.map((p) => p.toJson()).toList();
        await _repository.syncPlaylists(playlistsJson);
      }
    } catch (e) {
      print('[Auth] Local data migration error: $e');
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return sl<AuthRepository>();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
