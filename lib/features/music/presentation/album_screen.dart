import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/music_models.dart';
import 'music_providers.dart';
import 'playlist_providers.dart';
import '../data/itunes_metadata_service.dart';
import '../../player/presentation/player_providers.dart';
import 'source_picker_sheet.dart';
import 'torrent_picker_sheet.dart';
import 'now_playing_screen.dart';
import 'track_action_sheet.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import 'package:audio_service/audio_service.dart';
import 'package:isai/main.dart';
import 'package:flutter/services.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  final ItunesTrack album;

  const AlbumScreen({super.key, required this.album});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(albumTracksProvider(widget.album));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
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
        child: tracksAsync.when(
          data: (tracks) {
            final totalMillis = tracks.fold<int>(0, (sum, t) => sum + (t.trackTimeMillis ?? 0));
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(isDark, tracks, totalMillis),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1c1c1e) : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tracks',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                             
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (tracks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48.0),
                            child: Center(
                              child: Text(
                                'No tracks found for this album.',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: tracks.length,
                            itemBuilder: (context, index) {
                              final track = tracks[index];
                              return _AlbumTrackTile(
                                track: track,
                                album: widget.album,
                                allTracks: tracks,
                              );
                            },
                          ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppleMusicTheme.primaryPink,
            ),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Error loading tracks:\n$err',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, List<ItunesTrack> tracks, int totalMillis) {
    final trackCount = tracks.length;
    final artworkUrl = widget.album.artworkUrl?.replaceAll('170x170bb', '600x600bb') ?? '';

    return SliverAppBar(
      expandedHeight: 480.0,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GlassIconButton(
          icon: Icons.arrow_back_ios_new,
          size: 36,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: GlassIconButton(
            icon: Icons.more_horiz,
            size: 36,
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showAlbumActionSheet(context, tracks);
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (artworkUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: artworkUrl,
                fit: BoxFit.cover,
              ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                      isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  // Album Artwork
                  Hero(
                    tag: 'album_${widget.album.trackId}',
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: artworkUrl,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppleMusicTheme.primaryPink.withOpacity(0.3),
                                      AppleMusicTheme.primaryPurple.withOpacity(0.3),
                                    ],
                                  ),
                                ),
                                child: const Icon(Icons.album, size: 64, color: Colors.white54),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Artist Name (Smaller, Colored)
                  Text(
                    widget.album.artistName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppleMusicTheme.primaryPink,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Album Title (Big, Bold)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _cleanName(widget.album.collectionName),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Metadata Row (Tracks, Duration)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMetadataItem(
                        Icons.group_work_rounded,
                        '$trackCount tracks',
                        isDark,
                      ),
                      const SizedBox(width: 16),
                      _buildMetadataItem(
                        Icons.timer_outlined,
                        ItunesTrack.formatDurationLong(totalMillis),
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Play Button
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24, right: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _handlePlayAlbum(tracks, context, shuffle: false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Play',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Shuffle Button
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, right: 24),
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _handlePlayAlbum(tracks, context, shuffle: true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shuffle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Shuffle',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataItem(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _handlePlayAlbum(List<ItunesTrack> tracks, BuildContext context, {bool shuffle = false}) async {
    if (tracks.isEmpty) return;
    
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final library = ref.read(libraryProvider);
    
    // 1. Determine track order
    final sortedTracks = shuffle ? (tracks.toList()..shuffle()) : tracks;
    final List<TorBoxFile> queueFiles = [];

    // 2. Pre-build metadata and queue files
    for (final t in sortedTracks) {
      final tMeta = ItunesMeta(
        trackName: t.trackName,
        artistName: widget.album.artistName,
        artworkUrlLow: widget.album.artworkUrl,
        artworkUrlHigh: widget.album.artworkUrl?.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
        album: widget.album.collectionName,
      );

      final tLibFile = library.findMatchingTrack(t.trackName, widget.album.artistName);
      if (tLibFile != null) {
        queueFiles.add(tLibFile);
        await libraryNotifier.updateTrackMetadata(tLibFile, tMeta);
      } else {
        final flacDummy = TorBoxFile(
          id: -t.trackId,
          torrentId: -1,
          size: 0,
          name: t.trackName,
          localPath: null,
        );
        queueFiles.add(flacDummy);
        await libraryNotifier.updateTrackMetadata(flacDummy, tMeta);
      }
    }

    if (queueFiles.isEmpty) return;

    // 3. Start playback from the first track in the (potentially shuffled) list
    final firstTrack = sortedTracks.first;
    final firstFile = queueFiles.first;

    if (firstFile.torrentId != -1) {
      final firstMeta = ref.read(libraryProvider).metadata['${firstFile.torrentId}-${firstFile.id}'];
      final firstUrl = 'https://lazy.torbox.internal/${firstFile.torrentId}/${firstFile.id}';

      await audioHandler.customAction('play', {
        'url': firstUrl,
        'title': firstMeta?.trackName ?? firstFile.name,
        'artist': firstMeta?.artistName ?? widget.album.artistName,
        'artworkUrl': firstMeta?.artworkUrlHigh ?? firstMeta?.artworkUrlLow ?? '',
        'forceReplace': true,
        'queue': queueFiles.map((e) {
          final qMeta = ref.read(libraryProvider).metadata['${e.torrentId}-${e.id}'];
          String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
          if (e.torrentId == -1) {
            fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qMeta?.trackName ?? e.name)}&artist=${Uri.encodeComponent(qMeta?.artistName ?? widget.album.artistName)}';
          }
          return {
            'url': fUrl,
            'title': qMeta?.trackName ?? e.name,
            'artist': qMeta?.artistName ?? widget.album.artistName,
            'artworkUrl': qMeta?.artworkUrlHigh ?? qMeta?.artworkUrlLow ?? '',
            'extras': {
              'torrentId': e.torrentId,
              'fileId': e.id,
              'size': e.size,
              'localPath': e.localPath,
            }
          };
        }).toList(),
        'index': 0,
        'extras': {
          'torrentId': firstFile.torrentId,
          'fileId': firstFile.id,
          'size': firstFile.size,
          'localPath': null,
        },
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              file: firstFile,
              customQueue: queueFiles,
            ),
          ),
        );
      }
    } else {
      // If the first track needs resolution, open SourcePickerSheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SourcePickerSheet(
          track: firstTrack,
          albumContext: widget.album,
          albumQueue: queueFiles,
          forceReplace: true,
        ),
      );
    }
  }

  void _showAlbumActionSheet(BuildContext context, List<ItunesTrack> tracks) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playlists = ref.read(playlistProvider).value ?? [];
    final albumKey = 'apple_music_album_${widget.album.trackId}';
    final existingPlaylist = playlists.where((p) => p.playlist.sourceUrl == albumKey).firstOrNull;
    final isAdded = existingPlaylist != null;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1c1c1e).withOpacity(0.95) : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                // Album Header Preview
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.album.artworkUrl?.replaceAll('170x170bb', '200x200bb') ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.album.collectionName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.album.artistName,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppleMusicTheme.primaryPink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Action: Play from Source
                _buildActionItem(
                  icon: Icons.source_rounded,
                  label: 'Play Album from Source',
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SourcePickerSheet(
                        track: widget.album, // Uses album info for search
                        forceReplace: true,
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                // Action: Download Torrent
                _buildActionItem(
                  icon: Icons.download_for_offline_rounded,
                  label: 'Download Album (Torrent)',
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => TorrentPickerSheet(
                        track: widget.album, // Uses album info for torrent query
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                // Action: Add / Remove from Library
                _buildActionItem(
                  icon: isAdded ? Icons.library_add_check_rounded : Icons.library_add_rounded,
                  label: isAdded ? 'Remove from Library' : 'Add to Library',
                  onTap: () async {
                    Navigator.pop(context);
                    if (isAdded) {
                      try {
                        await ref.read(playlistProvider.notifier).deletePlaylist(existingPlaylist.playlist.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Removed album from Library'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to remove: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } else {
                      try {
                        await ref.read(playlistProvider.notifier).importItunesTracksPlaylist(
                          widget.album.collectionName,
                          widget.album.artworkUrl,
                          tracks,
                          sourceUrl: albumKey,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added album to Library'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to add: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
      onTap: onTap,
    );
  }
}

class _AlbumTrackTile extends ConsumerStatefulWidget {
  final ItunesTrack track;
  final ItunesTrack album;
  final List<ItunesTrack> allTracks;

  const _AlbumTrackTile({required this.track, required this.album, required this.allTracks});

  @override
  ConsumerState<_AlbumTrackTile> createState() => _AlbumTrackTileState();
}

class _AlbumTrackTileState extends ConsumerState<_AlbumTrackTile> {
  bool _isCheckingSources = false;

  void _handleTap(TorBoxFile? matchingFile) async {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final List<TorBoxFile> queueFiles = [];

    // Pre-build the album queue
    for (int i = 0; i < widget.allTracks.length; i++) {
       final t = widget.allTracks[i];
       
       final tMeta = ItunesMeta(
          trackName: t.trackName,
          artworkUrlLow: widget.album.artworkUrl,
          artworkUrlHigh: widget.album.artworkUrl?.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
          artistName: widget.album.artistName,
          album: widget.album.collectionName,
       );
       
       final tLibFile = ref.read(libraryProvider).findMatchingTrack(t.trackName, widget.album.artistName);
       if (tLibFile != null) {
          queueFiles.add(tLibFile);
          await libraryNotifier.updateTrackMetadata(tLibFile, tMeta);
       } else {
          final dummyId = -t.trackId;
          final flacDummy = TorBoxFile(
            id: dummyId,
            torrentId: -1,
            size: 0,
            name: t.trackName,
            localPath: null,
          );
          queueFiles.add(flacDummy);
          // Set metadata so NowPlayingScreen can build the lazy.flac.internal URL with title/artist
          await libraryNotifier.updateTrackMetadata(flacDummy, tMeta);
       }
    }

    // If the file is already downloaded or in library, just play it.
    if (matchingFile != null) {
      if (mounted) {
        // If nothing is playing, we can load the whole album starting from here.
        // If something is playing, we just add THIS track as next.
        final meta = ref.read(libraryProvider).metadata['${matchingFile.torrentId}-${matchingFile.id}'];
        final url = matchingFile.localPath != null 
            ? Uri.file(matchingFile.localPath!).toString() 
            : 'https://lazy.torbox.internal/${matchingFile.torrentId}/${matchingFile.id}';
        
        await audioHandler.customAction('play', {
          'url': url,
          'title': meta?.trackName ?? matchingFile.name,
          'artist': meta?.artistName ?? widget.album.artistName,
          'artworkUrl': meta?.artworkUrlHigh ?? meta?.artworkUrlLow ?? '',
          'forceReplace': true,
          'queue': queueFiles.map((e) {
            final qMeta = ref.read(libraryProvider).metadata['${e.torrentId}-${e.id}'];
            String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
            if (e.torrentId == -1) {
              fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qMeta?.trackName ?? e.name)}&artist=${Uri.encodeComponent(qMeta?.artistName ?? widget.album.artistName)}';
            }
            return {
              'url': fUrl,
              'title': qMeta?.trackName ?? e.name,
              'artist': qMeta?.artistName ?? widget.album.artistName,
              'artworkUrl': qMeta?.artworkUrlHigh ?? qMeta?.artworkUrlLow ?? '',
              'extras': {
                'torrentId': e.torrentId,
                'fileId': e.id,
                'size': e.size,
                'localPath': e.localPath,
              }
            };
          }).toList(),
          'index': queueFiles.indexOf(matchingFile),
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NowPlayingScreen(
                file: matchingFile,
                customQueue: queueFiles,
              ),
            ),
          );
        }
      }
      return;
    }

    // Try finding a direct FLAC
    setState(() => _isCheckingSources = true);
    final flacResult = await ref.read(flacSearchProvider.notifier).resolveDirectFlac(
      widget.track.trackName, 
      widget.album.artistName
    );
    
    // Safety check because widget lifecycle might have ended
    if (!mounted) return;
    setState(() => _isCheckingSources = false);

    if (flacResult != null) {
      // Direct stream found!
      final dummyFile = TorBoxFile(
        id: -widget.track.trackId, // Align with dummy queue ID
        torrentId: -1,
        size: flacResult.size,
        name: flacResult.title,
        localPath: null,
      );

      // Let AudioHandler know
      await audioHandler.customAction('play', {
        'url': flacResult.url,
        'title': widget.track.trackName, // Prefer iTunes metadata
        'artist': widget.album.artistName,
        'artworkUrl': widget.album.artworkUrl?.replaceAll(RegExp(r'\d+x\d+'), '1000x1000') ?? '',
        'queue': queueFiles.map((e) {
          final qMeta = ref.read(libraryProvider).metadata['${e.torrentId}-${e.id}'];
          String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
          if (e.id == dummyFile.id && e.torrentId == dummyFile.torrentId) {
             fUrl = flacResult.url; // Inject active
          } else if (e.torrentId == -1) {
             fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(qMeta?.trackName ?? e.name)}&artist=${Uri.encodeComponent(qMeta?.artistName ?? widget.album.artistName)}';
             return {
               'url': fUrl,
               'title': qMeta?.trackName ?? e.name,
               'artist': qMeta?.artistName ?? widget.album.artistName,
               'artworkUrl': qMeta?.artworkUrlHigh ?? qMeta?.artworkUrlLow ?? '',
               'extras': {
                 'torrentId': e.torrentId,
                 'fileId': e.id,
                 'size': e.size,
                 'localPath': e.localPath,
               }
             };
          }
          return {
            'url': fUrl,
            'title': qMeta?.trackName ?? e.name,
            'artist': qMeta?.artistName ?? widget.album.artistName,
            'artworkUrl': qMeta?.artworkUrlHigh ?? qMeta?.artworkUrlLow ?? '',
            'extras': {
              'torrentId': e.torrentId,
              'fileId': e.id,
              'size': e.size,
              'localPath': e.localPath,
            }
          };
        }).toList(),
        'forceReplace': true,
        'extras': {
          'torrentId': dummyFile.torrentId,
          'fileId': dummyFile.id,
          'size': dummyFile.size,
          'localPath': null,
          'source': flacResult.source,
        },
      });

      if (mounted) {
        if (audioHandler.playbackState.value.processingState != AudioProcessingState.idle) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to Next in Queue'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              backgroundColor: AppleMusicTheme.primaryPink,
            ),
          );
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              file: dummyFile,
              customQueue: queueFiles,
            ),
          ),
        );
      }
    } else {
      // Fallback: ask the user to pick from generic torrents / YT
      _showSourcePicker(
        context, 
        widget.track, 
        albumQueue: queueFiles,
        forceReplace: true,
      );
    }
  }

  void _showSourcePicker(BuildContext context, ItunesTrack track, {List<TorBoxFile>? albumQueue, bool forceReplace = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourcePickerSheet(
        track: track,
        albumQueue: albumQueue,
        forceReplace: forceReplace,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final matchingFile = ref.read(libraryProvider).findMatchingTrack(widget.track.trackName, widget.album.artistName);
    
    return InkWell(
      onTap: _isCheckingSources ? null : () {
        HapticFeedback.lightImpact();
        _handleTap(matchingFile);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            // Track Artwork / Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.album.artworkUrl?.replaceAll('170x170bb', '100x100bb') ?? '',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: isDark ? Colors.white12 : Colors.black12,
                  child: const Icon(Icons.music_note, size: 20, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Track Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.trackName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ItunesTrack.formatDuration(widget.track.trackTimeMillis),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Play Action
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
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _handleTap(matchingFile);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF5E3A), // Vibrant coral/orange
                        Color(0xFFFF2A68), // Pinkish red
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A68).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _cleanName(String name) {
  return name
      .replaceAll(RegExp(r'\[.*?\]'), '')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
