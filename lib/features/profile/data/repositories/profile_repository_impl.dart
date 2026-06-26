import 'package:dio/dio.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final Dio _dio;

  ProfileRepositoryImpl(this._dio);

  @override
  Future<Profile> getProfile() async {
    final response = await _dio.get('/api/auth/me');
    final data = response.data as Map<String, dynamic>;
    final userData = data['user'];
    if (userData is! Map<String, dynamic>) {
      throw FormatException('Invalid profile response: missing user object');
    }
    return Profile.fromJson(userData);
  }

  @override
  Future<void> updateUsername(String username) async {
    await _dio.put('/api/auth/settings', data: {
      'username': username,
    });
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    await _dio.put('/api/auth/settings', data: settings);
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _dio.get('/api/auth/settings');
    final data = response.data as Map<String, dynamic>;
    return data['settings'] as Map<String, dynamic>? ?? {};
  }
}
