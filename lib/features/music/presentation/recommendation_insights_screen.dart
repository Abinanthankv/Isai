import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'for_you_providers.dart';
import 'music_providers.dart';
import 'artist_screen.dart';
import 'now_playing_screen.dart';
import 'stats_providers.dart';
import 'source_picker_sheet.dart';
import 'package:isai/main.dart';
import '../data/recommendation_engine.dart';
import '../data/music_models.dart';
import '../data/deezer_service.dart';
import '../data/music_repository.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';

class RecommendationInsightsScreen extends ConsumerWidget {
  const RecommendationInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userMusicProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: AppleMusicGradientText(
          text: 'Insights',
          fontSize: 20,
          colors: [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple],
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile.interactionCount == 0) {
            return _buildEmptyState(context, isDark);
          }
          return _buildContent(context, ref, profile, isDark);
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No insights yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,),
            ),
            const SizedBox(height: 8),
            Text(
              'Start playing music to see how your recommendations are built.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white60 : Colors.black54,),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, UserMusicProfile profile, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Personality Hero Card
          _buildPersonalityCard(context, profile, isDark),
          const SizedBox(height: 20),

          // 2. Quick Stats Row
          _buildQuickStats(context, profile, isDark),
          const SizedBox(height: 24),

          // 3. Topic Weights (Genre Bar Chart)
          _buildSectionHeader(context, 'Topic Weights'),
          const SizedBox(height: 12),
          _buildTopicWeights(context, ref, profile, isDark),
          const SizedBox(height: 24),

          // 4. Interest Map (Bubble Chart)
          _buildSectionHeader(context, 'Interest Map'),
          const SizedBox(height: 12),
          _buildInterestMap(context, ref, profile, isDark),
          const SizedBox(height: 24),

          // 5. Temporal Patterns
          _buildSectionHeader(context, 'Temporal Patterns'),
          const SizedBox(height: 12),
          _buildTemporalPatterns(context, ref, profile, isDark),
          const SizedBox(height: 24),

          // 6. Artist Memory
          _buildSectionHeader(context, 'Artist Memory'),
          const SizedBox(height: 12),
          _buildArtistMemory(context, profile, isDark),
        ],
      ),
    );
  }

  // ─── Personality Card ─────────────────────────────────────────────────

  Widget _buildPersonalityCard(BuildContext context, UserMusicProfile profile, bool isDark) {
    final gradientColors = _personalityGradient(context, profile.personalityType);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors.map((c) => c.withOpacity(0.25)).toList(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: gradientColors[0].withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ACTIVE LEARNING',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: gradientColors[0],),
            ),
          ),
          const SizedBox(height: 16),

          // Personality Name
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: gradientColors).createShader(bounds),
            child: Text(
              profile.personalityName,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,),
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            profile.personalityDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w400,
              height: 1.4,),
          ),
          const SizedBox(height: 20),

          // Level Progress
          Row(
            children: [
              Text(
                'Level ${profile.level}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,),
              ),
              const Spacer(),
              Text(
                '${profile.interactionCount} interactions',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (profile.level % 10) / 10, // Progress within current tier
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation(gradientColors[0]),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Stats ─────────────────────────────────────────────────────

  Widget _buildQuickStats(BuildContext context, UserMusicProfile profile, bool isDark) {
    return Row(
      children: [
        _buildStatChip(
          context: context,
          value: profile.interactionCount.toString(),
          label: 'Interactions',
          icon: Icons.headphones_outlined,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          context: context,
          value: profile.uniqueGenresCount.toString(),
          label: 'Genres',
          icon: Icons.category_outlined,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          context: context,
          value: profile.uniqueArtistsCount.toString(),
          label: 'Artists',
          icon: Icons.people_outline,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        borderRadius: 16,
        child: Column(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Topic Weights ───────────────────────────────────────────────────

  Widget _buildTopicWeights(BuildContext context, WidgetRef ref, UserMusicProfile profile, bool isDark) {
    if (profile.genreWeights.isEmpty) return const SizedBox.shrink();

    final colors = [
      Theme.of(context).colorScheme.primary,
      AppleMusicTheme.primaryPurple,
      AppleMusicTheme.primaryOrange,
      AppleMusicTheme.primaryBlue,
      Colors.tealAccent,
      Colors.amberAccent,
      Colors.cyanAccent,
    ];

    final top = profile.genreWeights.take(7).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        children: top.asMap().entries.map((entry) {
          final index = entry.key;
          final gw = entry.value;
          final color = colors[index % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final deezer = getIt<DeezerService>();
                
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return _AsyncRecommendationMixSheet(
                      title: '${gw.genre} Mix',
                      fetchTracks: () async {
                        final libraryState = ref.read(libraryProvider);
                        final seedArtists = profile.artistAffinities
                            .where((a) => libraryState.metadata.values.any((m) => 
                                m.artistName == a.name && 
                                (m.genre?.toLowerCase().contains(gw.genre.toLowerCase()) ?? false)))
                            .map((a) => a.name)
                            .toList();
                        
                        if (seedArtists.isEmpty) {
                          seedArtists.addAll(profile.topArtists.take(3));
                        }
                        
                        final tracks = await deezer.getPersonalizedPlaylist(
                          seedArtists: seedArtists,
                          limit: 30,
                        );
                        
                        return tracks.map((t) {
                          final artist = t['artist'] as Map<String, dynamic>? ?? {};
                          final album = t['album'] as Map<String, dynamic>? ?? {};
                          String artwork = album['cover_big'] ?? album['cover_medium'] ?? artist['picture_big'] ?? '';
                          return ItunesTrack(
                            trackId: (t['id'] as num?)?.toInt() ?? 0,
                            trackName: t['title'] as String? ?? 'Unknown',
                            artistName: artist['name'] as String? ?? 'Unknown Artist',
                            collectionName: album['title'] as String? ?? '',
                            artworkUrl: artwork,
                            previewUrl: t['preview'] as String?,
                            trackTimeMillis: ((t['duration'] as num?)?.toInt() ?? 0) * 1000,
                          );
                        }).toList();
                      },
                    );
                  },
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: Text(
                      gw.genre,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (gw.percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${gw.percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Interest Map (Bubble Chart) ──────────────────────────────────────

  Widget _buildInterestMap(BuildContext context, WidgetRef ref, UserMusicProfile profile, bool isDark) {
    if (profile.genreWeights.isEmpty) return const SizedBox.shrink();

    final top = profile.genreWeights.take(8).toList();
    final maxPct = top.first.percentage;

    final colors = [
      Theme.of(context).colorScheme.primary,
      AppleMusicTheme.primaryPurple,
      AppleMusicTheme.primaryOrange,
      AppleMusicTheme.primaryBlue,
      Colors.tealAccent,
      Colors.amberAccent,
      Colors.cyanAccent,
      Colors.pinkAccent,
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: top.asMap().entries.map((entry) {
            final index = entry.key;
            final gw = entry.value;
            final size = 40 + (gw.percentage / maxPct) * 50; // 40-90 range
            final color = colors[index % colors.length];

            return GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final deezer = getIt<DeezerService>();
                
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return _AsyncRecommendationMixSheet(
                      title: '${gw.genre} Mix',
                      fetchTracks: () async {
                        final libraryState = ref.read(libraryProvider);
                        final seedArtists = profile.artistAffinities
                            .where((a) => libraryState.metadata.values.any((m) => 
                                m.artistName == a.name && 
                                (m.genre?.toLowerCase().contains(gw.genre.toLowerCase()) ?? false)))
                            .map((a) => a.name)
                            .toList();
                        
                        if (seedArtists.isEmpty) {
                          seedArtists.addAll(profile.topArtists.take(3));
                        }
                        
                        final tracks = await deezer.getPersonalizedPlaylist(
                          seedArtists: seedArtists,
                          limit: 30,
                        );
                        
                        return tracks.map((t) {
                          final artist = t['artist'] as Map<String, dynamic>? ?? {};
                          final album = t['album'] as Map<String, dynamic>? ?? {};
                          String artwork = album['cover_big'] ?? album['cover_medium'] ?? artist['picture_big'] ?? '';
                          return ItunesTrack(
                            trackId: (t['id'] as num?)?.toInt() ?? 0,
                            trackName: t['title'] as String? ?? 'Unknown',
                            artistName: artist['name'] as String? ?? 'Unknown Artist',
                            collectionName: album['title'] as String? ?? '',
                            artworkUrl: artwork,
                            previewUrl: t['preview'] as String?,
                            trackTimeMillis: ((t['duration'] as num?)?.toInt() ?? 0) * 1000,
                          );
                        }).toList();
                      },
                    );
                  },
                );
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.25),
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      gw.genre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: max(8, size / 8),
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Temporal Patterns ───────────────────────────────────────────────

  Widget _buildTemporalPatterns(BuildContext context, WidgetRef ref, UserMusicProfile profile, bool isDark) {
    final patterns = profile.temporalPatterns;
    if (patterns.isEmpty) return const SizedBox.shrink();

    final icons = {
      TimeSlot.morning: Icons.wb_sunny_rounded,
      TimeSlot.afternoon: Icons.light_mode_rounded,
      TimeSlot.evening: Icons.nightlight_round,
      TimeSlot.night: Icons.dark_mode_rounded,
    };

    final gradients = {
      TimeSlot.morning: [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
      TimeSlot.afternoon: [const Color(0xFF87CEEB), const Color(0xFF4169E1)],
      TimeSlot.evening: [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple],
      TimeSlot.night: [const Color(0xFF191970), const Color(0xFF483D8B)],
    };

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: patterns.map((p) {
        final icon = icons[p.slot] ?? Icons.schedule;
        final gradient = gradients[p.slot] ?? AppleMusicTheme.pinkGradient;
        return GlassCard(
          onTap: () {
            HapticFeedback.mediumImpact();
            final libraryState = ref.read(libraryProvider);
            final history = ref.read(allPlaybackProvider).value ?? [];
            
            final targetTracks = history.where((h) {
              final d = DateTime.fromMillisecondsSinceEpoch(h.playedAt);
              final hour = d.hour;
              
              bool inSlot = false;
              if (p.slot == TimeSlot.morning) inSlot = hour >= 6 && hour < 12;
              else if (p.slot == TimeSlot.afternoon) inSlot = hour >= 12 && hour < 18;
              else if (p.slot == TimeSlot.evening) inSlot = hour >= 18 && hour < 22;
              else if (p.slot == TimeSlot.night) inSlot = hour >= 22 || hour < 6;
              
              return inSlot;
            }).toList();

            final compiledItunesTracks = targetTracks.map((h) {
              // Try to find matching metadata or library image/properties
              String artwork = '';
              for (final song in libraryState.allAudioFiles) {
                final key = '${song.torrentId}-${song.id}';
                final meta = libraryState.metadata[key];
                if ((meta?.trackName?.toLowerCase() == h.trackTitle.toLowerCase() && meta?.artistName?.toLowerCase() == h.artist.toLowerCase()) ||
                    (song.name.toLowerCase() == h.trackTitle.toLowerCase())) {
                  artwork = meta?.artworkUrlHigh ?? meta?.artworkUrlLow ?? '';
                  break;
                }
              }
              return ItunesTrack(
                trackId: h.fileId,
                trackName: h.trackTitle,
                artistName: h.artist,
                collectionName: h.album,
                artworkUrl: artwork,
              );
            }).toList();

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => _RecommendationMixSheet(
                title: '${p.label} Mix',
                tracks: compiledItunesTracks,
              ),
            );
          },
          padding: const EdgeInsets.all(14),
          borderRadius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient.map((c) => c.withOpacity(0.3)).toList()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: gradient[0]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,),
                        ),
                        Text(
                          p.timeRange,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (p.topGenres.isNotEmpty) ...[
                ...p.topGenres.take(2).map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.genre,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white70 : Colors.black87,),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${g.percentage.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,),
                      ),
                    ],
                  ),
                )),
              ] else
                Text(
                  'No data yet',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white30 : Colors.black26,
                    fontStyle: FontStyle.italic,),
                ),
              const SizedBox(height: 4),
              Text(
                '${p.totalPlays} plays',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white24 : Colors.black26,),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Artist Memory ───────────────────────────────────────────────────

  Widget _buildArtistMemory(BuildContext context, UserMusicProfile profile, bool isDark) {
    final artists = profile.artistAffinities;
    if (artists.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        children: artists.take(10).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final a = entry.value;
          final barWidth = a.affinityScore;

          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtistScreen(artistName: a.name),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white24 : Colors.black26,),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${a.playCount} plays',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Affinity bar
                  Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: barWidth,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sentiment badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: a.sentiment == 'Positive'
                          ? Colors.green.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.sentiment,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                        color: a.sentiment == 'Positive'
                            ? (isDark ? Colors.greenAccent : Colors.green)
                            : Colors.grey,),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
        letterSpacing: -0.2,),
    );
  }

  List<Color> _personalityGradient(BuildContext context, PersonalityType type) {
    switch (type) {
      case PersonalityType.explorer:
        return [AppleMusicTheme.primaryPurple, AppleMusicTheme.primaryBlue];
      case PersonalityType.loyalist:
        return [Theme.of(context).colorScheme.primary, const Color(0xFFFF2D55)];
      case PersonalityType.nicheDiver:
        return [AppleMusicTheme.primaryOrange, const Color(0xFFFF9500)];
      case PersonalityType.moodRider:
        return [const Color(0xFF00C7BE), const Color(0xFF32D74B)];
      case PersonalityType.eclectic:
        return [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple];
    }
  }
}

class _RecommendationMixSheet extends ConsumerStatefulWidget {
  final String title;
  final List<ItunesTrack> tracks;

  const _RecommendationMixSheet({
    super.key,
    required this.title,
    required this.tracks,
  });

  @override
  ConsumerState<_RecommendationMixSheet> createState() => _RecommendationMixSheetState();
}

class _RecommendationMixSheetState extends ConsumerState<_RecommendationMixSheet> {
  void _handleTrackTap(BuildContext context, WidgetRef ref, ItunesTrack track, List<ItunesTrack> queue) async {
    final libraryState = ref.read(libraryProvider);
    
    // Convert ItunesTracks to TorBoxFiles dummy list or library matches to preserve full queue
    final customQueue = queue.map((t) {
      final matched = libraryState.findMatchingTrack(t.trackName, t.artistName);
      return matched ?? TorBoxFile(
        id: -t.trackId,
        name: '${t.artistName} - ${t.trackName}',
        size: 0,
        torrentId: -1,
      );
    }).toList().cast<TorBoxFile>();

    final startIndex = queue.indexOf(track);
    final file = customQueue[startIndex >= 0 ? startIndex : 0];
    final artwork = track.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000');

    final url = file.localPath != null 
        ? Uri.file(file.localPath!).toString() 
        : 'https://lazy.torbox.internal/${file.torrentId}/${file.id}';
      
    await audioHandler.customAction('play', {
      'url': url,
      'title': track.trackName,
      'artist': track.artistName,
      'artworkUrl': artwork,
      'forceReplace': true,
      'queue': List.generate(customQueue.length, (i) {
        final e = customQueue[i];
        final tMatch = queue[i];
        String fUrl = 'https://lazy.torbox.internal/${e.torrentId}/${e.id}';
        if (e.torrentId == -1) {
          fUrl = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(tMatch.trackName)}&artist=${Uri.encodeComponent(tMatch.artistName)}';
        }
        return {
          'url': fUrl,
          'title': tMatch.trackName,
          'artist': tMatch.artistName,
          'artworkUrl': tMatch.artworkUrl.replaceAll(RegExp(r'\d+x\d+'), '1000x1000'),
          'extras': {
            'torrentId': e.torrentId,
            'fileId': e.id,
            'size': e.size,
            'localPath': e.localPath,
          }
        };
      }),
      'index': startIndex >= 0 ? startIndex : 0,
    });

    if (context.mounted) {
      Navigator.pop(context); // Close mix sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NowPlayingScreen(
            file: file,
            customQueue: customQueue,
            initialArtwork: artwork,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151515) : const Color(0xFFF9F9FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (widget.tracks.isNotEmpty) ...[
                // Play Mix Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _handleTrackTap(context, ref, widget.tracks.first, widget.tracks);
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    label: Text(
                      'Play Mix',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Included Songs',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,),
                ),
                const SizedBox(height: 8),

                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.tracks.length,
                    itemBuilder: (context, index) {
                      final track = widget.tracks[index];

                      return AppleMusicListTile(
                        title: track.trackName,
                        subtitle: track.artistName,
                        imageUrl: track.artworkUrl,
                        trailing: Icon(
                          Icons.play_arrow_rounded,
                          color: isDark ? Colors.white30 : Colors.black26,
                          size: 24,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleTrackTap(context, ref, track, widget.tracks);
                        },
                      );
                    },
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Column(
                    children: [
                      Icon(Icons.queue_music_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'No recommended songs found for this mix yet.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey,),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AsyncRecommendationMixSheet extends ConsumerStatefulWidget {
  final String title;
  final Future<List<ItunesTrack>> Function() fetchTracks;

  const _AsyncRecommendationMixSheet({
    super.key,
    required this.title,
    required this.fetchTracks,
  });

  @override
  ConsumerState<_AsyncRecommendationMixSheet> createState() => _AsyncRecommendationMixSheetState();
}

class _AsyncRecommendationMixSheetState extends ConsumerState<_AsyncRecommendationMixSheet> {
  List<ItunesTrack>? _tracks;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      final res = await widget.fetchTracks();
      if (mounted) {
        setState(() {
          _tracks = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515) : const Color(0xFFF9F9FB),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151515) : const Color(0xFFF9F9FB),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Center(
          child: Text('Error compiling mix: $_error', style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    return _RecommendationMixSheet(
      title: widget.title,
      tracks: _tracks ?? [],
    );
  }
}

