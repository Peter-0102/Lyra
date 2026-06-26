import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile> getProfile();
  Future<void> updateUsername(String username);
  Future<void> updateSettings(Map<String, dynamic> settings);
  Future<Map<String, dynamic>> getSettings();
}
