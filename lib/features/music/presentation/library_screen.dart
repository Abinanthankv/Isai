import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/music_models.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';
import 'downloads_screen.dart';
import 'liked_songs_screen.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import 'metadata_picker_sheet.dart';
import '../data/itunes_metadata_service.dart';
import 'songs_screen.dart';
import 'playlists_screen.dart';
import 'playlist_providers.dart';
import 'followed_artists_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'dart:async';
import '../../audiobooks/presentation/audiobook_providers.dart';
import '../../audiobooks/data/audiobook_models.dart';
import '../../audiobooks/presentation/audiobook_stats_screen.dart';
import '../../audiobooks/presentation/audiobook_detail_screen.dart';
import 'package:isai/main.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _audiobookLibraryTab = 'local';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(libraryProvider.notifier).loadLibrary(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedTab = ref.watch(discoveryTabProvider);
    final tabs = [
      ('music', 'Music'),
      ('audiobooks', 'Audiobooks'),
    ];

    ref.listen(libraryProvider.select((s) => s.downloadError), (previous, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (selectedTab == 'music') {
              await ref.read(libraryProvider.notifier).loadLibrary(force: true);
            } else {
              ref.invalidate(localAudiobooksProvider);
              ref.invalidate(inProgressAudiobooksProvider);
              await ref.read(localAudiobooksProvider.future);
              await ref.read(inProgressAudiobooksProvider.future);
            }
          },
          color: Theme.of(context).colorScheme.primary,
          child: CustomScrollView(
            slivers: [
              // SliverAppBar with Library Title and synced Tab Bar
              SliverAppBar(
                backgroundColor: isDark
                    ? Colors.black.withOpacity(0.85)
                    : Colors.white.withOpacity(0.9),
                surfaceTintColor: Colors.transparent,
                floating: true,
                pinned: true,
                centerTitle: false,
                title: AppleMusicGradientText(
                  text: 'Library',
                  fontSize: 26,
                  colors: isDark
                      ? [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]
                      : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                ),
                actions: [
                  if (selectedTab == 'audiobooks')
                    IconButton(
                      icon: const Icon(Icons.bar_chart_rounded),
                      tooltip: 'Audiobook Insights',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AudiobookStatsScreen(),
                          ),
                        );
                      },
                    ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(40),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: tabs.map((tab) {
                          final isSelected = selectedTab == tab.$1;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => ref.read(discoveryTabProvider.notifier).state = tab.$1,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 20),
                              padding: const EdgeInsets.only(bottom: 10, top: 6),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark ? Colors.white54 : Colors.black45),
                                  letterSpacing: 0.1,
                                  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                ),
                                child: Text(tab.$2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

              if (selectedTab == 'music') ...[
                // Category Grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final stats = ref.watch(libraryStatsProvider);
                        final playlistsAsync = ref.watch(playlistProvider);
                        
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          children: [
                            _CategoryCard(
                              title: 'Liked Songs',
                              count: '${stats['liked'] ?? 0} songs',
                              icon: Icons.favorite_border_rounded,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LikedSongsScreen())),
                            ),
                            _CategoryCard(
                              title: 'Downloads',
                              count: '${stats['downloads'] ?? 0} songs',
                              icon: Icons.arrow_circle_down_rounded,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen())),
                            ),
                            _CategoryCard(
                              title: 'All Music',
                              count: '${stats['total'] ?? 0} songs',
                              icon: Icons.music_note_rounded,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SongsScreen(mode: SongListMode.all))),
                            ),
                            _CategoryCard(
                              title: 'Playlists',
                              count: '${stats['playlists'] ?? 0} playlists',
                              icon: Icons.queue_music_rounded,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistsScreen())),
                            ),
                            _CategoryCard(
                              title: 'Artists',
                              count: '${stats['artists'] ?? 0} artists',
                              icon: Icons.person_outline_rounded,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowedArtistsScreen())),
                            ),
                            _CategoryCard(
                              title: 'Albums',
                              count: playlistsAsync.maybeWhen(
                                data: (playlists) {
                                  final albumCount = playlists.where((p) => p.playlist.sourceUrl?.contains('album_') == true).length;
                                  return '$albumCount albums';
                                },
                                orElse: () => '0 albums',
                              ),
                              icon: Icons.album_rounded,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryAlbumsScreen())),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // Recently Played Label
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Recently Played',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,),
                        ),
                      ],
                    ),
                  ),
                ),

                // List of items or Empty State
                _buildContentSlivers(),
              ] else ..._buildAudiobookSlivers(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSlivers() {
    final recentAsync = ref.watch(recentlyPlayedProvider);
    final state = ref.watch(libraryProvider);
    
    return recentAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final h = history[i];
              // Map DB history to TorBoxFile for existing tile
              final file = TorBoxFile(
                id: h.fileId,
                torrentId: h.torrentId,
                name: h.trackTitle,
                size: 0,
              );
              // Reuse _TrackTile with metadata from state if available
              var meta = state.metadata['${h.torrentId}-${h.fileId}'];
              
              // If metadata is missing from the library state (e.g. search-to-play tracks),
              // or if library metadata lacks artwork, reconstruct/enrich from playback history!
              if ((meta == null || meta.artworkUrlLow == null) && (h.artworkUrlLow != null || h.artworkUrlHigh != null)) {
                meta = ItunesMeta(
                  trackName: h.trackTitle,
                  artistName: h.artist,
                  artworkUrlLow: h.artworkUrlLow,
                  artworkUrlHigh: h.artworkUrlHigh,
                );
              }
              
              return _TrackTile(file: file, meta: meta, queue: const [], playedAt: h.playedAt);
            },
            childCount: history.length,
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        )),
      ),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 80,
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,),
          ),
          const SizedBox(height: 8),
          Text(
            'Search and add music from TorBox',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAudiobookSlivers(BuildContext context, bool isDark) {
    final inProgressAsync = ref.watch(inProgressAudiobooksProvider);
    final localAudiobooksAsync = ref.watch(localAudiobooksProvider);

    return [
      // 1. Category Grid for Audiobooks
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Builder(
            builder: (context) {
              final inProgressCount = inProgressAsync.value?.length ?? 0;
              final allBooks = localAudiobooksAsync.value ?? [];
              final localCount = allBooks.where((b) => b.id.startsWith('local:')).length;
              final torBoxCount = allBooks.where((b) => b.id.startsWith('torrent:')).length;
              final totalCount = allBooks.length;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _CategoryCard(
                    title: 'Continue Listening',
                    count: '$inProgressCount books',
                    icon: Icons.play_circle_outline_rounded,
                    onTap: () {},
                  ),
                  _CategoryCard(
                    title: 'Local Downloads',
                    count: '$localCount books',
                    icon: Icons.phone_android_rounded,
                    onTap: () {},
                  ),
                  _CategoryCard(
                    title: 'TorBox Cloud',
                    count: '$torBoxCount books',
                    icon: Icons.cloud_queue_rounded,
                    onTap: () {},
                  ),
                  _CategoryCard(
                    title: 'All Audiobooks',
                    count: '$totalCount books',
                    icon: Icons.book_rounded,
                    onTap: () {},
                  ),
                ],
              );
            },
          ),
        ),
      ),

      // 2. Continue Listening Section
      inProgressAsync.when(
        data: (progressList) {
          if (progressList.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Continue Listening',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: progressList.length,
                    itemBuilder: (context, index) {
                      final progress = progressList[index];
                      return _buildProgressCard(context, progress);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      ),

      // 3. Books Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Books in Library',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'local',
                    label: Text('Local'),
                    icon: Icon(Icons.phone_android_rounded, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: 'torbox',
                    label: Text('TorBox'),
                    icon: Icon(Icons.cloud_queue_rounded, size: 16),
                  ),
                ],
                selected: {_audiobookLibraryTab},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _audiobookLibraryTab = newSelection.first;
                  });
                },
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),

      // 4. Books Grid
      localAudiobooksAsync.when(
        data: (allBooks) {
          final localBooksList = allBooks.where((book) => book.id.startsWith('local:')).toList();
          final torBoxBooksList = allBooks.where((book) => book.id.startsWith('torrent:')).toList();
          final displayBooks = _audiobookLibraryTab == 'local' ? localBooksList : torBoxBooksList;

          if (displayBooks.isEmpty) {
            return SliverToBoxAdapter(
              child: Container(
                height: 150,
                alignment: Alignment.center,
                child: Text(
                  _audiobookLibraryTab == 'local'
                      ? 'No downloaded or local audiobooks.'
                      : 'No audiobooks in TorBox cloud library.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = displayBooks[index];
                  return _buildGridCard(context, book);
                },
                childCount: displayBooks.length,
              ),
            ),
          );
        },
        loading: () => const SliverToBoxAdapter(
          child: Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          )),
        ),
        error: (e, _) => SliverToBoxAdapter(
          child: Center(child: Text('Error: $e')),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 120)),
    ];
  }

  Widget _buildProgressCard(BuildContext context, AudiobookWithProgress progress) {
    return GestureDetector(
      onTap: () => _resumePlayback(context, ref, progress.book),
      onLongPress: () => _showProgressOptions(context, ref, progress),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildArtworkWidget(
                progress.book.artworkUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.progressPercent,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, AudiobookResult book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
        );
      },
      onLongPress: () => _showLocalBookOptions(context, ref, book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildArtworkWidget(
              book.artworkUrl,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkWidget(String? url, {double? width, double? height, double borderRadius = 12}) {
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: const Icon(
          Icons.book,
          size: 28,
        ),
      );
    }

    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final cleanPath = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isLocal
          ? Image.file(
              File(cleanPath),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(
                  Icons.book,
                  size: 28,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (context, url, error) => Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(
                  Icons.book,
                  size: 28,
                ),
              ),
            ),
    );
  }

  void _showLocalBookOptions(BuildContext context, WidgetRef ref, AudiobookResult book) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Show Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AudiobookDetailScreen(book: book),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: const Text('Fetch Online Metadata'),
                onTap: () {
                  Navigator.pop(context);
                  _showMetadataSearchSheet(context, ref, book);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProgressOptions(BuildContext context, WidgetRef ref, AudiobookWithProgress progress) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Show Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AudiobookDetailScreen(book: progress.book),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove from Continue Listening', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final repo = ref.read(audiobookRepositoryProvider);
                  await repo.dismissBookFromContinueListening(progress.book.id);
                  ref.invalidate(inProgressAudiobooksProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from Continue Listening.')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resumePlayback(BuildContext context, WidgetRef ref, AudiobookResult book) async {
    final repo = ref.read(audiobookRepositoryProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final progress = await repo.getLatestBookProgress(book.id);
      final chapters = await repo.getBookChapters(book.id);
      if (context.mounted) Navigator.pop(context);
      if (chapters.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No chapters found to play.')),
          );
        }
        return;
      }
      final chapterIdx = (progress != null && progress.chapterIndex < chapters.length) 
          ? progress.chapterIndex 
          : 0;
      final chapter = chapters[chapterIdx];
      final streamUrl = await repo.resolveChapterStream(chapter);
      if (streamUrl == null || streamUrl.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to resolve stream URL.')),
          );
        }
        return;
      }
      await repo.cacheBookMetadata(book);
      await audioHandler.customAction('play', {
        'url': streamUrl,
        'title': chapter.title,
        'artist': book.author,
        'artworkUrl': book.artworkUrl ?? '',
        'forceReplace': true,
        'mediaType': 'audiobook',
        'extras': {
          'bookId': book.id,
          'chapterIndex': chapterIdx,
          'initialPositionMillis': progress?.positionMillis ?? 0,
        },
      });
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      print('[LibraryScreen] Resume playback error: $e');
    }
  }

  void _showMetadataSearchSheet(BuildContext context, WidgetRef ref, AudiobookResult currentBook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return MetadataSearchWidget(
              currentBook: currentBook,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

class _TrackTile extends ConsumerStatefulWidget {
  final TorBoxFile file;
  final ItunesMeta? meta;
  final List<TorBoxFile> queue;
  final int? playedAt;

  const _TrackTile({required this.file, this.meta, required this.queue, this.playedAt});

  @override
  ConsumerState<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends ConsumerState<_TrackTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).enrichTrack(widget.file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseFilename(widget.file.displayName);
    final meta = widget.meta;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final artist = meta?.artistName ?? (parsed.artist.isNotEmpty ? parsed.artist : null);
    final parts = <String>[];
    if (artist != null) parts.add(artist);
    if (meta?.genre != null) parts.add(meta!.genre!);
    if (meta?.releaseYear != null) parts.add(meta!.releaseYear.toString());
    if (widget.playedAt != null) parts.add(_formatPlayedAt(widget.playedAt!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        borderRadius: 14,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NowPlayingScreen(
                file: widget.file,
                customQueue: widget.queue,
              ),
            ),
          );
        },
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                    meta?.trackName ?? parsed.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold,),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.primary),
                    title: Text('Fix Metadata'),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => MetadataPickerSheet(
                          file: widget.file,
                          initialQuery: meta?.trackName ?? parsed.title,
                          initialArtist: meta?.artistName ?? parsed.artist,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      ref.read(libraryProvider.notifier).isDownloaded(widget.file)
                          ? Icons.delete_outline_rounded
                          : Icons.cloud_download_outlined,
                      color: Colors.white54,
                    ),
                    title: Text(
                      ref.read(libraryProvider.notifier).isDownloaded(widget.file)
                          ? 'Remove Download'
                          : 'Download',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (ref.read(libraryProvider.notifier).isDownloaded(widget.file)) {
                        // Handle delete if needed (not explicitly requested but good to have)
                      } else {
                        ref.read(libraryProvider.notifier).clearDownloadError();
                        ref.read(libraryProvider.notifier).downloadTrack(widget.file);
                      }
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: meta?.artworkUrlLow != null
                  ? CachedNetworkImage(
                      imageUrl: meta!.artworkUrlLow!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _artworkPlaceholder(),
                      errorWidget: (_, __, ___) => _artworkPlaceholder(),
                    )
                  : _artworkPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta?.trackName ?? parsed.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.isNotEmpty ? parts.join(' • ') : widget.file.formattedSize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark 
                          ? AppleMusicTheme.darkTextSecondary 
                          : AppleMusicTheme.lightTextSecondary,),
                  ),
                ],
              ),
            ),
            _buildDownloadButton(isDark),
            const SizedBox(width: 8),
            GlassIconButton(
              icon: Icons.play_arrow_rounded,
              size: 40,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  AppleMusicTheme.primaryPurple,
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(
                      file: widget.file,
                      customQueue: widget.queue,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(bool isDark) {
    final libraryState = ref.watch(libraryProvider);
    final key = '${widget.file.torrentId}-${widget.file.id}';
    final isDownloading = libraryState.downloadingIds.contains(key);
    final isDownloaded = ref.read(libraryProvider.notifier).isDownloaded(widget.file);

    if (isDownloading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }

    if (isDownloaded) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.offline_pin_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      );
    }

    return IconButton(
      icon: Icon(
        Icons.cloud_download_outlined,
        color: isDark ? Colors.white54 : Colors.black45,
        size: 20,
      ),
      onPressed: () {
        ref.read(libraryProvider.notifier).clearDownloadError();
        ref.read(libraryProvider.notifier).downloadTrack(widget.file);
      },
    );
  }

  Widget _artworkPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
            AppleMusicTheme.primaryPurple.withOpacity(0.3),
          ],
        ),
      ),
      child: const Icon(Icons.music_note, color: Colors.white38),
    );
  }

  ({String title, String artist}) _parseFilename(String displayName) {
    var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
    name = name.replaceAll(RegExp(r'^\d+\s*[-.]? \s*'), '');
    final match = RegExp(r' [-–] ').firstMatch(name);
    if (match != null) {
      return (
        artist: name.substring(0, match.start).trim(),
        title: name.substring(match.end).trim(),
      );
    }
    return (title: name.trim(), artist: '');
  }

  String _formatPlayedAt(int playedAt) {
    final now = DateTime.now();
    final playTime = DateTime.fromMillisecondsSinceEpoch(playedAt);
    final diff = now.difference(playTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${playTime.day}/${playTime.month}';
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 44,
      height: 44,
      child: GlassButton(
        onPressed: onTap,
        borderRadius: 12,
        child: Icon(
          icon,
          size: 24,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassButton(
      onPressed: onTap,
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,),
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryAlbumsScreen extends ConsumerWidget {
  const LibraryAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0a0a0a), Color(0xFF000000)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFf5f5f7), Color(0xFFefeff1)],
                ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120.0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.primary),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Library Albums',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(start: 48, bottom: 16),
              ),
            ),
            playlistsAsync.when(
              data: (playlists) {
                final albums = playlists.where((p) => p.playlist.sourceUrl?.contains('album_') == true).toList();
                
                return albums.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.album_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                              const SizedBox(height: 16),
                              Text(
                                'No saved albums yet',
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 0.8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = albums[index];
                              return _LibraryAlbumCard(item: item);
                            },
                            childCount: albums.length,
                          ),
                        ),
                      );
              },
              loading: () => SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _LibraryAlbumCard extends ConsumerWidget {
  final PlaylistWithCount item;
  const _LibraryAlbumCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Watch tracks for this album/playlist to get actual tracks
    final tracksAsync = ref.watch(playlistTracksProvider(item.playlist.id));
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailsScreen(
              localPlaylist: item.playlist,
            ),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: tracksAsync.when(
                    data: (tracks) {
                      final artwork = tracks.where((t) => t.artworkUrl != null && t.artworkUrl!.isNotEmpty).firstOrNull?.artworkUrl 
                                    ?? item.playlist.artworkUrl;
                      
                      return artwork != null && artwork.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: artwork,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.white.withOpacity(0.05)),
                              errorWidget: (_, __, ___) => Container(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                child: const Icon(Icons.album_rounded, color: Colors.white24, size: 48),
                              ),
                            )
                          : Container(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                              child: const Icon(Icons.album_rounded, color: Colors.white24, size: 48),
                            );
                    },
                    loading: () => Container(color: Colors.white.withOpacity(0.05)),
                    error: (_, __) => Container(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.count} tracks',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w500,),
            ),
          ],
        ),
      ),
    );
  }
}
