import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'music_providers.dart';
import 'source_picker_sheet.dart';
import 'now_playing_screen.dart';
import 'playlists_screen.dart';
import '../data/music_models.dart';
import '../data/itunes_metadata_service.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import 'package:isai/main.dart';

class MoodDetailsScreen extends ConsumerWidget {
  final String mood;
  final List<Color> gradientColors;
  final String? contextQuery;
  final bool isPersonal;
  final int? genreId;

  const MoodDetailsScreen({
    super.key,
    required this.mood,
    required this.gradientColors,
    this.contextQuery,
    this.isPersonal = false,
    this.genreId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ItunesTrack>> moodSongs;
    
    if (isPersonal) {
      moodSongs = ref.watch(reccoMixProvider(MoodSearchParams(mood: mood, context: contextQuery)));
    } else {
      moodSongs = ref.watch(moodSongsProvider(MoodSearchParams(mood: mood, context: contextQuery)));
    }
    
    final AsyncValue<List<DeezerPlaylist>> playlistsAsync;
    if (genreId != null) {
      playlistsAsync = ref.watch(genrePlaylistsProvider(GenrePlaylistsParams(id: genreId!, name: mood)));
    } else {
      playlistsAsync = const AsyncValue.data([]);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          
          if (genreId != null)
            playlistsAsync.when(
              data: (playlists) {
                if (playlists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Text(
                          'Related Playlists',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,),
                        ),
                      ),
                      SizedBox(
                        height: 185,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaylistDetailsScreen(
                                        deezerPlaylist: playlist,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: CachedNetworkImage(
                                          imageUrl: playlist.artworkUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: isDark ? Colors.white10 : Colors.black12,
                                            child: const Icon(Icons.music_note_rounded, color: Colors.grey),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: isDark ? Colors.white10 : Colors.black12,
                                            child: const Icon(Icons.queue_music_rounded, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        playlist.title,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Text(
                          'Top Songs',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: SizedBox(
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

          moodSongs.when(
            data: (songs) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _MoodSongTile(
                    track: songs[index],
                    allSongs: songs,
                    index: index + 1,
                    gradientColors: gradientColors,
                  ),
                  childCount: songs.length,
                ),
              ),
            ),
            loading: () => SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: isDark ? Colors.black : Colors.white,
      leading: const BackButton(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 50, bottom: 16),
        title: Text(
          isPersonal ? 'Personal $mood Mix' : '$mood Vibes',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),
            // Abstract pattern icons
            Center(
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  _getMoodIcon(),
                  size: 200,
                  color: Colors.white,
                ),
              ),
            ),
            // Bottom gradient for title readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMoodIcon() {
    switch (mood) {
      case 'Happy': return Icons.wb_sunny_rounded;
      case 'Chill': return Icons.nightlight_round;
      case 'Sad': return Icons.cloud_rounded;
      case 'Focus': return Icons.psychology_rounded;
      case 'Energy': return Icons.bolt_rounded;
      default: return Icons.music_note_rounded;
    }
  }
}

class _MoodSongTile extends ConsumerStatefulWidget {
  final ItunesTrack track;
  final List<ItunesTrack> allSongs;
  final int index;
  final List<Color> gradientColors;

  const _MoodSongTile({
    required this.track,
    required this.allSongs,
    required this.index,
    required this.gradientColors,
  });

  @override
  ConsumerState<_MoodSongTile> createState() => _MoodSongTileState();
}

class _MoodSongTileState extends ConsumerState<_MoodSongTile> {
  TorBoxFile? _matchingFile;
  ItunesMeta? _meta;
  bool _isCheckingSources = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLibrary());
  }

  void _handleTap() async {
    if (_matchingFile != null) {
      final library = ref.read(libraryProvider);
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

      final url = _matchingFile!.localPath != null
          ? Uri.file(_matchingFile!.localPath!).toString()
          : 'https://lazy.torbox.internal/${_matchingFile!.torrentId}/${_matchingFile!.id}';

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
              file: _matchingFile!,
              customQueue: customQueue,
            ),
          ),
        );
      }
    } else {
      HapticFeedback.lightImpact();
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

  Future<void> _checkLibrary() async {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final file = ref.read(libraryProvider).findMatchingTrack(widget.track.trackName, widget.track.artistName);
    if (file != null) {
      if (!mounted) return;
      setState(() {
        _matchingFile = file;
      });
      libraryNotifier.enrichTrack(file);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      
      final trackMeta = ItunesMeta(
        trackName: widget.track.trackName,
        artworkUrlLow: widget.track.artworkUrl,
        artworkUrlHigh: widget.track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        artistName: widget.track.artistName,
        album: widget.track.collectionName,
      );
      await libraryNotifier.updateTrackMetadata(file, trackMeta);
      
      if (mounted) {
        setState(() {
          _meta = trackMeta;
        });
      }
    }
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
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: CachedNetworkImageProvider(widget.track.artworkUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.trackName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.track.artistName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black54,),
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
