import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'music_providers.dart';
import 'music_search_screen.dart';
import 'now_playing_screen.dart';
import '../data/music_models.dart';
import '../data/music_repository.dart';
import 'album_screen.dart';
import 'package:isai/core/di/injection.dart';
import 'package:isai/core/theme/apple_music_theme.dart';
import 'package:isai/core/theme/glassmorphism.dart';
import 'package:isai/core/theme/apple_music_components.dart';
import 'package:isai/core/utils/string_utils.dart';
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
import 'playlist_grid_screen.dart';
import 'package:isai/features/audiobooks/presentation/audiobook_providers.dart';
import 'package:isai/features/audiobooks/presentation/audiobooks_sub_screen.dart';
import 'package:isai/features/audiobooks/data/audiobook_models.dart';
import 'package:isai/features/podcast/presentation/podcast_providers.dart';
import 'package:isai/features/podcast/presentation/podcast_listing_screen.dart';


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

    final regionName = RegionPickerSheet.getCountryName(selectedRegion);
    final selectedTab = ref.watch(discoveryTabProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          if (selectedTab == 'audiobooks') {
            ref.invalidate(audiobookCatalogProvider);
            ref.invalidate(localAudiobooksProvider);
            await Future.wait([
              ref.read(audiobookCatalogProvider.future).timeout(const Duration(seconds: 8)).catchError((_) => <AudiobookResult>[]),
              ref.read(localAudiobooksProvider.future).timeout(const Duration(seconds: 8)).catchError((_) => <AudiobookResult>[]),
            ]).catchError((_) => []);
          } else if (selectedTab == 'podcast') {
            ref.invalidate(podcastRecentProvider);
          } else {
            ref.invalidate(cachedTrendingSongsProvider);
            ref.invalidate(newReleasesProvider(selectedRegion));
            ref.invalidate(genresProvider);
            ref.invalidate(regionalPlaylistsProvider(selectedRegion));
            ref.invalidate(jiosaavnFeaturedPlaylistsProvider(selectedJioLanguage));
            await Future.wait([
              ref.read(newReleasesProvider(selectedRegion).future).catchError((_) => <ItunesTrack>[]),
              ref.read(genresProvider.future).catchError((_) => <DeezerGenre>[]),
              ref.read(regionalPlaylistsProvider(selectedRegion).future).catchError((_) => <AppleMusicPlaylist>[]),
              ref.read(jiosaavnFeaturedPlaylistsProvider(selectedJioLanguage).future).catchError((_) => <AppleMusicPlaylist>[]),
            ]);
          }
        },
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, ref, selectedRegion, isDark),
            
            // No separate tab widget here — tabs are now inside the AppBar

            // Conditional content based on selected tab
            if (selectedTab == 'audiobooks')
              const SliverToBoxAdapter(
                child: AudiobooksSubScreen(),
              )
            else if (selectedTab == 'podcast')
              const SliverToBoxAdapter(
                child: PodcastsSubScreen(),
              )
            else ...[
              SliverToBoxAdapter(
                child: _buildTrendingSongsSection(context, ref),
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


              
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          ],
        ),
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
      // Try to auto-resolve via scrapers before showing source picker
      final repo = getIt<MusicRepository>();
      final cleanT = StringUtils.unescapeHtml(track.trackName);
      final cleanA = StringUtils.unescapeHtml(track.artistName);
      final query = '$cleanA $cleanT'.trim();

      ScraperResult? autoResult;
      try {
        autoResult = await repo.searchFLACStream(query).first.timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {}

      if (autoResult != null && context.mounted) {
        final dummyFile = TorBoxFile(
          id: -autoResult.url.hashCode.abs(),
          torrentId: -1,
          size: autoResult.size,
          name: autoResult.title,
          localPath: null,
        );
        final artwork = track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000');
        await audioHandler.customAction('play', {
          'url': autoResult.url,
          'title': track.trackName,
          'artist': track.artistName,
          'artworkUrl': artwork,
          'forceReplace': true,
          'extras': {
            'torrentId': dummyFile.torrentId,
            'fileId': dummyFile.id,
            'size': autoResult.size,
            'localPath': null,
            'source': autoResult.source,
            'linkType': autoResult.linkType,
            'format': autoResult.format,
          },
        });
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NowPlayingScreen(
                file: dummyFile,
                customQueue: [dummyFile],
                initialArtwork: artwork,
              ),
            ),
          );
        }
        return;
      }

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

  Widget _buildTrendingSongsSection(BuildContext context, WidgetRef ref) {
    final topSongsAsync = ref.watch(cachedTrendingSongsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Trending Now', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),
        ),
        topSongsAsync.when(
          data: (songs) {
            if (songs.isEmpty) return const SizedBox.shrink();
            return TrendingSongsCarousel(
              tracks: songs,
              onTrackTap: (track) => _handleTrackTap(context, ref, track),
              onTrackLongPress: (track) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => TrackActionSheet(track: track),
                );
              },
            );
          },
          loading: () => SizedBox(
            height: 260,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
      ],
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
            gradient: LinearGradient(
              colors: ref.watch(settingsProvider).appThemeStyle == 'material3'
                  ? [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)]
                  : [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vibe Swipe',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold,),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Swipe through personalized 10s previews to find your new favorites.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70,),
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Trending Artists on Last.fm', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),
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
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,),
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Global Hot Tracks', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),
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
                            child: Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(
                            width: 150,
                            child: Text(artist, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                      gradient: LinearGradient(
                        colors: ref.watch(settingsProvider).appThemeStyle == 'material3'
                            ? [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)]
                            : [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('NEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(width: 8),
                  Text('Fresh Releases', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),
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
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold,),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      track.artistName,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.8),),
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
      loading: () => SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))),
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Browse by Genre', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold,),
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistGridScreen(
                              title: title,
                              playlists: items,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'See All',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 165,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length > 10 ? 10 : items.length,
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
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Curated Playlists',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                  letterSpacing: -0.8,),
              ),
            ),
            _buildCategoryRow('Language Curation', languagePlaylists, Icons.translate_rounded),
            _buildCategoryRow('Moods & Vibes', moodPlaylists, Icons.wb_twilight_rounded),
            _buildCategoryRow('Featured Hits & Genres', hitsPlaylists, Icons.auto_awesome_rounded),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, String selectedRegion, bool isDark) {
    final selectedTab = ref.watch(discoveryTabProvider);
    final tabs = [
      ('music', 'Music'),
      ('audiobooks', 'Audiobooks'),
      ('podcast', 'Podcasts'),
    ];

    return SliverAppBar(
      backgroundColor: isDark
          ? Colors.black.withOpacity(0.85)
          : Colors.white.withOpacity(0.9),
      surfaceTintColor: Colors.transparent,
      floating: true,
      pinned: true,
      centerTitle: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppleMusicGradientText(
            text: 'Discover',
            fontSize: 26,
            colors: isDark
                ? [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]
                : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          ),
          _buildRegionPicker(context, ref, selectedRegion, isDark),
        ],
      ),
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
    );
  }


  Widget _buildRegionPicker(BuildContext context, WidgetRef ref, String currentRegion, bool isDark) {
    final countryString = RegionPickerSheet.regions[currentRegion] ?? '🌎 $currentRegion';
    final flag = countryString.split(' ').first;
    final displayLabel = '$flag ${currentRegion.toUpperCase()}';

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RegionPickerSheet(
            currentRegion: currentRegion,
            onRegionSelected: (code) => ref.read(selectedRegionProvider.notifier).set(code),
          ),
        );
      },
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
              displayLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.black, 
                fontWeight: FontWeight.w600,),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded, 
              color: isDark ? Colors.white70 : Colors.black54, 
              size: 16,
            ),
          ],
        ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.library_music_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'JioSaavn Featured Playlists',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                          letterSpacing: -0.8,
                          color: isDark ? Colors.white : Colors.black,),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (playlistsAsync.value != null && playlistsAsync.value!.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistGridScreen(
                          title: 'JioSaavn Featured Playlists',
                          playlists: playlistsAsync.value!,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'See All',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.w600,),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(selectedJioSaavnLanguageProvider.notifier).state = entry.key;
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
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
          height: 165,
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
                itemCount: items.length > 10 ? 10 : items.length,
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
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_rounded,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              size: 24,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class TrendingSongsCarousel extends StatefulWidget {
  final List<ItunesTrack> tracks;
  final Function(ItunesTrack) onTrackTap;
  final Function(ItunesTrack) onTrackLongPress;

  const TrendingSongsCarousel({
    super.key,
    required this.tracks,
    required this.onTrackTap,
    required this.onTrackLongPress,
  });

  @override
  State<TrendingSongsCarousel> createState() => _TrendingSongsCarouselState();
}

class _TrendingSongsCarouselState extends State<TrendingSongsCarousel> {
  late PageController _pageController;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.7,
      initialPage: 0,
    );
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = 260.0;

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _pageController,
        clipBehavior: Clip.none,
        itemCount: widget.tracks.length,
        itemBuilder: (context, index) {
          final track = widget.tracks[index];
          final double diff = index - _currentPage;
          final double t = (1.0 - diff.abs()).clamp(0.0, 1.0);
          
          final double width = 60.0 + (260.0 - 60.0) * t;
          final double borderRadius = 30.0 + (24.0 - 30.0) * t;
          final double alignX = -diff;
          
          final artworkHi = track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '600x600');

          return Align(
            alignment: Alignment(alignX.clamp(-1.0, 1.0), 0.0),
            child: GestureDetector(
              onTap: () => widget.onTrackTap(track),
              onLongPress: () => widget.onTrackLongPress(track),
              child: Container(
                width: width,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15 * t),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: artworkHi,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.grey),
                        ),
                      ),
                      Positioned.fill(
                        child: AnimatedOpacity(
                          duration: Duration.zero,
                          opacity: t,
                          child: Container(
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
                      ),
                      if (t > 0.0)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Opacity(
                            opacity: t,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        track.trackName,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white,
                                          fontWeight: FontWeight.bold,),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artistName,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withOpacity(0.7),),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
    );
  }
}

class RegionPickerSheet extends StatefulWidget {
  final String currentRegion;
  final Function(String) onRegionSelected;

  const RegionPickerSheet({
    super.key,
    required this.currentRegion,
    required this.onRegionSelected,
  });

  static const Map<String, String> regions = {
    'dz': '🇩🇿 Algeria',
    'ao': '🇦🇴 Angola',
    'ai': '🇦🇮 Anguilla',
    'ag': '🇦🇬 Antigua & Barbuda',
    'ar': '🇦🇷 Argentina',
    'am': '🇦🇲 Armenia',
    'au': '🇦🇺 Australia',
    'at': '🇦🇹 Austria',
    'az': '🇦🇿 Azerbaijan',
    'bs': '🇧🇸 Bahamas',
    'bh': '🇧🇭 Bahrain',
    'bd': '🇧🇩 Bangladesh',
    'bb': '🇧🇧 Barbados',
    'by': '🇧🇾 Belarus',
    'be': '🇧🇪 Belgium',
    'bz': '🇧🇿 Belize',
    'bj': '🇧🇯 Benin',
    'bm': '🇧🇲 Bermuda',
    'bt': '🇧🇹 Bhutan',
    'bo': '🇧🇴 Bolivia',
    'bw': '🇧🇼 Botswana',
    'br': '🇧🇷 Brazil',
    'vg': '🇻🇬 British Virgin Islands',
    'bn': '🇧🇳 Brunei',
    'bg': '🇧🇬 Bulgaria',
    'bf': '🇧🇫 Burkina Faso',
    'kh': '🇰🇭 Cambodia',
    'cm': '🇨🇲 Cameroon',
    'ca': '🇨🇦 Canada',
    'cv': '🇨🇻 Cape Verde',
    'ky': '🇰🇾 Cayman Islands',
    'td': '🇹🇩 Chad',
    'cl': '🇨🇱 Chile',
    'cn': '🇨🇳 China',
    'co': '🇨🇴 Colombia',
    'cg': '🇨🇬 Congo',
    'cr': '🇨🇷 Costa Rica',
    'hr': '🇭🇷 Croatia',
    'cy': '🇨🇾 Cyprus',
    'cz': '🇨🇿 Czechia',
    'dk': '🇩🇰 Denmark',
    'dm': '🇩🇲 Dominica',
    'do': '🇩🇴 Dominican Republic',
    'ec': '🇪🇨 Ecuador',
    'eg': '🇪🇬 Egypt',
    'sv': '🇸🇻 El Salvador',
    'ee': '🇪🇪 Estonia',
    'sz': '🇸🇿 Eswatini',
    'fj': '🇫🇯 Fiji',
    'fi': '🇫🇮 Finland',
    'fr': '🇫🇷 France',
    'ga': '🇬🇦 Gabon',
    'gm': '🇬🇲 Gambia',
    'ge': '🇬🇪 Georgia',
    'de': '🇩🇪 Germany',
    'gh': '🇬🇭 Ghana',
    'gr': '🇬🇷 Greece',
    'gd': '🇬🇩 Grenada',
    'gt': '🇬🇹 Guatemala',
    'gw': '🇬🇼 Guinea-Bissau',
    'gy': '🇬🇾 Guyana',
    'hn': '🇭🇳 Honduras',
    'hk': '🇭🇰 Hong Kong',
    'hu': '🇭🇺 Hungary',
    'is': '🇮🇸 Iceland',
    'in': '🇮🇳 India',
    'id': '🇮🇩 Indonesia',
    'iq': '🇮🇶 Iraq',
    'ie': '🇮🇪 Ireland',
    'il': '🇮🇱 Israel',
    'it': '🇮🇹 Italy',
    'jm': '🇯🇲 Jamaica',
    'jp': '🇯🇵 Japan',
    'jo': '🇯🇴 Jordan',
    'kz': '🇰🇿 Kazakhstan',
    'ke': '🇰🇪 Kenya',
    'kr': '🇰🇷 South Korea',
    'kw': '🇰🇼 Kuwait',
    'kg': '🇰🇬 Kyrgyzstan',
    'la': '🇱🇦 Laos',
    'lv': '🇱🇻 Latvia',
    'lb': '🇱🇧 Lebanon',
    'lr': '🇱🇷 Liberia',
    'ly': '🇱🇾 Libya',
    'lt': '🇱🇹 Lithuania',
    'lu': '🇱🇺 Luxembourg',
    'mo': '🇲🇴 Macau',
    'mg': '🇲🇬 Madagascar',
    'mw': '🇲🇼 Malawi',
    'my': '🇲🇾 Malaysia',
    'mv': '🇲🇻 Maldives',
    'ml': '🇲🇱 Mali',
    'mt': '🇲🇹 Malta',
    'mr': '🇲🇷 Mauritania',
    'mu': '🇲🇺 Mauritius',
    'mx': '🇲🇽 Mexico',
    'fm': '🇫🇲 Micronesia',
    'md': '🇲🇩 Moldova',
    'mn': '🇲🇳 Mongolia',
    'me': '🇲🇪 Montenegro',
    'ms': '🇲🇸 Montserrat',
    'ma': '🇲🇦 Morocco',
    'mz': '🇲🇿 Mozambique',
    'mm': '🇲🇲 Myanmar',
    'na': '🇳🇦 Namibia',
    'np': '🇳🇵 Nepal',
    'nl': '🇳🇱 Netherlands',
    'nz': '🇳🇿 New Zealand',
    'ni': '🇳🇮 Nicaragua',
    'ne': '🇳🇪 Niger',
    'ng': '🇳🇬 Nigeria',
    'mk': '🇲🇰 North Macedonia',
    'no': '🇳🇴 Norway',
    'om': '🇴🇲 Oman',
    'pk': '🇵🇰 Pakistan',
    'pw': '🇵🇼 Palau',
    'pa': '🇵🇦 Panama',
    'pg': '🇵🇬 Papua New Guinea',
    'py': '🇵🇾 Paraguay',
    'pe': '🇵🇪 Peru',
    'ph': '🇵🇭 Philippines',
    'pl': '🇵🇱 Poland',
    'pt': '🇵🇹 Portugal',
    'qa': '🇶🇦 Qatar',
    'ro': '🇷🇴 Romania',
    'ru': '🇷🇺 Russia',
    'rw': '🇷🇼 Rwanda',
    'kn': '🇰🇳 St. Kitts & Nevis',
    'lc': '🇱🇨 St. Lucia',
    'vc': '🇻🇨 St. Vincent',
    'ws': '🇼🇸 Samoa',
    'sa': '🇸🇦 Saudi Arabia',
    'sn': '🇸🇳 Senegal',
    'rs': '🇷🇸 Serbia',
    'sc': '🇸🇨 Seychelles',
    'sl': '🇸🇱 Sierra Leone',
    'sg': '🇸🇬 Singapore',
    'sk': '🇸🇰 Slovakia',
    'si': '🇸🇮 Slovenia',
    'sb': '🇸🇧 Solomon Islands',
    'za': '🇿🇦 South Africa',
    'es': '🇪🇸 Spain',
    'lk': '🇱🇰 Sri Lanka',
    'sr': '🇸🇷 Suriname',
    'se': '🇸🇪 Sweden',
    'ch': '🇨🇭 Switzerland',
    'tw': '🇹🇼 Taiwan',
    'tj': '🇹🇯 Tajikistan',
    'tz': '🇹🇿 Tanzania',
    'th': '🇹🇭 Thailand',
    'tr': '🇹🇷 Turkey',
    'tm': '🇹🇲 Turkmenistan',
    'tc': '🇹🇨 Turks & Caicos',
    'ug': '🇺🇬 Uganda',
    'ua': '🇺🇦 Ukraine',
    'ae': '🇦🇪 United Arab Emirates',
    'gb': '🇬🇧 United Kingdom',
    'us': '🇺🇸 United States',
    'uy': '🇺🇾 Uruguay',
    'uz': '🇺🇿 Uzbekistan',
    'vu': '🇻🇺 Vanuatu',
    've': '🇻🇪 Venezuela',
    'vn': '🇻🇳 Vietnam',
    'ye': '🇾🇪 Yemen',
    'zm': '🇿🇲 Zambia',
    'zw': '🇿🇼 Zimbabwe',
  };

  static String getCountryName(String code) {
    final entry = regions[code] ?? 'Region';
    final parts = entry.split(' ');
    if (parts.length > 1) {
      return parts.sublist(1).join(' ');
    }
    return entry;
  }

  @override
  State<RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<RegionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredRegions = RegionPickerSheet.regions.entries.where((e) {
      return e.value.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             e.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select Region',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search countries...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.black54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredRegions.length,
                  itemBuilder: (context, index) {
                    final entry = filteredRegions[index];
                    final isSelected = entry.key == widget.currentRegion;
                    return ListTile(
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        widget.onRegionSelected(entry.key);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


