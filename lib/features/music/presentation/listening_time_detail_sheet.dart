import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stats_providers.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../music/data/music_models.dart';

enum HistoryPeriod { day, week, month, year, custom }

class ListeningTimeDetailSheet extends ConsumerStatefulWidget {
  const ListeningTimeDetailSheet({super.key});

  @override
  ConsumerState<ListeningTimeDetailSheet> createState() => _ListeningTimeDetailSheetState();
}

class _ListeningTimeDetailSheetState extends ConsumerState<ListeningTimeDetailSheet> {
  HistoryPeriod _selectedPeriod = HistoryPeriod.week;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    // Default custom range is last 7 days
    final now = DateTime.now();
    _customRange = DateTimeRange(
      start: DateUtils.dateOnly(now.subtract(const Duration(days: 7))),
      end: DateUtils.dateOnly(now),
    );
  }

  Future<void> _selectCustomRange() async {
    HapticFeedback.mediumImpact();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppleMusicTheme.primaryPink,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1C1C1E),
                    onSurface: Colors.white,
                    secondary: AppleMusicTheme.primaryPink,
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF1C1C1E),
                    iconTheme: IconThemeData(color: Colors.white),
                  ),
                  dialogBackgroundColor: const Color(0xFF1C1C1E),
                  datePickerTheme: DatePickerThemeData(
                    headerBackgroundColor: const Color(0xFF1C1C1E),
                    headerForegroundColor: Colors.white,
                    backgroundColor: const Color(0xFF1C1C1E),
                    rangeSelectionOverlayColor: WidgetStateProperty.all(
                      AppleMusicTheme.primaryPink.withValues(alpha: 0.15),
                    ),
                    rangeSelectionBackgroundColor: AppleMusicTheme.primaryPink.withValues(alpha: 0.15),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppleMusicTheme.primaryPink,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                    secondary: AppleMusicTheme.primaryPink,
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    iconTheme: IconThemeData(color: AppleMusicTheme.primaryPink),
                  ),
                  dialogBackgroundColor: Colors.white,
                  datePickerTheme: DatePickerThemeData(
                    headerBackgroundColor: Colors.white,
                    headerForegroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    rangeSelectionOverlayColor: WidgetStateProperty.all(
                      AppleMusicTheme.primaryPink.withValues(alpha: 0.12),
                    ),
                    rangeSelectionBackgroundColor: AppleMusicTheme.primaryPink.withValues(alpha: 0.12),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final history = ref.watch(allPlaybackProvider).value ?? [];
    final metaMap = ref.watch(trackMetadataMapProvider).value ?? {};

    // 1. Filter history based on selected period
    final now = DateTime.now();
    DateTime startCutoff;

    switch (_selectedPeriod) {
      case HistoryPeriod.day:
        startCutoff = now.subtract(const Duration(days: 1));
        break;
      case HistoryPeriod.week:
        startCutoff = now.subtract(const Duration(days: 7));
        break;
      case HistoryPeriod.month:
        startCutoff = now.subtract(const Duration(days: 30));
        break;
      case HistoryPeriod.year:
        startCutoff = now.subtract(const Duration(days: 365));
        break;
      case HistoryPeriod.custom:
        startCutoff = _customRange?.start ?? now.subtract(const Duration(days: 7));
        break;
    }

    final filteredHistory = history.where((h) {
      if (_selectedPeriod == HistoryPeriod.custom && _customRange != null) {
        // Between start and end of selected day (inclusive)
        final playedDate = DateTime.fromMillisecondsSinceEpoch(h.playedAt);
        // Include the entire end day up to 23:59:59
        final startMs = _customRange!.start.millisecondsSinceEpoch;
        final endMs = _customRange!.end.add(const Duration(days: 1)).millisecondsSinceEpoch - 1;
        return h.playedAt >= startMs && h.playedAt <= endMs;
      } else {
        return h.playedAt >= startCutoff.millisecondsSinceEpoch;
      }
    }).toList();

    // 2. Compute metrics
    final totalPlays = filteredHistory.length;
    
    final totalSeconds = filteredHistory.map((h) {
      if (h.duration != null && h.duration! > 0) return h.duration!;
      final metaTime = metaMap['${h.torrentId}-${h.fileId}'] ?? 0;
      return metaTime ~/ 1000;
    }).fold<int>(0, (a, b) => a + b);

    final hoursCount = totalSeconds ~/ 3600;
    final minutesCount = (totalSeconds % 3600) ~/ 60;
    final formattedTime = hoursCount > 0 ? '${hoursCount}h ${minutesCount}m' : '${minutesCount}m';

    final uniqueTracks = filteredHistory.map((h) => '${h.trackTitle}-${h.artist}').toSet().length;
    final uniqueArtists = filteredHistory.map((h) => h.artist).where((a) => a.isNotEmpty).toSet().length;

    // 3. Compute Top Tracks played in this period
    final Map<String, Map<String, dynamic>> trackCounts = {};
    for (final h in filteredHistory) {
      final key = '${h.trackTitle}|${h.artist}';
      if (!trackCounts.containsKey(key)) {
        trackCounts[key] = {
          'title': h.trackTitle,
          'artist': h.artist,
          'artworkUrlLow': h.artworkUrlLow,
          'count': 0,
        };
      }
      trackCounts[key]!['count'] = (trackCounts[key]!['count'] as int) + 1;
    }
    final topTracks = trackCounts.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    final displayTopTracks = topTracks.take(3).toList();

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
              // Pull Bar indicator
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
                  const Text(
                    'Listening History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Segmented selector for period
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildPeriodTab(HistoryPeriod.day, '1D'),
                    _buildPeriodTab(HistoryPeriod.week, '1W'),
                    _buildPeriodTab(HistoryPeriod.month, '1M'),
                    _buildPeriodTab(HistoryPeriod.year, '1Y'),
                    _buildPeriodTab(HistoryPeriod.custom, 'Custom'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Custom range picker button
              if (_selectedPeriod == HistoryPeriod.custom && _customRange != null) ...[
                GestureDetector(
                  onTap: _selectCustomRange,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderRadius: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month, color: AppleMusicTheme.primaryPink, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatDate(_customRange!.start)} - ${_formatDate(_customRange!.end)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Metrics Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _buildSubStatCard(
                    isDark: isDark,
                    icon: Icons.headphones_outlined,
                    label: 'Total Plays',
                    value: totalPlays.toString(),
                    subValue: 'Tracks played',
                  ),
                  _buildSubStatCard(
                    isDark: isDark,
                    icon: Icons.access_time_rounded,
                    label: 'Listening Time',
                    value: formattedTime,
                    subValue: '${(totalSeconds / 3600).toStringAsFixed(1)} hours',
                  ),
                  _buildSubStatCard(
                    isDark: isDark,
                    icon: Icons.music_note_outlined,
                    label: 'Unique Tracks',
                    value: uniqueTracks.toString(),
                    subValue: 'Individual songs',
                  ),
                  _buildSubStatCard(
                    isDark: isDark,
                    icon: Icons.person_outline_rounded,
                    label: 'Unique Artists',
                    value: uniqueArtists.toString(),
                    subValue: 'Artists explored',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Top Tracks for this period
              if (displayTopTracks.isNotEmpty) ...[
                const Text(
                  'Top Tracks in Period',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...displayTopTracks.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final track = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        Text(
                          '$idx',
                          style: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: track['artworkUrlLow'] != null
                              ? CachedNetworkImage(
                                  imageUrl: track['artworkUrlLow'] as String,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.black12),
                                  errorWidget: (_, __, ___) => Container(color: Colors.black12),
                                )
                              : Container(
                                  width: 38,
                                  height: 38,
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  child: const Icon(Icons.music_note, size: 18),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                track['artist'] as String,
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppleMusicTheme.primaryPink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${track['count']} plays',
                            style: const TextStyle(
                              color: AppleMusicTheme.primaryPink,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No playback activity recorded in this period.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodTab(HistoryPeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedPeriod = period;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppleMusicTheme.primaryPink
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubStatCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppleMusicTheme.primaryPink),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 1),
          Text(
            subValue,
            style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
