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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'goals') {
                _showGoalSettingsDialog(context, ref);
              } else if (value == 'reset') {
                _showResetConfirmationDialog(context, ref);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'goals', child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Listening Goals'),
                ],
              )),
              const PopupMenuItem(value: 'reset', child: Row(
                children: [
                  Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Text('Reset Statistics', style: TextStyle(color: Colors.redAccent)),
                ],
              )),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(audiobookHistoryProvider);
          ref.invalidate(audiobookStatsSummaryProvider);
          ref.invalidate(topAudiobooksProvider);
          ref.invalidate(audiobookGenreBreakdownProvider);
          ref.invalidate(audiobookAuthorsProvider);

          await ref.read(audiobookHistoryProvider.future);
          await ref.read(audiobookStatsSummaryProvider.future);
          await ref.read(topAudiobooksProvider.future);
          await ref.read(audiobookGenreBreakdownProvider.future);
          await ref.read(audiobookAuthorsProvider.future);
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
    final authorsAsync = ref.watch(audiobookAuthorsProvider);

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

              // Activity Calendar
              _buildActivityCalendar(context, ref, isDark),
              const SizedBox(height: 20),

              // Metrics Grid
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: SizedBox(
                        height: 110,
                        child: _buildStatCard(
                          context,
                          isDark: isDark,
                          icon: Icons.headphones_outlined,
                          label: 'Listening Time',
                          value: summary['totalListeningTime'].toString(),
                          subValue: 'Total Duration',
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(
                        height: 110,
                        child: _buildStatCard(
                          context,
                          isDark: isDark,
                          icon: Icons.book_outlined,
                          label: 'Books Started',
                          value: summary['totalBooks'].toString(),
                          subValue: 'Unique titles',
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: SizedBox(
                        height: 110,
                        child: _buildStatCard(
                          context,
                          isDark: isDark,
                          icon: Icons.bookmark_added_outlined,
                          label: 'Completed Books',
                          value: summary['completedBooks'].toString(),
                          subValue: 'Finished completely',
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(
                        height: 110,
                        child: _buildStatCard(
                          context,
                          isDark: isDark,
                          icon: Icons.playlist_play_rounded,
                          label: 'Chapters Played',
                          value: summary['totalChapters'].toString(),
                          subValue: 'Listened chapters',
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: _buildStatCard(
                      context,
                      isDark: isDark,
                      icon: Icons.people,
                      label: 'Authors',
                      value: '${authorsAsync.value?.length ?? 0}',
                      subValue: 'Unique authors',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Top Audiobooks
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

              // Habits
              _buildSectionHeader(context, 'Weekly Activity'),
              const SizedBox(height: 12),
              _buildHabitsCard(context, habits, isDark),
              const SizedBox(height: 28),

              // Genre Breakdown
              genresAsync.when(
                data: (genres) {
                  if (genres.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, 'Genre Breakdown'),
                      const SizedBox(height: 12),
                      _buildGenreCard(context, genres, isDark),
                      const SizedBox(height: 28),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Top 10 Authors
              _buildAuthorsColumn(context, authorsAsync, isDark),
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

  // ── Activity Calendar ────────────────────────────────────────

  Widget _buildActivityCalendar(BuildContext context, WidgetRef ref, bool isDark) {
    final calendarMonth = ref.watch(calendarMonthProvider);
    final dayDataAsync = ref.watch(monthListeningDataProvider(calendarMonth));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header with navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ref.read(calendarMonthProvider.notifier).previousMonth(),
            ),
            Text(
              '${_monthName(calendarMonth.month)} ${calendarMonth.year}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ref.read(calendarMonthProvider.notifier).nextMonth(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Day of week headers
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Expanded(
            child: Center(
              child: Text(d, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white38 : Colors.black38,
              )),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        dayDataAsync.when(
          data: (dayData) => _buildCalendarGrid(context, calendarMonth, dayData, isDark),
          loading: () => const SizedBox(
            height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox(height: 200),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context, DateTime month, Map<int, Map<String, dynamic>> dayData, bool isDark) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1=Mon ... 7=Sun
    final today = DateTime.now();
    final todayDay = (today.year == month.year && today.month == month.month) ? today.day : -1;

    // Find max seconds for color intensity scaling
    double maxSec = 1;
    for (final entry in dayData.entries) {
      final sec = (entry.value['seconds'] as int?)?.toDouble() ?? 0;
      if (sec > maxSec) maxSec = sec;
    }

    final cells = <Widget>[];
    // Leading empty cells
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const Expanded(child: SizedBox(height: 38)));
    }
    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final data = dayData[day];
      final sec = (data?['seconds'] as int?) ?? 0;
      final intensity = maxSec > 0 ? (sec / maxSec).clamp(0.0, 1.0) : 0.0;
      final isToday = day == todayDay;
      final hasActivity = sec > 0;

      cells.add(Expanded(
        child: GestureDetector(
          onTap: hasActivity ? () => _showDayDetail(context, day, data!, isDark) : null,
          child: Container(
            height: 38,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: hasActivity
                  ? Color.lerp(
                      isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      Colors.amber,
                      intensity,
                    )
                  : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(6),
              border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: hasActivity ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
          ),
        ),
      ));
    }

    return Column(
      children: [
        // Calendar grid rows (up to 6 rows)
        ...List.generate(6, (row) {
          final start = row * 7;
          final rowCells = cells.skip(start).take(7).toList();
          if (rowCells.isEmpty) return const SizedBox.shrink();
          if (rowCells.length < 7) {
            // Pad remaining cells
            while (rowCells.length < 7) {
              rowCells.add(const Expanded(child: SizedBox(height: 38)));
            }
          }
          return Row(children: rowCells);
        }).where((w) => w is SizedBox ? false : true),
        // Legend
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 4),
            ...[-0.25, 0.25, 0.5, 0.75, 1.0].map((v) => Container(
              width: 12, height: 12, margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Color.lerp(
                  isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  Colors.amber, v,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(width: 4),
            Text('More', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ],
    );
  }

  void _showDayDetail(BuildContext context, int day, Map<String, dynamic> data, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Day $day', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _detailRow(Icons.headphones_outlined, 'Listening time', data['formattedTime'] as String? ?? '0m'),
            const SizedBox(height: 10),
            _detailRow(Icons.book_outlined, 'Books listened', '${data['booksCount'] ?? 0}'),
            const SizedBox(height: 10),
            _detailRow(Icons.playlist_play_rounded, 'Chapters played', '${data['chaptersCount'] ?? 0}'),
            if ((data['bookTitles'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Text('Books', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              )),
              const SizedBox(height: 6),
              ...((data['bookTitles'] as List).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $t', style: const TextStyle(fontSize: 13)),
              ))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.amber),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber)),
      ],
    );
  }

  String _monthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }

  // ── Stat Card ────────────────────────────────────────────────

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

  // ── Streak Card ──────────────────────────────────────────────

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
                '\u{1F525}',
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

  // ── Top Books List ───────────────────────────────────────────

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

  // ── Habits Card (Weekly Activity) ────────────────────────────

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

  // ── Old: Genre Breakdown Card ────────────────────────────────

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

  Widget _buildAuthorsColumn(BuildContext context, AsyncValue<List<Map<String, dynamic>>> authorsAsync, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top 10 Authors', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          )),
          const SizedBox(height: 12),
          authorsAsync.when(
            data: (authors) {
              if (authors.isEmpty) return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No author data',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              );
              return Column(
                children: authors.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final a = entry.value;
                  final count = a['count'] as int? ?? 0;
                  final percent = a['percent'] as double? ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            '$i.',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            a['author'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            width: 60,
                            height: 6,
                            child: LinearProgressIndicator(
                              value: percent.clamp(0.0, 1.0),
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(height: 40, child: Center(child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ))),
            error: (_, __) => const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Error', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────

  Future<void> _showGoalSettingsDialog(BuildContext context, WidgetRef ref) async {
    final goals = await ref.read(listeningGoalsProvider.future);
    final dailyCtrl = TextEditingController(text: goals.dailyMinutes > 0 ? goals.dailyMinutes.toString() : '');
    final weeklyCtrl = TextEditingController(text: goals.weeklyMinutes > 0 ? goals.weeklyMinutes.toString() : '');

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Listening Goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dailyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily goal (minutes)',
                hintText: 'e.g. 30',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: weeklyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weekly goal (minutes)',
                hintText: 'e.g. 180',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final daily = int.tryParse(dailyCtrl.text) ?? 0;
              final weekly = int.tryParse(weeklyCtrl.text) ?? 0;
              setListeningGoals(
                ref,
                dailyMinutes: daily > 0 ? daily : null,
                weeklyMinutes: weekly > 0 ? weekly : null,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetConfirmationDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Reset All Statistics'),
          ],
        ),
        content: const Text(
          'This will permanently delete:\n\n'
          '• All listening history and progress\n'
          '• Book metadata cache\n'
          '• Daily & weekly goals\n\n'
          'Your audiobook files will NOT be deleted.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await resetAllAudiobookStats(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All audiobook statistics have been reset.')),
        );
      }
    }
  }
}
