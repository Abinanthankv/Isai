import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
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
    final rawFeedUrl = widget.podcast.feedUrl;
    final hasFeedUrl = rawFeedUrl != null && rawFeedUrl.isNotEmpty;
    final lookupAsync = !hasFeedUrl && widget.podcast.collectionId > 0
        ? ref.watch(podcastLookupProvider(widget.podcast.collectionId))
        : null;
    final feedUrl = hasFeedUrl ? rawFeedUrl : lookupAsync?.asData?.value?.feedUrl;

    final dbEpisodesAsync = feedUrl != null && feedUrl.isNotEmpty
        ? ref.watch(podcastEpisodesDbProvider(feedUrl))
        : null;
    final networkEpisodesAsync = feedUrl != null && feedUrl.isNotEmpty
        ? ref.watch(podcastEpisodesProvider(feedUrl))
        : null;

    List<PodcastEpisode>? loadedEpisodes;
    if (dbEpisodesAsync?.asData?.value != null && dbEpisodesAsync!.asData!.value.isNotEmpty) {
      loadedEpisodes = dbEpisodesAsync.asData!.value.map((dbEp) {
        final pubDateStr = dbEp.pubDate != null
            ? DateTime.fromMillisecondsSinceEpoch(dbEp.pubDate!).toIso8601String()
            : null;
        return PodcastEpisode(
          id: dbEp.guid,
          guid: dbEp.guid,
          title: dbEp.title,
          description: dbEp.description,
          audioUrl: dbEp.isDownloaded && dbEp.localPath != null && dbEp.localPath!.isNotEmpty
              ? dbEp.localPath
              : dbEp.audioUrl,
          durationSec: dbEp.durationSeconds,
          pubDate: pubDateStr,
          artworkUrl: dbEp.artworkUrl ?? widget.podcast.artworkUrl,
          chaptersUrl: dbEp.chaptersUrl,
          feedUrl: dbEp.feedUrl,
        );
      }).toList();
    } else if (networkEpisodesAsync?.asData?.value != null) {
      loadedEpisodes = networkEpisodesAsync!.asData!.value;
    }

    final subscribedList = ref.watch(subscribedPodcastsProvider).asData?.value ?? [];
    final isDbSubscribed = feedUrl != null && subscribedList.any((s) => s.feedUrl == feedUrl);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  isDbSubscribed ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  color: isDbSubscribed ? Theme.of(context).colorScheme.primary : null,
                ),
                tooltip: isDbSubscribed ? 'Unsubscribe' : 'Subscribe',
                onPressed: feedUrl == null ? null : () async {
                  final repo = ref.read(podcastRepositoryProvider);
                  if (isDbSubscribed) {
                    await repo.unsubscribe(feedUrl);
                    ref.read(podcastFollowedProvider.notifier).remove(widget.podcast.collectionId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unsubscribed from podcast')),
                      );
                    }
                  } else {
                    await repo.subscribe(widget.podcast);
                    ref.read(podcastFollowedProvider.notifier).add(widget.podcast.collectionId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscribed to podcast')),
                      );
                    }
                  }
                },
              ),
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
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                          child: PodcastArtworkImage(
                            imageUrl: widget.podcast.artworkUrl,
                            width: 120,
                            height: 120,
                          ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              widget.podcast.collectionName,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.podcast.artistName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: feedUrl == null ? null : () async {
                              final repo = ref.read(podcastRepositoryProvider);
                              if (isDbSubscribed) {
                                await repo.unsubscribe(feedUrl);
                                ref.read(podcastFollowedProvider.notifier).remove(widget.podcast.collectionId);
                              } else {
                                await repo.subscribe(widget.podcast);
                                ref.read(podcastFollowedProvider.notifier).add(widget.podcast.collectionId);
                              }
                            },
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            ),
                            icon: Icon(isDbSubscribed ? Icons.check_rounded : Icons.add_rounded, size: 16),
                            label: Text(isDbSubscribed ? 'Subscribed' : 'Subscribe', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (loadedEpisodes != null)
            _buildEpisodesList(context, loadedEpisodes, feedUrl)
          else if (networkEpisodesAsync?.isLoading == true || dbEpisodesAsync?.isLoading == true)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No episodes found.')),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildEpisodesList(BuildContext context, List<PodcastEpisode> episodes, String? feedUrl) {
    if (episodes.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No episodes found.')),
        ),
      );
    }

    final months = _buildMonthSections(episodes);
    final isAllSelected = _selectedMonth == null || _selectedMonth == 'All';

    final List<PodcastEpisode> filtered = isAllSelected
        ? episodes
        : episodes.where((ep) {
            final dt = _parseDate(ep.pubDate);
            return dt != null && _monthKey(dt) == _selectedMonth;
          }).toList();

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildFilteredEmpty(episodes, months),
      );
    }

    // Group filtered episodes by month
    final Map<String, List<PodcastEpisode>> grouped = {};
    for (final ep in filtered) {
      final dt = _parseDate(ep.pubDate);
      final key = dt != null ? _monthKey(dt) : 'Other';
      grouped.putIfAbsent(key, () => []).add(ep);
    }

    final items = <Widget>[];
    if (months.isNotEmpty) {
      items.add(_buildFilterHeader(episodes, months));
    }

    grouped.forEach((monthKey, groupEpisodes) {
      items.add(_buildMonthHeader(monthKey, groupEpisodes.length));
      for (final ep in groupEpisodes) {
        items.add(_buildEpisodeTile(context, ep, episodes, feedUrl: feedUrl));
      }
    });

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => items[index],
        childCount: items.length,
      ),
    );
  }

  Widget _buildMonthHeader(String monthKey, int count) {
    final label = monthKey == 'Other' ? 'Other Episodes' : _monthLabel(monthKey);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
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

  DateTime? _parseDate(String? dateStr) => parseRssDate(dateStr);

  List<String> _buildMonthSections(List<PodcastEpisode> episodes) {
    final months = <String>{};
    for (final ep in episodes) {
      final dt = _parseDate(ep.pubDate);
      if (dt != null) months.add(_monthKey(dt));
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Widget _buildFilterHeader(List<PodcastEpisode> episodes, List<String> months) {
    final allMonthsOptions = ['All', ...months];
    final currentSelection = _selectedMonth ?? 'All';

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
            itemCount: allMonthsOptions.length,
            itemBuilder: (context, index) {
              final monthOpt = allMonthsOptions[index];
              final isSelected = monthOpt == currentSelection;
              final label = monthOpt == 'All' ? 'All' : _monthLabel(monthOpt);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    label,
                    style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedMonth = monthOpt);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredEmpty(List<PodcastEpisode> episodes, List<String> months) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFilterHeader(episodes, months),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text('No episodes in ${_selectedMonth == 'All' ? 'All' : _monthLabel(_selectedMonth!)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeTile(BuildContext context, PodcastEpisode episode, List<PodcastEpisode> allEpisodes, {String? feedUrl}) {
    final theme = Theme.of(context);
    final guid = episode.guid?.isNotEmpty == true ? episode.guid! : (episode.id.isNotEmpty ? episode.id : (episode.audioUrl ?? ''));

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
                  primaryGenre: widget.podcast.primaryGenre,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PodcastArtworkImage(
                        imageUrl: episode.artworkUrl ?? widget.podcast.artworkUrl,
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
                          Consumer(
                            builder: (context, ref, child) {
                              final progressData = ref.watch(podcastEpisodeProgressDbProvider(guid)).asData?.value;
                              final ratio = (progressData != null && progressData.durationMillis > 0)
                                  ? (progressData.positionMillis / progressData.durationMillis).clamp(0.0, 1.0)
                                  : 0.0;
                              final isCompleted = progressData != null && (progressData.isCompleted || ratio >= 0.95);

                              return Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  if (isCompleted)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.check_circle_rounded, size: 13, color: Colors.green),
                                        SizedBox(width: 4),
                                        Text(
                                          'Completed',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (episode.durationSec != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
                                      ],
                                    ),
                                  if (episode.pubDate != null)
                                    Text(
                                      _formatDate(episode.pubDate!),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              );
                            },
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
                    Consumer(
                      builder: (context, ref, child) {
                        final downloadedList = ref.watch(downloadedPodcastEpisodesProvider).asData?.value ?? [];
                        final dbEpMatch = downloadedList.where((e) => e.guid == guid || e.audioUrl == episode.audioUrl).firstOrNull;
                        final isDownloaded = dbEpMatch?.isDownloaded ?? false;
                        final downloadProgress = dbEpMatch?.downloadProgress ?? 0.0;
                        final isPaused = dbEpMatch?.isPaused ?? false;
                        final isDownloading = downloadProgress > 0.0 && downloadProgress < 1.0 && !isPaused;

                        if (isDownloaded) {
                          return IconButton(
                            icon: const Icon(Icons.download_done_rounded, color: Colors.green, size: 24),
                            tooltip: 'Downloaded (Tap to delete)',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Download'),
                                  content: Text('Delete offline copy of "${episode.title}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true && dbEpMatch != null) {
                                await ref.read(podcastRepositoryProvider).deleteDownload(dbEpMatch);
                              }
                            },
                          );
                        } else if (isDownloading) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(value: downloadProgress, strokeWidth: 2.5),
                              ),
                              IconButton(
                                icon: const Icon(Icons.pause_rounded, size: 22),
                                tooltip: 'Pause Download',
                                onPressed: () {
                                  if (dbEpMatch != null) {
                                    ref.read(podcastRepositoryProvider).pauseDownload(dbEpMatch);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 22),
                                tooltip: 'Cancel Download',
                                onPressed: () {
                                  if (dbEpMatch != null) {
                                    ref.read(podcastRepositoryProvider).cancelDownload(dbEpMatch);
                                  }
                                },
                              ),
                            ],
                          );
                        } else if (isPaused) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.orange, size: 24),
                                tooltip: 'Resume Download',
                                onPressed: () {
                                  if (dbEpMatch != null) {
                                    ref.read(podcastRepositoryProvider).resumeDownload(dbEpMatch);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 22),
                                tooltip: 'Cancel Download',
                                onPressed: () {
                                  if (dbEpMatch != null) {
                                    ref.read(podcastRepositoryProvider).cancelDownload(dbEpMatch);
                                  }
                                },
                              ),
                            ],
                          );
                        } else {
                          return IconButton(
                            icon: const Icon(Icons.download_for_offline_outlined, size: 24),
                            tooltip: 'Download Episode',
                            onPressed: () async {
                              final repo = ref.read(podcastRepositoryProvider);
                              final pubDateMs = _parseDate(episode.pubDate)?.millisecondsSinceEpoch;
                              final dbEp = DbPodcastEpisodeData(
                                id: 0,
                                feedUrl: feedUrl ?? widget.podcast.feedUrl ?? '',
                                guid: guid,
                                title: episode.title,
                                description: episode.description,
                                audioUrl: episode.audioUrl ?? '',
                                pubDate: pubDateMs,
                                durationSeconds: episode.durationSec ?? 0,
                                artworkUrl: episode.artworkUrl ?? widget.podcast.artworkUrl,
                                chaptersUrl: episode.chaptersUrl,
                                isDownloaded: false,
                                isCompleted: false,
                                downloadProgress: 0.0,
                                isPaused: false,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Downloading "${episode.title}"...')),
                              );
                              try {
                                await repo.downloadEpisode(dbEp);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Download failed: $e')),
                                  );
                                }
                              }
                            },
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_fill_rounded,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      onPressed: () {
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
                              primaryGenre: widget.podcast.primaryGenre,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final progressData = ref.watch(podcastEpisodeProgressDbProvider(guid)).asData?.value;
                    if (progressData != null && (progressData.positionMillis > 5000 || progressData.isCompleted) && progressData.durationMillis > 0) {
                      final ratio = (progressData.positionMillis / progressData.durationMillis).clamp(0.0, 1.0);
                      final isCompleted = progressData.isCompleted || ratio >= 0.95;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: isCompleted ? 1.0 : ratio,
                              minHeight: 3,
                              color: isCompleted ? Colors.green : null,
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
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
