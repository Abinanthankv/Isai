/// Data models for the Audiobook feature.
/// 
/// These are entirely separate from music models ([ItunesTrack], [TorBoxFile])
/// to ensure clean data isolation between the two domains.
library;

/// Represents a single audiobook result from a search or catalog browse.
class AudiobookResult {
  final String id;
  final String title;
  final String author;
  final String? narrator;
  final String? artworkUrl;
  final String? description;
  final int? totalChapters;
  final String? language;
  final String? genre;
  final String? releaseYear;
  final String? releaseDate;
  final String? publisher;
  final String? previewUrl;
  final int? durationMillis;
  final double? rating;
  final int? ratingCount;

  const AudiobookResult({
    required this.id,
    required this.title,
    required this.author,
    this.narrator,
    this.artworkUrl,
    this.description,
    this.totalChapters,
    this.language,
    this.genre,
    this.releaseYear,
    this.releaseDate,
    this.publisher,
    this.previewUrl,
    this.durationMillis,
    this.rating,
    this.ratingCount,
  });

  factory AudiobookResult.fromStremioMeta(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Unknown Book';
    
    // Parse author/narrator from description or meta
    String author = 'Unknown Author';
    String? narrator;
    String? description = json['description'] as String?;
    final releaseInfo = json['releaseInfo'] as String?;
    
    // Stremio meta often has "by Author" in description
    if (description != null && description.contains(' by ')) {
      final byIndex = description.indexOf(' by ');
      author = description.substring(byIndex + 4).split('.').first.trim();
    }
    
    // Check for explicit author/director fields
    if (json['director'] != null) {
      author = (json['director'] as List?)?.join(', ') ?? author;
    }
    if (json['cast'] != null) {
      narrator = (json['cast'] as List?)?.join(', ');
    }

    // Genre from Stremio genres array
    String? genre;
    if (json['genres'] != null && (json['genres'] as List).isNotEmpty) {
      genre = (json['genres'] as List).join(', ');
    }

    return AudiobookResult(
      id: json['id'] as String? ?? '',
      title: name,
      author: author,
      narrator: narrator,
      artworkUrl: json['poster'] as String? ?? json['logo'] as String?,
      description: description,
      totalChapters: null, // resolved when fetching streams
      language: json['language'] as String?,
      genre: genre,
      releaseYear: releaseInfo,
    );
  }

  /// Create from a catalog item (simplified structure).
  factory AudiobookResult.fromCatalogItem(Map<String, dynamic> json) {
    return AudiobookResult(
      id: json['id'] as String? ?? '',
      title: json['name'] as String? ?? 'Unknown Book',
      author: json['author'] as String? ?? 'Unknown Author',
      artworkUrl: json['poster'] as String? ?? json['posterShape'] as String?,
      description: json['description'] as String?,
      genre: json['genre'] as String?,
    );
  }

  AudiobookResult copyWith({
    String? id,
    String? title,
    String? author,
    String? narrator,
    String? artworkUrl,
    String? description,
    int? totalChapters,
    String? language,
    String? genre,
    String? releaseYear,
    String? releaseDate,
    String? publisher,
    String? previewUrl,
    int? durationMillis,
    double? rating,
    int? ratingCount,
  }) {
    return AudiobookResult(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      description: description ?? this.description,
      totalChapters: totalChapters ?? this.totalChapters,
      language: language ?? this.language,
      genre: genre ?? this.genre,
      releaseYear: releaseYear ?? this.releaseYear,
      releaseDate: releaseDate ?? this.releaseDate,
      publisher: publisher ?? this.publisher,
      previewUrl: previewUrl ?? this.previewUrl,
      durationMillis: durationMillis ?? this.durationMillis,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }

  @override
  String toString() => 'AudiobookResult(id: $id, title: $title, author: $author)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudiobookResult && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a single chapter within an audiobook.
class AudiobookChapter {
  final String id;
  final String title;
  final int chapterNumber;
  final int durationMillis;
  final int startTimeMillis;
  final String? streamUrl;
  final String? source;

  const AudiobookChapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    this.durationMillis = 0,
    this.startTimeMillis = 0,
    this.streamUrl,
    this.source,
  });

  factory AudiobookChapter.fromStremioStream(Map<String, dynamic> json, int index) {
    final title = json['title'] as String? ?? 
                  json['name'] as String? ?? 
                  'Chapter ${index + 1}';
    
    return AudiobookChapter(
      id: json['infoHash'] as String? ?? json['url'] as String? ?? 'ch_$index',
      title: title,
      chapterNumber: index + 1,
      durationMillis: 0,
      streamUrl: json['url'] as String?,
      source: json['name'] as String? ?? json['title'] as String?,
    );
  }

  @override
  String toString() => 'AudiobookChapter(ch$chapterNumber: $title)';
}

/// An audiobook paired with its listening progress.
class AudiobookWithProgress {
  final AudiobookResult book;
  final int currentChapter;
  final int positionMillis;
  final int totalChapters;
  final DateTime lastListenedAt;
  final double progressPercent;

  const AudiobookWithProgress({
    required this.book,
    this.currentChapter = 0,
    this.positionMillis = 0,
    this.totalChapters = 0,
    required this.lastListenedAt,
    this.progressPercent = 0.0,
  });
}

/// Pre-computed progress for a book, stored in progress.json and cache.
class BookProgress {
  final String bookId;
  final String title;
  final String author;
  final String? artworkUrl;
  final int listenedMillis;
  final int totalDurationMillis;
  final int completedChapters;
  final int totalChapters;
  final DateTime lastListenedAt;
  final double progressPercent;

  const BookProgress({
    required this.bookId,
    required this.title,
    this.author = 'Unknown Author',
    this.artworkUrl,
    this.listenedMillis = 0,
    this.totalDurationMillis = 0,
    this.completedChapters = 0,
    this.totalChapters = 0,
    required this.lastListenedAt,
    this.progressPercent = 0.0,
  });

  factory BookProgress.fromJson(Map<String, dynamic> json) => BookProgress(
    bookId: json['bookId'] as String? ?? '',
    title: json['title'] as String? ?? 'Audiobook',
    author: json['author'] as String? ?? 'Unknown Author',
    artworkUrl: json['artworkUrl'] as String?,
    listenedMillis: json['listenedMillis'] as int? ?? 0,
    totalDurationMillis: json['totalDurationMillis'] as int? ?? 0,
    completedChapters: json['completedChapters'] as int? ?? 0,
    totalChapters: json['totalChapters'] as int? ?? 0,
    lastListenedAt: DateTime.tryParse(json['lastListenedAt'] as String? ?? '') ?? DateTime(2000),
    progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'title': title,
    'author': author,
    'artworkUrl': artworkUrl,
    'listenedMillis': listenedMillis,
    'totalDurationMillis': totalDurationMillis,
    'completedChapters': completedChapters,
    'totalChapters': totalChapters,
    'lastListenedAt': lastListenedAt.toIso8601String(),
    'progressPercent': progressPercent,
  };
}

/// State class for audiobook search.
class AudiobookSearchState {
  final List<AudiobookResult> results;
  final bool isLoading;
  final String? error;
  final String query;

  const AudiobookSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  AudiobookSearchState copyWith({
    List<AudiobookResult>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return AudiobookSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class AudiobookBookmark {
  final int id;
  final String bookId;
  final int chapterIndex;
  final int positionMillis;
  final String? label;
  final DateTime createdAt;

  const AudiobookBookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.positionMillis,
    this.label,
    required this.createdAt,
  });
}
