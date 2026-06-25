import 'dart:io' as io;
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/audiobook_repository.dart';
import '../data/audiobook_models.dart';
import 'audiobook_providers.dart'; // to read audiobookRepositoryProvider
import '../../music/presentation/music_providers.dart'; // to read settingsProvider
import '../../../core/database/database.dart';

/// User-configurable listening goals.
class ListeningGoals {
  final int dailyMinutes;
  final int weeklyMinutes;
  const ListeningGoals({this.dailyMinutes = 0, this.weeklyMinutes = 0});

  ListeningGoals copyWith({int? dailyMinutes, int? weeklyMinutes}) => ListeningGoals(
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
  );
}

final listeningGoalsProvider = FutureProvider<ListeningGoals>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return ListeningGoals(
    dailyMinutes: prefs.getInt('goal_daily_min') ?? 0,
    weeklyMinutes: prefs.getInt('goal_weekly_min') ?? 0,
  );
});

Future<void> setListeningGoals(WidgetRef ref, {int? dailyMinutes, int? weeklyMinutes}) async {
  final prefs = await SharedPreferences.getInstance();
  if (dailyMinutes != null) await prefs.setInt('goal_daily_min', dailyMinutes);
  if (weeklyMinutes != null) await prefs.setInt('goal_weekly_min', weeklyMinutes);
  ref.invalidate(listeningGoalsProvider);
}

/// Reset all audiobook listening statistics: progress, metadata cache, goals, dismissed books.
Future<void> resetAllAudiobookStats(WidgetRef ref) async {
  final repo = ref.read(audiobookRepositoryProvider);
  await repo.clearAllAudiobookData();
  ref.invalidate(audiobookHistoryProvider);
  ref.invalidate(audiobookStatsSummaryProvider);
  ref.invalidate(topAudiobooksProvider);
  ref.invalidate(audiobookListeningHabitsProvider);
  ref.invalidate(audiobookGenreBreakdownProvider);
  ref.invalidate(listeningGoalsProvider);
  ref.invalidate(inProgressAudiobooksProvider);
}

final audiobookHistoryProvider = FutureProvider<List<DbAudiobookProgress>>((ref) async {
  try {
    final repo = ref.read(audiobookRepositoryProvider);
    return await repo.getAllInProgressBooks();
  } catch (e) {
    print('[audiobookHistoryProvider] Error: $e');
    return [];
  }
});

/// Detailed audiobook statistics summary.
final audiobookStatsSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final history = await ref.watch(audiobookHistoryProvider.future);
    final repo = ref.read(audiobookRepositoryProvider);

    // Normalize bookIds and deduplicate by (normalizedId, chapterIndex)
    final Map<String, Set<int>> seenChapters = {};
    final List<({String bookId, int chapterIndex, int positionMillis, int durationMillis, bool isCompleted, DateTime lastListenedAt})> deduped = [];

    for (final p in history) {
      final normId = AudiobookRepository.normalizeBookId(p.bookId);
      if (!seenChapters.containsKey(normId)) {
        seenChapters[normId] = {};
      }
      if (seenChapters[normId]!.add(p.chapterIndex)) {
        deduped.add((
          bookId: normId,
          chapterIndex: p.chapterIndex,
          positionMillis: p.positionMillis,
          durationMillis: p.durationMillis,
          isCompleted: p.isCompleted,
          lastListenedAt: p.lastListenedAt,
        ));
      }
    }

    final totalPlays = deduped.length;
    final uniqueBooks = deduped.map((h) => h.bookId).toSet();
    final totalBooksCount = uniqueBooks.length;

    // Calculate total listening time using max absolute position per book
    int totalSeconds = 0;
    final Map<String, int> bookMaxPosition = {};
    for (final p in deduped) {
      final currentMax = bookMaxPosition[p.bookId] ?? 0;
      if (p.positionMillis > currentMax) {
        bookMaxPosition[p.bookId] = p.positionMillis;
      }
    }
    for (final entry in bookMaxPosition.entries) {
      totalSeconds += entry.value ~/ 1000;
    }

    final hoursCount = totalSeconds ~/ 3600;
    final minutesCount = (totalSeconds % 3600) ~/ 60;
    final formattedTime = hoursCount > 0 ? '${hoursCount}h ${minutesCount}m' : '${minutesCount}m';

    // Calculate completed books count — only count books where ALL chapters are isCompleted
    int completedBooksCount = 0;
    for (final bookId in uniqueBooks) {
      final bookProgressList = deduped.where((h) => h.bookId == bookId).toList();
      if (bookProgressList.isEmpty) continue;
      if (bookProgressList.every((p) => p.isCompleted)) {
        completedBooksCount++;
      }
    }

    // Calculate consecutive days streak
    int streak = 0;
    if (deduped.isNotEmpty) {
      final dates = deduped.map((h) {
        final d = h.lastListenedAt;
        return DateTime(d.year, d.month, d.day);
      }).toSet().toList();
      dates.sort((a, b) => b.compareTo(a));

      final today = DateTime.now();
      final todayNoTime = DateTime(today.year, today.month, today.day);
      
      if (dates.isNotEmpty && (dates.first == todayNoTime || dates.first == todayNoTime.subtract(const Duration(days: 1)))) {
        streak = 1;
        for (int i = 0; i < dates.length - 1; i++) {
          if (dates[i].difference(dates[i+1]).inDays == 1) {
            streak++;
          } else {
            break;
          }
        }
      }
    }

    // Calculate listening time for today and this week
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Group all raw history by (normalizedBookId, chapterIndex) to compute position deltas
    final Map<String, List<DbAudiobookProgress>> chapterGroups = {};
    for (final p in history) {
      final normId = AudiobookRepository.normalizeBookId(p.bookId);
      final key = '$normId:${p.chapterIndex}';
      chapterGroups.putIfAbsent(key, () => []).add(p);
    }

    int todaySec = 0;
    int weekSec = 0;
    for (final group in chapterGroups.values) {
      group.sort((a, b) => a.lastListenedAt.compareTo(b.lastListenedAt));
      todaySec += _deltaForPeriod(group, todayStart);
      weekSec += _deltaForPeriod(group, mondayStart);
    }

    return {
      'totalListeningTime': formattedTime,
      'hours': hoursCount + (minutesCount / 60),
      'totalBooks': totalBooksCount,
      'completedBooks': completedBooksCount,
      'totalChapters': totalPlays,
      'streak': streak,
      'bookSeconds': bookMaxPosition,
      'todaySeconds': todaySec,
      'thisWeekSeconds': weekSec,
    };
  } catch (e, stack) {
    print('[audiobookStatsSummaryProvider] Error: $e\n$stack');
    return {
      'totalListeningTime': '0m', 'hours': 0.0, 'totalBooks': 0, 'completedBooks': 0,
      'totalChapters': 0, 'streak': 0, 'bookSeconds': <String, int>{},
      'todaySeconds': 0, 'thisWeekSeconds': 0,
    };
  }
});

int _deltaForPeriod(List<DbAudiobookProgress> sortedAsc, DateTime periodStart) {
  if (sortedAsc.isEmpty) return 0;
  final firstInPeriod = sortedAsc.indexWhere((e) => !e.lastListenedAt.isBefore(periodStart));
  if (firstInPeriod == -1) return 0;
  final startPos = firstInPeriod > 0 ? sortedAsc[firstInPeriod - 1].positionMillis : 0;
  final endPos = sortedAsc.last.positionMillis;
  return (endPos - startPos) ~/ 1000;
}

/// Top listened audiobooks.
final topAudiobooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final history = await ref.watch(audiobookHistoryProvider.future);
    final repo = ref.read(audiobookRepositoryProvider);
    final summary = await ref.watch(audiobookStatsSummaryProvider.future);
    final bookSeconds = summary['bookSeconds'] as Map<String, int>? ?? {};

    final List<Map<String, dynamic>> topBooks = [];
    for (final entry in bookSeconds.entries) {
      final bookId = entry.key;
      final cached = await repo.getCachedMetadata(bookId);
      if (cached != null) {
        final seconds = entry.value ~/ 1000;
        final hours = seconds / 3600;
        topBooks.add({
          'bookId': bookId,
          'title': cached.title,
          'author': cached.author ?? 'Unknown Author',
          'artworkUrl': cached.artworkUrl,
          'hours': hours,
          'formattedTime': hours >= 1.0 ? '${hours.toStringAsFixed(1)}h' : '${(seconds ~/ 60)}m',
          'seconds': seconds,
        });
      }
    }

    topBooks.sort((a, b) => (b['seconds'] as int).compareTo(a['seconds'] as int));
    return topBooks.take(5).toList();
  } catch (e) {
    print('[topAudiobooksProvider] Error: $e');
    return [];
  }
});

/// Listening habits for audiobooks (By day of week / hours of day).
final audiobookListeningHabitsProvider = Provider<Map<String, dynamic>>((ref) {
  try {
    final history = ref.watch(audiobookHistoryProvider).value ?? [];
    
    // Normalize bookIds and deduplicate by (bookId, chapterIndex)
    final Set<String> seenKeys = {};
    final List<DbAudiobookProgress> deduped = [];
    for (final h in history) {
      final normId = AudiobookRepository.normalizeBookId(h.bookId);
      final key = '$normId:${h.chapterIndex}';
      if (seenKeys.add(key)) {
        deduped.add(h);
      }
    }

    final Map<int, int> hourCounts = {for (int i = 0; i < 24; i++) i: 0};
    final Map<int, int> weekdayCounts = {for (int i = 1; i <= 7; i++) i: 0};

    for (final h in deduped) {
      final d = h.lastListenedAt;
      hourCounts[d.hour] = hourCounts[d.hour]! + 1;
      weekdayCounts[d.weekday] = weekdayCounts[d.weekday]! + 1;
    }

    return {
      'hours': hourCounts,
      'weekdays': weekdayCounts,
    };
  } catch (e) {
    print('[audiobookListeningHabitsProvider] Error: $e');
    return {
      'hours': {for (int i = 0; i < 24; i++) i: 0},
      'weekdays': {for (int i = 1; i <= 7; i++) i: 0},
    };
  }
});

/// Genre breakdown for audiobooks.
final audiobookGenreBreakdownProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final history = await ref.watch(audiobookHistoryProvider.future);
    final repo = ref.read(audiobookRepositoryProvider);

    final uniqueBooks = history.map((h) => AudiobookRepository.normalizeBookId(h.bookId)).toSet();
    final List<String> genres = [];
    
    for (final bookId in uniqueBooks) {
      final cached = await repo.getCachedMetadata(bookId);
      if (cached != null && cached.genre != null && cached.genre!.isNotEmpty) {
        final bookGenres = cached.genre!.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty);
        genres.addAll(bookGenres);
      }
    }

    if (genres.isEmpty) return [];

    final Map<String, int> counts = {};
    for (final g in genres) {
      counts[g] = (counts[g] ?? 0) + 1;
    }

    final totalCount = genres.length;
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) {
      return {
        'genre': e.key,
        'count': e.value,
        'percentage': (e.value / totalCount) * 100,
      };
    }).toList();
  } catch (e) {
    print('[audiobookGenreBreakdownProvider] Error: $e');
    return [];
  }
});

/// Top authors ranked by total chapters played.
final audiobookAuthorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final history = await ref.watch(audiobookHistoryProvider.future);
    final repo = ref.read(audiobookRepositoryProvider);

    // Deduplicate by (bookId, chapterIndex)
    final Set<String> seen = {};
    final List<String> uniqueBookIds = [];
    for (final h in history) {
      final normId = AudiobookRepository.normalizeBookId(h.bookId);
      if (seen.add(normId)) {
        uniqueBookIds.add(normId);
      }
    }

    final Map<String, int> authorChapterCount = {};
    final Map<String, String> authorNames = {};

    for (final bookId in uniqueBookIds) {
      final cached = await repo.getCachedMetadata(bookId);
      if (cached != null && cached.author != null && cached.author!.isNotEmpty) {
        final author = cached.author!;
        authorNames[author] = author;
        final chapterCount = (await repo.getBookChapterProgress(bookId)).length;
        authorChapterCount[author] = (authorChapterCount[author] ?? 0) + chapterCount;
      }
    }

    final sorted = authorChapterCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sorted.isNotEmpty ? sorted.first.value : 1;
    return sorted.take(10).map((e) {
      return {
        'author': e.key,
        'count': e.value,
        'percent': e.value / maxCount,
      };
    }).toList();
  } catch (e) {
    print('[audiobookAuthorsProvider] Error: $e');
    return [];
  }
});

/// Total download size of audiobooks in GB.
final audiobookSizeProvider = FutureProvider<double>((ref) async {
  try {
    final repo = ref.read(audiobookRepositoryProvider);
    final history = await ref.watch(audiobookHistoryProvider.future);

    final uniqueBookIds = history.map((h) => AudiobookRepository.normalizeBookId(h.bookId)).toSet();
    double totalBytes = 0;

    for (final bookId in uniqueBookIds) {
      try {
        final localDir = await repo.getLocalBookDirectoryForBackup(bookId);
        if (localDir != null) {
          final dir = io.Directory(localDir);
          if (await dir.exists()) {
            await for (final entity in dir.list(recursive: true)) {
              if (entity is io.File) {
                totalBytes += await entity.length();
              }
            }
          }
        }
      } catch (_) {}
    }

    return totalBytes / (1024 * 1024 * 1024);
  } catch (e) {
    print('[audiobookSizeProvider] Error: $e');
    return 0.0;
  }
});

class _CalendarMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime(DateTime.now().year, DateTime.now().month, 1);
  void previousMonth() => state = DateTime(state.year, state.month - 1, 1);
  void nextMonth() => state = DateTime(state.year, state.month + 1, 1);
}

final calendarMonthProvider = NotifierProvider<_CalendarMonthNotifier, DateTime>(_CalendarMonthNotifier.new);

final monthListeningDataProvider = FutureProvider.family<Map<int, Map<String, dynamic>>, DateTime>((ref, monthFirst) async {
  try {
    final history = await ref.watch(audiobookHistoryProvider.future);
    final repo = ref.read(audiobookRepositoryProvider);

    final monthStart = DateTime(monthFirst.year, monthFirst.month, 1);
    final monthEnd = DateTime(monthFirst.year, monthFirst.month + 1, 1);

    // Group all entries by (normalizedBookId, chapterIndex) for delta calculation
    final Map<String, List<DbAudiobookProgress>> chapterGroups = {};
    for (final p in history) {
      final normId = AudiobookRepository.normalizeBookId(p.bookId);
      final key = '$normId:${p.chapterIndex}';
      chapterGroups.putIfAbsent(key, () => []).add(p);
    }

    // Per-day accumulators
    final Map<int, int> dayListeningSec = {};
    final Map<int, Set<String>> dayBookIds = {};
    final Map<int, Set<int>> dayChapterCounts = {};
    final Map<int, Set<String>> dayBookTitles = {};
    final Map<String, String> bookTitleCache = {};

    // Compute deltas per chapter group
    for (final group in chapterGroups.values) {
      group.sort((a, b) => a.lastListenedAt.compareTo(b.lastListenedAt));
      int previousPos = 0;

      for (final p in group) {
        final delta = p.positionMillis - previousPos;
        previousPos = p.positionMillis;

        final listenedAt = p.lastListenedAt;
        if (listenedAt.isBefore(monthStart) || !listenedAt.isBefore(monthEnd)) continue;

        final day = listenedAt.day;
        dayListeningSec[day] = (dayListeningSec[day] ?? 0) + (delta ~/ 1000);

        final normId = AudiobookRepository.normalizeBookId(p.bookId);
        dayBookIds.putIfAbsent(day, () => {}).add(normId);
        dayChapterCounts.putIfAbsent(day, () => {}).add(p.chapterIndex);

        dayBookTitles.putIfAbsent(day, () => {});
        if (bookTitleCache.containsKey(normId)) {
          dayBookTitles[day]!.add(bookTitleCache[normId]!);
        } else {
          final cached = await repo.getCachedMetadata(normId);
          final title = cached?.title ?? 'Unknown';
          bookTitleCache[normId] = title;
          dayBookTitles[day]!.add(title);
        }
      }
    }

    // Build result map
    final dayData = <int, Map<String, dynamic>>{};
    for (final day in dayBookIds.keys) {
      final sec = dayListeningSec[day] ?? 0;
      dayData[day] = {
        'seconds': sec,
        'hours': sec / 3600,
        'formattedTime': sec >= 3600
            ? '${(sec / 3600).toStringAsFixed(1)}h'
            : '${(sec ~/ 60)}m',
        'booksCount': dayBookIds[day]?.length ?? 0,
        'chaptersCount': dayChapterCounts[day]?.length ?? 0,
        'bookTitles': dayBookTitles[day]?.toList() ?? [],
      };
    }

    return dayData;
  } catch (e) {
    print('[monthListeningDataProvider] Error: $e');
    return {};
  }
});

/// Longest audiobooks by total duration (hrs).
final audiobookLongestItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final history = await ref.watch(audiobookHistoryProvider.future);
    final repo = ref.read(audiobookRepositoryProvider);

    // Deduplicate book IDs
    final seen = <String>{};
    final List<String> uniqueBookIds = [];
    for (final h in history) {
      final normId = AudiobookRepository.normalizeBookId(h.bookId);
      if (seen.add(normId)) {
        uniqueBookIds.add(normId);
      }
    }

    final List<Map<String, dynamic>> items = [];
    for (final bookId in uniqueBookIds) {
      final cached = await repo.getCachedMetadata(bookId);
      final summary = await repo.getBookProgressSummary(bookId);
      final totalDurationMs = summary?['totalDurationMillis'] as int? ?? 0;
      final hours = totalDurationMs / 3600000.0;

      if (hours > 0) {
        items.add({
          'bookId': bookId,
          'title': cached?.title ?? 'Unknown',
          'author': cached?.author ?? 'Unknown Author',
          'hours': hours,
        });
      }
    }

    items.sort((a, b) => (b['hours'] as double).compareTo(a['hours'] as double));
    return items.take(10).toList();
  } catch (e) {
    print('[audiobookLongestItemsProvider] Error: $e');
    return [];
  }
});
