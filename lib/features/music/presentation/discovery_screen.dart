import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'discovery_skeletons.dart';
import 'discovery_cache_manager.dart';


class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRegion = ref.watch(selectedRegionProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedTab = ref.watch(discoveryTabProvider);
    final discoverSettings = ref.watch(settingsProvider);
    final disabledSections = discoverSettings.disabledDiscoverSections.toSet();

    final enabledSections = discoverSettings.discoverSectionOrder
        .where((id) => !disabledSections.contains(id))
        .toList();

    final showGenreSections =
        enabledSections.contains('genre_pills') || enabledSections.contains('genres');
    final showNewReleases = enabledSections.contains('new_releases');
    final showJioSaavn = enabledSections.contains('jiosaavn');

    final genres =
        showGenreSections ? ref.watch(genresProvider) : null;
    final newReleases = showNewReleases ? ref.watch(newReleasesProvider(selectedRegion)) : null;
    final selectedJioLanguage =
        showJioSaavn ? ref.watch(selectedJioSaavnLanguageProvider) : 'english';
    final jioPlaylistsAsync = showJioSaavn
        ? ref.watch(jiosaavnFeaturedPlaylistsProvider(selectedJioLanguage))
        : null;

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
            final discover = ref.read(settingsProvider);
            final disabled = discover.disabledDiscoverSections.toSet();
            final enabled = discover.discoverSectionOrder
                .where((id) => !disabled.contains(id))
                .toList();
            final futures = <Future>[];
            if (enabled.contains('trending')) {
              ref.invalidate(cachedTrendingSongsProvider);
            }
            if (enabled.contains('new_releases')) {
              ref.invalidate(newReleasesProvider(selectedRegion));
              futures.add(
                ref.read(newReleasesProvider(selectedRegion).future)
                    .catchError((_) => <ItunesTrack>[]),
              );
            }
            if (enabled.contains('genre_pills') || enabled.contains('genres')) {
              ref.invalidate(genresProvider);
              futures.add(
                ref.read(genresProvider.future).catchError((_) => <DeezerGenre>[]),
              );
            }
            if (enabled.contains('apple_music')) {
              ref.invalidate(regionalPlaylistsProvider(selectedRegion));
              futures.add(
                ref.read(regionalPlaylistsProvider(selectedRegion).future)
                    .catchError((_) => <AppleMusicPlaylist>[]),
              );
            }
            if (enabled.contains('jiosaavn')) {
              final lang = ref.read(selectedJioSaavnLanguageProvider);
              ref.invalidate(jiosaavnFeaturedPlaylistsProvider(lang));
              futures.add(
                ref.read(jiosaavnFeaturedPlaylistsProvider(lang).future)
                    .catchError((_) => <AppleMusicPlaylist>[]),
              );
            }
            await Future.wait(futures);
          }
        },
        child: CustomScrollView(
          cacheExtent: 600,
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
              ...enabledSections.map((id) {
                final section = _buildDiscoverSection(
                  id,
                  context,
                  ref,
                  isDark,
                  genres,
                  newReleases,
                  selectedJioLanguage,
                  jioPlaylistsAsync,
                );
                if (section == null) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(child: section);
              }),

              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildDiscoverSection(
    String id,
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    AsyncValue<List<DeezerGenre>>? genres,
    AsyncValue<List<ItunesTrack>>? newReleases,
    String selectedJioLanguage,
    AsyncValue<List<AppleMusicPlaylist>>? jioPlaylistsAsync,
  ) {
    switch (id) {
      case 'genre_pills':
        return _buildQuickGenrePills(context, ref, genres!, isDark);
      case 'trending':
        return _buildTrendingSongsSection(context, ref);
      case 'vibe_swipe':
        return _buildVibeSwipeBanner(context, ref, isDark);
      case 'new_releases':
        return _buildNewReleasesSection(context, ref, newReleases!, isDark);
      case 'global_trends':
        return _buildGlobalTrendsSection(context, ref);
      case 'genres':
        return _buildGenreBrowseSection(context, ref, genres!, isDark);
      case 'jiosaavn':
        return _buildJioSaavnPlaylistsSection(
            context, ref, selectedJioLanguage, jioPlaylistsAsync!, isDark);
      case 'apple_music':
        return _buildAppleMusicPlaylistsSection(context, ref, isDark);
      default:
        return null;
    }
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

  Widget _buildQuickGenrePills(BuildContext context, WidgetRef ref, AsyncValue<List<DeezerGenre>> genresAsync, bool isDark) {
    return genresAsync.when(
      data: (genres) {
        if (genres.isEmpty) return const SizedBox.shrink();
        final displayGenres = genres.where((g) => g.id != 0).take(10).toList();
        final pillGradients = [
          [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)],
          [const Color(0xFF7C4DFF), const Color(0xFF536DFE)],
          [const Color(0xFF00C9FF), const Color(0xFF92FE9D)],
          [const Color(0xFFF7971E), const Color(0xFFFFD200)],
          [const Color(0xFFFA709A), const Color(0xFFFEE140)],
          [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          [const Color(0xFF11998e), const Color(0xFF38ef7d)],
          [const Color(0xFFFC5C7D), const Color(0xFF6A82FB)],
          [const Color(0xFFf093fb), const Color(0xFFf5576c)],
          [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
        ];
        return SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: displayGenres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final genre = displayGenres[index];
              final gradient = pillGradients[index % pillGradients.length];
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    genre.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _handleTrackTap(BuildContext context, WidgetRef ref, ItunesTrack track) async {
    HapticFeedback.lightImpact();
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
        'extras': {
          'torrentId': matchingFile.torrentId,
          'fileId': matchingFile.id,
          'size': matchingFile.size,
          'localPath': matchingFile.localPath,
        },
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
    } else if (context.mounted) {
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
          'duration': autoResult.duration,
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
    final selectedRegion = ref.watch(selectedRegionProvider);
    final regionFlag = RegionPickerSheet.regions[selectedRegion]?.split(' ').first ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text('🔥', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trending Now',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (regionFlag.isNotEmpty)
                Text(regionFlag, style: const TextStyle(fontSize: 20)),
            ],
          ),
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
          loading: () => trendingSongsSkeleton(context),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
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
        child: Consumer(builder: (context, ref, _) {
          final useMaterial3 = ref.watch(settingsProvider).appThemeStyle == 'material3';
          final gradientColors = useMaterial3
              ? [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  Theme.of(context).colorScheme.secondary,
                ]
              : [
                  Theme.of(context).colorScheme.primary,
                  AppleMusicTheme.primaryPurple,
                  const Color(0xFFFC3C71),
                ];
          return Container(
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '⚡ DISCOVER',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                   fontWeight: FontWeight.bold,
                                   letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                            const SizedBox(height: 8),
                            Text(
                              'Vibe Swipe',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Swipe through 10s previews to find your new favorites',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated swipe icons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_rounded, color: Colors.white.withOpacity(0.5), size: 14),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                                ),
                                child: const Icon(Icons.style_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.5), size: 14),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Swipe →',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGlobalTrendsSection(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(lastfmGlobalTopArtistsProvider);
    final tracksAsync = ref.watch(lastfmGlobalTopTracksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              Icon(Icons.public_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Global Trends',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
              ),
              Text(
                'via Last.fm',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Trending Artists — horizontal scrollable list
        artistsAsync.when(
          data: (artists) {
            if (artists.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    'Trending Artists',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: artists.length,
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      final name = artist['name'] as String;
                      final imageUrl = artist['image_url'] as String;

                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ArtistScreen(artistName: name)),
                            );
                          },
                          child: SizedBox(
                            width: 80,
                            child: Column(
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            cacheManager: DiscoveryCacheManager(),
                                            memCacheWidth: 76,
                                            memCacheHeight: 76,
                                            imageUrl: imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: Colors.grey.withOpacity(0.1)),
                                            errorWidget: (_, __, ___) => _buildArtistPlaceholder(),
                                          )
                                        : _buildArtistPlaceholder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(height: 120),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // Top Tracks as vertical list
        tracksAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) return const SizedBox.shrink();
            final topTracks = tracks.take(5).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(topTracks.length, (index) {
                  final track = topTracks[index];
                  final name = track['name'] as String;
                  final artist = track['artist'] as String;
                  final imageUrl = track['image_url'] as String;

                  final itunesTrack = ItunesTrack(
                    trackId: index,
                    trackName: name,
                    artistName: artist,
                    collectionName: '',
                    artworkUrl: imageUrl,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () => _handleTrackTap(context, ref, itunesTrack),
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => TrackActionSheet(track: itunesTrack),
                        );
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${index + 1}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      cacheManager: DiscoveryCacheManager(),
                                      memCacheWidth: 42,
                                      memCacheHeight: 42,
                                      imageUrl: imageUrl,
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(width: 42, height: 42, color: Colors.grey.withOpacity(0.1)),
                                      errorWidget: (_, __, ___) => _buildTrackPlaceholder(42),
                                    )
                                  : _buildTrackPlaceholder(42),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    artist,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.play_circle_outline_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.6), size: 24),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
          loading: () => const SizedBox(height: 200),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
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

  // ─── NEW RELEASES SQUARE CARDS ─────────────────────────────────
  Widget _buildNewReleasesSection(BuildContext context, WidgetRef ref, AsyncValue<List<ItunesTrack>> releasesAsync, bool isDark) {
    return releasesAsync.when(
      data: (releases) {
        if (releases.isEmpty) return const SizedBox.shrink();
        final items = releases.take(12).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                children: [
                  Consumer(builder: (context, ref, _) {
                    final useMaterial3 = ref.watch(settingsProvider).appThemeStyle == 'material3';
                    final badgeColors = useMaterial3
                        ? [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)]
                        : [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: badgeColors),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('NEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    );
                  }),
                  const SizedBox(width: 10),
                  Text(
                    'Fresh Releases',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final track = items[index];
                  final artworkHi = track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '600x600');
                  return GestureDetector(
                    onTap: () => _handleTrackTap(context, ref, track),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => TrackActionSheet(track: track),
                      );
                    },
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    cacheManager: DiscoveryCacheManager(),
                                    memCacheWidth: 140,
                                    memCacheHeight: 140,
                                    imageUrl: artworkHi,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                      ),
                                      child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 36),
                                    ),
                                  ),
                                  // NEW badge
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Play icon overlay
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 140,
                            child: Text(
                              track.trackName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 140,
                            child: Text(
                              track.artistName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45),
                              maxLines: 1,
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
            const SizedBox(height: 4),
          ],
        );
      },
      loading: () => newReleasesSkeleton(context),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── BROWSE BY GENRE HORIZONTAL SCROLL ────────────────────────────
  Widget _buildGenreBrowseSection(BuildContext context, WidgetRef ref, AsyncValue<List<DeezerGenre>> genresAsync, bool isDark) {
    final genreGradients = [
      [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)],
      [const Color(0xFF7C4DFF), const Color(0xFF536DFE)],
      [const Color(0xFF00C9FF), const Color(0xFF92FE9D)],
      [const Color(0xFFF7971E), const Color(0xFFFFD200)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFFFC5C7D), const Color(0xFF6A82FB)],
    ];

    return genresAsync.when(
      data: (genres) {
        if (genres.isEmpty) return const SizedBox.shrink();
        final displayGenres = genres.where((g) => g.id != 0).take(8).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.explore_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Explore Genres',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayGenres.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final genre = displayGenres[index];
                  final gradient = genreGradients[index % genreGradients.length];
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
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: gradient[0].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Genre image from Deezer
                            if (genre.picture.isNotEmpty)
                              CachedNetworkImage(
                                cacheManager: DiscoveryCacheManager(),
                                memCacheWidth: 120,
                                memCacheHeight: 130,
                                imageUrl: genre.picture,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: gradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            // Gradient overlay
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
                                    stops: const [0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            // Genre name
                            Positioned(
                              bottom: 12,
                              left: 10,
                              right: 10,
                              child: Text(
                                genre.name,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
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
            ),
            const SizedBox(height: 4),
          ],
        );
      },
      loading: () => genreBrowseSkeleton(context),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── APPLE MUSIC CURATED PLAYLISTS ──────────────────────────────
  Widget _buildAppleMusicPlaylistsSection(BuildContext context, WidgetRef ref, bool isDark) {
    final region = ref.watch(selectedRegionProvider);
    final categorized = ref.watch(appleMusicCategorizedProvider(region));
    final loading = ref.watch(regionalPlaylistsProvider(region)).isLoading;

    if (loading) return appleMusicPlaylistsSkeleton(context);

    final moodPlaylists = categorized.mood;
    final languagePlaylists = categorized.language;
    final hitsPlaylists = categorized.hits;

    if (moodPlaylists.isEmpty && languagePlaylists.isEmpty && hitsPlaylists.isEmpty) {
      return const SizedBox.shrink();
    }

    // Language Curation — horizontal scroll with larger cards
    Widget _buildLanguageRow(List<AppleMusicPlaylist> items) {
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
                      Icon(Icons.translate_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Language Curation',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
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
                          title: 'Language Curation',
                          playlists: items,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'See All',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length > 10 ? 10 : items.length,
              itemBuilder: (context, index) {
                final playlist = items[index];
                final isFirst = index == 0;
                final cardWidth = isFirst ? 155.0 : 140.0;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: cardWidth,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
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
                                        cacheManager: DiscoveryCacheManager(),
                                        memCacheWidth: cardWidth.toInt(),
                                        memCacheHeight: 140,
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
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: cardWidth,
                          child: Text(
                            playlist.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
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

    // Moods & Vibes — 2-column grid
    Widget _buildMoodGrid(List<AppleMusicPlaylist> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      final displayItems = items.take(6).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.wb_twilight_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Moods & Vibes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
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
                          title: 'Moods & Vibes',
                          playlists: items,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'See All',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 215,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final playlist = displayItems[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
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
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                playlist.artworkUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        cacheManager: DiscoveryCacheManager(),
                                        memCacheWidth: 150,
                                        memCacheHeight: 150,
                                        imageUrl: playlist.artworkUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                          ),
                                          child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 30),
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                        ),
                                        child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 30),
                                      ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                                        stops: const [0.4, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 10,
                                  right: 10,
                                  child: Text(
                                    playlist.name,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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

    // Featured Hits — wide rectangular cards
    Widget _buildHitsRow(List<AppleMusicPlaylist> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Featured Hits & Genres',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
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
                          title: 'Featured Hits & Genres',
                          playlists: items,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'See All',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length > 8 ? 8 : items.length,
              itemBuilder: (context, index) {
                final playlist = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
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
                    child: Container(
                      width: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                            ),
                            child: playlist.artworkUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    cacheManager: DiscoveryCacheManager(),
                                    memCacheWidth: 90,
                                    memCacheHeight: 90,
                                    imageUrl: playlist.artworkUrl,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                      ),
                                      child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 28),
                                    ),
                                  )
                                : Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: _getGradientForIndex(index)),
                                    ),
                                    child: const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 28),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.name,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Curated For You',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        _buildLanguageRow(languagePlaylists),
        _buildMoodGrid(moodPlaylists),
        _buildHitsRow(hitsPlaylists),
        const SizedBox(height: 16),
      ],
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
                        'JioSaavn Featured',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Language chips
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.w600,
                    ),
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

        // Mixed-size playlist cards
        SizedBox(
          height: 200,
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
                  final isFeatured = index == 0;
                  final cardWidth = isFeatured ? 155.0 : 140.0;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: cardWidth,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
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
                                              cacheManager: DiscoveryCacheManager(),
                                              memCacheWidth: cardWidth.toInt(),
                                              memCacheHeight: 140,
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
                                      // Gradient overlay
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
                                      // Featured badge
                                      if (isFeatured)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'HOT',
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Play icon
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withOpacity(0.5),
                                          ),
                                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: cardWidth,
                            child: Text(
                              playlist.name,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
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
            loading: () => jioSaavnPlaylistsSkeleton(context),
            error: (err, __) => Center(
              child: Text(
                'Failed to load playlists.',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
                          cacheManager: DiscoveryCacheManager(),
                          memCacheWidth: 80,
                          memCacheHeight: 80,
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
                cacheManager: DiscoveryCacheManager(),
                memCacheWidth: 54,
                memCacheHeight: 54,
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
      viewportFraction: 0.75,
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

  List<Color> _getGradientForIndex(int index) {
    final gradients = [
      AppleMusicTheme.pinkGradient,
      AppleMusicTheme.purpleGradient,
      AppleMusicTheme.orangeGradient,
      AppleMusicTheme.blueGradient,
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final height = 300.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pageController,
            clipBehavior: Clip.none,
            itemCount: widget.tracks.length,
            itemBuilder: (context, index) {
              final track = widget.tracks[index];
              final double diff = index - _currentPage;
              final double t = (1.0 - diff.abs()).clamp(0.0, 1.0);

              final double width = 60.0 + (280.0 - 60.0) * t;
              final double borderRadius = 30.0 + (22.0 - 30.0) * t;
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
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2 * t),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            cacheManager: DiscoveryCacheManager(),
                            memCacheWidth: 300,
                            memCacheHeight: 300,
                            imageUrl: artworkHi,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _getGradientForIndex(index),
                                ),
                              ),
                              child: const Icon(Icons.music_note_rounded, color: Colors.grey, size: 40),
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
                                      Colors.black.withOpacity(0.75),
                                    ],
                                    stops: const [0.35, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (t > 0.0)
                            Positioned(
                              bottom: 14,
                              left: 14,
                              right: 14,
                              child: Opacity(
                                opacity: t,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.12),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            track.trackName,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            track.artistName,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.white.withOpacity(0.75),
                                            ),
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
                          if (t > 0.5)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Opacity(
                                opacity: (t - 0.5) * 2,
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
        const SizedBox(height: 10),
        // Page indicator dots
        if (widget.tracks.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.tracks.length.clamp(0, 10),
              (index) {
                final isActive = (_currentPage - index).abs() < 0.5;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),
      ],
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


