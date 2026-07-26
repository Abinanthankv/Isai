import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stats_providers.dart';
import 'lastfm_stats_providers.dart';
import '../../settings/data/lastfm_repository.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import 'listening_time_detail_sheet.dart';
import 'monthly_wrapped_section.dart';
import 'decade_tracks_screen.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNewMilestones());
  }

  void _checkNewMilestones() {
    if (_celebrationShown) return;
    final newMilestones = ref.read(newMilestonesProvider);
    if (newMilestones.isNotEmpty) {
      _celebrationShown = true;
      _showMilestoneCelebration(newMilestones);
    }
  }

  void _showMilestoneCelebration(List<StreakMilestone> milestones) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack), child: child),
        );
      },
      pageBuilder: (ctx, _, __) => _MilestoneCelebrationOverlay(
        milestones: milestones,
        onDismiss: () {
          Navigator.of(ctx).pop();
          for (final m in milestones) {
            ref.read(milestoneCelebrationProvider.notifier).markAsCelebrated(m.days);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewMode = ref.watch(statsViewModeProvider);
    final statsListAsync = ref.watch(allPlaybackProvider);
    final lastfmConnected = getIt<LastfmRepository>().username != null;

    // Re-check milestones when playback data updates
    ref.listen(newMilestonesProvider, (prev, next) {
      if (next.isNotEmpty && !_celebrationShown) {
        _celebrationShown = true;
        _showMilestoneCelebration(next);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Your Stats', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold,)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: lastfmConnected ? PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildModeToggle(ref, viewMode, isDark),
          ),
        ) : null,
      ),
      body: viewMode == StatsViewMode.local
          ? statsListAsync.when(
              data: (history) => history.isEmpty ? _buildEmptyState(isDark) : _buildContent(context, ref, isDark),
              loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
              error: (e, _) => Center(child: Text('Error: $e')),
            )
          : _buildLastfmContent(context, ref, isDark),
    );
  }

  Widget _buildModeToggle(WidgetRef ref, StatsViewMode currentMode, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              'App stats',
              currentMode == StatsViewMode.local,
              () => ref.read(statsViewModeProvider.notifier).setMode(StatsViewMode.local),
              isDark,
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              'Last.fm Profile',
              currentMode == StatsViewMode.lastfm,
              () => ref.read(statsViewModeProvider.notifier).setMode(StatsViewMode.lastfm),
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Your Stats', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No stats available yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Start playing music to see your insights',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool isDark) {
    final summary = ref.watch(statsSummaryProvider);
    final personality = ref.watch(musicPersonalityProvider);
    final earnedMilestones = ref.watch(earnedMilestonesProvider);
    final nextMilestone = ref.watch(nextMilestoneProvider);
    final streak = summary['streak'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monthly Wrapped Section (Spotify Wrapped-style)
            const MonthlyWrappedSection(),

            // 0a. Streak Card
            if (streak > 0) ...[
              _StreakCard(streak: streak, earned: earnedMilestones, next: nextMilestone, isDark: isDark),
              const SizedBox(height: 16),
            ],
            // 0b. Music Personality Card
            if (personality != null) ...[
              _PersonalityCard(personality: personality, isDark: isDark),
              const SizedBox(height: 16),
            ],
            // 1. Header Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildStatCard(
                  isDark: isDark,
                  icon: Icons.headphones_outlined,
                  label: 'Total Plays',
                  value: summary['totalPlays'].toString(),
                  subValue: '${summary['streak']} streak',
                ),
                _buildStatCard(
                  isDark: isDark,
                  icon: Icons.access_time,
                  label: 'Listening Time',
                  value: summary['listeningTime'],
                  subValue: '${summary['hours'].toStringAsFixed(1)} hours',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const ListeningTimeDetailSheet(),
                    );
                  },
                ),
                _buildStatCard(
                  isDark: isDark,
                  icon: Icons.music_note_outlined,
                  label: 'Unique Tracks',
                  value: summary['uniqueTracks'].toString(),
                  subValue: 'Tracks',
                ),
                _buildStatCard(
                  isDark: isDark,
                  icon: Icons.album_outlined,
                  label: 'Unique Albums',
                  value: summary['uniqueAlbums'].toString(),
                  subValue: 'Albums',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Top Charts Lists Row
            _buildSectionHeader('Top Charts'),
            const SizedBox(height: 8),
            _buildTopListsRow(context, ref, isDark),
            const SizedBox(height: 24),

            // 3. Graphs Section
            _buildSectionHeader('Listening Habits'),
            const SizedBox(height: 12),
            _buildHabitsSection(ref, isDark),
            const SizedBox(height: 24),

            // 4. Genre breakdown 
            _buildSectionHeader('Genre Breakdown'),
            const SizedBox(height: 12),
            _buildGenreBreakdown(ref, isDark),
            const SizedBox(height: 24),

            // 5. Decades
            _buildSectionHeader('Decades'),
            const SizedBox(height: 12),
            _buildDecadesSection(ref, isDark),
          ],
        ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.2),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subValue,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopListsRow(BuildContext context, WidgetRef ref, bool isDark) {
    final artists = ref.watch(topArtistsProvider);
    final tracks = ref.watch(topTracksProvider);
    final albums = ref.watch(topAlbumsProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (artists.isNotEmpty) _buildListCard(isDark, 'Top Artists', artists, _buildArtistRow),
          const SizedBox(width: 12),
          if (tracks.isNotEmpty) _buildListCard(isDark, 'Top Tracks', tracks, _buildTrackRow),
          const SizedBox(width: 12),
          if (albums.isNotEmpty) _buildListCard(isDark, 'Top Albums', albums, _buildAlbumRow),
        ],
      ),
    );
  }

  Widget _buildListCard(bool isDark, String title, List<dynamic> items, Widget Function(bool, dynamic, int) rowBuilder) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      width: 280,
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((e) => rowBuilder(isDark, e.value, e.key + 1)).toList(),
        ],
      ),
    );
  }

  Widget _buildArtistRow(bool isDark, dynamic item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          _buildIndex(index, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item['name'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item['count']} plays',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackRow(bool isDark, dynamic item, int index) {
    return _buildMediaRow(
        isDark: isDark,
        title: item['title'],
        subtitle: item['artist'],
        artworkUrl: item['artworkUrlLow'],
        count: item['count'],
        index: index);
  }

  Widget _buildAlbumRow(bool isDark, dynamic item, int index) {
    return _buildMediaRow(
        isDark: isDark,
        title: item['album'],
        subtitle: item['artist'],
        artworkUrl: item['artworkUrlLow'],
        count: item['count'],
        index: index);
  }

  Widget _buildMediaRow({
    required bool isDark,
    required String title,
    required String subtitle,
    required String? artworkUrl,
    required int count,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          _buildIndex(index, isDark),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: artworkUrl != null
                ? CachedNetworkImage(
                    imageUrl: artworkUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  )
                : Container(width: 32, height: 32, color: isDark ? Colors.white12 : Colors.black12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count plays',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildIndex(int index, bool isDark) {
    return SizedBox(
      width: 16,
      child: Text(
        index.toString(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold,),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHabitsSection(WidgetRef ref, bool isDark) {
    final habits = ref.watch(listeningHabitsProvider);
    final weekdayCounts = habits['weekdays'] as Map<int, int>;

    double maxDay = weekdayCounts.values.fold(1.0, (m, c) => c > m ? c.toDouble() : m);

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By Day of Week', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,)),
          const SizedBox(height: 16),
          ...List.generate(7, (index) {
            final count = weekdayCounts[index + 1] ?? 0;
            final percent = count / maxDay;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 32, child: Text(weekdays[index], style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white60 : Colors.black54))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(5)),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent > 0 ? percent : 0.0,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, AppleMusicTheme.primaryPurple]),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 20, child: Text(count.toString(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGenreBreakdown(WidgetRef ref, bool isDark) {
    final genres = ref.watch(genreBreakdownProvider);
    if (genres.isEmpty) return const SizedBox.shrink();

    final colors = [Theme.of(context).colorScheme.primary, Colors.orangeAccent, Colors.tealAccent, Colors.blueAccent, Colors.purpleAccent];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Genre Distribution', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: genres.asMap().entries.map((e) {
                  final item = e.value;
                  final index = e.key;
                  final percent = item['percentage'] / 100;
                  return Expanded(
                    flex: (percent * 100).toInt(),
                    child: Container(color: colors[index % colors.length]),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: genres.asMap().entries.map((e) {
              final item = e.value;
              final index = e.key;
              final color = colors[index % colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    '${item['genre']} (${item['percentage'].toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDecadesSection(WidgetRef ref, bool isDark) {
    final decades = ref.watch(listeningByDecadeProvider);
    if (decades.isEmpty) return const SizedBox.shrink();

    final maxPlays = decades.map((d) => d['plays'] as int).fold(1, (a, b) => a > b ? a : b);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tracks by Decade', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...decades.map((d) {
            final decade = d['decade'] as int;
            final plays = d['plays'] as int;
            final unique = d['uniqueTracks'] as int;
            final fraction = plays / maxPlays;
            final label = '${decade}s';
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DecadeTracksScreen(decade: decade),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 48, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 14,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$plays', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(width: 4),
                    Text('($unique unique)', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLastfmContent(BuildContext context, WidgetRef ref, bool isDark) {
    final profileAsync = ref.watch(lastfmUserProfileProvider);
    final topArtistsAsync = ref.watch(lastfmTopArtistsOverallProvider);
    final topTracksAsync = ref.watch(lastfmTopTracksOverallProvider);
    final topAlbumsAsync = ref.watch(lastfmTopAlbumsOverallProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const Center(child: Text('Please connect Last.fm in settings'));

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Metrics
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _buildStatCard(
                    isDark: isDark,
                    icon: Icons.headphones_outlined,
                    label: 'Total Scrobbles',
                    value: profile['scrobbles'].toString(),
                    subValue: 'Lifetime plays',
                  ),
                  _buildStatCard(
                    isDark: isDark,
                    icon: Icons.person_outline,
                    label: 'Artists Explored',
                    value: profile['artists'].toString(),
                    subValue: 'Unique artists',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Offset for registration date info
              if (profile['registered'] != null && profile['registered'] != 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: Text(
                      'Scrobbling since ${DateTime.fromMillisecondsSinceEpoch((int.tryParse(profile['registered'].toString()) ?? 0) * 1000).year}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
                    ),
                  ),
                ),

              // 2. Lifetime Charts
              _buildSectionHeader('Lifetime Top Charts'),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    topArtistsAsync.when(
                      data: (items) => _buildListCard(isDark, 'Top Artists', items, _buildLastfmArtistRow),
                      loading: () => _buildLoadingListCard('Top Artists'),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 12),
                    topTracksAsync.when(
                      data: (items) => _buildListCard(isDark, 'Top Tracks', items, _buildLastfmTrackRow),
                      loading: () => _buildLoadingListCard('Top Tracks'),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 12),
                    topAlbumsAsync.when(
                      data: (items) => _buildListCard(isDark, 'Top Albums', items, _buildLastfmAlbumRow),
                      loading: () => _buildLoadingListCard('Top Albums'),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildLoadingListCard(String title) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      width: 280,
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold,)),
          const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
    );
  }

  Widget _buildLastfmArtistRow(bool isDark, dynamic item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _buildIndex(index, isDark),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: item['image_url'] ?? '',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _buildArtistPlaceholderForLastfm(isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item['name'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item['playcount']} scrobbles',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildLastfmTrackRow(bool isDark, dynamic item, int index) {
    return _buildLastfmMediaRow(
      isDark: isDark,
      title: item['name'],
      subtitle: item['artist'],
      artworkUrl: item['image_url'],
      count: int.tryParse(item['playcount']?.toString() ?? '0') ?? 0,
      index: index,
    );
  }

  Widget _buildLastfmAlbumRow(bool isDark, dynamic item, int index) {
    return _buildLastfmMediaRow(
      isDark: isDark,
      title: item['name'],
      subtitle: item['artist'],
      artworkUrl: item['image_url'],
      count: int.tryParse(item['playcount']?.toString() ?? '0') ?? 0,
      index: index,
    );
  }

  Widget _buildLastfmMediaRow({
    required bool isDark,
    required String title,
    required String subtitle,
    required String? artworkUrl,
    required int count,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _buildIndex(index, isDark),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: artworkUrl != null && artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: artworkUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(width: 40, height: 40, color: isDark ? Colors.white10 : Colors.black12, child: const Icon(Icons.music_note, size: 20)),
                  )
                : Container(width: 40, height: 40, color: isDark ? Colors.white10 : Colors.black12, child: const Icon(Icons.music_note, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white54 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistPlaceholderForLastfm(bool isDark) {
    return Container(
      width: 36,
      height: 36,
      color: isDark ? Colors.white10 : Colors.black12,
      child: const Icon(Icons.person, size: 20, color: Colors.grey),
    );
  }
}

// ─── Streak Card ──────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int streak;
  final List<StreakMilestone> earned;
  final StreakMilestone? next;
  final bool isDark;

  const _StreakCard({required this.streak, required this.earned, this.next, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final highestEarned = earned.isNotEmpty ? earned.last : null;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                highestEarned?.emoji ?? '🔥',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak Day${streak == 1 ? '' : 's'} Streak',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (highestEarned != null)
                      Text(
                        highestEarned.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600,
                          color: highestEarned.primaryColor,),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Progress to next milestone
          if (next != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next: ${next!.emoji} ${next!.title}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: streak / next!.days,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation(next!.primaryColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${next!.days - streak} to go',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],

          // Earned badges gallery
          if (earned.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Badges Earned', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: earned.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [m.primaryColor.withOpacity(0.25), m.secondaryColor.withOpacity(0.15)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: m.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.emoji, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 4),
                      Text(m.title, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: m.primaryColor)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Music Personality Card ──────────────────────────────────────────────────

class _PersonalityCard extends StatelessWidget {
  final MusicPersonality personality;
  final bool isDark;

  const _PersonalityCard({required this.personality, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            personality.primaryColor.withOpacity(0.25),
            personality.secondaryColor.withOpacity(0.15),
          ],
        ),
        border: Border.all(color: personality.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Music Personality',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(personality.emoji, style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personality.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: personality.primaryColor),
                    ),
                    Text(
                      '${personality.timeEmoji} ${personality.timeTitle}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            personality.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─── Milestone Celebration Overlay ──────────────────────────────────────────

class _MilestoneCelebrationOverlay extends StatefulWidget {
  final List<StreakMilestone> milestones;
  final VoidCallback onDismiss;

  const _MilestoneCelebrationOverlay({required this.milestones, required this.onDismiss});

  @override
  State<_MilestoneCelebrationOverlay> createState() => _MilestoneCelebrationOverlayState();
}

class _MilestoneCelebrationOverlayState extends State<_MilestoneCelebrationOverlay> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < widget.milestones.length - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestones[_currentIndex];
    final isLast = _currentIndex == widget.milestones.length - 1;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated emoji
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) {
                    final scale = 1.0 + (_pulseController.value * 0.15);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Text(m.emoji, style: Theme.of(context).textTheme.displayMedium),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  m.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..shader = LinearGradient(colors: [m.primaryColor, m.secondaryColor])
                          .createShader(const Rect.fromLTWH(0, 0, 200, 40)),),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  m.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Progress indicator dots
                if (widget.milestones.length > 1) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.milestones.length, (i) {
                      return Container(
                        width: i == _currentIndex ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _currentIndex ? m.primaryColor : Colors.white24,
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 36),
                // Button
                GestureDetector(
                  onTap: _next,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [m.primaryColor, m.secondaryColor]),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      isLast ? 'Awesome!' : 'Next Badge',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold,),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
