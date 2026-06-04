import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'monthly_wrapped_providers.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';

// ─── Month Names ─────────────────────────────────────────────────────────────

const _monthNames = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
  'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
];

const _monthNamesShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// ═══════════════════════════════════════════════════════════════════════════════
//  MONTHLY WRAPPED SECTION — Top-level widget inserted into StatsScreen
// ═══════════════════════════════════════════════════════════════════════════════

class MonthlyWrappedSection extends ConsumerStatefulWidget {
  const MonthlyWrappedSection({super.key});

  @override
  ConsumerState<MonthlyWrappedSection> createState() =>
      _MonthlyWrappedSectionState();
}

class _MonthlyWrappedSectionState
    extends ConsumerState<MonthlyWrappedSection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPreviousMonth() {
    HapticFeedback.lightImpact();
    final current = ref.read(selectedWrappedMonthProvider);
    ref.read(selectedWrappedMonthProvider.notifier).state =
        DateTime(current.year, current.month - 1);
  }

  void _goToNextMonth() {
    final current = ref.read(selectedWrappedMonthProvider);
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    if (current.year == currentMonthStart.year &&
        current.month == currentMonthStart.month) return;
    HapticFeedback.lightImpact();
    ref.read(selectedWrappedMonthProvider.notifier).state =
        DateTime(current.year, current.month + 1);
  }

  bool get _isCurrentMonth {
    final current = ref.watch(selectedWrappedMonthProvider);
    final now = DateTime.now();
    return current.year == now.year && current.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final month = ref.watch(selectedWrappedMonthProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final totalPlays = summary['totalPlays'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Month Selector Header ──
        _buildMonthSelector(month, isDark),
        const SizedBox(height: 12),

        // ── Card Carousel ──
        if (totalPlays == 0)
          _buildEmptyMonthState(isDark)
        else ...[
          SizedBox(
            height: 380,
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: const [
                _TopAlbumsCard(),
                _TopArtistsCalendarCard(),
                _MilestonesCard(),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Page Indicator Dots ──
          _buildPageDots(isDark),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMonthSelector(DateTime month, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goToPreviousMonth,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_left_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthNames[month.month - 1],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white : AppleMusicTheme.lightText,
                  ),
                ),
                Text(
                  '${month.year}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white38
                        : AppleMusicTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppleMusicTheme.pinkGradient,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'MONTHLY RECAP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isCurrentMonth ? null : _goToNextMonth,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: _isCurrentMonth
                      ? (isDark ? Colors.white12 : Colors.black12)
                      : (isDark ? Colors.white70 : Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonthState(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      borderRadius: 20,
      child: Center(
        child: Column(
          children: [
            Icon(Icons.music_off_outlined,
                size: 48,
                color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            Text(
              'No listening data this month',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Navigate to a month with playback history',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDots(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: isActive ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? AppleMusicTheme.primaryPink
                : (isDark ? Colors.white24 : Colors.black12),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CARD 1 — TOP ALBUMS (Circular Ring)
// ═══════════════════════════════════════════════════════════════════════════════

class _TopAlbumsCard extends ConsumerWidget {
  const _TopAlbumsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final albums = ref.watch(monthlyTopAlbumsProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final month = ref.watch(selectedWrappedMonthProvider);
    final totalAlbums = summary['uniqueAlbums'] as int;

    // Take top 12 for the ring
    final ringAlbums = albums.take(12).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f3460),
                  ]
                : [
                    const Color(0xFFe8f4fd),
                    const Color(0xFFd4ecfc),
                    const Color(0xFFbde0fe),
                  ],
          ),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_monthNamesShort[month.month - 1].toUpperCase()} ${month.year}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'MY TOP ALBUMS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Ring of albums
              Expanded(
                child: Center(
                  child: ringAlbums.length >= 3
                      ? _AlbumRingWidget(
                          albums: ringAlbums,
                          centerCount: totalAlbums,
                          isDark: isDark,
                        )
                      : _AlbumGridFallback(
                          albums: ringAlbums,
                          centerCount: totalAlbums,
                          isDark: isDark,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Album Ring — Arranges album art thumbnails in a circle
class _AlbumRingWidget extends StatelessWidget {
  final List<Map<String, dynamic>> albums;
  final int centerCount;
  final bool isDark;

  const _AlbumRingWidget({
    required this.albums,
    required this.centerCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = math.min(constraints.maxWidth, constraints.maxHeight);
      final ringRadius = size * 0.38;
      final thumbSize = size * 0.16;
      final center = Offset(size / 2, size / 2);

      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // Center count
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$centerCount',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ALBUMS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Album thumbnails around the ring
            for (int i = 0; i < albums.length; i++)
              Builder(builder: (context) {
                final angle =
                    (2 * math.pi * i / albums.length) - (math.pi / 2);
                final x = center.dx + ringRadius * math.cos(angle) - thumbSize / 2;
                final y = center.dy + ringRadius * math.sin(angle) - thumbSize / 2;

                // Slight tilt for visual flair
                final tilt = (angle + math.pi / 2) * 0.15;

                return Positioned(
                  left: x,
                  top: y,
                  child: Transform.rotate(
                    angle: tilt,
                    child: _AlbumThumb(
                      artworkUrl: albums[i]['artworkUrlLow'] as String?,
                      size: thumbSize,
                      isDark: isDark,
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    });
  }
}

class _AlbumThumb extends StatelessWidget {
  final String? artworkUrl;
  final double size;
  final bool isDark;

  const _AlbumThumb({
    this.artworkUrl,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.15),
        child: artworkUrl != null && artworkUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: artworkUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                errorWidget: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      child: Icon(Icons.album, size: size * 0.4, color: Colors.grey),
    );
  }
}

// Fallback grid when fewer than 3 albums
class _AlbumGridFallback extends StatelessWidget {
  final List<Map<String, dynamic>> albums;
  final int centerCount;
  final bool isDark;

  const _AlbumGridFallback({
    required this.albums,
    required this.centerCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$centerCount',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
          ),
        ),
        Text(
          'ALBUMS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: albums.map((a) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _AlbumThumb(
                artworkUrl: a['artworkUrlLow'] as String?,
                size: 56,
                isDark: isDark,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CARD 2 — TOP ARTISTS CALENDAR
// ═══════════════════════════════════════════════════════════════════════════════

class _TopArtistsCalendarCard extends ConsumerWidget {
  const _TopArtistsCalendarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final month = ref.watch(selectedWrappedMonthProvider);
    final dailyArtists = ref.watch(monthlyDailyTopArtistProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final uniqueArtists = summary['uniqueArtists'] as int;
    final totalMinutes = summary['totalMinutes'] as int;

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // Day of week for the 1st (0 = Mon, 6 = Sun in our grid)
    final firstWeekday = DateTime(month.year, month.month, 1).weekday - 1;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1025),
                    const Color(0xFF1e1535),
                    const Color(0xFF251845),
                  ]
                : [
                    const Color(0xFFF3EEFF),
                    const Color(0xFFEDE5FF),
                    const Color(0xFFE5DAFF),
                  ],
          ),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_monthNamesShort[month.month - 1].toUpperCase()} ${month.year}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  Text(
                    'MY TOP ARTISTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Section title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppleMusicTheme.primaryPurple.withOpacity(isDark ? 0.3 : 0.15),
                      AppleMusicTheme.primaryPink.withOpacity(isDark ? 0.2 : 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'TOP ARTISTS EACH DAY OF THE MONTH',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white : AppleMusicTheme.lightText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Weekday headers
              Row(
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),

              // Calendar grid
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: rowCount * 7,
                  itemBuilder: (context, index) {
                    final dayNumber = index - firstWeekday + 1;
                    if (index < firstWeekday || dayNumber > daysInMonth) {
                      return const SizedBox.shrink();
                    }

                    final artist = dailyArtists[dayNumber];
                    return _CalendarDayCell(
                      day: dayNumber,
                      artist: artist,
                      isDark: isDark,
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Bottom summary
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatNumber(uniqueArtists),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppleMusicTheme.primaryPink,
                      ),
                    ),
                    Text(
                      ' artists  •  ',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    Text(
                      _formatNumber(totalMinutes),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppleMusicTheme.primaryPurple,
                      ),
                    ),
                    Text(
                      ' minutes',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final Map<String, dynamic>? artist;
  final bool isDark;

  const _CalendarDayCell({
    required this.day,
    this.artist,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final artworkUrl = artist?['artworkUrlLow'] as String?;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: artist != null
            ? Colors.transparent
            : (isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Artist image
          if (artworkUrl != null && artworkUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: artworkUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ),
            ),

          // Day number overlay (when image is present)
          if (artworkUrl != null && artworkUrl.isNotEmpty)
            Positioned(
              top: 1,
              left: 2,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.8),
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CARD 3 — MILESTONES
// ═══════════════════════════════════════════════════════════════════════════════

class _MilestonesCard extends ConsumerStatefulWidget {
  const _MilestonesCard();

  @override
  ConsumerState<_MilestonesCard> createState() => _MilestonesCardState();
}

class _MilestonesCardState extends ConsumerState<_MilestonesCard> {
  bool _showPlays = true; // Toggle between Plays/Minutes view

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final milestonesData = ref.watch(monthlyMilestonesProvider);
    final earned = milestonesData.earned;
    final totalPlays = milestonesData.totalPlays;
    final nextThreshold = milestonesData.nextThreshold;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a1a),
                    const Color(0xFF252525),
                    const Color(0xFF1C1C1E),
                  ]
                : [
                    const Color(0xFFFFF8F0),
                    const Color(0xFFFFF3E6),
                    const Color(0xFFFFEDD5),
                  ],
          ),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // "You" badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person,
                            size: 14,
                            color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Plays / Minutes toggle
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggle('Plays', _showPlays, () {
                          setState(() => _showPlays = true);
                        }, isDark),
                        _buildToggle('Minutes', !_showPlays, () {
                          setState(() => _showPlays = false);
                        }, isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Next Milestone Progress
              if (nextThreshold != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'NEXT MILESTONE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          Text(
                            '${((totalPlays / nextThreshold) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppleMusicTheme.primaryPink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatNumber(totalPlays)} / ${_formatNumber(nextThreshold)} Plays',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppleMusicTheme.lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (totalPlays / nextThreshold).clamp(0.0, 1.0),
                          backgroundColor:
                              isDark ? Colors.white12 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation(
                              AppleMusicTheme.primaryPink),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Milestones label
              if (earned.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Your milestones so far:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),

              // Earned milestones list
              Expanded(
                child: earned.isEmpty
                    ? Center(
                        child: Text(
                          'Keep listening to earn milestones!',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: earned.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final m = earned[index];
                          return _MilestoneRow(milestone: m, isDark: isDark);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(
      String label, bool isActive, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppleMusicTheme.primaryPink : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final PlayCountMilestone milestone;
  final bool isDark;

  const _MilestoneRow({required this.milestone, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(milestone.achievedAt);
    final relativeTime = _formatRelativeTime(diff);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          // Milestone badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [milestone.primaryColor, milestone.secondaryColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: milestone.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                milestone.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatNumber(milestone.threshold)} Plays',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: milestone.primaryColor,
                  ),
                ),
                Text(
                  milestone.trackTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppleMusicTheme.lightText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        milestone.artist,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•  $relativeTime',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Track artwork
          if (milestone.artworkUrl != null && milestone.artworkUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: milestone.artworkUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(width: 40, height: 40, color: Colors.black12),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatNumber(int n) {
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K'
        .replaceAll('.0K', 'K');
  }
  return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

String _formatRelativeTime(Duration diff) {
  if (diff.inDays > 365) {
    final years = diff.inDays ~/ 365;
    return '${years}y ago';
  } else if (diff.inDays > 30) {
    final months = diff.inDays ~/ 30;
    final days = diff.inDays % 30;
    return '${months}mo ${days}d ago';
  } else if (diff.inDays > 0) {
    return '${diff.inDays}d ago';
  } else if (diff.inHours > 0) {
    return '${diff.inHours}h ago';
  } else {
    return 'Just now';
  }
}
