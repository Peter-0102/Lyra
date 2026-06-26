import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../playlists/domain/repositories/playlist_repository.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);

    if (!state.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_rounded,
                color: AppColors.textSecondaryDark, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Not signed in',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to sync your data\nacross devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withAlpha(51),
                child: Text(
                  (state.user!.username.isNotEmpty
                          ? state.user!.username[0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                state.user!.username,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                state.user!.email,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Account',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.person_rounded,
          title: 'Profile',
          subtitle: 'View and edit your profile',
          onTap: () => context.push('/profile'),
        ),
        _SettingsTile(
          icon: Icons.history_rounded,
          title: 'Listening History',
          subtitle: 'View your recently played songs',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
        ),
        _SettingsTile(
          icon: Icons.sync_rounded,
          title: 'Sync Data',
          subtitle: 'Upload your favorites and playlists',
          onTap: () => _syncData(context, ref),
        ),
        _SettingsTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          subtitle: 'You can sign in again anytime',
          onTap: () => _logout(context, ref),
        ),
      ],
    );
  }

  Future<void> _syncData(BuildContext context, WidgetRef ref) async {
    try {
      final favoritesRepo = sl<FavoritesRepository>();
      final playlistsRepo = sl<PlaylistRepository>();
      final authRepo = sl<AuthRepository>();

      final localFavorites = await favoritesRepo.getAllFavorites();
      if (localFavorites.isNotEmpty) {
        await authRepo.syncFavorites(
          localFavorites.map((s) => s.toJson()).toList(),
        );
      }

      final localPlaylists = await playlistsRepo.getAllPlaylists();
      if (localPlaylists.isNotEmpty) {
        await authRepo.syncPlaylists(
          localPlaylists.map((p) => p.toJson()).toList(),
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Sign Out?',
            style: TextStyle(color: AppColors.textPrimaryDark)),
        content: const Text(
          'Your local favorites and playlists will remain on this device.',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textPrimaryDark, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondaryDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
