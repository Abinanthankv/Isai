import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database.dart';
import '../../../core/di/injection.dart';

/// Stream of ALL playback history which triggers updates real-time.
final allPlaybackProvider = StreamProvider<List<DbPlaybackHistory>>((ref) {
  return getIt<AppDatabase>().watchAllPlayback();
});

/// Load Track metadata to backfill duration for older history entries
final trackMetadataMapProvider = FutureProvider<Map<String, int>>((ref) async {
  final meta = await getIt<AppDatabase>().getAllMetadata();
  return {for (final m in meta) '${m.torrentId}-${m.fileId}': m.trackTimeMillis ?? 0};
});

/// Basic aggregated metrics (Plays, Duration, Unique)
final statsSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final metaMap = ref.watch(trackMetadataMapProvider).value ?? {};
  
  final totalPlays = history.length;
  
  final totalSeconds = history.map((h) {
    if (h.duration != null && h.duration! > 0) return h.duration!;
    final metaTime = metaMap['${h.torrentId}-${h.fileId}'] ?? 0;
    return metaTime ~/ 1000;
  }).fold<int>(0, (a, b) => a + b);
  final hoursCount = totalSeconds ~/ 3600;
  final minutesCount = (totalSeconds % 3600) ~/ 60;
  final formattedTime = hoursCount > 0 ? '${hoursCount}h ${minutesCount}m' : '${minutesCount}m';

  final uniqueTracks = history.map((h) => '${h.trackTitle}-${h.artist}').toSet().length;
  final uniqueAlbums = history.map((h) => h.album).where((a) => a.isNotEmpty).toSet().length;

  int streak = 0;
  if (history.isNotEmpty) {
     final dates = history.map((h) {
       final d = DateTime.fromMillisecondsSinceEpoch(h.playedAt);
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
    'totalPlays': totalPlays,
    'listeningTime': formattedTime,
    'hours': hoursCount + (minutesCount / 60),
    'uniqueTracks': uniqueTracks,
    'uniqueAlbums': uniqueAlbums,
    'streak': streak,
  };
});

/// Count aggregates grouping. Generic list mapping creator helper.
List<Map<String, dynamic>> _getTopAggregates(List<String> items, {int limit = 5}) {
  final Map<String, int> counts = {};
  for (final item in items) {
    counts[item] = (counts[item] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(limit).map((e) => {'name': e.key, 'count': e.value}).toList();
}

List<String> _splitArtists(String artist) {
  return artist
      .split(RegExp(r'\s*(?:feat\.?|ft\.?|featuring|vs\.?)\s+', caseSensitive: false))
      .expand((p) => p.split(RegExp(r'\s*[,&]\s*')))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s.length > 1)
      .toList();
}

final topArtistsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final artists = history
      .map((h) => h.artist)
      .where((a) => a.isNotEmpty)
      .expand(_splitArtists)
      .toList();
  return _getTopAggregates(artists);
});

final topTracksProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final Map<String, Map<String, dynamic>> tracks = {};
  
  for (final h in history) {
    final key = '${h.trackTitle}|${h.artist}';
    if (!tracks.containsKey(key)) {
      tracks[key] = {
        'title': h.trackTitle,
        'artist': h.artist,
        'artworkUrlLow': h.artworkUrlLow,
        'artworkUrlHigh': h.artworkUrlHigh,
        'count': 0,
      };
    }
    tracks[key]!['count'] = (tracks[key]!['count'] as int) + 1;
  }

  final sorted = tracks.values.toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return sorted.take(5).toList();
});

final topAlbumsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final Map<String, Map<String, dynamic>> albums = {};

  for (final h in history) {
    final key = '${h.album}|${h.artist}';
    if (h.album.isEmpty) continue;
    if (!albums.containsKey(key)) {
      albums[key] = {
        'album': h.album,
        'artist': h.artist,
        'artworkUrlLow': h.artworkUrlLow,
        'artworkUrlHigh': h.artworkUrlHigh,
        'count': 0,
      };
    }
    albums[key]!['count'] = (albums[key]!['count'] as int) + 1;
  }

  final sorted = albums.values.toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return sorted.take(5).toList();
});

final listeningHabitsProvider = Provider<Map<String, dynamic>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  
  final Map<int, int> hourCounts = {for (int i = 0; i < 24; i++) i: 0};
  final Map<int, int> weekdayCounts = {for (int i = 1; i <= 7; i++) i: 0};

  for (final h in history) {
    final d = DateTime.fromMillisecondsSinceEpoch(h.playedAt);
    hourCounts[d.hour] = hourCounts[d.hour]! + 1;
    weekdayCounts[d.weekday] = weekdayCounts[d.weekday]! + 1;
  }

  return {
    'hours': hourCounts,
    'weekdays': weekdayCounts,
  };
});

final genreBreakdownProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final genres = history.map((h) => h.genre).where((g) => g.isNotEmpty).toList();
  
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

// ─── Milestone Definitions ────────────────────────────────────────────────────

class StreakMilestone {
  final int days;
  final String emoji;
  final String title;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;

  const StreakMilestone({
    required this.days,
    required this.emoji,
    required this.title,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

const List<StreakMilestone> kStreakMilestones = [
  StreakMilestone(days: 3,   emoji: '🔥', title: 'Getting Warm',       description: '3 days in a row — you\'re on fire!',               primaryColor: Color(0xFFff6b35), secondaryColor: Color(0xFFf7c59f)),
  StreakMilestone(days: 7,   emoji: '🎵', title: 'Weekly Listener',    description: 'A full week of daily listening.',                   primaryColor: Color(0xFF4facfe), secondaryColor: Color(0xFF00f2fe)),
  StreakMilestone(days: 14,  emoji: '⭐', title: 'Two-Week Streak',    description: 'Music is becoming your daily ritual.',              primaryColor: Color(0xFFf6d365), secondaryColor: Color(0xFFfda085)),
  StreakMilestone(days: 30,  emoji: '💜', title: 'Monthly Devotee',    description: 'An entire month without missing a day!',            primaryColor: Color(0xFFa18cd1), secondaryColor: Color(0xFFfbc2eb)),
  StreakMilestone(days: 60,  emoji: '🏆', title: 'Consistent Fan',     description: 'Two months of unbroken dedication.',               primaryColor: Color(0xFF43e97b), secondaryColor: Color(0xFF38f9d7)),
  StreakMilestone(days: 100, emoji: '👑', title: 'Legendary Listener', description: '100 days of pure music bliss. You\'re a legend.', primaryColor: Color(0xFFf093fb), secondaryColor: Color(0xFFf5576c)),
];

/// All milestones earned based on current streak.
final earnedMilestonesProvider = Provider<List<StreakMilestone>>((ref) {
  final summary = ref.watch(statsSummaryProvider);
  final streak = summary['streak'] as int? ?? 0;
  return kStreakMilestones.where((m) => streak >= m.days).toList();
});

/// The next milestone the user is working toward.
final nextMilestoneProvider = Provider<StreakMilestone?>((ref) {
  final summary = ref.watch(statsSummaryProvider);
  final streak = summary['streak'] as int? ?? 0;
  try {
    return kStreakMilestones.firstWhere((m) => m.days > streak);
  } catch (_) {
    return null;
  }
});

/// Persists which milestones have been shown in the celebration overlay.
class MilestoneCelebrationNotifier extends Notifier<Set<int>> {
  static const _key = 'celebrated_milestone_days';

  @override
  Set<int> build() {
    final prefs = getIt<SharedPreferences>();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((s) => int.tryParse(s) ?? 0).toSet();
  }

  Future<void> markAsCelebrated(int days) async {
    final prefs = getIt<SharedPreferences>();
    final newSet = {...state, days};
    state = newSet;
    await prefs.setStringList(_key, newSet.map((d) => d.toString()).toList());
  }
}

final milestoneCelebrationProvider = NotifierProvider<MilestoneCelebrationNotifier, Set<int>>(
  MilestoneCelebrationNotifier.new,
);

/// Milestones earned but NOT yet shown in celebration overlay.
final newMilestonesProvider = Provider<List<StreakMilestone>>((ref) {
  final earned = ref.watch(earnedMilestonesProvider);
  final celebrated = ref.watch(milestoneCelebrationProvider);
  return earned.where((m) => !celebrated.contains(m.days)).toList();
});

// ─── Music Personality ────────────────────────────────────────────────────────

class MusicPersonality {
  final String emoji;
  final String title;
  final String timeEmoji;
  final String timeTitle;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;

  const MusicPersonality({
    required this.emoji,
    required this.title,
    required this.timeEmoji,
    required this.timeTitle,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
  });

  String get fullTitle => '$timeEmoji $title';
}

final musicPersonalityProvider = Provider<MusicPersonality?>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  if (history.isEmpty) return null;

  final habits = ref.watch(listeningHabitsProvider);

  // ── Genre analysis ──
  final genres = history.map((h) => h.genre.toLowerCase()).where((g) => g.isNotEmpty).toList();

  String genreTitle = 'Genre Explorer';
  String genreEmoji = '🎧';
  Color primary = const Color(0xFF667eea);
  Color secondary = const Color(0xFF764ba2);
  String description = 'You have eclectic taste spanning all genres.';

  if (genres.isNotEmpty) {
    final Map<String, int> buckets = {};
    for (final g in genres) {
      String bucket = 'Other';
      if (g.contains('pop') || g.contains('k-pop') || g.contains('j-pop'))                       bucket = 'Pop';
      else if (g.contains('hip') || g.contains('rap') || g.contains('urban'))                     bucket = 'Hip-Hop';
      else if (g.contains('rock') || g.contains('metal') || g.contains('punk') || g.contains('alternative') || g.contains('grunge')) bucket = 'Rock';
      else if (g.contains('electronic') || g.contains('dance') || g.contains('edm') || g.contains('house') || g.contains('techno')) bucket = 'Electronic';
      else if (g.contains('classical') || g.contains('jazz') || g.contains('blues') || g.contains('orchestral')) bucket = 'Classical';
      else if (g.contains('r&b') || g.contains('soul') || g.contains('funk'))                     bucket = 'R&B';
      else if (g.contains('film') || g.contains('score') || g.contains('soundtrack') || g.contains('cinematic')) bucket = 'Soundtrack';
      else if (g.contains('bollywood') || g.contains('hindi') || g.contains('tamil') || g.contains('telugu') || g.contains('indian')) bucket = 'Indian';
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }

    final meaningful = buckets.entries.where((e) => e.key != 'Other').toList();
    if (meaningful.isNotEmpty) {
      final top = meaningful.reduce((a, b) => a.value >= b.value ? a : b);
      final pct = top.value / genres.length;
      if (pct >= 0.30) {
        switch (top.key) {
          case 'Pop':         genreTitle = 'Pop Pioneer';     genreEmoji = '🌟'; primary = const Color(0xFFf093fb); secondary = const Color(0xFFf5576c); description = 'Always ahead of the pop curve.';
          case 'Hip-Hop':     genreTitle = 'Hip-Hop Head';    genreEmoji = '🎤'; primary = const Color(0xFF4facfe); secondary = const Color(0xFF00f2fe); description = 'The beats, the bars, the flow — that\'s your world.';
          case 'Rock':        genreTitle = 'Rock Rebel';       genreEmoji = '🎸'; primary = const Color(0xFF43e97b); secondary = const Color(0xFF38f9d7); description = 'Life sounds better with a guitar riff.';
          case 'Electronic':  genreTitle = 'Beat Chaser';      genreEmoji = '🎛'; primary = const Color(0xFF0fd850); secondary = const Color(0xFFf9f047); description = 'Always chasing the perfect drop.';
          case 'Classical':   genreTitle = 'Timeless Ear';     genreEmoji = '🎻'; primary = const Color(0xFFe0c3fc); secondary = const Color(0xFF8ec5fc); description = 'Your taste transcends centuries.';
          case 'R&B':         genreTitle = 'Soul Seeker';      genreEmoji = '🎶'; primary = const Color(0xFFf6d365); secondary = const Color(0xFFfda085); description = 'You feel every note deep in your soul.';
          case 'Soundtrack':  genreTitle = 'Cinematic Soul';   genreEmoji = '🎬'; primary = const Color(0xFF96fbc4); secondary = const Color(0xFFf9f586); description = 'Life is a movie and you\'ve got the score.';
          case 'Indian':      genreTitle = 'Desi Devotee';     genreEmoji = '🪘'; primary = const Color(0xFFf7971e); secondary = const Color(0xFFffd200); description = 'From Bollywood bangers to classical ragas.';
        }
      }
    }
  }

  // ── Time analysis ──
  final hourMap = habits['hours'] as Map<int, int>? ?? {};
  int peakHour = 20;
  int maxPlays = 0;
  hourMap.forEach((hour, plays) {
    if (plays > maxPlays) { maxPlays = plays; peakHour = hour; }
  });

  final String timeEmoji;
  final String timeTitle;
  if (peakHour < 6)       { timeEmoji = '🌙'; timeTitle = 'Night Owl'; }
  else if (peakHour < 12) { timeEmoji = '☀️'; timeTitle = 'Morning Groover'; }
  else if (peakHour < 18) { timeEmoji = '🌤'; timeTitle = 'Daytime Listener'; }
  else                    { timeEmoji = '🌆'; timeTitle = 'Evening Enthusiast'; }

  return MusicPersonality(
    emoji: genreEmoji,
    title: genreTitle,
    timeEmoji: timeEmoji,
    timeTitle: timeTitle,
    description: description,
    primaryColor: primary,
    secondaryColor: secondary,
  );
});

final listeningByDecadeProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final Map<int, ({int plays, Set<String> tracks})> decades = {};

  for (final h in history) {
    if (h.releaseYear == null) continue;
    final decade = (h.releaseYear! ~/ 10) * 10;
    final entry = decades.putIfAbsent(decade, () => (plays: 0, tracks: {}));
    decades[decade] = (plays: entry.plays + 1, tracks: {...entry.tracks, '${h.trackTitle}-${h.artist}'});
  }

  final sorted = decades.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  return sorted.map((e) => {
    'decade': e.key,
    'plays': e.value.plays,
    'uniqueTracks': e.value.tracks.length,
  }).toList();
});

final listeningByYearProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final Map<int, int> years = {};

  for (final h in history) {
    if (h.releaseYear == null) continue;
    years[h.releaseYear!] = (years[h.releaseYear!] ?? 0) + 1;
  }

  final sorted = years.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  return sorted.map((e) => {'year': e.key, 'plays': e.value}).toList();
});

final tracksByDecadeProvider = Provider.family<List<Map<String, dynamic>>, int>((ref, decade) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final Map<String, Map<String, dynamic>> tracks = {};

  for (final h in history) {
    if (h.releaseYear == null) continue;
    if ((h.releaseYear! ~/ 10) * 10 != decade) continue;
    final key = '${h.trackTitle}|${h.artist}';
    if (!tracks.containsKey(key)) {
      tracks[key] = {
        'title': h.trackTitle,
        'artist': h.artist,
        'releaseYear': h.releaseYear,
        'artworkUrlLow': h.artworkUrlLow,
        'artworkUrlHigh': h.artworkUrlHigh,
        'plays': 0,
        'fileId': h.fileId,
        'torrentId': h.torrentId,
      };
    }
    tracks[key]!['plays'] = (tracks[key]!['plays'] as int) + 1;
  }

  final sorted = tracks.values.toList()..sort((a, b) => (b['releaseYear'] as int).compareTo(a['releaseYear'] as int));
  return sorted;
});
