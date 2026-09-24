import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../../core/theme/glassmorphism.dart';
import '../data/music_models.dart';
import 'music_providers.dart';
import 'playlists_screen.dart';
import 'now_playing_screen.dart';
import 'source_picker_sheet.dart';
import 'package:isai/main.dart';

class CategoryDetailScreen extends ConsumerWidget {
  final DeezerGenre genre;

  const CategoryDetailScreen({super.key, required this.genre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(genrePlaylistsProvider(GenrePlaylistsParams(id: genre.id, name: genre.name)));
    final topSongsAsync = ref.watch(moodSongsProvider(MoodSearchParams(mood: genre.name, context: genre.name)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? Colors.black : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                genre.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: genre.picture,
                    memCacheWidth: 600,
                    memCacheHeight: 400,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          playlistsAsync.when(
            data: (playlists) {
              if (playlists.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(
                        'Category Playlists',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridCrossAxisCount(context),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final playlist = playlists[index];
                          return RepaintBoundary(
                            child: AppleMusicCard(
                              title: playlist.title,
                              subtitle: '${playlist.nbTracks} tracks',
                              imageUrl: playlist.artworkUrl,
                              onTap: () {
                                debugPrint('[CategoryDetailScreen] Tapped playlist: ${playlist.title} (ID: ${playlist.id})');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlaylistDetailsScreen(
                                      deezerPlaylist: playlist,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: playlists.length,
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top Songs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  topSongsAsync.maybeWhen(
                    data: (songs) => songs.isEmpty
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () => _playAllSongs(context, ref, songs),
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: const Text('Play All'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: () => _playAllSongs(context, ref, songs, shuffle: true),
                                icon: const Icon(Icons.shuffle_rounded, size: 18),
                                tooltip: 'Shuffle All',
                                style: IconButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          topSongsAsync.when(
            data: (songs) {
              if (songs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No tracks found for this category'),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => RepaintBoundary(
                      child: _CategorySongTile(
                        track: songs[index],
                        allSongs: songs,
                      ),
                    ),
                    childCount: songs.length,
                  ),
                ),
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Future<void> _playAllSongs(BuildContext context, WidgetRef ref, List<ItunesTrack> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) return;
    AppHaptics.light(context);

    final trackList = List<ItunesTrack>.from(songs);
    if (shuffle) {
      trackList.shuffle();
    }

    final library = ref.read(libraryProvider);
    final customQueue = trackList.map<TorBoxFile>((t) {
      final match = library.findMatchingTrack(t.trackName, t.artistName);
      if (match != null) return match;
      return TorBoxFile(
        id: -t.trackId,
        torrentId: -1,
        name: t.trackName,
        size: 0,
        localPath: null,
      );
    }).toList();

    final firstTrack = trackList.first;
    final matchFile = customQueue.first;

    final url = matchFile.localPath != null
        ? Uri.file(matchFile.localPath!).toString()
        : 'https://lazy.torbox.internal/${matchFile.torrentId}/${matchFile.id}';

    await audioHandler.customAction('play', {
      'url': url,
      'title': firstTrack.trackName,
      'artist': firstTrack.artistName,
      'artworkUrl': firstTrack.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
      'forceReplace': true,
      'queue': List.generate(customQueue.length, (i) {
        final e = customQueue[i];
        final qTrack = trackList[i];
        String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
        if (e.torrentId == -1) {
          fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qTrack.trackName)}&artist=${Uri.encodeComponent(qTrack.artistName)}';
        }
        return {
          'url': fUrl,
          'title': qTrack.trackName,
          'artist': qTrack.artistName,
          'artworkUrl': qTrack.artworkUrl,
          'extras': {
            'torrentId': e.torrentId,
            'fileId': e.id,
            'size': e.size,
            'localPath': e.localPath,
          },
        };
      }),
      'index': 0,
    });

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NowPlayingScreen(
            file: matchFile,
            customQueue: customQueue,
          ),
        ),
      );
    }
  }

  int _gridCrossAxisCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 1200) return 6;
    if (w > 900) return 5;
    if (w > 700) return 4;
    if (w > 500) return 3;
    return 2;
  }
}

class _CategorySongTile extends ConsumerStatefulWidget {
  final ItunesTrack track;
  final List<ItunesTrack> allSongs;

  const _CategorySongTile({
    required this.track,
    required this.allSongs,
  });

  @override
  ConsumerState<_CategorySongTile> createState() => _CategorySongTileState();
}

class _CategorySongTileState extends ConsumerState<_CategorySongTile> {
  bool _isCheckingSources = false;

  void _handleTap() async {
    final library = ref.read(libraryProvider);
    final matchFile = library.findMatchingTrack(widget.track.trackName, widget.track.artistName);

    if (matchFile != null) {
      final customQueue = widget.allSongs.map<TorBoxFile>((t) {
        final match = library.findMatchingTrack(t.trackName, t.artistName);
        if (match != null) return match;
        return TorBoxFile(
          id: -t.trackId,
          torrentId: -1,
          name: t.trackName,
          size: 0,
          localPath: null,
        );
      }).toList();

      final startIndex = widget.allSongs.indexWhere((t) => t.trackId == widget.track.trackId);

      final url = matchFile.localPath != null
          ? Uri.file(matchFile.localPath!).toString()
          : 'https://lazy.torbox.internal/${matchFile.torrentId}/${matchFile.id}';

      await audioHandler.customAction('play', {
        'url': url,
        'title': widget.track.trackName,
        'artist': widget.track.artistName,
        'artworkUrl': widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        'forceReplace': true,
        'queue': List.generate(customQueue.length, (i) {
          final e = customQueue[i];
          final qTrack = widget.allSongs[i];
          String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
          if (e.torrentId == -1) {
            fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qTrack.trackName)}&artist=${Uri.encodeComponent(qTrack.artistName)}';
          }
          return {
            'url': fUrl,
            'title': qTrack.trackName,
            'artist': qTrack.artistName,
            'artworkUrl': qTrack.artworkUrl,
            'extras': {
              'torrentId': e.torrentId,
              'fileId': e.id,
              'size': e.size,
              'localPath': e.localPath,
            },
          };
        }),
        'index': startIndex != -1 ? startIndex : 0,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              file: matchFile,
              customQueue: customQueue,
            ),
          ),
        );
      }
    } else {
      AppHaptics.light(context);
      setState(() => _isCheckingSources = true);
      try {
        final flacResult = await ref.read(flacSearchProvider.notifier).resolveDirectFlac(
          widget.track.trackName,
          widget.track.artistName,
        );
        if (!mounted) return;
        setState(() => _isCheckingSources = false);

        if (flacResult != null) {
          final dummyFile = TorBoxFile(
            id: -flacResult.url.hashCode.abs(),
            torrentId: -1,
            size: flacResult.size,
            name: flacResult.title,
            localPath: null,
          );

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

          if (mounted) {
            if (audioHandler.playbackState.value.playing) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Added to Next in Queue'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
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
          }
        } else {
          _showSourcePicker(context, widget.track);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isCheckingSources = false);
          _showSourcePicker(context, widget.track);
        }
      }
    }
  }

  void _showSourcePicker(BuildContext context, ItunesTrack track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourcePickerSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 20,
        onTap: _isCheckingSources ? null : _handleTap,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.track.artworkUrl,
                memCacheWidth: 120,
                memCacheHeight: 120,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: isDark ? Colors.white10 : Colors.black12),
                errorWidget: (_, __, ___) => Container(color: isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.trackName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.track.artistName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _isCheckingSources
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.play_circle_fill_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
          ],
        ),
      ),
    );
  }
}

