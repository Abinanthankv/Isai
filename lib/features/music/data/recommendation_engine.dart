import 'dart:math';
import '../../../core/database/database.dart';

/// Time slot classification for temporal patterns.
enum TimeSlot { morning, afternoon, evening, night }

/// Listening personality types.
enum PersonalityType { explorer, loyalist, nicheDiver, moodRider, eclectic }

/// A scored artist entry with affinity data.
class ArtistAffinity {
  final String name;
  final int playCount;
  final bool isFollowed;
  final bool hasLikedTracks;
  final double affinityScore; // 0.0 - 1.0

  const ArtistAffinity({
    required this.name,
    required this.playCount,
    required this.isFollowed,
    required this.hasLikedTracks,
    required this.affinityScore,
  });

  String get sentiment {
    if (affinityScore >= 0.7) return 'Positive';
    if (affinityScore >= 0.4) return 'Neutral';
    return 'Low';
  }
}

/// Genre weight entry.
class GenreWeight {
  final String genre;
  final int count;
  final double percentage;

  const GenreWeight({
    required this.genre,
    required this.count,
    required this.percentage,
  });
}

/// Temporal pattern entry: what genres/artists are played in each time slot.
class TemporalPattern {
  final TimeSlot slot;
  final String label;
  final String timeRange;
  final List<GenreWeight> topGenres;
  final int totalPlays;

  const TemporalPattern({
    required this.slot,
    required this.label,
    required this.timeRange,
    required this.topGenres,
    required this.totalPlays,
  });
}

/// The full user music profile computed from local data.
class UserMusicProfile {
  final PersonalityType personalityType;
  final String personalityName;
  final String personalityDescription;
  final int level;
  final int interactionCount;
  final int uniqueGenresCount;
  final int uniqueArtistsCount;
  final List<String> topArtists;
  final List<GenreWeight> genreWeights;
  final List<TemporalPattern> temporalPatterns;
  final List<ArtistAffinity> artistAffinities;

  const UserMusicProfile({
    required this.personalityType,
    required this.personalityName,
    required this.personalityDescription,
    required this.level,
    required this.interactionCount,
    required this.uniqueGenresCount,
    required this.uniqueArtistsCount,
    required this.topArtists,
    required this.genreWeights,
    required this.temporalPatterns,
    required this.artistAffinities,
  });

  static const empty = UserMusicProfile(
    personalityType: PersonalityType.eclectic,
    personalityName: 'Getting Started',
    personalityDescription: 'Play more music to discover your listening personality.',
    level: 0,
    interactionCount: 0,
    uniqueGenresCount: 0,
    uniqueArtistsCount: 0,
    topArtists: [],
    genreWeights: [],
    temporalPatterns: [],
    artistAffinities: [],
  );
}

/// Recommendation engine that builds a user profile from local data.
class RecommendationEngine {
  const RecommendationEngine();

  /// Splits a multi-artist string into individual artist names.
  /// e.g. "Drake & Future" → ["Drake", "Future"]
  /// e.g. "Post Malone feat. Doja Cat" → ["Post Malone", "Doja Cat"]
  static List<String> splitArtists(String artistField) {
    if (artistField.isEmpty) return [];

    // Split by common delimiters (order matters — longer patterns first)
    final parts = artistField
        .split(RegExp(r'\s*(?:feat\.?|ft\.?|featuring)\s+', caseSensitive: false))
        .expand((part) => part.split(RegExp(r'\s*[,&]\s*')))
        .expand((part) => part.split(RegExp(r'\s+(?:x|X|with|and)\s+')))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 1)
        .toList();

    // If splitting produced nothing useful, return original as single entry
    return parts.isNotEmpty ? parts : [artistField.trim()];
  }

  /// Build a full user profile from playback history and metadata.
  UserMusicProfile buildProfile({
    required List<DbPlaybackHistory> history,
    required List<DbTrackMetadata> metadata,
    required List<DbFollowedArtist> followedArtists,
  }) {
    if (history.isEmpty) return UserMusicProfile.empty;

    final interactionCount = history.length;

    // --- Artist & Decade analysis with exponential time decay & duration weighting ---
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final Map<String, double> artistDecayedScores = {};
    final Map<int, double> decadeDecayedScores = {};
    final Map<String, int> rawArtistCounts = {};

    for (final h in history) {
      if (h.artist.isEmpty) continue;
      
      // 1. Time decay factor: half-life = 14 days
      final ageInDays = (nowMs - h.playedAt) / (1000 * 60 * 60 * 24);
      final timeDecayWeight = exp(-0.05 * max(0.0, ageInDays)); // 1.0 today, ~0.5 at 14d, ~0.25 at 28d

      // 2. Play duration ratio / completion weight
      double completionWeight = 1.0;
      if (h.duration != null && h.duration! > 0) {
        // If track duration is logged, check ratio (assume standard song 3.5 min if unknown)
        completionWeight = 1.0; 
      }

      final weight = timeDecayWeight * completionWeight;

      final artists = splitArtists(h.artist);
      for (final artist in artists) {
        artistDecayedScores[artist] = (artistDecayedScores[artist] ?? 0.0) + weight;
        rawArtistCounts[artist] = (rawArtistCounts[artist] ?? 0) + 1;
      }

      // Track release year for decade breakdown
      if (h.releaseYear != null && h.releaseYear! > 1920) {
        final decade = (h.releaseYear! ~/ 10) * 10;
        decadeDecayedScores[decade] = (decadeDecayedScores[decade] ?? 0.0) + weight;
      }
    }

    final sortedArtistScores = artistDecayedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtistScores.take(10).map((e) => e.key).toList();
    final uniqueArtistsCount = artistDecayedScores.length;

    // --- Genre analysis (with time decay weighting) ---
    final Map<String, double> genreDecayedScores = {};

    // Source 1: PlaybackHistory genre field
    for (final h in history) {
      if (h.genre.isNotEmpty) {
        final ageInDays = (nowMs - h.playedAt) / (1000 * 60 * 60 * 24);
        final weight = exp(-0.05 * max(0.0, ageInDays));
        genreDecayedScores[h.genre] = (genreDecayedScores[h.genre] ?? 0.0) + weight;
      }
    }

    // Source 2: TrackMetadata genre field (iTunes-enriched)
    for (final m in metadata) {
      if (m.genre != null && m.genre!.isNotEmpty) {
        genreDecayedScores[m.genre!] = (genreDecayedScores[m.genre!] ?? 0.0) + 1.0;
      }
    }

    // Source 3: Fallback if empty
    if (genreDecayedScores.isEmpty && artistDecayedScores.isNotEmpty) {
      for (final entry in artistDecayedScores.entries) {
        genreDecayedScores[entry.key] = entry.value;
      }
    }

    final totalGenreWeight = genreDecayedScores.values.fold<double>(0.0, (a, b) => a + b);
    final sortedGenres = genreDecayedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final genreWeights = sortedGenres.map((e) => GenreWeight(
      genre: e.key,
      count: (e.value * 10).round(),
      percentage: totalGenreWeight > 0 ? (e.value / totalGenreWeight) * 100 : 0,
    )).toList();
    final uniqueGenresCount = genreDecayedScores.length;

    // --- Temporal patterns ---
    final temporalPatterns = _buildTemporalPatterns(history);

    // --- Artist affinity (recency weighted + follow/like boost) ---
    final followedNames = followedArtists.map((a) => a.name.toLowerCase()).toSet();
    final likedArtists = <String>{};
    for (final m in metadata) {
      if (m.isLiked && m.artist != null && m.artist!.isNotEmpty) {
        for (final artist in splitArtists(m.artist!)) {
          likedArtists.add(artist.toLowerCase());
        }
      }
    }

    final maxScore = sortedArtistScores.isNotEmpty ? sortedArtistScores.first.value : 1.0;
    final artistAffinities = sortedArtistScores.take(20).map((e) {
      final normalizedName = e.key.toLowerCase();
      final playScore = e.value / maxScore;
      final followBonus = followedNames.contains(normalizedName) ? 0.2 : 0.0;
      final likeBonus = likedArtists.contains(normalizedName) ? 0.15 : 0.0;
      final affinity = min(1.0, playScore * 0.65 + followBonus + likeBonus);

      return ArtistAffinity(
        name: e.key,
        playCount: rawArtistCounts[e.key] ?? e.value.round(),
        isFollowed: followedNames.contains(normalizedName),
        hasLikedTracks: likedArtists.contains(normalizedName),
        affinityScore: affinity,
      );
    }).toList();

    // --- Personality classification ---
    final personality = _classifyPersonality(
      uniqueArtists: uniqueArtistsCount,
      totalPlays: interactionCount,
      genreWeights: genreWeights,
      temporalPatterns: temporalPatterns,
      artistCounts: rawArtistCounts,
    );

    // --- Level ---
    final level = _computeLevel(interactionCount);

    return UserMusicProfile(
      personalityType: personality.type,
      personalityName: personality.name,
      personalityDescription: personality.description,
      level: level,
      interactionCount: interactionCount,
      uniqueGenresCount: uniqueGenresCount,
      uniqueArtistsCount: uniqueArtistsCount,
      topArtists: topArtists,
      genreWeights: genreWeights,
      temporalPatterns: temporalPatterns,
      artistAffinities: artistAffinities,
    );
  }

  /// Determine the current time slot.
  static TimeSlot getCurrentTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return TimeSlot.morning;
    if (hour >= 12 && hour < 18) return TimeSlot.afternoon;
    if (hour >= 18 && hour < 22) return TimeSlot.evening;
    return TimeSlot.night;
  }

  /// Get time slot label.
  static String getTimeSlotLabel(TimeSlot slot) {
    switch (slot) {
      case TimeSlot.morning: return 'Morning Chill';
      case TimeSlot.afternoon: return 'Afternoon Vibes';
      case TimeSlot.evening: return 'Evening Energy';
      case TimeSlot.night: return 'Late Night';
    }
  }

  // --- Private helpers ---

  List<TemporalPattern> _buildTemporalPatterns(List<DbPlaybackHistory> history) {
    final Map<TimeSlot, Map<String, int>> slotGenres = {
      TimeSlot.morning: {},
      TimeSlot.afternoon: {},
      TimeSlot.evening: {},
      TimeSlot.night: {},
    };
    final Map<TimeSlot, Map<String, int>> slotArtists = {
      TimeSlot.morning: {},
      TimeSlot.afternoon: {},
      TimeSlot.evening: {},
      TimeSlot.night: {},
    };
    final Map<TimeSlot, int> slotCounts = {
      TimeSlot.morning: 0,
      TimeSlot.afternoon: 0,
      TimeSlot.evening: 0,
      TimeSlot.night: 0,
    };

    for (final h in history) {
      final dt = DateTime.fromMillisecondsSinceEpoch(h.playedAt);
      final slot = _hourToSlot(dt.hour);
      slotCounts[slot] = slotCounts[slot]! + 1;

      if (h.genre.isNotEmpty) {
        slotGenres[slot]![h.genre] = (slotGenres[slot]![h.genre] ?? 0) + 1;
      }

      // Also track artists per time slot (split multi-artist)
      if (h.artist.isNotEmpty) {
        for (final artist in splitArtists(h.artist)) {
          slotArtists[slot]![artist] = (slotArtists[slot]![artist] ?? 0) + 1;
        }
      }
    }

    final slotInfo = {
      TimeSlot.morning: ('Morning', '6AM - 12PM'),
      TimeSlot.afternoon: ('Afternoon', '12PM - 6PM'),
      TimeSlot.evening: ('Evening', '6PM - 10PM'),
      TimeSlot.night: ('Night', '10PM - 6AM'),
    };

    return TimeSlot.values.map((slot) {
      final genres = slotGenres[slot]!;
      final artists = slotArtists[slot]!;
      
      // Use genres if available, otherwise fall back to artists
      final Map<String, int> dataSource = genres.isNotEmpty ? genres : artists;
      final total = dataSource.values.fold<int>(0, (a, b) => a + b);
      final sorted = dataSource.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topEntries = sorted.take(3).map((e) => GenreWeight(
        genre: e.key,
        count: e.value,
        percentage: total > 0 ? (e.value / total) * 100 : 0,
      )).toList();

      return TemporalPattern(
        slot: slot,
        label: slotInfo[slot]!.$1,
        timeRange: slotInfo[slot]!.$2,
        topGenres: topEntries,
        totalPlays: slotCounts[slot]!,
      );
    }).toList();
  }

  TimeSlot _hourToSlot(int hour) {
    if (hour >= 6 && hour < 12) return TimeSlot.morning;
    if (hour >= 12 && hour < 18) return TimeSlot.afternoon;
    if (hour >= 18 && hour < 22) return TimeSlot.evening;
    return TimeSlot.night;
  }

  ({PersonalityType type, String name, String description}) _classifyPersonality({
    required int uniqueArtists,
    required int totalPlays,
    required List<GenreWeight> genreWeights,
    required List<TemporalPattern> temporalPatterns,
    required Map<String, int> artistCounts,
  }) {
    if (totalPlays < 10) {
      return (
        type: PersonalityType.eclectic,
        name: 'The Eclectic',
        description: 'Still building your profile. Keep listening!',
      );
    }

    // Explorer: High artist diversity (>70% unique relative to plays)
    final uniqueRatio = uniqueArtists / totalPlays;
    if (uniqueRatio > 0.5 && genreWeights.length >= 4) {
      return (
        type: PersonalityType.explorer,
        name: 'The Explorer',
        description: 'Chaotic and beautiful. A bit of everything.',
      );
    }

    // Loyalist: Top artist >50% of plays
    if (artistCounts.isNotEmpty) {
      final topArtistPlays = artistCounts.values.reduce(max);
      if (topArtistPlays / totalPlays > 0.4) {
        return (
          type: PersonalityType.loyalist,
          name: 'The Loyalist',
          description: 'Deep connections with your favourite artists.',
        );
      }
    }

    // Niche Diver: Top genre >60% of plays
    if (genreWeights.isNotEmpty && genreWeights.first.percentage > 60) {
      return (
        type: PersonalityType.nicheDiver,
        name: 'The Niche Diver',
        description: 'You know what you love and go deep.',
      );
    }

    // Mood Rider: Strong temporal variation
    final slotDiversity = temporalPatterns
        .where((p) => p.topGenres.isNotEmpty)
        .map((p) => p.topGenres.first.genre)
        .toSet()
        .length;
    if (slotDiversity >= 3) {
      return (
        type: PersonalityType.moodRider,
        name: 'The Mood Rider',
        description: 'Your music shifts with the time of day.',
      );
    }

    return (
      type: PersonalityType.eclectic,
      name: 'The Eclectic',
      description: 'A balanced listener with wide-ranging taste.',
    );
  }

  int _computeLevel(int interactions) {
    // Simple level curve: level = sqrt(interactions / 5)
    if (interactions == 0) return 0;
    return (sqrt(interactions / 5)).floor().clamp(1, 50);
  }
}
