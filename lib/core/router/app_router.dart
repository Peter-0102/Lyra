import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/library/presentation/screens/home_screen.dart';
import '../../../features/audio_player/presentation/screens/player_screen.dart';
import '../../../features/audio_player/presentation/screens/queue_screen.dart';
import '../../../features/playlists/presentation/screens/playlist_detail_screen.dart';
import '../../../features/auth/presentation/screens/settings_screen.dart';
import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/auth/presentation/screens/register_screen.dart';
import '../../../features/auth/presentation/screens/welcome_screen.dart';
import '../../../features/profile/presentation/screens/profile_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({required bool showWelcome}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: showWelcome ? '/welcome' : '/',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PlayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/queue',
        builder: (context, state) => const QueueScreen(),
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PlaylistDetailScreen(playlistId: id);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
}
