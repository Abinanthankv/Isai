import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'music_providers.dart';
import 'music_search_screen.dart';
import 'now_playing_screen.dart';
import '../data/music_models.dart';
import 'album_screen.dart';
import 'package:isai/core/theme/apple_music_theme.dart';
import 'package:isai/core/theme/glassmorphism.dart';
import 'package:isai/core/theme/apple_music_components.dart';
import 'downloads_screen.dart';
import 'mood_details_screen.dart';
import 'artist_screen.dart';
import 'package:isai/main.dart';
import 'source_picker_sheet.dart';
import 'playlists_screen.dart';
import 'track_action_sheet.dart';
import 'lastfm_discovery_providers.dart';
import 'package:isai/features/music/presentation/discovery_swipe_screen.dart';
import 'package:isai/features/music/presentation/discovery_providers.dart';


class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topSongs = ref.watch(cachedTrendingSongsProvider);
    final selectedRegion = ref.watch(selectedRegionProvider);
    final regionalSongs = ref.watch(regionalTrendingSongsProvider(RegionalChartParams(selectedRegion)));
    final isOffline = ref.watch(isOfflineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newReleases = ref.watch(newReleasesProvider(selectedRegion));
    final genres = ref.watch(genresProvider);
    final playlists = ref.watch(regionalPlaylistsProvider(selectedRegion));
    final selectedJioLanguage = ref.watch(selectedJioSaavnLanguageProvider);
    final jioPlaylistsAsync = ref.watch(jiosaavnFeaturedPlaylistsProvider(selectedJioLanguage));

    if (isOffline) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: OfflinePlaceholder(
          title: 'No Internet Connection',
          message: 'Connect to the internet to discover new music, or listen to your downloaded songs.',
          onGoToDownloads: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
            );
          },
        ),
      );
    }

    final regionName = {
      'in': 'India',
      'us': 'USA',
      'gb': 'UK',
      'jp': 'Japan',
      'kr': 'Korea',
    }[selectedRegion] ?? 'Region';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, ref, selectedRegion, isDark),
          
          SliverToBoxAdapter(
            child: _buildRecentlyPlayedSection(context, ref),
          ),
          
          SliverToBoxAdapter(
            child: _buildVibeSwipeBanner(context, ref, isDark),
          ),

          SliverToBoxAdapter(
            child: _buildNewReleasesSection(context, ref, newReleases, isDark),
          ),

          SliverToBoxAdapter(
            child: _buildLastfmTrendingSection(context, ref),
          ),

          SliverToBoxAdapter(
            child: _buildGenreBrowseSection(context, ref, genres, isDark),
          ),

          SliverToBoxAdapter(
            child: _buildJioSaavnPlaylistsSection(context, ref, selectedJioLanguage, jioPlaylistsAsync, isDark),
          ),

          SliverToBoxAdapter(
            child: _buildAppleMusicPlaylistsSection(context, ref, playlists, isDark),
          ),


          
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),

    );
  }

  List<Color> _getGradientForIndex(int index) {
    final gradients = [
      AppleMusicTheme.pinkGradient,
      AppleMusicTheme.purpleGradient,
      AppleMusicTheme.orangeGradient,
      AppleMusicTheme.blueGradient,
    ];
    return gradients[index % gradients.length];
  }

  void _handleTrackTap(BuildContext context, WidgetRef ref, ItunesTrack track) async {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final matchingFile = ref.read(libraryProvider).findMatchingTrack(track.trackName, track.artistName);

    if (matchingFile != null) {
      final meta = ref.read(libraryProvider).metadata['${matchingFile.torrentId}-${matchingFile.id}'];
      final url = matchingFile.localPath != null 
          ? Uri.file(matchingFile.localPath!).toString() 
          : 'https://lazy.torbox.internal/${matchingFile.torrentId}/${matchingFile.id}';
      
      final initialArtwork = meta?.artworkUrlHigh ?? meta?.artworkUrlLow ?? track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000');
      
      await audioHandler.customAction('play', {
        'url': url,
        'title': meta?.trackName ?? track.trackName,
        'artist': meta?.artistName ?? track.artistName,
        'artworkUrl': initialArtwork,
        'forceReplace': true,
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              file: matchingFile,
              initialArtwork: initialArtwork,
            ),
          ),
        );
      }
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SourcePickerSheet(
          track: track,
          forceReplace: true,
        ),
      );
    }
  }

  Widget _buildRecentlyPlayedSection(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(recentlyPlayedProvider);
    return historyAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final displayItems = items.take(4).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Recently played', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2, // Tweak based on content
              ),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return GlassCard(
                  padding: const EdgeInsets.all(8),
                  borderRadius: 12,
                  onTap: () {
                    final file = TorBoxFile(
                      id: item.fileId,
                      torrentId: item.torrentId,
                      name: item.trackTitle,
                      size: 0,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NowPlayingScreen(
                          file: file,
                          customQueue: [file],
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    final itunesTrack = ItunesTrack(
                      trackId: item.fileId,
                      trackName: item.trackTitle,
                      artistName: item.artist,
                      collectionName: item.album,
                      artworkUrl: item.artworkUrlHigh ?? item.artworkUrlLow ?? '',
                    );
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => TrackActionSheet(
                        track: itunesTrack,
                        libraryFile: TorBoxFile(
                          id: item.fileId,
                          torrentId: item.torrentId,
                          name: item.trackTitle,
                          size: 0,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item.artworkUrlHigh ?? item.artworkUrlLow ?? '',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: Colors.grey.withOpacity(0.2)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.trackTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(item.artist, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildVibeSwipeBanner(BuildContext context, WidgetRef ref, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiscoverySwipeScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppleMusicTheme.primaryPink, AppleMusicTheme.primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppleMusicTheme.primaryPink.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vibe Swipe',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Swipe through personalized 10s previews to find your new favorites.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.style_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastfmTrendingSection(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(lastfmGlobalTopArtistsProvider);
    final tracksAsync = ref.watch(lastfmGlobalTopTracksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Trending on Last.fm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ),
        artistsAsync.when(
          data: (artists) {
            if (artists.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: artists.length,
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  final name = artist['name'] as String;
                  final imageUrl = artist['image_url'] as String;

                  return Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ArtistScreen(artistName: name)),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 85,
                            height: 85,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey.withOpacity(0.1)),
                                      errorWidget: (_, __, ___) => _buildArtistPlaceholder(),
                                    )
                                  : _buildArtistPlaceholder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 85,
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Global Hot Tracks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ),
        tracksAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final name = track['name'] as String;
                  final artist = track['artist'] as String;
                  final imageUrl = track['image_url'] as String;

                  // Map to ItunesTrack for reuse of UI handlers
                  final itunesTrack = ItunesTrack(
                    trackId: index, // Placeholder
                    trackName: name,
                    artistName: artist,
                    collectionName: '',
                    artworkUrl: imageUrl,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _handleTrackTap(context, ref, itunesTrack),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.grey.withOpacity(0.1)),
                                    errorWidget: (_, __, ___) => _buildTrackPlaceholder(150),
                                  )
                                : _buildTrackPlaceholder(150),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 150,
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(
                            width: 150,
                            child: Text(artist, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildArtistPlaceholder() {
    return Container(
      color: Colors.grey.withOpacity(0.2),
      child: const Icon(Icons.person_rounded, color: Colors.grey),
    );
  }

  Widget _buildTrackPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.withOpacity(0.2),
      child: const Icon(Icons.music_note_rounded, color: Colors.grey),
    );
  }

  // ─── NEW RELEASES HERO CAROUSEL ─────────────────────────────────
  Widget _buildNewReleasesSection(BuildContext context, WidgetRef ref, AsyncValue<List<ItunesTrack>> releasesAsync, bool isDark) {
    return releasesAsync.when(
      data: (releases) {
        if (releases.isEmpty) return const SizedBox.shrink();
        final items = releases.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppleMusicTheme.primaryPink, AppleMusicTheme.primaryPurple]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Fresh Releases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.85),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final track = items[index];
                  final artworkHi = track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '600x600');
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => _handleTrackTap(context, ref, track),
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => TrackActionSheet(track: track),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: artworkHi,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _getGradientForIndex(index),
                                    ),
                                  ),
                                ),
                              ),
                              // Gradient overlay for text readability
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                      stops: const [0.4, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.trackName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      track.artistName,
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Play icon overlay
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppleMusicTheme.primaryPink))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── BROWSE BY GENRE GRID ───────────────────────────────────────
  Widget _buildGenreBrowseSection(BuildContext context, WidgetRef ref, AsyncValue<List<DeezerGenre>> genresAsync, bool isDark) {
    final genreGradients = [
      [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)],
      [const Color(0xFF7C4DFF), const Color(0xFF536DFE)],
      [const Color(0xFF00C9FF), const Color(0xFF92FE9D)],
      [const Color(0xFFF7971E), const Color(0xFFFFD200)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
    ];
    final genreIcons = [
      Icons.music_note_rounded,
      Icons.headphones_rounded,
      Icons.album_rounded,
      Icons.piano_rounded,
      Icons.mic_rounded,
      Icons.equalizer_rounded,
    ];

    return genresAsync.when(
      data: (genres) {
        if (genres.isEmpty) return const SizedBox.shrink();
        // Filter out "All" genre (id 0) and take top 6
        final displayGenres = genres.where((g) => g.id != 0).take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Browse by Genre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.8,
              ),
              itemCount: displayGenres.length,
              itemBuilder: (context, index) {
                final genre = displayGenres[index];
                final gradient = genreGradients[index % genreGradients.length];
                final icon = genreIcons[index % genreIcons.length];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MoodDetailsScreen(
                          mood: genre.name,
                          gradientColors: gradient,
                          contextQuery: genre.name,
                          genreId: genre.id,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              genre.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── APPLE MUSIC PLAYLISTS ──────────────────────────────────────
  Widget _buildAppleMusicPlaylistsSection(BuildContext context, WidgetRef ref, AsyncValue<List<AppleMusicPlaylist>> playlistsAsync, bool isDark) {
    return playlistsAsync.when(
      data: (playlists) {
        if (playlists.isEmpty) return const SizedBox.shrink();
        
        final moodPlaylists = <AppleMusicPlaylist>[];
        final languagePlaylists = <AppleMusicPlaylist>[];
        final hitsPlaylists = <AppleMusicPlaylist>[];
        
        for (final playlist in playlists) {
          final nameLower = playlist.name.toLowerCase();
          
          if (nameLower.contains('tamil') || 
              nameLower.contains('telugu') || 
              nameLower.contains('hindi') || 
              nameLower.contains('bollywood') || 
              nameLower.contains('punjabi') || 
              nameLower.contains('malayalam') || 
              nameLower.contains('kannada') || 
              nameLower.contains('k-pop') || 
              nameLower.contains('j-pop') || 
              nameLower.contains('indie') || 
              nameLower.contains('english')) {
            languagePlaylists.add(playlist);
          } else if (nameLower.contains('chill') || 
                   nameLower.contains('relax') || 
                   nameLower.contains('lo-fi') || 
                   nameLower.contains('lofi') || 
                   nameLower.contains('study') || 
                   nameLower.contains('focus') || 
                   nameLower.contains('workout') || 
                   nameLower.contains('energy') || 
                   nameLower.contains('party') || 
                   nameLower.contains('dance') || 
                   nameLower.contains('sad') || 
                   nameLower.contains('acoustic') || 
                   nameLower.contains('sleep') || 
                   nameLower.contains('feel good') || 
                   nameLower.contains('vibes')) {
            moodPlaylists.add(playlist);
          } else {
            hitsPlaylists.add(playlist);
          }
        }

        Widget _buildCategoryRow(String title, List<AppleMusicPlaylist> items, IconData icon) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(icon, color: AppleMusicTheme.primaryPink, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 185,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final playlist = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailsScreen(
                                appleMusicPlaylist: playlist,
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
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    playlist.artworkUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: playlist.artworkUrl,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                              ),
                                              child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 36),
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                            ),
                                            child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 36),
                                          ),
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                            stops: const [0.5, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 120,
                              child: Text(
                                playlist.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
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
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 4),
              child: Text(
                'Curated Playlists',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            _buildCategoryRow('Language Curation', languagePlaylists, Icons.translate_rounded),
            _buildCategoryRow('Moods & Vibes', moodPlaylists, Icons.wb_twilight_rounded),
            _buildCategoryRow('Featured Hits & Genres', hitsPlaylists, Icons.auto_awesome_rounded),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppleMusicTheme.primaryPink))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, String selectedRegion, bool isDark) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      floating: true,
      centerTitle: false,
      expandedHeight: 110,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppleMusicGradientText(
              text: 'Discover',
              fontSize: 28,
              colors: isDark
                  ? [AppleMusicTheme.primaryPink, AppleMusicTheme.primaryPurple]
                  : [const Color(0xFF667eea), const Color(0xFF764ba2)],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildRegionPicker(context, ref, selectedRegion, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionPicker(BuildContext context, WidgetRef ref, String currentRegion, bool isDark) {
    final regions = {
      'in': '🇮🇳 IN',
      'us': '🇺🇸 US',
      'gb': '🇬🇧 UK',
      'jp': '🇯🇵 JP',
      'kr': '🇰🇷 KR',
    };

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      ),
      child: PopupMenuButton<String>(
        initialValue: currentRegion,
        onSelected: (code) => ref.read(selectedRegionProvider.notifier).set(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                regions[currentRegion] ?? '🌎',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded, 
                color: isDark ? Colors.white70 : Colors.black54, 
                size: 16,
              ),
            ],
          ),
        ),
        itemBuilder: (context) => regions.entries.map((e) {
          return PopupMenuItem(
            value: e.key,
            child: Text(
              e.value, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          );
        }).toList(),
      ),
    );
  }

  // JioSaavn Playlists Section
  Widget _buildJioSaavnPlaylistsSection(
    BuildContext context,
    WidgetRef ref,
    String selectedLanguage,
    AsyncValue<List<AppleMusicPlaylist>> playlistsAsync,
    bool isDark,
  ) {
    final Map<String, String> languages = {
      'english': 'English',
      'hindi': 'Hindi',
      'tamil': 'Tamil',
      'telugu': 'Telugu',
      'punjabi': 'Punjabi',
      'kannada': 'Kannada',
      'malayalam': 'Malayalam',
      'bengali': 'Bengali',
      'marathi': 'Marathi',
      'bhojpuri': 'Bhojpuri',
      'gujarati': 'Gujarati',
      'haryanvi': 'Haryanvi',
      'rajasthani': 'Rajasthani',
      'odia': 'Odia',
      'assamese': 'Assamese',
      'sanskrit': 'Sanskrit',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.library_music_rounded, color: AppleMusicTheme.primaryPink, size: 22),
              const SizedBox(width: 8),
              Text(
                'JioSaavn Featured Playlists',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: -0.8,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: languages.entries.map((entry) {
              final isSelected = entry.key == selectedLanguage;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(selectedJioSaavnLanguageProvider.notifier).state = entry.key;
                  },
                  selectedColor: AppleMusicTheme.primaryPink,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  checkmarkColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        SizedBox(
          height: 185,
          child: playlistsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'No playlists found.',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final playlist = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailsScreen(
                              appleMusicPlaylist: playlist,
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
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  playlist.artworkUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: playlist.artworkUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                            ),
                                            child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 36),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                          ),
                                          child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 36),
                                        ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                          stops: const [0.5, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 120,
                            child: Text(
                              playlist.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppleMusicTheme.primaryPink,
              ),
            ),
            error: (err, __) => Center(
              child: Text(
                'Failed to load playlists.',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

}

class _ArtistAvatar extends ConsumerWidget {
  final ItunesTrack artist;

  const _ArtistAvatar({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(trendingArtistImageProvider(
      ArtistImageParams(name: artist.artistName, url: artist.artistViewUrl),
    ));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ArtistScreen(artistName: artist.artistName),
          ),
        );
      },
      child: SizedBox(
        width: 85,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: imageAsync.when(
                  data: (url) => url != null
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          errorWidget: (_, __, ___) => _buildFallback(isDark),
                        )
                      : _buildFallback(isDark),
                  loading: () => Container(
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, __) => _buildFallback(isDark),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.artistName,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(bool isDark) {
    return Container(
      color: isDark ? Colors.white10 : Colors.black12,
      child: Icon(
        Icons.person,
        color: isDark ? Colors.white30 : Colors.black26,
        size: 35,
      ),
    );
  }
}

class _SongGridItem extends ConsumerWidget {
  final ItunesTrack track;
  final List<Color> gradientColors;

  const _SongGridItem({
    required this.track,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 75,
      margin: const EdgeInsets.only(bottom: 5),
      child: GlassCard(
        padding: const EdgeInsets.all(6),
        borderRadius: 12,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => MusicSearchScreen(
                initialQuery: '${track.artistName} ${track.trackName}',
              ),
            ),
          );
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: track.artworkUrl,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 54,
                  height: 54,
                  color: Colors.black12,
                  child: const Icon(Icons.music_note, color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.trackName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_rounded,
              color: AppleMusicTheme.primaryPink.withOpacity(0.8),
              size: 24,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}


