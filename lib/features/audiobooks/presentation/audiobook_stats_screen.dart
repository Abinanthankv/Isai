import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'audiobook_stats_providers.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import 'dart:io';

class AudiobookStatsScreen extends ConsumerWidget {
  const AudiobookStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyAsync = ref.watch(audiobookHistoryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Audiobook Insights',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(audiobookHistoryProvider);
          ref.invalidate(audiobookStatsSummaryProvider);
          ref.invalidate(topAudiobooksProvider);
          ref.invalidate(audiobookGenreBreakdownProvider);
          
          await ref.read(audiobookHistoryProvider.future);
          await ref.read(audiobookStatsSummaryProvider.future);
          await ref.read(topAudiobooksProvider.future);
          await ref.read(audiobookGenreBreakdownProvider.future);
        },
        color: Theme.of(context).colorScheme.primary,
        child: historyAsync.when(
          data: (history) => history.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    alignment: Alignment.center,
                    child: _buildEmptyState(context, isDark),
                  ),
                )
              : _buildContent(context, ref, isDark),
          loading: () => Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          error: (e, _) => Center(child: Text('Error loading stats: $e')),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.query_stats_rounded,
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No listening insights yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Listen to your audiobooks to see stats here.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool isDark) {
    final summaryAsync = ref.watch(audiobookStatsSummaryProvider);
    final topBooksAsync = ref.watch(topAudiobooksProvider);
    final habits = ref.watch(audiobookListeningHabitsProvider);
    final genresAsync = ref.watch(audiobookGenreBreakdownProvider);

    return summaryAsync.when(
      data: (summary) {
        final streak = summary['streak'] as int? ?? 0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Streak Card
              if (streak > 0) ...[
                _buildStreakCard(context, streak, isDark),
                const SizedBox(height: 20),
              ],

              // 2. Metrics Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _buildStatCard(
                    context,
                    isDark: isDark,
                    icon: Icons.headphones_outlined,
                    label: 'Listening Time',
                    value: summary['totalListeningTime'].toString(),
                    subValue: 'Total Duration',
                  ),
                  _buildStatCard(
                    context,
                    isDark: isDark,
                    icon: Icons.book_outlined,
                    label: 'Books Started',
                    value: summary['totalBooks'].toString(),
                    subValue: 'Unique titles',
                  ),
                  _buildStatCard(
                    context,
                    isDark: isDark,
                    icon: Icons.bookmark_added_outlined,
                    label: 'Completed Books',
                    value: summary['completedBooks'].toString(),
                    subValue: 'Finished completely',
                  ),
                  _buildStatCard(
                    context,
                    isDark: isDark,
                    icon: Icons.playlist_play_rounded,
                    label: 'Chapters Played',
                    value: summary['totalChapters'].toString(),
                    subValue: 'Listened chapters',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 3. Top Audiobooks Section
              topBooksAsync.when(
                data: (books) {
                  if (books.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, 'Top Listened Books'),
                      const SizedBox(height: 12),
                      _buildTopBooksList(context, books, isDark),
                      const SizedBox(height: 28),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // 4. Habits Section
              _buildSectionHeader(context, 'Weekly Activity'),
              const SizedBox(height: 12),
              _buildHabitsCard(context, habits, isDark),
              const SizedBox(height: 28),

              // 5. Genre Breakdown Section
              genresAsync.when(
                data: (genres) {
                  if (genres.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, 'Genre Breakdown'),
                      const SizedBox(height: 12),
                      _buildGenreCard(context, genres, isDark),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      error: (e, _) => Center(child: Text('Error calculating summary: $e')),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, int streak, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            AppleMusicTheme.primaryPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '🔥',
                style: TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak Day Streak!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are keeping your daily audiobook learning routine alive.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBooksList(
      BuildContext context, List<Map<String, dynamic>> books, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        children: books.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final book = entry.value;
          final isLocal = book['artworkUrl']?.startsWith('/') == true ||
              book['artworkUrl']?.startsWith('file://') == true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '$index',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.white30 : Colors.black38,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: book['artworkUrl'] != null
                      ? (isLocal
                          ? Image.file(
                              File(book['artworkUrl'].startsWith('file://')
                                  ? Uri.parse(book['artworkUrl']).toFilePath()
                                  : book['artworkUrl']),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildArtworkPlaceholder(context),
                            )
                          : CachedNetworkImage(
                              imageUrl: book['artworkUrl'],
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _buildArtworkPlaceholder(context),
                            ))
                      : _buildArtworkPlaceholder(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book['author'],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  book['formattedTime'],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildArtworkPlaceholder(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.book, size: 20),
    );
  }

  Widget _buildHabitsCard(
      BuildContext context, Map<String, dynamic> habits, bool isDark) {
    final weekdayCounts = habits['weekdays'] as Map<int, int>;
    double maxDay = weekdayCounts.values
        .fold(1.0, (m, c) => c > m ? c.toDouble() : m);

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(7, (index) {
            final count = weekdayCounts[index + 1] ?? 0;
            final percent = count / maxDay;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      weekdays[index],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                          widthFactor: percent > 0 ? percent : 0.0,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  AppleMusicTheme.primaryPurple,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 24,
                    child: Text(
                      count.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGenreCard(BuildContext context, List<Map<String, dynamic>> genres,
      bool isDark) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.blueAccent,
      Colors.purpleAccent
    ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: genres.asMap().entries.map((entry) {
                  final item = entry.value;
                  final index = entry.key;
                  final percent = item['percentage'] / 100;
                  return Expanded(
                    flex: (percent * 100).toInt().clamp(1, 100),
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
            children: genres.asMap().entries.map((entry) {
              final item = entry.value;
              final index = entry.key;
              final color = colors[index % colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item['genre']} (${item['percentage'].toStringAsFixed(0)}%)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
