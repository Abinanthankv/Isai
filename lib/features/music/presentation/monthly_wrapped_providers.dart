import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import 'stats_providers.dart';

// ─── Selected Month ──────────────────────────────────────────────────────────

class SelectedWrappedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  set state(DateTime val) => super.state = val;
}

final selectedWrappedMonthProvider = NotifierProvider<SelectedWrappedMonthNotifier, DateTime>(
  SelectedWrappedMonthNotifier.new,
);

// ─── Monthly Filtered Playback ───────────────────────────────────────────────

final monthlyPlaybackProvider = Provider<List<DbPlaybackHistory>>((ref) {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  final month = ref.watch(selectedWrappedMonthProvider);

  final startMs = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
  final endMs = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;

  return history
      .where((h) => h.playedAt >= startMs && h.playedAt < endMs)
      .toList();
});

// ─── Monthly Summary ─────────────────────────────────────────────────────────

final monthlySummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final history = ref.watch(monthlyPlaybackProvider);
  final metaMap = ref.watch(trackMetadataMapProvider).value ?? {};

  final totalPlays = history.length;

  final totalSeconds = history.map((h) {
    if (h.duration != null && h.duration! > 0) return h.duration!;
    final metaTime = metaMap['${h.torrentId}-${h.fileId}'] ?? 0;
    return metaTime ~/ 1000;
  }).fold<int>(0, (a, b) => a + b);

  final totalMinutes = totalSeconds ~/ 60;
  final hoursCount = totalSeconds ~/ 3600;
  final minutesCount = (totalSeconds % 3600) ~/ 60;
  final formattedTime =
      hoursCount > 0 ? '${hoursCount}h ${minutesCount}m' : '${minutesCount}m';

  final uniqueTracks =
      history.map((h) => '${h.trackTitle}-${h.artist}').toSet().length;
  final uniqueArtists = history
      .map((h) => h.artist)
      .where((a) => a.isNotEmpty)
      .expand(_splitArtists)
      .toSet()
      .length;
  final uniqueAlbums = history
      .map((h) => h.album)
      .where((a) => a.isNotEmpty)
      .toSet()
      .length;

  return {
    'totalPlays': totalPlays,
    'totalMinutes': totalMinutes,
    'listeningTime': formattedTime,
    'hours': hoursCount + (minutesCount / 60),
    'uniqueTracks': uniqueTracks,
    'uniqueArtists': uniqueArtists,
    'uniqueAlbums': uniqueAlbums,
  };
});

// ─── Monthly Top Albums ──────────────────────────────────────────────────────

final monthlyTopAlbumsProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(monthlyPlaybackProvider);
  final Map<String, Map<String, dynamic>> albums = {};

  for (final h in history) {
    if (h.album.isEmpty) continue;
    final key = '${h.album}|${h.artist}';
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

  final sorted = albums.values.toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return sorted;
});

// ─── Monthly Top Artists ─────────────────────────────────────────────────────

final monthlyTopArtistsProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(monthlyPlaybackProvider);
  final Map<String, Map<String, dynamic>> artists = {};

  for (final h in history) {
    if (h.artist.isEmpty) continue;
    for (final name in _splitArtists(h.artist)) {
      if (!artists.containsKey(name)) {
        artists[name] = {
          'name': name,
          'artworkUrlLow': h.artworkUrlLow,
          'artworkUrlHigh': h.artworkUrlHigh,
          'count': 0,
        };
      }
      artists[name]!['count'] = (artists[name]!['count'] as int) + 1;
    }
  }

  final sorted = artists.values.toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return sorted;
});

// ─── Monthly Top Tracks ──────────────────────────────────────────────────────

final monthlyTopTracksProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(monthlyPlaybackProvider);
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

  final sorted = tracks.values.toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  return sorted;
});

// ─── Daily Top Artist (Calendar Grid) ────────────────────────────────────────

final monthlyDailyTopArtistProvider =
    Provider<Map<int, Map<String, dynamic>>>((ref) {
  final history = ref.watch(monthlyPlaybackProvider);
  final month = ref.watch(selectedWrappedMonthProvider);

  // Group plays by day of month
  final Map<int, Map<String, Map<String, dynamic>>> dayArtistMap = {};

  for (final h in history) {
    final d = DateTime.fromMillisecondsSinceEpoch(h.playedAt);
    final day = d.day;

    dayArtistMap.putIfAbsent(day, () => {});
    for (final name in _splitArtists(h.artist)) {
      if (!dayArtistMap[day]!.containsKey(name)) {
        dayArtistMap[day]![name] = {
          'name': name,
          'artworkUrlLow': h.artworkUrlLow,
          'artworkUrlHigh': h.artworkUrlHigh,
          'count': 0,
        };
      }
      dayArtistMap[day]![name]!['count'] =
          (dayArtistMap[day]![name]!['count'] as int) + 1;
    }
  }

  // Pick top artist per day
  final Map<int, Map<String, dynamic>> result = {};
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

  for (int day = 1; day <= daysInMonth; day++) {
    final artists = dayArtistMap[day];
    if (artists != null && artists.isNotEmpty) {
      final sorted = artists.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      result[day] = sorted.first;
    }
  }

  return result;
});

// ─── Monthly Play Count Milestones ───────────────────────────────────────────

class PlayCountMilestone {
  final int threshold;
  final String label;
  final String trackTitle;
  final String artist;
  final String? artworkUrl;
  final DateTime achievedAt;
  final Color primaryColor;
  final Color secondaryColor;

  const PlayCountMilestone({
    required this.threshold,
    required this.label,
    required this.trackTitle,
    required this.artist,
    this.artworkUrl,
    required this.achievedAt,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

const _milestoneThresholds = [
  (threshold: 100, label: '100', primary: Color(0xFF43e97b), secondary: Color(0xFF38f9d7)),
  (threshold: 500, label: '500', primary: Color(0xFFf6d365), secondary: Color(0xFFfda085)),
  (threshold: 1000, label: '1K', primary: Color(0xFF4facfe), secondary: Color(0xFF00f2fe)),
  (threshold: 5000, label: '5K', primary: Color(0xFFf093fb), secondary: Color(0xFFf5576c)),
  (threshold: 10000, label: '10K', primary: Color(0xFFa18cd1), secondary: Color(0xFFfbc2eb)),
  (threshold: 25000, label: '25K', primary: Color(0xFFff6b35), secondary: Color(0xFFff9500)),
  (threshold: 50000, label: '50K', primary: Color(0xFFFC3C71), secondary: Color(0xFF8B5CF6)),
];

final monthlyMilestonesProvider =
    Provider<({List<PlayCountMilestone> earned, int totalPlays, int? nextThreshold})>((ref) {
  final allHistory = ref.watch(allPlaybackProvider).value ?? [];

  // Sort by playedAt ascending to find which track hit each milestone
  final sorted = [...allHistory]..sort((a, b) => a.playedAt.compareTo(b.playedAt));

  final totalPlays = sorted.length;
  final List<PlayCountMilestone> earned = [];

  for (final m in _milestoneThresholds) {
    if (totalPlays >= m.threshold) {
      // The track at index (threshold - 1) is the one that triggered the milestone
      final triggerEntry = sorted[m.threshold - 1];
      earned.add(PlayCountMilestone(
        threshold: m.threshold,
        label: m.label,
        trackTitle: triggerEntry.trackTitle,
        artist: triggerEntry.artist,
        artworkUrl: triggerEntry.artworkUrlHigh ?? triggerEntry.artworkUrlLow,
        achievedAt: DateTime.fromMillisecondsSinceEpoch(triggerEntry.playedAt),
        primaryColor: m.primary,
        secondaryColor: m.secondary,
      ));
    }
  }

  // Next milestone
  int? nextThreshold;
  for (final m in _milestoneThresholds) {
    if (totalPlays < m.threshold) {
      nextThreshold = m.threshold;
      break;
    }
  }

  return (earned: earned.reversed.toList(), totalPlays: totalPlays, nextThreshold: nextThreshold);
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

List<String> _splitArtists(String artist) {
  return artist
      .split(RegExp(r'\s*(?:feat\.?|ft\.?|featuring|vs\.?)\s+',
          caseSensitive: false))
      .expand((p) => p.split(RegExp(r'\s*[,&]\s*')))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s.length > 1)
      .toList();
}
