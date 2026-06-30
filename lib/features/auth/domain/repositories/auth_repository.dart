import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<User> register(String email, String password, String username);
  Future<void> logout();
  Future<String> refreshToken();
  Future<User?> getCurrentUser();
  Future<bool> isAuthenticated();
  Future<String?> getAccessToken();
  Future<void> syncFavorites(List<Map<String, dynamic>> favorites);
  Future<void> syncPlaylists(List<Map<String, dynamic>> playlists);
  Future<Map<String, dynamic>> getSettings();
  Future<void> updateSettings(Map<String, dynamic> settings);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String code, String newPassword);
}
