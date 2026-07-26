import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'for_you_providers.dart';
import 'track_action_sheet.dart';
import 'music_providers.dart';
import 'source_picker_sheet.dart';
import 'now_playing_screen.dart';
import 'artist_screen.dart';
import 'recommendation_insights_screen.dart';
import '../data/music_models.dart';
import '../data/music_repository.dart';
import 'package:isai/core/di/injection.dart';
import 'package:isai/core/theme/apple_music_theme.dart';
import 'package:isai/core/theme/glassmorphism.dart';
import 'package:isai/core/theme/apple_music_components.dart';
import 'package:isai/core/utils/string_utils.dart';
import 'downloads_screen.dart';
import 'playlists_screen.dart';
import 'package:isai/main.dart';
import 'lastfm_discovery_providers.dart';

class ForYouScreen extends ConsumerWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userMusicProfileProvider);
    final isOffline = ref.watch(isOfflineProvider);

    if (isOffline) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: OfflinePlaceholder(
          title: 'No Internet Connection',
          message: 'Connect to the internet to get personalized recommendations.',
          onGoToDownloads: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: isDark ? const Color(0xFF1c1c1e) : Colors.white,
        onRefresh: () async {
          // Invalidate key providers to trigger fresh fetch
          ref.invalidate(userMusicProfileProvider);
          ref.invalidate(forYouMixProvider);
          ref.invalidate(personalizedTasteMixProvider);
          ref.invalidate(becauseYouListenedProvider);
          ref.invalidate(similarArtistsForYouProvider);
          ref.invalidate(genreRadioProvider);
          ref.invalidate(timeBasedMixProvider);
          ref.invalidate(newReleasesForYouProvider);
          ref.invalidate(outsideYourBubbleProvider);
          ref.invalidate(freshAndDifferentProvider);
          ref.invalidate(decadeMixesProvider);
          ref.invalidate(lastfmRecommendedProvider);
          ref.invalidate(lastfmMixProvider);
          
          // Wait for the main profile to at least start loading
          await ref.read(userMusicProfileProvider.future);
        },
        child: profileAsync.when(
          data: (profile) {
            if (profile.interactionCount == 0) {
              return _buildEmptyState(context, isDark);
            }
            return _buildContent(context, ref, isDark);
          },
          loading: () => Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          ),
          error: (e, __) => _buildErrorState(context, isDark, e.toString(), ref),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, String error, WidgetRef ref) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildAppBar(context, isDark),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent.withOpacity(0.5)),
                   const SizedBox(height: 24),
                   Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                   const SizedBox(height: 12),
                   Text(
                    'We couldn\'t load your recommendations right now. Pull down to try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(userMusicProfileProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
      slivers: [
        _buildAppBar(context, isDark),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppleMusicTheme.darkCard : AppleMusicTheme.lightCard,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your music journey starts here',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start playing music to get personalized recommendations, curated playlists, and daily mixes tailored to your taste.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? Colors.white60 : Colors.black54,),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool isDark) {
    final dailyMixes = ref.watch(forYouMixProvider);
    final tasteMix = ref.watch(personalizedTasteMixProvider);
    final becauseSections = ref.watch(becauseYouListenedProvider);
    final similarArtists = ref.watch(similarArtistsForYouProvider);
    final genreRadio = ref.watch(genreRadioProvider);
    final timeBasedMix = ref.watch(timeBasedMixProvider);
    final newReleases = ref.watch(newReleasesForYouProvider);
    final outsideBubble = ref.watch(outsideYourBubbleProvider);
    final freshDiff = ref.watch(freshAndDifferentProvider);
    final decadeMixes = ref.watch(decadeMixesProvider);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildAppBar(context, isDark),

        // ─── Familiar Zone ─────────────────────────────────────────────
        // Made For You
        SliverToBoxAdapter(
          child: _buildPersonalizedMixSection(context, ref, tasteMix, isDark),
        ),

        // Your Daily Mixes
        SliverToBoxAdapter(
          child: _buildDailyMixSection(context, ref, dailyMixes, isDark),
        ),

        // ─── Decade Mixes ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _buildDecadeMixesSection(context, ref, decadeMixes, isDark),
        ),

        // Because You Listened To...
        SliverToBoxAdapter(
          child: _buildBecauseYouListenedSections(context, ref, becauseSections, isDark),
        ),

        // ─── Discovery Zone ────────────────────────────────────────────
        // Outside Your Bubble
        SliverToBoxAdapter(
          child: _buildDiscoverySection(
            context, ref, outsideBubble, isDark,
            title: 'Outside Your Bubble',
            subtitle: 'Explore genres you rarely listen to',
            icon: Icons.explore_rounded,
          ),
        ),

        // Fresh & Different
        SliverToBoxAdapter(
          child: _buildDiscoverySection(
            context, ref, freshDiff, isDark,
            title: 'Fresh & Different',
            subtitle: 'Tracks by artists you haven\'t heard yet',
            icon: Icons.auto_awesome_rounded,
          ),
        ),

        // Genre Radio
        SliverToBoxAdapter(
          child: _buildGenreRadioSection(context, ref, genreRadio, isDark),
        ),

        // ─── Utility Zone ─────────────────────────────────────────────
        // Artists You Might Like
        SliverToBoxAdapter(
          child: _buildSimilarArtistsSection(context, ref, similarArtists, isDark),
        ),
        // Time-based Mix
        SliverToBoxAdapter(
          child: _buildTimeBasedMixSection(context, ref, timeBasedMix, isDark),
        ),

        // Fresh Picks
        SliverToBoxAdapter(
          child: _buildNewReleasesSection(context, ref, newReleases, isDark),
        ),

        // Last.fm Personalized Sections
        SliverToBoxAdapter(
          child: _buildLastfmPersonalizedSection(context, ref, isDark),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, bool isDark) {
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
              text: 'For You',
              fontSize: 28,
              colors: isDark
                  ? [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]
                  : [const Color(0xFF667eea), const Color(0xFF764ba2)],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecommendationInsightsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        AppleMusicTheme.primaryPurple.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insights_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Insights',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Personalized Mix ──────────────────────────────────────────────────

  Widget _buildPersonalizedMixSection(BuildContext context, WidgetRef ref, AsyncValue<List<ItunesTrack>> mixAsync, bool isDark) {
    return mixAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        
        final profile = ref.watch(userMusicProfileProvider).value;
        final topGenre = profile?.genreWeights.firstOrNull?.genre ?? 'Your Style';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppleMusicSectionHeader(
              title: 'Made For You',
              subtitle: 'A mix inspired by your taste',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMixCard(
                context: context,
                tracks: tracks,
                title: 'Your Taste Mix',
                subtitle: '${tracks.length} songs tailored for you',
                isDark: isDark,
                gradient: isDark 
                    ? [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)]
                    : [const Color(0xFFff9a9e), const Color(0xFFfecfef)],
                icon: Icons.insights_rounded,
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Daily Mix ──────────────────────────────────────────────────────────

  Widget _buildDailyMixSection(BuildContext context, WidgetRef ref, AsyncValue<List<DailyMix>> mixAsync, bool isDark) {
    return mixAsync.when(
      data: (mixes) {
        if (mixes.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppleMusicSectionHeader(
              title: 'Your Daily Mixes',
              subtitle: 'Discovery and favorites combined',
            ),
            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mixes.length,
                itemBuilder: (context, index) {
                  final mix = mixes[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: _buildMixCard(
                        context: context,
                        tracks: mix.tracks,
                        title: mix.title,
                        subtitle: mix.subtitle,
                        isDark: isDark,
                        gradient: mix.colors,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => _buildLoadingSection(context, 'Your Daily Mixes', isDark),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDecadeMixesSection(BuildContext context, WidgetRef ref, AsyncValue<List<DailyMix>> mixAsync, bool isDark) {
    return mixAsync.when(
      data: (mixes) {
        if (mixes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppleMusicSectionHeader(
              title: 'Your Decade Mixes',
              subtitle: 'From your most listened eras',
            ),
            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mixes.length,
                itemBuilder: (context, index) {
                  final mix = mixes[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: _buildMixCard(
                        context: context,
                        tracks: mix.tracks,
                        title: mix.title,
                        subtitle: mix.subtitle,
                        isDark: isDark,
                        gradient: mix.colors,
                        icon: Icons.queue_music_rounded,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => _buildLoadingSection(context, 'Your Decade Mixes', isDark),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Shared Mix Card UI ────────────────────────────────────────────────
  
  Widget _buildMixCard({
    required BuildContext context,
    required List<ItunesTrack> tracks,
    required String title,
    required String subtitle,
    required bool isDark,
    required List<Color> gradient,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailsScreen(
              customTracks: tracks,
              customTitle: title,
              customArtwork: tracks.firstOrNull?.artworkUrl,
            ),
          ),
        );
      },
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 150,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PLAYLIST',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                      fontWeight: FontWeight.w500,),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: isDark ? Colors.black : Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Because You Listened To ──────────────────────────────────────────

  Widget _buildBecauseYouListenedSections(BuildContext context, WidgetRef ref, AsyncValue<List<BecauseSection>> sectionsAsync, bool isDark) {
    return sectionsAsync.when(
      data: (sections) {
        if (sections.isEmpty) return const SizedBox.shrink();
        return Column(
          children: sections.map((section) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppleMusicSectionHeader(
                  title: 'Because you listened to',
                  subtitle: section.artistName,
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: section.tracks.length.clamp(0, 10),
                    itemBuilder: (context, index) {
                      return _buildTrackCard(context, ref, section.tracks[index], isDark, width: 150, height: 150);
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
      loading: () => _buildLoadingSection(context, 'Because you listened to...', isDark),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Genre Radio ─────────────────────────────────────────────────────

  Widget _buildGenreRadioSection(BuildContext context, WidgetRef ref, AsyncValue<({String genre, List<ItunesTrack> tracks})> radioAsync, bool isDark) {
    return radioAsync.when(
      data: (data) {
        if (data.tracks.isEmpty || data.genre.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppleMusicSectionHeader(
              title: '${data.genre} Radio',
              subtitle: 'Based on your top genre',
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: data.tracks.length.clamp(0, 10),
                itemBuilder: (context, index) {
                  return _buildTrackCard(context, ref, data.tracks[index], isDark, width: 150, height: 150);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Similar Artists ──────────────────────────────────────────────────

  Widget _buildSimilarArtistsSection(BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> artistsAsync, bool isDark) {
    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppleMusicSectionHeader(
              title: 'Artists You Might Like',
              subtitle: 'Based on your listening',
            ),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: artists.length,
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  final name = artist['name'] as String;
                  final imageUrl = artist['image_url'] as String? ?? '';

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
                                      placeholder: (_, __) => Container(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                      ),
                                      errorWidget: (_, __, ___) => _buildArtistFallback(isDark),
                                    )
                                  : _buildArtistFallback(isDark),
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
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,),
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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Time-based Mix ───────────────────────────────────────────────────

  Widget _buildTimeBasedMixSection(BuildContext context, WidgetRef ref, AsyncValue<({String label, List<ItunesTrack> tracks})> mixAsync, bool isDark) {
    return mixAsync.when(
      data: (data) {
        if (data.tracks.isEmpty || data.label.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppleMusicSectionHeader(
              title: data.label,
              subtitle: 'For right now',
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: data.tracks.length.clamp(0, 8),
                itemBuilder: (context, index) {
                  return _buildTrackCard(context, ref, data.tracks[index], isDark, width: 150, height: 150);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── New Releases ─────────────────────────────────────────────────────

  Widget _buildNewReleasesSection(BuildContext context, WidgetRef ref, AsyncValue<List<ItunesTrack>> releasesAsync, bool isDark) {
    return releasesAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppleMusicSectionHeader(
              title: 'Fresh Picks',
              subtitle: 'New from artists you love',
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tracks.length.clamp(0, 6),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(8),
                    borderRadius: 12,
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
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: track.artworkUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 48, height: 48,
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: const Icon(Icons.music_note, color: Colors.grey, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.trackName,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                track.artistName,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppleMusicTheme.darkTextSecondary : AppleMusicTheme.lightTextSecondary,),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.play_circle_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ],
                    ),
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

  // ─── Discovery Section (shared by Outside Your Bubble + Fresh & Different) ──

  Widget _buildDiscoverySection(
    BuildContext context, WidgetRef ref, AsyncValue<List<ItunesTrack>> tracksAsync, bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return tracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppleMusicSectionHeader(
                      title: title,
                      subtitle: subtitle,
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
                itemCount: tracks.length.clamp(0, 10),
                itemBuilder: (context, index) {
                  return _buildTrackCard(context, ref, tracks[index], isDark, width: 150, height: 150);
                },
              ),
            ),
          ],
        );
      },
      loading: () => _buildLoadingSection(context, title, isDark),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────

  Widget _buildTrackCard(BuildContext context, WidgetRef ref, ItunesTrack track, bool isDark, {double width = 150, double height = 150}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: track.artworkUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: width,
                  height: height,
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: const Icon(Icons.music_note, color: Colors.grey, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: width,
              child: Text(
                track.trackName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.white : Colors.black),
              ),
            ),
            SizedBox(
              width: width,
              child: Text(
                track.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? AppleMusicTheme.darkTextSecondary : AppleMusicTheme.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastfmPersonalizedSection(BuildContext context, WidgetRef ref, bool isDark) {
    final recentTracks = ref.watch(lastfmUserRecentTracksProvider).asData?.value;
    final topArtists = ref.watch(lastfmUserTopArtistsProvider).asData?.value;
    final recommended = ref.watch(lastfmRecommendedProvider).asData?.value;
    final mixTracks = ref.watch(lastfmMixProvider).asData?.value;

    final hasRecent = recentTracks != null && recentTracks.isNotEmpty;
    final hasArtists = topArtists != null && topArtists.isNotEmpty;
    final hasRecommended = recommended != null && recommended.isNotEmpty;
    final hasMix = mixTracks != null && mixTracks.isNotEmpty;

    if (!hasRecent && !hasArtists && !hasRecommended && !hasMix) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasRecent) _buildRecentTracksSection(context, ref, recentTracks, isDark),
        if (hasArtists) _buildTopArtistsSection(context, ref, topArtists, isDark),
        if (hasRecommended) _buildStationPlaylistSection(context, ref, recommended, isDark,
          title: 'Recommended for You',
          subtitle: 'Personalized picks from Last.fm',
        ),
        if (hasMix) _buildStationPlaylistSection(context, ref, mixTracks, isDark,
          title: 'Your Last.fm Mix',
          subtitle: 'A personalized mix from Last.fm',
        ),
      ],
    );
  }

  Widget _buildRecentTracksSection(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> tracks, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppleMusicSectionHeader(
          title: 'Your Last.fm Activity',
          subtitle: 'Recently played across all your devices',
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final t = tracks[index];
              final itunesTrack = ItunesTrack(
                trackId: index,
                trackName: t['name'] ?? '',
                artistName: t['artist'] ?? '',
                collectionName: t['album'] ?? '',
                artworkUrl: t['image_url'] ?? '',
              );
              return _buildTrackCard(context, ref, itunesTrack, isDark, width: 150, height: 150);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTopArtistsSection(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> artists, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppleMusicSectionHeader(
          title: 'Last.fm Top Artists',
          subtitle: 'Your most played lately',
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              final name = artist['name'] as String;
              final imageUrl = artist['image_url'] as String? ?? '';

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
                                  placeholder: (_, __) => Container(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                  ),
                                  errorWidget: (_, __, ___) => _buildArtistFallback(isDark),
                                )
                              : _buildArtistFallback(isDark),
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStationPlaylistSection(BuildContext context, WidgetRef ref,
    List<({String title, String subtitle, List<ItunesTrack> tracks, List<Color> colors})> playlists, bool isDark, {
    required String title,
    required String subtitle,
  }) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppleMusicSectionHeader(
          title: title,
          subtitle: subtitle,
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: _buildMixCard(
                    context: context,
                    tracks: pl.tracks,
                    title: pl.title,
                    subtitle: pl.subtitle,
                    isDark: isDark,
                    gradient: pl.colors,
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildArtistFallback(bool isDark) {
    return Container(
      color: isDark ? Colors.white10 : Colors.black12,
      child: Icon(Icons.person, color: isDark ? Colors.white30 : Colors.black26, size: 35),
    );
  }

  Widget _buildLoadingSection(BuildContext context, String title, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppleMusicSectionHeader(title: title),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  void _handleTrackTap(BuildContext context, WidgetRef ref, ItunesTrack track) async {
    HapticFeedback.lightImpact();
    final matchingFile = ref.read(libraryProvider).findMatchingTrack(track.trackName, track.artistName);

    if (matchingFile != null) {
      final meta = ref.read(libraryProvider).metadata['${matchingFile.torrentId}-${matchingFile.id}'];
      final url = matchingFile.localPath != null
          ? Uri.file(matchingFile.localPath!).toString()
          : 'https://lazy.torbox.internal/${matchingFile.torrentId}/${matchingFile.id}';

      await audioHandler.customAction('play', {
        'url': url,
        'title': meta?.trackName ?? track.trackName,
        'artist': meta?.artistName ?? track.artistName,
        'artworkUrl': meta?.artworkUrlHigh ?? meta?.artworkUrlLow ?? track.artworkUrl,
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
            builder: (_) => NowPlayingScreen(file: matchingFile, customQueue: [matchingFile]),
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
        builder: (_) => SourcePickerSheet(track: track, forceReplace: true),
      );
    }
  }
}
