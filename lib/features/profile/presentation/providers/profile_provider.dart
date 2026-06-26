import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileState {
  final Profile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  ProfileState copyWith({
    Profile? profile,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(const ProfileState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _repository.getProfile();
      state = ProfileState(profile: profile, isLoading: false);
    } catch (e) {
      state = ProfileState(error: 'Failed to load profile: $e', isLoading: false);
    }
  }

  Future<bool> updateUsername(String username) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _repository.updateUsername(username);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: 'Failed to update: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _load();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return sl<ProfileRepository>();
});

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repository);
});
