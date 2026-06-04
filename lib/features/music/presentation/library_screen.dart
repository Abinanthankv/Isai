import 'dart:ui';
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

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
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
                // Settings is the 4th tab (index 3)
                // We need to access the MusicHubScreen's state to change the tab.
                // However, without a global navigator or controller, we can't easily.
                // For now, just show the message. 
                // Alternatively, we could push SettingsScreen on top.
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
          onRefresh: () => ref.read(libraryProvider.notifier).loadLibrary(force: true),
          color: AppleMusicTheme.primaryPink,
          child: CustomScrollView(
            slivers: [
              // 1. Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(
                    children: [
                      const Text(
                        'Library',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      
                    ],
                  ),
                ),
              ),


                // 3. Category Grid
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

              // 4. Recently Played Label
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Recently Played',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. List of items or Empty State
              _buildContentSlivers(),
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
      loading: () => const SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: AppleMusicTheme.primaryPink),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded, color: AppleMusicTheme.primaryPink),
                    title: const Text('Fix Metadata'),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.isNotEmpty ? parts.join(' • ') : widget.file.formattedSize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark 
                          ? AppleMusicTheme.darkTextSecondary 
                          : AppleMusicTheme.lightTextSecondary,
                      fontSize: 12,
                    ),
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
                  AppleMusicTheme.primaryPink.withOpacity(0.8),
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
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppleMusicTheme.primaryPink),
          ),
        ),
      );
    }

    if (isDownloaded) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppleMusicTheme.primaryPink.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.offline_pin_rounded,
          color: AppleMusicTheme.primaryPink,
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
            AppleMusicTheme.primaryPink.withOpacity(0.3),
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
                color: AppleMusicTheme.primaryPink.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppleMusicTheme.primaryPink,
                size: 20,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
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
                icon: const Icon(Icons.arrow_back_ios, color: AppleMusicTheme.primaryPink),
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
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppleMusicTheme.primaryPink)),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.count} tracks',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
