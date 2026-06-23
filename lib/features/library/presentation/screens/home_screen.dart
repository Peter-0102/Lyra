import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../audio_player/presentation/widgets/mini_player.dart';
import '../../../playlists/presentation/screens/playlist_list_screen.dart';
import '../../../favorites/presentation/screens/favorites_screen.dart';
import '../providers/library_provider.dart';
import '../widgets/song_list_tile.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _LibraryTab(),
      const SearchScreen(),
      const FavoritesScreen(),
      const PlaylistListScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              Expanded(
                child: pages[_currentIndex],
              ),
              // Mini player
              const MiniPlayer(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryVariant,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondaryDark,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music_rounded),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_rounded),
                label: 'Favorites',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.playlist_play_rounded),
                label: 'Playlists',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            'Your Library',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            '${libraryState.songs.length} songs downloaded',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
        ),
        // Refresh button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: AppColors.textPrimaryDark),
                  decoration: InputDecoration(
                    hintText: 'Search your library...',
                    hintStyle: const TextStyle(
                        color: AppColors.textSecondaryDark, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondaryDark, size: 20),
                    filled: true,
                    fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (q) {
                    ref.read(libraryProvider.notifier).search(q);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondaryDark),
                onPressed: () {
                  ref.read(libraryProvider.notifier).refreshSongs();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Song list
        Expanded(
          child: libraryState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : libraryState.songs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_off,
                              color: AppColors.textSecondaryDark, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'No songs yet',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Search YouTube and download songs\nto build your library',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Switch to search tab
                              final homeState = context
                                  .findAncestorStateOfType<_HomeScreenState>();
                              if (homeState != null) {
                                homeState.setState(() {
                                  homeState._currentIndex = 1;
                                });
                              }
                            },
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Search YouTube'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.cardDark,
                      onRefresh: () async {
                        await ref
                            .read(libraryProvider.notifier)
                            .refreshSongs();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: libraryState.filteredSongs.length,
                        itemBuilder: (context, index) {
                          final song = libraryState.filteredSongs[index];
                          return Dismissible(
                            key: ValueKey(song.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppColors.error,
                              child: const Icon(Icons.delete_rounded,
                                  color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.cardDark,
                                  title: const Text('Delete song?',
                                      style: TextStyle(
                                          color: AppColors.textPrimaryDark)),
                                  content: Text(
                                    'Remove "${song.title}" from your library?',
                                    style: const TextStyle(
                                        color: AppColors.textSecondaryDark),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Delete',
                                          style: TextStyle(
                                              color: AppColors.error)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) {
                              ref
                                  .read(libraryProvider.notifier)
                                  .deleteSong(song.filePath);
                            },
                            child: SongListTile(
                              song: song,
                              index: index,
                              allSongs: libraryState.filteredSongs,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}


