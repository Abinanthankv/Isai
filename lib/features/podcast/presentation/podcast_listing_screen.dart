import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../data/podcast_models.dart';
import '../data/podcast_api_service.dart';
import 'podcast_providers.dart';
import 'podcast_artwork.dart';
import 'package:isai/main.dart';
import 'podcast_detail_screen.dart';
import 'podcast_now_playing_screen.dart';
import 'podcast_stats_screen.dart';

class PodcastsSubScreen extends ConsumerStatefulWidget {
  const PodcastsSubScreen({super.key});

  @override
  ConsumerState<PodcastsSubScreen> createState() => _PodcastsSubScreenState();
}

class _PodcastsSubScreenState extends ConsumerState<PodcastsSubScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _loadingEpisodeId;
  int _selectedTab = 0; // 0: Explore, 1: Subscribed, 2: Downloaded

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

  Future<void> _importOpml() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['opml', 'xml'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importing OPML podcasts...')),
          );
        }
        final count = await ref.read(podcastRepositoryProvider).importOpml(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported $count podcast(s)!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OPML Import failed: $e')),
        );
      }
    }
  }

  Future<void> _exportOpml() async {
    try {
      final opmlXml = await ref.read(podcastRepositoryProvider).exportOpml();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/podcasts_export.opml');
      await file.writeAsString(opmlXml);
      await Share.shareXFiles([XFile(file.path)], text: 'My Podcast Subscriptions (OPML)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OPML Export failed: $e')),
        );
      }
    }
  }

  Future<void> _showAddByUrlDialog() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Podcast by RSS URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/feed.xml',
            labelText: 'RSS Feed URL',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      ref.read(podcastManualFeedUrlsProvider.notifier).add(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newReleasesAsync = ref.watch(podcastRecentProvider);
    final followed = ref.watch(podcastFollowedProvider);
    final manualUrls = ref.watch(podcastManualFeedUrlsProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search podcasts...',
              leading: const Icon(Icons.search),
              trailing: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Options & OPML',
                  onSelected: (val) {
                    if (val == 'import') _importOpml();
                    if (val == 'export') _exportOpml();
                    if (val == 'rss') _showAddByUrlDialog();
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.file_upload_outlined, size: 20), SizedBox(width: 8), Text('Import OPML')])),
                    PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.file_download_outlined, size: 20), SizedBox(width: 8), Text('Export OPML')])),
                    PopupMenuItem(value: 'rss', child: Row(children: [Icon(Icons.rss_feed_rounded, size: 20), SizedBox(width: 8), Text('Add RSS Feed')])),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart_rounded),
                  tooltip: 'Stats',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PodcastStatsScreen(),
                      ),
                    );
                  },
                ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Explore'), icon: Icon(Icons.explore_outlined, size: 18)),
                ButtonSegment(value: 1, label: Text('Subscribed'), icon: Icon(Icons.bookmarks_outlined, size: 18)),
                ButtonSegment(value: 2, label: Text('Downloaded'), icon: Icon(Icons.download_for_offline_outlined, size: 18)),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (val) => setState(() => _selectedTab = val.first),
            ),
          ),
          if (_selectedTab == 1)
            _buildSubscribedTab()
          else if (_selectedTab == 2)
            _buildDownloadedTab()
          else ...[
            if (followed.isNotEmpty || manualUrls.isNotEmpty) _buildFollowedSection(followed),
            _buildContinueListening(),
            _buildNewReleasesSection(newReleasesAsync),
            _buildGenreCatalogs(),
            _buildSpotifySection('Top Podcasts - US', spotifyTopPodcastsUsProvider),
            _buildSpotifySection('Top Podcasts - India', spotifyTopPodcastsInProvider),
            _buildSpotifySection('Top Episodes - US', spotifyTopEpisodesUsProvider),
            _buildSpotifySection('Top Episodes - India', spotifyTopEpisodesInProvider),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildSubscribedTab() {
    final asyncSubs = ref.watch(subscribedPodcastsProvider);
    return asyncSubs.when(
      data: (subs) {
        if (subs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.bookmarks_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('No Subscriptions Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Explore podcasts or import an OPML file to build your subscription library.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _importOpml,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import OPML File'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: subs.length,
          itemBuilder: (context, index) {
            final sub = subs[index];
            final series = PodcastSeries(
              collectionId: sub.collectionId,
              collectionName: sub.title,
              artistName: sub.artist,
              feedUrl: sub.feedUrl,
              artworkUrl: sub.artworkUrl,
              primaryGenre: sub.genres?.split(',').firstOrNull,
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PodcastArtworkImage(imageUrl: sub.artworkUrl, width: 52, height: 52),
                ),
                title: Text(sub.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(sub.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                  tooltip: 'Unsubscribe',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Unsubscribe'),
                        content: Text('Unsubscribe from "${sub.title}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unsubscribe')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(podcastRepositoryProvider).unsubscribe(sub.feedUrl);
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PodcastDetailScreen(podcast: series)));
                },
              ),
            );
          },
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Error loading subscriptions: $e'))),
    );
  }

  Widget _buildDownloadedTab() {
    final asyncDownloads = ref.watch(downloadedPodcastEpisodesProvider);
    final subs = ref.watch(subscribedPodcastsProvider).asData?.value ?? [];
    return asyncDownloads.when(
      data: (episodes) {
        if (episodes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.download_for_offline_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('No Downloaded Episodes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Download episodes from any podcast detail screen to listen offline anywhere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final ep = episodes[index];
            final subMatch = subs.where((s) => s.feedUrl == ep.feedUrl).firstOrNull;
            final podcastTitle = subMatch?.title ?? 'Podcast Episode';
            final podcastArtist = subMatch?.artist ?? '';
            final isCompleted = ep.isDownloaded;
            final isPaused = ep.isPaused;
            final podcastEp = PodcastEpisode(
              id: ep.guid,
              guid: ep.guid,
              title: ep.title,
              description: ep.description,
              audioUrl: ep.localPath ?? ep.audioUrl,
              durationSec: ep.durationSeconds,
              artworkUrl: ep.artworkUrl,
              chaptersUrl: ep.chaptersUrl,
              feedUrl: ep.feedUrl,
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PodcastArtworkImage(imageUrl: ep.artworkUrl, width: 52, height: 52),
                ),
                title: Text(ep.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      isCompleted
                          ? (ep.durationSeconds > 0 ? '${(ep.durationSeconds / 60).round()} mins • Offline' : 'Offline Episode')
                          : (isPaused ? 'Paused... ${(ep.downloadProgress * 100).round()}%' : 'Downloading... ${(ep.downloadProgress * 100).round()}%'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : (isPaused ? Colors.orange : Theme.of(context).colorScheme.primary),
                        fontWeight: isCompleted ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    if (!isCompleted) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ep.downloadProgress,
                          minHeight: 4,
                          color: isPaused ? Colors.orange : null,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: isCompleted
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            tooltip: 'Delete Download',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Download'),
                                  content: Text('Delete offline file for "${ep.title}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(podcastRepositoryProvider).deleteDownload(ep);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.play_circle_fill_rounded, color: Theme.of(context).colorScheme.primary, size: 36),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PodcastNowPlayingScreen(
                                    episode: podcastEp,
                                    allEpisodes: [podcastEp],
                                    podcastTitle: podcastTitle,
                                    podcastArtist: podcastArtist,
                                    podcastArtwork: ep.artworkUrl,
                                    feedUrl: ep.feedUrl,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 24, color: isPaused ? Colors.orange : null),
                            tooltip: isPaused ? 'Resume Download' : 'Pause Download',
                            onPressed: () {
                              final repo = ref.read(podcastRepositoryProvider);
                              if (isPaused) {
                                repo.resumeDownload(ep);
                              } else {
                                repo.pauseDownload(ep);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 22),
                            tooltip: 'Cancel Download',
                            onPressed: () {
                              ref.read(podcastRepositoryProvider).cancelDownload(ep);
                            },
                          ),
                        ],
                      ),
                onTap: isCompleted
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PodcastNowPlayingScreen(
                              episode: podcastEp,
                              allEpisodes: [podcastEp],
                              podcastTitle: podcastTitle,
                              podcastArtist: podcastArtist,
                              podcastArtwork: ep.artworkUrl,
                              feedUrl: ep.feedUrl,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Error loading downloads: $e'))),
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

    const int initialCount = 3;
    final showAll = ref.watch(showAllContinueProvider);
    final displayed = showAll ? items : items.take(initialCount).toList();

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
        for (final item in displayed)
          item.isLive
              ? _buildLiveContinueCard(item)
              : _buildSavedContinueCard(item),
        if (items.length > initialCount)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(showAllContinueProvider.notifier).toggle(),
              child: Text(
                showAll ? 'Show less' : 'Show more (${items.length - initialCount} more)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
            onLongPress: () => _confirmRemove(current),
          ),
        );
      },
    );
  }

  void _confirmRemove(ContinueListeningData item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Continue Listening?'),
        content: Text('Remove "${item.episodeTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(lastPlayedPodcastProvider.notifier).remove(item.episodeKey);
              Navigator.pop(ctx);
            },
            child: Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
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
        trailing: _loadingEpisodeId == current.episodeId
            ? const SizedBox(
                width: 36, height: 36,
                child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5))),
              )
            : Icon(
                Icons.play_circle_fill_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 36,
              ),
        onTap: () async {
          if (_loadingEpisodeId != null) return;
          setState(() => _loadingEpisodeId = current.episodeId);
          try {
            final isSame = audioHandler.mediaItem.value?.id == current.audioUrl
                || audioHandler.mediaItem.value?.id == current.episodeId;
            if (isSame) {
              await audioHandler.play();
              await audioHandler.seek(current.position);
            } else {
              var audioUrl = current.audioUrl;
              final repo = ref.read(podcastRepositoryProvider);
              if (current.feedUrl != null && current.feedUrl!.isNotEmpty) {
                final cachedEps = await repo.getEpisodes(current.feedUrl!);
                final match = cachedEps.where((e) =>
                  e.guid == current.episodeId || e.title == current.episodeTitle
                ).firstOrNull;
                if (match?.localPath != null && match!.localPath!.isNotEmpty) {
                  audioUrl = match.localPath!;
                } else if (match?.audioUrl != null && match!.audioUrl.isNotEmpty) {
                  audioUrl = match.audioUrl;
                }
              }
              final resolved = audioUrl.isNotEmpty ? await PodcastApiService.resolveAudioUrl(audioUrl) : audioUrl;
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
                  'episodeId': current.episodeId,
                  'episodeTitle': current.episodeTitle,
                  'episodeDuration': current.duration.inSeconds,
                  'feedUrl': current.feedUrl ?? '',
                  'initialPositionMillis': current.position.inMilliseconds,
                },
              });
            }
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PodcastNowPlayingScreen.fromMediaItem(),
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _loadingEpisodeId = null);
          }
        },
        onLongPress: () => _confirmRemove(current),
      ),
    );
  }

  Widget _buildContinueCard({
    required ContinueListeningData current,
    required double progress,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
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
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PodcastArtworkImage(
                    imageUrl: current.episodeArtwork ?? current.podcastArtwork,
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

  Widget _buildNewReleasesSection(AsyncValue<List<PodcastSeries>> async) {
    return async.when(
      data: (podcasts) {
        if (podcasts.isEmpty) return const SizedBox.shrink();
        return _buildHorizontalSection(
          title: 'New Releases',
          icon: Icons.new_releases_rounded,
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
    VoidCallback? onShowMore,
    int? maxItems,
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
        _PodcastHorizontalRow(
          podcasts: podcasts,
          onShowMore: onShowMore,
          maxItems: maxItems,
          buildPodcastCard: _buildPodcastCard,
        ),
      ],
    );
  }

  Widget _buildPodcastCard(PodcastSeries podcast) {
    final manualUrls = ref.read(podcastManualFeedUrlsProvider);
    final isManual = podcast.feedUrl != null && manualUrls.contains(podcast.feedUrl);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PodcastDetailScreen(podcast: podcast),
          ),
        );
      },
      onLongPress: isManual
          ? () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove Podcast'),
                  content: Text('Remove "${podcast.collectionName}" from your library?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirm == true && podcast.feedUrl != null) {
                ref.read(podcastManualFeedUrlsProvider.notifier).remove(podcast.feedUrl!);
              }
            }
          : null,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PodcastArtworkImage(
                imageUrl: podcast.artworkUrl,
                width: 150,
                height: 150,
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
              maxItems: 10,
              onShowMore: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PodcastGenreScreen(genre: genre),
                  ),
                );
              },
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

  Widget _buildSpotifySection(String title, FutureProvider<List<SpotifyChartItem>> provider) {
    final async = ref.watch(provider);
    return async.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildSpotifyCard(items[index]);
                },
              ),
            ),
          ],
        );
      },
      loading: () => _buildLoadingSection(170),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSpotifyCard(SpotifyChartItem item) {
    final imageUrl = item.episodeImageUrl ?? item.showImageUrl;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PodcastSearchScreen(query: item.showName),
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
              child: PodcastArtworkImage(
                imageUrl: imageUrl,
                width: 150,
                height: 136,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.episodeName ?? item.showName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodcastHorizontalRow extends StatefulWidget {
  final List<PodcastSeries> podcasts;
  final VoidCallback? onShowMore;
  final int? maxItems;
  final Widget Function(PodcastSeries) buildPodcastCard;

  const _PodcastHorizontalRow({
    required this.podcasts,
    required this.buildPodcastCard,
    this.onShowMore,
    this.maxItems,
  });

  @override
  State<_PodcastHorizontalRow> createState() => _PodcastHorizontalRowState();
}

class _PodcastHorizontalRowState extends State<_PodcastHorizontalRow> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => 200.0,
      LogicalKeyboardKey.arrowLeft => -200.0,
      _ => null,
    };
    if (delta != null) {
      final target = (_scrollController.offset + delta)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(target);
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 158;
    const double horizontalPadding = 24;

    return SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - horizontalPadding;
          final fitsWithoutScroll = (availableWidth / cardWidth).floor();
          final minItems = widget.maxItems ?? widget.podcasts.length;
          final itemsToShow = fitsWithoutScroll > minItems
              ? fitsWithoutScroll
              : minItems;
          final hasShowMore = widget.onShowMore != null && widget.podcasts.length > itemsToShow;
          final display = widget.podcasts.take(itemsToShow).toList();

          return Focus(
            focusNode: _focusNode,
            onKeyEvent: (node, event) {
              _onKeyEvent(event);
              return event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                   event.logicalKey == LogicalKeyboardKey.arrowRight)
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored;
            },
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: display.length + (hasShowMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < display.length) {
                  return widget.buildPodcastCard(display[index]);
                }
                return _ShowMoreCard(onTap: widget.onShowMore!);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ShowMoreCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ShowMoreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_forward_rounded, size: 32,
              color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text('Show all',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              )),
          ],
        ),
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
              child: PodcastArtworkImage(
                imageUrl: podcast.artworkUrl,
                width: 56,
                height: 56,
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

class PodcastGenreScreen extends ConsumerStatefulWidget {
  final String genre;

  const PodcastGenreScreen({super.key, required this.genre});

  @override
  ConsumerState<PodcastGenreScreen> createState() => _PodcastGenreScreenState();
}

class _PodcastGenreScreenState extends ConsumerState<PodcastGenreScreen> {
  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(genrePodcastsProvider(widget.genre));

    return Scaffold(
      appBar: AppBar(title: Text(widget.genre)),
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
                  Text('No podcasts found for ${widget.genre}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              childAspectRatio: 0.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: podcasts.length,
            itemBuilder: (context, index) {
              return _buildGenreGridItem(context, podcasts[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(genrePodcastsProvider(widget.genre).notifier).retry(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
              borderRadius: BorderRadius.circular(10),
              child: PodcastArtworkImage(
                imageUrl: podcast.artworkUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            podcast.collectionName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
