import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'music_providers.dart';
import '../../music/data/music_models.dart';
import 'source_picker_sheet.dart';
import 'music_providers.dart';
import '../data/itunes_metadata_service.dart';
import 'album_screen.dart';
import 'artist_screen.dart';
import 'now_playing_screen.dart';
import 'track_action_sheet.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import 'downloads_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/di/injection.dart';
import '../../music/data/music_repository.dart';
import 'package:isai/main.dart';
import 'category_detail_screen.dart';

class MusicSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const MusicSearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends ConsumerState<MusicSearchScreen> {
  late final TextEditingController _controller;
  bool _showChips = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showChips = false);
        ref.read(musicSearchProvider.notifier).search(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final isOffline = ref.watch(isOfflineProvider);
    final searchState = ref.watch(musicSearchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isOffline) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: OfflinePlaceholder(
          title: 'Search Unavailable',
          message: 'Searching for new music requires an internet connection. Access your downloaded tracks below.',
          onGoToDownloads: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
            );
          },
        ),
      );
    }

    return Scaffold(
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
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppleMusicGradientText(
                        text: 'Search',
                        fontSize: 28,
                        colors: isDark
                            ? [AppleMusicTheme.primaryPink, AppleMusicTheme.primaryPurple]
                            : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                      ),
                      const SizedBox(height: 16),
                      AppleMusicSearchBar(
                        controller: _controller,
                        hintText: 'Search for music...',
                        onChanged: (value) {
                          setState(() {
                            _showChips = value.isEmpty;
                          });
                        },
                        onTap: () {
                          setState(() => _showChips = false);
                        },
                        onSubmitted: (q) {
                          if (q.isNotEmpty) {
                            ref.read(musicSearchProvider.notifier).search(q);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            AppleMusicChip(
                              label: 'Songs',
                              gradientColors: [AppleMusicTheme.primaryPink, AppleMusicTheme.primaryPurple],
                              isSelected: searchState.searchMode == 'songs',
                              onTap: () {
                                ref.read(musicSearchProvider.notifier).setMode('songs');
                              },
                            ),
                            const SizedBox(width: 8),
                            AppleMusicChip(
                              label: 'Albums',
                              gradientColors: [AppleMusicTheme.primaryBlue, Colors.cyan],
                              isSelected: searchState.searchMode == 'albums',
                              onTap: () {
                                ref.read(musicSearchProvider.notifier).setMode('albums');
                              },
                            ),
                            const SizedBox(width: 8),
                            AppleMusicChip(
                              label: 'Artists',
                              gradientColors: [Colors.orange, Colors.deepOrange],
                              isSelected: searchState.searchMode == 'artists',
                              onTap: () {
                                ref.read(musicSearchProvider.notifier).setMode('artists');
                              },
                            ),
                          ],
                        ),
                      ),
                      if (_showChips) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Regional Languages',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
                          children: [
                            BrowseCard(
                              title: 'Tamil',
                              imageUrl: 'https://cdn-images.dzcdn.net/images/cover/962cce1fa82c725979407d6ef0f15577-025e6f72ea7f1b92b40f53bcac28ce54-27c0b6aa1e977262da32f80e2260d7b4-2197b73d3c1165eabf47f6b83b7c6bbc/500x500-000000-80-0-0.jpg',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CategoryDetailScreen(
                                      genre: DeezerGenre(
                                        id: -1, 
                                        name: 'Tamil', 
                                        picture: 'https://cdn-images.dzcdn.net/images/cover/962cce1fa82c725979407d6ef0f15577-025e6f72ea7f1b92b40f53bcac28ce54-27c0b6aa1e977262da32f80e2260d7b4-2197b73d3c1165eabf47f6b83b7c6bbc/500x500-000000-80-0-0.jpg'
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            BrowseCard(
                              title: 'Hindi',
                              imageUrl: 'https://cdn-images.dzcdn.net/images/playlist/5ba519e87d4ef19ad28dd466d43f65bc/500x500-000000-80-0-0.jpg',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CategoryDetailScreen(
                                      genre: DeezerGenre(
                                        id: -2, 
                                        name: 'Hindi', 
                                        picture: 'https://cdn-images.dzcdn.net/images/playlist/5ba519e87d4ef19ad28dd466d43f65bc/500x500-000000-80-0-0.jpg'
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            BrowseCard(
                              title: 'Malayalam',
                              imageUrl: 'https://cdn-images.dzcdn.net/images/cover/ed91008d13a968600cd8f475653c306d/500x500-000000-80-0-0.jpg',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CategoryDetailScreen(
                                      genre: DeezerGenre(
                                        id: -3, 
                                        name: 'Malayalam', 
                                        picture: 'https://cdn-images.dzcdn.net/images/cover/ed91008d13a968600cd8f475653c306d/500x500-000000-80-0-0.jpg'
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Browse Categories',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              if (_showChips)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: ref.watch(genresProvider).when(
                        data: (genres) => SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final genre = genres[index];
                              return BrowseCard(
                                title: genre.name,
                                imageUrl: genre.picture,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoryDetailScreen(genre: genre),
                                    ),
                                  );
                                },
                              );
                            },
                            childCount: genres.length,
                          ),
                        ),
                        loading: () => const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(color: AppleMusicTheme.primaryPink),
                            ),
                          ),
                        ),
                        error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
                      ),
                ),
              if (!_showChips)
                SliverToBoxAdapter(
                  child: searchState.isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(color: AppleMusicTheme.primaryPink),
                          ),
                        )
                      : null,
                ),
              if (!_showChips && !searchState.isLoading)
                searchState.tracks.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GlassContainer(
                                padding: const EdgeInsets.all(20),
                                borderRadius: BorderRadius.circular(20),
                                child: Icon(
                                  Icons.search,
                                  size: 48,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchState.query.isEmpty ? 'Search for your favourite music' : 'No results for "${searchState.query}"',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.only(bottom: 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final track = searchState.tracks[i];
                              if (searchState.searchMode == 'albums') {
                                return _AlbumResultTile(album: track);
                              }
                              if (searchState.searchMode == 'artists') {
                                return _ArtistResultTile(artist: track);
                              }
                              return _TrackTile(track: track);
                            },
                            childCount: searchState.tracks.length,
                          ),
                        ),
                      ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  void _searchAndShowResults(String query) {
    _controller.text = query;
    setState(() => _showChips = false);
    ref.read(musicSearchProvider.notifier).search(query);
  }
}

class _FlacResultTile extends ConsumerWidget {
  final ScraperResult result;
  const _FlacResultTile({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        onTap: () => _playDirect(context, ref),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: result.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: result.thumbnail!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.black12),
                      errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.black12, child: const Icon(Icons.high_quality)),
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.black12,
                      child: const Icon(Icons.high_quality, color: Colors.white54),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                  ),
                  Text(
                    '${result.artist} · ${result.format}${result.size > 0 ? ' · ${result.formattedSize}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppleMusicTheme.darkTextSecondary : AppleMusicTheme.lightTextSecondary,
                    ),
                  ),
                  Text(
                    'via ${result.source}',
                    style: TextStyle(fontSize: 10, color: AppleMusicTheme.primaryPink.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            GlassIconButton(
              icon: Icons.play_arrow_rounded,
              size: 36,
              gradient: const LinearGradient(colors: AppleMusicTheme.purpleGradient),
              onPressed: () => _playDirect(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _playDirect(BuildContext context, WidgetRef ref) async {
    // Create a dummy file for the NowPlayingScreen
    final dummyFile = TorBoxFile(
      id: -result.url.hashCode.abs(), // Pseudo-random negative ID
      torrentId: -1,
      size: result.size,
      name: result.title,
      localPath: null, // Avoid misinterpretation as a downloaded file
    );

    await audioHandler.customAction('play', {
      'url': result.url,
      'title': result.title,
      'artist': result.artist,
      'artworkUrl': result.thumbnail ?? '',
      'forceReplace': audioHandler.playbackState.value.processingState == AudioProcessingState.idle,
      'extras': {
        'torrentId': dummyFile.torrentId,
        'fileId': dummyFile.id,
        'size': dummyFile.size,
        'localPath': null, // Ensure it's not treated as downloaded
        'source': result.source,
      },
    });

    if (context.mounted) {
      if (audioHandler.playbackState.value.playing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to Next in Queue'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppleMusicTheme.primaryPink,
          ),
        );
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NowPlayingScreen(
            file: dummyFile,
            customQueue: [dummyFile], // Prevent full library queue generation
          ),
        ),
      );
    }
  }
}

class _TrackTile extends ConsumerStatefulWidget {
  final ItunesTrack track;
  const _TrackTile({required this.track});

  @override
  ConsumerState<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends ConsumerState<_TrackTile> {
  bool _isCheckingSources = false;

  void _handleTap(TorBoxFile? matchingFile) async {
    // If the file is already in library, check if we should play next or play now
    if (matchingFile != null) {
      final trackMeta = ItunesMeta(
        trackName: widget.track.trackName,
        artistName: widget.track.artistName,
        artworkUrlLow: widget.track.artworkUrl,
        artworkUrlHigh: widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        album: widget.track.collectionName,
      );
      await ref.read(libraryProvider.notifier).updateTrackMetadata(matchingFile, trackMeta);

      final trackUrl = matchingFile.localPath != null 
          ? Uri.file(matchingFile.localPath!).toString() 
          : 'https://lazy.torbox.internal/${matchingFile.torrentId}/${matchingFile.id}';

      await audioHandler.customAction('play', {
        'url': trackUrl,
        'title': widget.track.trackName,
        'artist': widget.track.artistName,
        'artworkUrl': widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        'forceReplace': false,
        'extras': {
          'torrentId': matchingFile.torrentId,
          'fileId': matchingFile.id,
          'size': matchingFile.size,
          'localPath': matchingFile.localPath,
        },
      });

      if (!mounted) return;

      final playbackState = audioHandler.playbackState.value;
      if (playbackState.playing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to Next in Queue'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppleMusicTheme.primaryPink,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NowPlayingScreen(
            file: matchingFile,
            customQueue: [matchingFile],
          ),
        ),
      );
      return;
    }

    // Try finding a direct FLAC
    setState(() => _isCheckingSources = true);
    final flacResult = await ref.read(flacSearchProvider.notifier).resolveDirectFlac(
          widget.track.trackName,
          widget.track.artistName,
        );

    // Safety check because widget lifecycle might have ended
    if (!mounted) return;
    setState(() => _isCheckingSources = false);

    if (flacResult != null) {
      // Direct stream found!
      final dummyFile = TorBoxFile(
        id: -flacResult.url.hashCode.abs(),
        torrentId: -1,
        size: flacResult.size,
        name: flacResult.title,
        localPath: null,
      );

      // Let AudioHandler know
      await audioHandler.customAction('play', {
        'url': flacResult.url,
        'title': widget.track.trackName, 
        'artist': widget.track.artistName,
        'artworkUrl': widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        'forceReplace': false,
        'extras': {
          'torrentId': dummyFile.torrentId,
          'fileId': dummyFile.id,
          'size': dummyFile.size,
          'localPath': null,
          'source': flacResult.source,
        },
      });

      if (!mounted) return;

      if (audioHandler.playbackState.value.playing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to Next in Queue'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppleMusicTheme.primaryPink,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NowPlayingScreen(
            file: dummyFile,
            customQueue: [dummyFile],
          ),
        ),
      );
    } else {
      // Fallback: ask the user to pick from generic torrents / YT
      _showSourcePicker(context, widget.track);
    }
  }

  void _addToQueue(TorBoxFile? matchingFile) async {
    if (matchingFile != null) {
      final item = MediaItem(
        id: 'https://lazy.torbox.internal/${matchingFile.torrentId}/${matchingFile.id}',
        title: widget.track.trackName,
        artist: widget.track.artistName,
        artUri: Uri.parse(widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000')),
        extras: {
          'torrentId': matchingFile.torrentId,
          'fileId': matchingFile.id,
          'size': matchingFile.size,
          'localPath': matchingFile.localPath,
        },
      );
      await audioHandler.addQueueItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to queue: ${widget.track.trackName}'),
            backgroundColor: AppleMusicTheme.primaryPink.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isCheckingSources = true);
    final flacResult = await ref.read(flacSearchProvider.notifier).resolveDirectFlac(
          widget.track.trackName,
          widget.track.artistName,
        );
    if (!mounted) return;
    setState(() => _isCheckingSources = false);

    if (flacResult != null) {
      final item = MediaItem(
        id: flacResult.url,
        title: widget.track.trackName,
        artist: widget.track.artistName,
        artUri: Uri.parse(widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000')),
        extras: {
          'torrentId': -1,
          'fileId': -flacResult.url.hashCode.abs(),
          'size': flacResult.size,
          'localPath': null,
          'source': flacResult.source,
        },
      );
      await audioHandler.addQueueItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to queue: ${widget.track.trackName}'),
            backgroundColor: AppleMusicTheme.primaryPink.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      _showSourcePicker(context, widget.track);
    }
  }

  void _handleDownload(TorBoxFile? matchingFile) async {
    ref.read(libraryProvider.notifier).clearDownloadError();
    if (matchingFile != null) {
      final isDownloaded = ref.read(libraryProvider.notifier).isDownloaded(matchingFile);
      if (isDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already downloaded')),
        );
        return;
      }
      await ref.read(libraryProvider.notifier).downloadTrack(matchingFile);
      return;
    }

    // Not in library? Try direct FLAC first!
    setState(() => _isCheckingSources = true);
    final flacResult = await ref.read(flacSearchProvider.notifier).resolveDirectFlac(
      widget.track.trackName, 
      widget.track.artistName
    );
    
    if (!mounted) return;
    setState(() => _isCheckingSources = false);
    if (flacResult != null) {
      // Found a direct source! Let's download it directly to local "Offline Songs"
      final fileId = -flacResult.url.hashCode.abs();
      await ref.read(libraryProvider.notifier).downloadTrackFromUri(
            url: flacResult.url,
            title: widget.track.trackName,
            artist: widget.track.artistName,
            artworkUrl: widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
            fileId: fileId,
          );
    } else {
      // Fallback: show picker
      _showSourcePicker(context, widget.track);
    }
  }

  void _showDownloadFeedback(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting download: $title'),
        backgroundColor: AppleMusicTheme.primaryBlue.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryNotifier = ref.read(libraryProvider.notifier);
    
    final matchingFile = ref.read(libraryProvider).findMatchingTrack(widget.track.trackName, widget.track.artistName);
       return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Slidable(
        key: ValueKey(widget.track.trackId),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.4,
          children: [
            SlidableAction(
              onPressed: (_) => _addToQueue(matchingFile),
              backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              foregroundColor: isDark ? Colors.white : Colors.black,
              icon: Icons.add_rounded,
              label: 'Queue',
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 4),
            SlidableAction(
              onPressed: (_) => _handleDownload(matchingFile),
              backgroundColor: AppleMusicTheme.primaryBlue.withOpacity(0.1),
              foregroundColor: AppleMusicTheme.primaryBlue,
              icon: Icons.download_rounded,
              label: 'Get',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(8),
          borderRadius: 12,
          onTap: _isCheckingSources ? null : () => _handleTap(matchingFile),
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => TrackActionSheet(
                track: widget.track,
                libraryFile: matchingFile,
              ),
            );
          },
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.track.artworkUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.black12,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.black12,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      '${widget.track.artistName} · ${widget.track.collectionName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark 
                            ? AppleMusicTheme.darkTextSecondary 
                            : AppleMusicTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCheckingSources)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppleMusicTheme.primaryPink),
                  ),
                )
              else
                GlassIconButton(
                  icon: matchingFile != null ? Icons.play_arrow_rounded : Icons.search_rounded,
                  size: 36,
                  gradient: const LinearGradient(
                    colors: [
                      AppleMusicTheme.primaryPink,
                      AppleMusicTheme.primaryPurple,
                    ],
                  ),
                  onPressed: () => _handleTap(matchingFile),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourcePicker(BuildContext context, ItunesTrack track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourcePickerSheet(track: track),
    );
  }
}

class _AlbumResultTile extends StatelessWidget {
  final ItunesTrack album;
  const _AlbumResultTile({required this.album});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => AlbumScreen(album: album)),
          );
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: album.artworkUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.black12,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.black12,
                  child: const Icon(Icons.album, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.collectionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    album.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark 
                          ? AppleMusicTheme.darkTextSecondary 
                          : AppleMusicTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistResultTile extends ConsumerWidget {
  final ItunesTrack artist;
  const _ArtistResultTile({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageAsync = ref.watch(artistImageProvider(ArtistImageParams(name: artist.artistName, url: artist.artistViewUrl)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => ArtistScreen(artistName: artist.artistName),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
              child: ClipOval(
                child: imageAsync.when(
                  data: (url) => url != null && url.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Icon(
                            Icons.person,
                            color: isDark ? Colors.white24 : Colors.black26,
                            size: 30,
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            color: isDark ? Colors.white24 : Colors.black26,
                            size: 30,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: isDark ? Colors.white24 : Colors.black26,
                          size: 30,
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => Icon(
                    Icons.person,
                    color: isDark ? Colors.white24 : Colors.black26,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    'Artist',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppleMusicTheme.darkTextSecondary
                          : AppleMusicTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
