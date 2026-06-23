import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            'Liked Songs',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            '${state.favorites.length} liked songs',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : state.favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_border_rounded,
                              color: AppColors.textSecondaryDark, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'No liked songs yet',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the heart icon on any song\nto add it to your favorites',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.cardDark,
                      onRefresh: () async {
                        await ref.read(favoritesProvider.notifier).loadFavorites();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: state.favorites.length,
                        itemBuilder: (context, index) {
                          final song = state.favorites[index];
                          return SongListTile(
                            song: song,
                            index: index,
                            allSongs: state.favorites,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
