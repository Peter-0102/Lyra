import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../download/presentation/providers/download_provider.dart';

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

    setState(() {
      _isLoading = true;
      _error = null;
      _lastQuery = trimmed;
    });

    try {
      final yt = sl<YoutubeExplode>();
      final results = await yt.search.search(trimmed);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
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
          if (downloadState.isBusy)
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
                    'Downloading ${downloadState.totalActive} track(s)...',
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
              content: Text('Download to play: ${video.title}'),
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
    final videoId = video.id.toString();
    final isDownloading = downloadState.activeDownloads.containsKey(videoId);
    final isCompleted = downloadState.isBusyOrDone(videoId);

    if (isCompleted) {
      return const Icon(Icons.check_circle, color: AppColors.primary, size: 28);
    }

    if (isDownloading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_rounded,
          color: AppColors.textSecondaryDark, size: 26),
      onPressed: () {
        ref.read(downloadProvider.notifier).startDownload(
              videoId,
              video.title,
              video.author,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading: ${video.title}'),
            backgroundColor: AppColors.cardDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
