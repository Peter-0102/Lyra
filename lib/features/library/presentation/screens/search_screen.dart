import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../download/domain/utils/duplicate_detector.dart';
import '../../../download/presentation/providers/download_provider.dart';
import '../providers/library_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Video> _results = [];
  bool _isLoading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed == _lastQuery) return;

    print('[DOWNLOAD] UI: Search initiated => "$trimmed"');
    setState(() {
      _isLoading = true;
      _error = null;
      _lastQuery = trimmed;
    });

    try {
      final yt = sl<YoutubeExplode>();
      final results = await yt.search.search(trimmed);
      print('[DOWNLOAD] UI: Search returned ${results.length} results');
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[DOWNLOAD] UI: Search FAILED => $e');
      if (mounted) {
        setState(() {
          _error = 'Search failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Search YouTube'),
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: AppColors.textPrimaryDark),
              decoration: InputDecoration(
                hintText: 'Search songs, artists...',
                hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondaryDark),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.textSecondaryDark),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Active downloads indicator
          if (downloadState.isBusy || downloadState.totalPending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withAlpha(26),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    downloadState.totalPending > 0
                        ? 'Downloading ${downloadState.totalActive} track(s), ${downloadState.totalPending} in queue...'
                        : 'Downloading ${downloadState.totalActive} track(s)...',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          // Results
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondaryDark),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _search(_controller.text),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty && _lastQuery.isNotEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: AppColors.textSecondaryDark, size: 48),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                  color: AppColors.textSecondaryDark, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline,
                color: AppColors.textSecondaryDark, size: 64),
            SizedBox(height: 16),
            Text(
              'Search for songs on YouTube',
              style: TextStyle(
                  color: AppColors.textSecondaryDark, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final video = _results[index];
        return _YouTubeResultTile(video: video);
      },
    );
  }
}

class _YouTubeResultTile extends ConsumerWidget {
  final Video video;
  const _YouTubeResultTile({required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final videoId = video.id.toString();
    final isDownloading = downloadState.activeDownloads.containsKey(videoId);
    final activeItem = downloadState.activeDownloads[videoId];

    final duration = video.duration;
    final durationText = duration != null
        ? '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}'
        : '--:--';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Play from YouTube source (for now, show info)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download to play: ${video.title}', style: TextStyle(color: AppColors.onPrimary), ),
              backgroundColor: AppColors.cardDark,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Thumbnail
              Stack(
                children: [
                  Container(
                    width: 120,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.cardDark,
                    ),
                    child: video.thumbnails.highResUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              video.thumbnails.highResUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => const Center(
                                child: Icon(Icons.music_note,
                                    color: AppColors.textSecondaryDark),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.music_note,
                                color: AppColors.textSecondaryDark),
                          ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(179),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durationText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.author,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                    if (isDownloading && activeItem != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: activeItem.progress,
                              backgroundColor: AppColors.playerProgressBackground,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.playerProgress),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(activeItem.progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Download button
              const SizedBox(width: 8),
              _DownloadButton(video: video),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  final Video video;
  const _DownloadButton({required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final authState = ref.watch(authProvider);
    final videoId = video.id.toString();
    final isDownloading = downloadState.activeDownloads.containsKey(videoId);
    final activeItem = downloadState.activeDownloads[videoId];
    final isCompleted = downloadState.isBusyOrDone(videoId);
    final isQueued = downloadState.pendingQueue.any((d) => d.videoId == videoId);
    final queuePosition = downloadState.pendingQueue
        .where((d) => d.videoId == videoId)
        .map((d) => d.queuePosition)
        .firstOrNull;

    final failedItem = downloadState.failedDownloads
        .where((d) => d.videoId == videoId)
        .toList();

    if (isCompleted && !isDownloading && !isQueued) {
      return const Icon(Icons.check_circle, color: AppColors.primary, size: 28);
    }

    if (isQueued && !isDownloading) {
      return Tooltip(
        message: 'In queue (position $queuePosition)',
        child: Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.textSecondaryDark,
                value: null,
              ),
            ),
            Text(
              '$queuePosition',
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isDownloading && activeItem != null) {
      if (activeItem.status == DownloadState.error ||
          activeItem.status == DownloadState.cancelled) {
        return IconButton(
          icon: const Icon(Icons.error_outline, color: AppColors.error, size: 28),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(activeItem.errorMessage ?? 'Download failed'),
                backgroundColor: AppColors.cardDark,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      }

      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      );
    }

    if (failedItem.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.error, size: 26),
        onPressed: () {
          ref.read(downloadProvider.notifier).retryDownload(videoId);
        },
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_rounded,
          color: AppColors.textSecondaryDark, size: 26),
      onPressed: () async {
        if (!authState.isAuthenticated) {
          _showAuthRequiredDialog(context);
          return;
        }

        final libraryState = ref.read(libraryProvider);
        final duplicates = findDuplicateSongs(
          libraryState.songs,
          video.title,
          video.author,
        );

        if (duplicates.isNotEmpty) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.cardDark,
              title: const Text(
                'Already in library?',
                style: TextStyle(color: AppColors.textPrimaryDark),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Similar songs found in your library:',
                    style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...duplicates.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note_rounded,
                            color: AppColors.textSecondaryDark, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: const TextStyle(
                                    color: AppColors.textPrimaryDark, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                s.artist,
                                style: const TextStyle(
                                    color: AppColors.textSecondaryDark, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (duplicates.length > 3)
                    Text(
                      '+${duplicates.length - 3} more',
                      style: const TextStyle(
                          color: AppColors.textSecondaryDark, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Download anyway?',
                    style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Download',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }

        final videoId = video.id.toString();
        final isCurrentlyBusy = ref.read(downloadProvider).isBusy;
        ref.read(downloadProvider.notifier).startDownload(
              videoId,
              video.title,
              video.author,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCurrentlyBusy
                    ? 'Queued: ${video.title}'
                    : 'Downloading: ${video.title}',
              ),
              backgroundColor: AppColors.cardDark,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
}

void _showAuthRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_rounded,
            color: AppColors.primary,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Sign in to download songs',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Downloads require an authenticated account. Create one to start building your offline library.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push('/register');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/login');
            },
            child: Text(
              'I already have an account',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
