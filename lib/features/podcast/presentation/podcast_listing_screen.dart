import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:isai/main.dart';
import '../data/podcast_models.dart';
import '../data/podcast_api_service.dart';
import 'podcast_providers.dart';
import 'podcast_detail_screen.dart';
import 'podcast_now_playing_screen.dart';

class PodcastsSubScreen extends ConsumerStatefulWidget {
  const PodcastsSubScreen({super.key});

  @override
  ConsumerState<PodcastsSubScreen> createState() => _PodcastsSubScreenState();
}

class _PodcastsSubScreenState extends ConsumerState<PodcastsSubScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const Map<String, IconData> _genreIcons = {
    'Comedy': Icons.theater_comedy_rounded,
    'Technology': Icons.computer_rounded,
    'Science': Icons.science_rounded,
    'News': Icons.newspaper_rounded,
    'Music': Icons.music_note_rounded,
    'History': Icons.history_rounded,
    'True Crime': Icons.local_police_rounded,
    'Business': Icons.business_rounded,
    'Health': Icons.favorite_rounded,
    'Education': Icons.school_rounded,
    'Sports': Icons.sports_rounded,
    'TV & Film': Icons.tv_rounded,
    'Religion': Icons.church_rounded,
    'Society': Icons.people_rounded,
    'Arts': Icons.palette_rounded,
    'Fiction': Icons.auto_stories_rounded,
    'Kids & Family': Icons.family_restroom_rounded,
    'Leisure': Icons.self_improvement_rounded,
    'Government': Icons.account_balance_rounded,
    'How To': Icons.tips_and_updates_rounded,
  };

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PodcastSearchScreen(query: query.trim()),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(podcastTrendingProvider);
    final recentAsync = ref.watch(podcastRecentProvider);
    final followed = ref.watch(podcastFollowedProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search podcasts...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
              ],
              onChanged: _onSearchChanged,
            ),
          ),
          if (followed.isNotEmpty) _buildFollowedSection(followed),
          _buildContinueListening(),
          _buildTrendingSection(trendingAsync),
          _buildRecentSection(recentAsync),
          _buildGenreCatalogs(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFollowedSection(Set<int> followedIds) {
    return ref.watch(podcastFollowedDetailsProvider).when(
      data: (podcasts) {
        if (podcasts.isEmpty) return const SizedBox.shrink();
        return _buildHorizontalSection(
          title: 'Your Podcasts',
          icon: Icons.favorite_rounded,
          podcasts: podcasts,
        );
      },
      loading: () => _buildLoadingSection(180),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContinueListening() {
    final items = ref.watch(continueListeningProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 20,
                color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Continue Listening',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        for (final item in items)
          item.isLive
              ? _buildLiveContinueCard(item)
              : _buildSavedContinueCard(item),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLiveContinueCard(ContinueListeningData current) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      initialData: audioHandler.playbackState.value,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final position = state?.position ?? Duration.zero;
        final playing = state?.playing ?? false;
        final progress = current.duration.inMilliseconds > 0
            ? (position.inMilliseconds / current.duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        final remaining = current.duration - position;
        final remainingStr = _formatRemaining(remaining);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildContinueCard(
            current: current,
            progress: progress,
            subtitle: remainingStr,
            trailing: Icon(
              playing ? Icons.pause_circle_filled : Icons.play_circle_fill_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PodcastNowPlayingScreen.fromMediaItem(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSavedContinueCard(ContinueListeningData current) {
    final progress = current.duration.inMilliseconds > 0
        ? (current.position.inMilliseconds / current.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final remaining = current.duration - current.position;
    final remainingStr = _formatRemaining(remaining);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildContinueCard(
        current: current,
        progress: progress,
        subtitle: remainingStr,
        trailing: Icon(
          Icons.play_circle_fill_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 36,
        ),
        onTap: () async {
          final isSame = audioHandler.mediaItem.value?.id == current.audioUrl
              || audioHandler.mediaItem.value?.id == current.episodeId;
          if (isSame) {
            await audioHandler.play();
            await audioHandler.seek(current.position);
          } else {
            final url = current.audioUrl;
            final resolved = url.isNotEmpty ? await PodcastApiService.resolveAudioUrl(url) : url;
            await audioHandler.customAction('play', {
              'url': resolved,
              'title': current.episodeTitle,
              'artist': current.podcastArtist,
              'artworkUrl': current.podcastArtwork ?? '',
              'forceReplace': true,
              'mediaType': 'podcast',
              'extras': {
                'mediaType': 'podcast',
                'podcastTitle': current.podcastTitle,
                'podcastArtist': current.podcastArtist,
                'podcastArtwork': current.podcastArtwork ?? '',
                'episodeTitle': current.episodeTitle,
                'episodeDuration': current.duration.inSeconds,
                'feedUrl': current.feedUrl ?? '',
              },
            });
            await Future.delayed(const Duration(milliseconds: 500));
            await audioHandler.seek(current.position);
          }
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PodcastNowPlayingScreen.fromMediaItem(),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildContinueCard({
    required ContinueListeningData current,
    required double progress,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: current.podcastArtwork != null
                      ? CachedNetworkImage(
                          imageUrl: current.podcastArtwork!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.podcasts, size: 28),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.podcasts, size: 28),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.episodeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        current.podcastTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRemaining(Duration remaining) {
    if (remaining.inMilliseconds < 0) remaining = Duration.zero;
    if (remaining.inHours > 0) {
      final h = remaining.inHours;
      final m = remaining.inMinutes.remainder(60);
      return '${h}h ${m.toString().padLeft(2, '0')}m left';
    }
    if (remaining.inMinutes > 0) {
      final m = remaining.inMinutes;
      final s = remaining.inSeconds.remainder(60);
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} left';
    }
    return '${remaining.inSeconds}s left';
  }

  Widget _buildTrendingSection(AsyncValue<List<PodcastSeries>> async) {
    return async.when(
      data: (podcasts) {
        if (podcasts.isEmpty) return const SizedBox.shrink();
        return _buildHorizontalSection(
          title: 'Trending Podcasts',
          icon: Icons.trending_up_rounded,
          podcasts: podcasts,
        );
      },
      loading: () => _buildLoadingSection(180),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentSection(AsyncValue<List<PodcastSeries>> async) {
    return async.when(
      data: (podcasts) {
        if (podcasts.isEmpty) return const SizedBox.shrink();
        return _buildHorizontalSection(
          title: 'New & Noteworthy',
          icon: Icons.fiber_new_rounded,
          podcasts: podcasts,
        );
      },
      loading: () => _buildLoadingSection(180),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHorizontalSection({
    required String title,
    required IconData icon,
    required List<PodcastSeries> podcasts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: podcasts.length,
            itemBuilder: (context, index) {
              return _buildPodcastCard(podcasts[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPodcastCard(PodcastSeries podcast) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PodcastDetailScreen(podcast: podcast),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: podcast.artworkUrl != null
                  ? CachedNetworkImage(
                      imageUrl: podcast.artworkUrl!,
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 150,
                        height: 150,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.podcasts, size: 48),
                      ),
                    )
                  : Container(
                      width: 150,
                      height: 150,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.podcasts, size: 48),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              podcast.collectionName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              podcast.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreCatalogs() {
    final allGenresAsync = ref.watch(allGenresPodcastsProvider);

    return allGenresAsync.when(
      data: (genreMap) {
        return Column(
          children: podcastGenreNames.map((genre) {
            final podcasts = genreMap[genre] ?? [];
            if (podcasts.isEmpty) return const SizedBox.shrink();
            return _buildHorizontalSection(
              title: genre,
              icon: _genreIcons[genre] ?? Icons.category_rounded,
              podcasts: podcasts,
            );
          }).toList(),
        );
      },
      loading: () => _buildLoadingSection(120),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLoadingSection(double height) {
    return SizedBox(
      height: height,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class PodcastSearchScreen extends ConsumerStatefulWidget {
  final String query;

  const PodcastSearchScreen({super.key, required this.query});

  @override
  ConsumerState<PodcastSearchScreen> createState() => _PodcastSearchScreenState();
}

class _PodcastSearchScreenState extends ConsumerState<PodcastSearchScreen> {
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.query;
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(podcastSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          controller: TextEditingController(text: _query),
          decoration: const InputDecoration(
            hintText: 'Search podcasts...',
            border: InputBorder.none,
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              setState(() => _query = val.trim());
            }
          },
        ),
      ),
      body: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No podcasts found for "$_query"',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final podcast = results[index];
              return _buildSearchResultTile(podcast);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSearchResultTile(PodcastSeries podcast) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: podcast.artworkUrl != null
                ? CachedNetworkImage(
                    imageUrl: podcast.artworkUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.podcasts, size: 28),
                    ),
                  )
                : Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.podcasts, size: 28),
                  ),
          ),
        ),
        title: Text(
          podcast.collectionName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              podcast.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (podcast.primaryGenre != null) ...[
              const SizedBox(height: 2),
              Text(
                podcast.primaryGenre!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PodcastDetailScreen(podcast: podcast),
            ),
          );
        },
      ),
    );
  }
}

class PodcastGenreScreen extends ConsumerWidget {
  final String genre;

  const PodcastGenreScreen({super.key, required this.genre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(podcastByGenreProvider(genre));

    return Scaffold(
      appBar: AppBar(title: Text(genre)),
      body: resultsAsync.when(
        data: (podcasts) {
          if (podcasts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No podcasts found for $genre',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: podcasts.length,
            itemBuilder: (context, index) {
              return _buildGenreGridItem(context, podcasts[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildGenreGridItem(BuildContext context, PodcastSeries podcast) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PodcastDetailScreen(podcast: podcast),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: podcast.artworkUrl != null
                  ? CachedNetworkImage(
                      imageUrl: podcast.artworkUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.podcasts, size: 48),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.podcasts, size: 48),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            podcast.collectionName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            podcast.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class PodcastAllGenresScreen extends StatelessWidget {
  final List<({String name, IconData icon})> genres;

  const PodcastAllGenresScreen({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('All Genres')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PodcastGenreScreen(genre: genre.name),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(genre.icon, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      genre.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
