import 'dart:math';
import 'package:dio/dio.dart';
import '../../../core/database/database.dart';
import 'audiobook_models.dart';
import 'audiobook_repository.dart';

/// Listening personality types for audiobooks.
enum AudiobookPersonality { explorer, loyalist, nicheDiver, moodRider, bibliophile }

/// Weighted genre entry from user listening history.
class AudiobookGenreWeight {
  final String genre;
  final int count;
  final double percentage;
  const AudiobookGenreWeight({required this.genre, required this.count, required this.percentage});
}

/// Weighted author entry from user listening history.
class AudiobookAuthorWeight {
  final String author;
  final int chapterCount;
  final double affinity;
  const AudiobookAuthorWeight({required this.author, required this.chapterCount, required this.affinity});
}

/// Weighted narrator entry from user listening history.
class AudiobookNarratorWeight {
  final String narrator;
  final int chapterCount;
  final double affinity;
  const AudiobookNarratorWeight({required this.narrator, required this.chapterCount, required this.affinity});
}

/// The full user audiobook profile computed from listening history.
class UserAudiobookProfile {
  final AudiobookPersonality personality;
  final String personalityName;
  final String personalityDescription;
  final int uniqueBooksCount;
  final int completedBooksCount;
  final int totalChaptersPlayed;
  final double totalListeningHours;
  final List<AudiobookGenreWeight> genreWeights;
  final List<AudiobookAuthorWeight> authorWeights;
  final List<AudiobookNarratorWeight> narratorWeights;
  final Set<String> completedBookIds;
  final Set<String> wishlistBookIds;
  final Map<int, int> hourDistribution;

  const UserAudiobookProfile({
    this.personality = AudiobookPersonality.bibliophile,
    this.personalityName = 'Getting Started',
    this.personalityDescription = 'Listen to more audiobooks to discover your listening personality.',
    this.uniqueBooksCount = 0,
    this.completedBooksCount = 0,
    this.totalChaptersPlayed = 0,
    this.totalListeningHours = 0.0,
    this.genreWeights = const [],
    this.authorWeights = const [],
    this.narratorWeights = const [],
    this.completedBookIds = const {},
    this.wishlistBookIds = const {},
    this.hourDistribution = const {},
  });
}

/// A scored recommendation candidate.
class AudiobookRecommendation {
  final AudiobookResult book;
  final double score;
  final String reason;

  const AudiobookRecommendation({
    required this.book,
    required this.score,
    required this.reason,
  });
}

/// Recommendation engine that builds an audiobook profile from listening history
/// and generates personalized recommendations via iTunes catalog search.
class AudiobookRecommendationEngine {
  final AudiobookRepository _repo;
  final Dio _dio;

  AudiobookRecommendationEngine(this._repo, Dio? dio)
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  /// Build a user profile from listening progress and cached metadata.
  Future<UserAudiobookProfile> buildProfile({
    required List<DbAudiobookProgress> history,
    Set<String> wishlistBookIds = const {},
  }) async {
    if (history.isEmpty) return const UserAudiobookProfile();

    // Deduplicate by normalized bookId
    final seenBooks = <String>{};
    final bookChapters = <String, Set<int>>{};
    final bookListeningMs = <String, int>{};
    final bookCompleted = <String>{};

    for (final h in history) {
      final normId = AudiobookRepository.normalizeBookId(h.bookId);
      seenBooks.add(normId);
      bookChapters.putIfAbsent(normId, () => {}).add(h.chapterIndex);
      final currentMax = bookListeningMs[normId] ?? 0;
      if (h.positionMillis > currentMax) {
        bookListeningMs[normId] = h.positionMillis;
      }
      if (h.isCompleted) {
        bookCompleted.add(normId);
      }
    }

    final totalListeningMs = bookListeningMs.values.fold<int>(0, (a, b) => a + b);
    final totalHours = totalListeningMs / 3600000.0;
    final totalChapters = bookChapters.values.fold<int>(0, (a, set) => a + set.length);

    // Genre analysis from cached metadata
    final Map<String, int> genreCounts = {};
    final Map<String, int> authorChapterCount = {};
    final Map<String, int> narratorChapterCount = {};
    final Map<int, int> hourDist = {for (int i = 0; i < 24; i++) i: 0};

    for (final bookId in seenBooks) {
      final cached = await _repo.getCachedMetadata(bookId);
      if (cached != null) {
        if (cached.genre != null && cached.genre!.isNotEmpty) {
          for (final g in cached.genre!.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty)) {
            genreCounts[g] = (genreCounts[g] ?? 0) + 1;
          }
        }
        if (cached.author != null && cached.author!.isNotEmpty) {
          authorChapterCount[cached.author!] = (authorChapterCount[cached.author!] ?? 0) +
              (bookChapters[bookId]?.length ?? 0);
        }
        if (cached.narrator != null && cached.narrator!.isNotEmpty) {
          narratorChapterCount[cached.narrator!] = (narratorChapterCount[cached.narrator!] ?? 0) +
              (bookChapters[bookId]?.length ?? 0);
        }
      }
      // Reconstruct hour distribution from lastListenedAt in history
      for (final h in history) {
        if (AudiobookRepository.normalizeBookId(h.bookId) == bookId) {
          hourDist[h.lastListenedAt.hour] = (hourDist[h.lastListenedAt.hour] ?? 0) + 1;
        }
      }
    }

    return UserAudiobookProfile(
      personality: _classifyPersonality(genreCounts.length, authorChapterCount.length, totalChapters, hourDist),
      personalityName: _personalityName(_classifyPersonality(genreCounts.length, authorChapterCount.length, totalChapters, hourDist)),
      personalityDescription: _personalityDescription(_classifyPersonality(genreCounts.length, authorChapterCount.length, totalChapters, hourDist)),
      uniqueBooksCount: seenBooks.length,
      completedBooksCount: bookCompleted.length,
      totalChaptersPlayed: totalChapters,
      totalListeningHours: totalHours,
      genreWeights: _computeGenreWeights(genreCounts),
      authorWeights: _computeAuthorWeights(authorChapterCount, totalChapters),
      narratorWeights: _computeNarratorWeights(narratorChapterCount, totalChapters),
      completedBookIds: bookCompleted,
      wishlistBookIds: wishlistBookIds,
      hourDistribution: hourDist,
    );
  }

  /// Generate personalized recommendations for the user.
  Future<List<AudiobookRecommendation>> getRecommendations(UserAudiobookProfile profile, {int limit = 20}) async {
    final seenIds = <String>{...profile.completedBookIds, ...profile.wishlistBookIds};
    final List<_ScoredCandidate> candidates = [];

    // Strategy 1: Author affinity — books by most-listened authors
    for (final authorWeight in profile.authorWeights.take(3)) {
      try {
        final books = await _repo.fetchBooksByAuthor(authorWeight.author, limit: 10);
        for (final book in books) {
          if (!seenIds.contains(book.id)) {
            seenIds.add(book.id);
            candidates.add(_ScoredCandidate(
              book: book,
              authorScore: authorWeight.affinity,
              narratorScore: 0,
              genreScore: _genreScore(profile, book.genre),
              popularityScore: _popularityScore(book.rating, book.ratingCount),
              reason: 'By ${authorWeight.author}',
            ));
          }
        }
      } catch (_) {}
    }

    // Strategy 2: Top-rated in preferred genres
    for (final genreWeight in profile.genreWeights.take(3)) {
      try {
        final books = await _repo.searchItunesCatalog(genreWeight.genre, limit: 15);
        for (final book in books) {
          if (!seenIds.contains(book.id)) {
            seenIds.add(book.id);
            candidates.add(_ScoredCandidate(
              book: book,
              authorScore: _authorScore(profile, book.author),
              narratorScore: _narratorScore(profile, book.narrator),
              genreScore: genreWeight.percentage / 100,
              popularityScore: _popularityScore(book.rating, book.ratingCount),
              reason: 'Popular in ${genreWeight.genre}',
            ));
          }
        }
      } catch (_) {}
    }

    // Strategy 3: Overall top-rated (fill remaining slots)
    if (candidates.length < limit) {
      try {
        final topRated = await _repo.fetchTopRated(limit: 30);
        for (final book in topRated) {
          if (!seenIds.contains(book.id)) {
            seenIds.add(book.id);
            candidates.add(_ScoredCandidate(
              book: book,
              authorScore: _authorScore(profile, book.author),
              narratorScore: _narratorScore(profile, book.narrator),
              genreScore: _genreScore(profile, book.genre),
              popularityScore: _popularityScore(book.rating, book.ratingCount),
              reason: 'Top rated',
            ));
          }
          if (candidates.length >= limit * 2) break;
        }
      } catch (_) {}
    }

    // Score and sort
    for (final c in candidates) {
      c.computeFinalScore(profile);
    }
    candidates.sort((a, b) => b.finalScore.compareTo(a.finalScore));

    return candidates.take(limit).map((c) => AudiobookRecommendation(
      book: c.book,
      score: c.finalScore,
      reason: c.reason,
    )).toList();
  }

  /// Quick recommendations without building a full profile (cold-start).
  Future<List<AudiobookRecommendation>> coldStartRecommendations({int limit = 10}) async {
    try {
      final topRated = await _repo.fetchTopRated(limit: limit);
      return topRated.map((book) => AudiobookRecommendation(
        book: book,
        score: _popularityScore(book.rating, book.ratingCount),
        reason: 'Top rated',
      )).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Private helpers ---

  double _authorScore(UserAudiobookProfile profile, String? author) {
    if (author == null || author.isEmpty) return 0;
    final idx = profile.authorWeights.indexWhere((a) =>
        a.author.toLowerCase() == author.toLowerCase());
    return idx >= 0 ? profile.authorWeights[idx].affinity : 0;
  }

  double _narratorScore(UserAudiobookProfile profile, String? narrator) {
    if (narrator == null || narrator.isEmpty) return 0;
    final idx = profile.narratorWeights.indexWhere((n) =>
        n.narrator.toLowerCase() == narrator.toLowerCase());
    return idx >= 0 ? profile.narratorWeights[idx].affinity : 0;
  }

  double _genreScore(UserAudiobookProfile profile, String? genre) {
    if (genre == null || genre.isEmpty) return 0;
    final idx = profile.genreWeights.indexWhere((g) =>
        g.genre.toLowerCase() == genre.toLowerCase());
    return idx >= 0 ? profile.genreWeights[idx].percentage / 100 : 0;
  }

  double _popularityScore(double? rating, int? ratingCount) {
    if (rating == null || ratingCount == null || ratingCount == 0) return 0;
    return rating * (log(ratingCount + 1) / log(10)) / 10;
  }

  List<AudiobookGenreWeight> _computeGenreWeights(Map<String, int> genreCounts) {
    final total = genreCounts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];
    final sorted = genreCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => AudiobookGenreWeight(
      genre: e.key,
      count: e.value,
      percentage: (e.value / total) * 100,
    )).toList();
  }

  List<AudiobookAuthorWeight> _computeAuthorWeights(Map<String, int> authorChapters, int totalChapters) {
    if (totalChapters == 0) return [];
    final sorted = authorChapters.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxChapters = sorted.isNotEmpty ? sorted.first.value : 1;
    return sorted.map((e) => AudiobookAuthorWeight(
      author: e.key,
      chapterCount: e.value,
      affinity: e.value / maxChapters,
    )).toList();
  }

  List<AudiobookNarratorWeight> _computeNarratorWeights(Map<String, int> narratorChapters, int totalChapters) {
    if (totalChapters == 0) return [];
    final sorted = narratorChapters.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxChapters = sorted.isNotEmpty ? sorted.first.value : 1;
    return sorted.map((e) => AudiobookNarratorWeight(
      narrator: e.key,
      chapterCount: e.value,
      affinity: e.value / maxChapters,
    )).toList();
  }

  AudiobookPersonality _classifyPersonality(int uniqueGenres, int uniqueAuthors, int totalChapters, Map<int, int> hourDist) {
    if (totalChapters < 5) return AudiobookPersonality.bibliophile;
    final slotDiversity = hourDist.values.where((v) => v > 0).length;
    if (slotDiversity >= 4 && uniqueGenres >= 3) return AudiobookPersonality.moodRider;
    if (uniqueGenres >= 4 && uniqueAuthors >= 5) return AudiobookPersonality.explorer;
    if (uniqueAuthors <= 2 && uniqueAuthors > 0) return AudiobookPersonality.loyalist;
    if (uniqueGenres <= 2 && uniqueGenres > 0) return AudiobookPersonality.nicheDiver;
    return AudiobookPersonality.bibliophile;
  }

  String _personalityName(AudiobookPersonality p) {
    switch (p) {
      case AudiobookPersonality.explorer: return 'The Explorer';
      case AudiobookPersonality.loyalist: return 'The Loyalist';
      case AudiobookPersonality.nicheDiver: return 'The Niche Diver';
      case AudiobookPersonality.moodRider: return 'The Mood Rider';
      case AudiobookPersonality.bibliophile: return 'The Bibliophile';
    }
  }

  String _personalityDescription(AudiobookPersonality p) {
    switch (p) {
      case AudiobookPersonality.explorer: return 'You love discovering new authors and genres. Always exploring!';
      case AudiobookPersonality.loyalist: return 'You stick with your favourite authors. Deep connections.';
      case AudiobookPersonality.nicheDiver: return 'You go deep into specific genres you love.';
      case AudiobookPersonality.moodRider: return 'Your listening changes with the time of day.';
      case AudiobookPersonality.bibliophile: return 'A well-rounded listener with broad taste.';
    }
  }
}

/// Internal scored candidate used during recommendation computation.
class _ScoredCandidate {
  final AudiobookResult book;
  double authorScore;
  double narratorScore;
  double genreScore;
  double popularityScore;
  String reason;
  double finalScore = 0;

  _ScoredCandidate({
    required this.book,
    this.authorScore = 0,
    this.narratorScore = 0,
    this.genreScore = 0,
    this.popularityScore = 0,
    this.reason = '',
  });

  void computeFinalScore(UserAudiobookProfile profile) {
    final wAuthor = 0.35;
    final wNarrator = 0.15;
    final wGenre = 0.30;
    final wPopularity = 0.20;
    finalScore = authorScore * wAuthor + narratorScore * wNarrator + genreScore * wGenre + popularityScore * wPopularity;
  }
}
