import 'dart:io' as io;
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/audiobook_repository.dart';
import '../data/audiobook_models.dart';
import 'audiobook_providers.dart'; // to read audiobookRepositoryProvider
import '../../music/presentation/music_providers.dart'; // to read settingsProvider
import '../../../core/database/database.dart';

final audiobookHistoryProvider = FutureProvider<List<DbAudiobookProgress>>((ref) async {
  final repo = ref.watch(audiobookRepositoryProvider);
  return repo.getAllInProgressBooks();
});

/// Detailed audiobook statistics summary.
final audiobookStatsSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final history = await ref.watch(audiobookHistoryProvider.future);
  final repo = ref.watch(audiobookRepositoryProvider);

  final totalPlays = history.length; // Number of chapters started/finished
  final uniqueBooks = history.map((h) => h.bookId).toSet();
  final totalBooksCount = uniqueBooks.length;

  // Calculate total listening time in seconds
  int totalSeconds = 0;
  final Map<String, int> bookSeconds = {};
  
  for (final p in history) {
    int durationSecs = 0;
    if (p.isCompleted) {
      durationSecs = p.durationMillis ~/ 1000;
    } else {
      durationSecs = p.positionMillis ~/ 1000;
    }
    // Prevent zero duration messing up stats if durationMillis wasn't recorded
    if (durationSecs <= 0 && p.isCompleted) {
      durationSecs = 1800; // default 30 mins estimate if completed but metadata is missing
    }
    
    totalSeconds += durationSecs;
    bookSeconds[p.bookId] = (bookSeconds[p.bookId] ?? 0) + durationSecs;
  }

  final hoursCount = totalSeconds ~/ 3600;
  final minutesCount = (totalSeconds % 3600) ~/ 60;
  final formattedTime = hoursCount > 0 ? '${hoursCount}h ${minutesCount}m' : '${minutesCount}m';

  // Calculate completed books count
  int completedBooksCount = 0;
  for (final bookId in uniqueBooks) {
    final cached = await repo.getCachedMetadata(bookId);
    final bookProgressList = history.where((h) => h.bookId == bookId).toList();
    
    // If we have no cached metadata, we cannot confidently declare it completed.
    if (cached == null || cached.totalChapters <= 0) {
      continue;
    }

    final totalCh = cached.totalChapters;
    double progressPercent = 0.0;
    
    if (totalCh > 0) {
      double totalProgressValue = 0.0;
      for (final p in bookProgressList) {
        double chProgressRatio = 0.0;
        if (p.isCompleted) {
          chProgressRatio = 1.0;
        } else if (p.durationMillis > 0) {
          if (bookProgressList.length == 1 && p.durationMillis > 3600000) {
            chProgressRatio = (p.positionMillis / p.durationMillis).clamp(0.0, 1.0);
            totalProgressValue = chProgressRatio * totalCh;
            break;
          } else {
            chProgressRatio = (p.positionMillis / p.durationMillis).clamp(0.0, 1.0);
          }
        }
        totalProgressValue += chProgressRatio;
      }
      progressPercent = (totalCh == 1)
          ? (totalProgressValue).clamp(0.0, 1.0)
          : (totalProgressValue / totalCh).clamp(0.0, 1.0);
    }
    
    if (progressPercent >= 0.99) {
      completedBooksCount++;
    }
  }

  // Calculate consecutive days streak
  int streak = 0;
  if (history.isNotEmpty) {
    final dates = history.map((h) {
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

  return {
    'totalListeningTime': formattedTime,
    'hours': hoursCount + (minutesCount / 60),
    'totalBooks': totalBooksCount,
    'completedBooks': completedBooksCount,
    'totalChapters': totalPlays,
    'streak': streak,
    'bookSeconds': bookSeconds,
  };
});

/// Top listened audiobooks.
final topAudiobooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final history = await ref.watch(audiobookHistoryProvider.future);
  final repo = ref.watch(audiobookRepositoryProvider);
  final summary = await ref.watch(audiobookStatsSummaryProvider.future);
  final bookSeconds = summary['bookSeconds'] as Map<String, int>? ?? {};

  final List<Map<String, dynamic>> topBooks = [];
  for (final entry in bookSeconds.entries) {
    final bookId = entry.key;
    final cached = await repo.getCachedMetadata(bookId);
    if (cached != null) {
      final hours = entry.value / 3600;
      topBooks.add({
        'bookId': bookId,
        'title': cached.title,
        'author': cached.author ?? 'Unknown Author',
        'artworkUrl': cached.artworkUrl,
        'hours': hours,
        'formattedTime': hours >= 1.0 ? '${hours.toStringAsFixed(1)}h' : '${(entry.value ~/ 60)}m',
        'seconds': entry.value,
      });
    }
  }

  topBooks.sort((a, b) => (b['seconds'] as int).compareTo(a['seconds'] as int));
  return topBooks.take(5).toList();
});

/// Listening habits for audiobooks (By day of week / hours of day).
final audiobookListeningHabitsProvider = Provider<Map<String, dynamic>>((ref) {
  final history = ref.watch(audiobookHistoryProvider).value ?? [];
  
  final Map<int, int> hourCounts = {for (int i = 0; i < 24; i++) i: 0};
  final Map<int, int> weekdayCounts = {for (int i = 1; i <= 7; i++) i: 0};

  for (final h in history) {
    final d = h.lastListenedAt;
    hourCounts[d.hour] = hourCounts[d.hour]! + 1;
    weekdayCounts[d.weekday] = weekdayCounts[d.weekday]! + 1;
  }

  return {
    'hours': hourCounts,
    'weekdays': weekdayCounts,
  };
});

/// Genre breakdown for audiobooks.
final audiobookGenreBreakdownProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final history = await ref.watch(audiobookHistoryProvider.future);
  final repo = ref.watch(audiobookRepositoryProvider);
  
  final uniqueBooks = history.map((h) => h.bookId).toSet();
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
});
