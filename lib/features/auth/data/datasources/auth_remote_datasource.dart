import 'package:dio/dio.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw FormatException('Unexpected response type: ${data.runtimeType}');
  }

  Future<Map<String, dynamic>> register(
      String email, String password, String username) async {
    final response = await _dio.post('/api/auth/register', data: {
      'email': email,
      'password': password,
      'username': username,
    });
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post('/api/auth/refresh', data: {
      'refreshToken': refreshToken,
    });
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/api/auth/me');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _dio.get('/api/auth/settings');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateSettings(
      Map<String, dynamic> settings) async {
    final response = await _dio.put('/api/auth/settings', data: settings);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> syncFavorites(
      List<Map<String, dynamic>> favorites) async {
    final response = await _dio.post('/api/sync/favorites',
        data: {'favorites': favorites});
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> syncPlaylists(
      List<Map<String, dynamic>> playlists) async {
    final response = await _dio.post('/api/sync/playlists',
        data: {'playlists': playlists});
    return _asMap(response.data);
  }
}
