import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'podcast_artwork.dart';
import '../data/podcast_models.dart';
import 'podcast_providers.dart';
import 'podcast_now_playing_screen.dart';

class PodcastDetailScreen extends ConsumerStatefulWidget {
  final PodcastSeries podcast;

  const PodcastDetailScreen({super.key, required this.podcast});

  @override
  ConsumerState<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends ConsumerState<PodcastDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedMonth;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lookupAsync = widget.podcast.feedUrl == null && widget.podcast.collectionId > 0
        ? ref.watch(podcastLookupProvider(widget.podcast.collectionId))
        : null;
    final feedUrl = widget.podcast.feedUrl ?? lookupAsync?.asData?.value?.feedUrl;
    final episodesAsync = feedUrl != null
        ? ref.watch(podcastEpisodesProvider(feedUrl))
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              Consumer(builder: (context, ref, child) {
                final followed = ref.watch(podcastFollowedProvider);
                final isFollowed = followed.contains(widget.podcast.collectionId);
                return IconButton(
                  icon: Icon(
                    isFollowed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFollowed ? Theme.of(context).colorScheme.primary : null,
                  ),
                  onPressed: () {
                    ref.read(podcastFollowedProvider.notifier).toggle(widget.podcast.collectionId);
                  },
                );
              }),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.podcast.artworkUrl != null)
                    PodcastArtworkImage(
                      imageUrl: widget.podcast.artworkUrl,
                      fit: BoxFit.cover,
                    ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                          child: PodcastArtworkImage(
                            imageUrl: widget.podcast.artworkUrl,
                            width: 140,
                            height: 140,
                          ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              widget.podcast.collectionName,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.podcast.artistName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (widget.podcast.primaryGenre != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.podcast.primaryGenre!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (episodesAsync != null)
            episodesAsync.when(
              data: (episodes) {
                if (episodes.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No episodes found.')),
                    ),
                  );
                }
                final months = _buildMonthSections(episodes);
                if (months.isEmpty) {
        return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildEpisodeTile(context, episodes[index], episodes, feedUrl: feedUrl),
                    childCount: episodes.length,
                    ),
                  );
                }
                _selectedMonth ??= months.last;
                return SliverToBoxAdapter(
                  child: _buildEpisodesWithFilter(episodes, months, feedUrl: feedUrl),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48,
                          color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Failed to load episodes.'),
                        const SizedBox(height: 4),
                        Text('$e', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Loading...')),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  String _monthKey(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[month - 1]} $year';
  }

  static final RegExp _rssDate = RegExp(
    r'^\w{3},\s(\d{2})\s(\w{3})\s(\d{4})\s(\d{2}):(\d{2}):(\d{2})',
  );

  static const _monthMap = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    DateTime? dt;
    try {
      dt = DateTime.tryParse(dateStr);
    } catch (_) {}
    if (dt != null && dt.year > 1970) return dt;
    final match = _rssDate.firstMatch(dateStr);
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final month = _monthMap[match.group(2)];
      final year = int.tryParse(match.group(3)!);
      final hour = int.tryParse(match.group(4)!);
      final min = int.tryParse(match.group(5)!);
      final sec = int.tryParse(match.group(6)!);
      if (day != null && month != null && year != null &&
          hour != null && min != null && sec != null) {
        return DateTime.utc(year, month, day, hour, min, sec);
      }
    }
    try {
      final cleaned = dateStr
          .replaceAll(RegExp(r'[A-Za-z]{3},\s'), '')
          .replaceAll(RegExp(r'\s[+-]\d{4}$'), '')
          .replaceAll(' GMT', '');
      dt = DateTime.tryParse(cleaned);
      if (dt != null && dt.year > 1970) return dt;
    } catch (_) {}
    return null;
  }

  List<String> _buildMonthSections(List<PodcastEpisode> episodes) {
    final months = <String>{};
    for (final ep in episodes) {
      final dt = _parseDate(ep.pubDate);
      if (dt != null) months.add(_monthKey(dt));
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Widget _buildEpisodesWithFilter(List<PodcastEpisode> episodes, List<String> months, {String? feedUrl}) {
    final filtered = _selectedMonth != null
        ? episodes.where((ep) {
            final dt = _parseDate(ep.pubDate);
            return dt != null && _monthKey(dt) == _selectedMonth;
          }).toList()
        : episodes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Episodes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${episodes.length} episodes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final isSelected = month == _selectedMonth;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_monthLabel(month),
                    style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedMonth = month);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text('No episodes in ${_monthLabel(_selectedMonth!)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          ...filtered.map((ep) => _buildEpisodeTile(context, ep, episodes, feedUrl: feedUrl)),
      ],
    );
  }

  Widget _buildEpisodeTile(BuildContext context, PodcastEpisode episode, List<PodcastEpisode> allEpisodes, {String? feedUrl}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PodcastNowPlayingScreen(
                  episode: episode,
                  allEpisodes: allEpisodes,
                  initialIndex: allEpisodes.indexOf(episode),
                  podcastArtwork: widget.podcast.artworkUrl,
                  podcastTitle: widget.podcast.collectionName,
                  podcastArtist: widget.podcast.artistName,
                  feedUrl: feedUrl,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PodcastArtworkImage(
                    imageUrl: episode.artworkUrl,
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (episode.durationSec != null) ...[
                            Icon(Icons.schedule_rounded, size: 12,
                              color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(episode.durationSec!),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (episode.pubDate != null)
                            Text(
                              _formatDate(episode.pubDate!),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (episode.description != null && episode.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          episode.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }
}
