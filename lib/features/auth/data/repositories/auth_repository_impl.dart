import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  AuthRepositoryImpl(this._remote, this._local);

  @override
  Future<User> login(String email, String password) async {
    final data = await _remote.login(email, password);
    print('[AuthRepo] login response keys: ${data.keys}');
    final userJson = data['user'];
    print('[AuthRepo] userJson type: ${userJson.runtimeType}');
    if (userJson is! Map<String, dynamic>) {
      throw FormatException('Unexpected user data type: ${userJson.runtimeType}');
    }
    final user = User.fromJson(userJson);
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw FormatException('Invalid token types: access=${accessToken.runtimeType}, refresh=${refreshToken.runtimeType}');
    }
    await _local.saveTokens(accessToken, refreshToken);
    await _local.saveUser(user);
    return user;
  }

  @override
  Future<User> register(
      String email, String password, String username) async {
    final data = await _remote.register(email, password, username);
    print('[AuthRepo] register response keys: ${data.keys}');
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw FormatException('Unexpected user data type: ${userJson.runtimeType}');
    }
    final user = User.fromJson(userJson);
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw FormatException('Invalid token types: access=${accessToken.runtimeType}, refresh=${refreshToken.runtimeType}');
    }
    await _local.saveTokens(accessToken, refreshToken);
    await _local.saveUser(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await _local.clear();
  }

  @override
  Future<String> refreshToken() async {
    final oldRefresh = await _local.getRefreshToken();
    if (oldRefresh == null) throw Exception('No refresh token');
    final data = await _remote.refreshToken(oldRefresh);
    print('[AuthRepo] refreshToken response keys: ${data.keys}');
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw FormatException('Invalid token types in refresh');
    }
    await _local.saveTokens(accessToken, refreshToken);
    final userJson = data['user'];
    if (userJson is Map<String, dynamic>) {
      await _local.saveUser(User.fromJson(userJson));
    }
    return accessToken;
  }

  @override
  Future<User?> getCurrentUser() async {
    return _local.getUser();
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _local.getAccessToken();
    return token != null;
  }

  @override
  Future<String?> getAccessToken() async {
    return _local.getAccessToken();
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _remote.forgotPassword(email);
  }

  @override
  Future<void> resetPassword(String code, String newPassword) async {
    await _remote.resetPassword(code, newPassword);
  }

  @override
  Future<void> syncFavorites(List<Map<String, dynamic>> favorites) async {
    await _remote.syncFavorites(favorites);
  }

  @override
  Future<void> syncPlaylists(List<Map<String, dynamic>> playlists) async {
    await _remote.syncPlaylists(playlists);
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final data = await _remote.getSettings();
    return data['settings'] as Map<String, dynamic>? ?? {};
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    await _remote.updateSettings(settings);
  }
}
