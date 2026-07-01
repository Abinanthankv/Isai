import 'package:dio/dio.dart';

class HardcoverBook {
  final int id;
  final String title;
  final String? author;
  final String? slug;
  final String? artworkUrl;
  final double? rating;
  final bool hasAudiobook;
  final int? audioSeconds;

  HardcoverBook({
    required this.id,
    required this.title,
    this.author,
    this.slug,
    this.artworkUrl,
    this.rating,
    this.hasAudiobook = false,
    this.audioSeconds,
  });

  factory HardcoverBook.fromJson(Map<String, dynamic> json) {
    final authors = json['author_names'] as List?;
    final image = json['image'] as Map<String, dynamic>?;
    return HardcoverBook(
      id: int.parse('${json['id']}'),
      title: json['title'] ?? '',
      author: authors?.isNotEmpty == true ? authors!.first.toString() : null,
      slug: json['slug'] as String?,
      artworkUrl: image?['url'] as String?,
      rating: double.tryParse('${json['rating']}'),
      hasAudiobook: json['has_audiobook'] == true,
      audioSeconds: json['audio_seconds'] as int?,
    );
  }
}

class CurrentlyReadingEntry {
  final int userBookId;
  final HardcoverBook book;
  final int? readId;
  final int? editionId;
  final int? progressSeconds;
  final int? progressPages;
  final String? startedAt;

  CurrentlyReadingEntry({
    required this.userBookId,
    required this.book,
    this.readId,
    this.editionId,
    this.progressSeconds,
    this.progressPages,
    this.startedAt,
  });

  double get progressHours => progressSeconds != null ? progressSeconds! / 3600.0 : 0;
}

class HardcoverApiService {
  static const String _endpoint = 'https://api.hardcover.app/v1/graphql';
  final Dio _dio;

  HardcoverApiService() : _dio = Dio(BaseOptions(
    headers: {'Content-Type': 'application/json', 'User-Agent': 'Isai-Hardcover/1.0'},
  ));

  Future<String?> validateAndGetUsername(String apiKey) async {
    try {
      final res = await _query(apiKey, '{ me { id username } }');
      final me = (res['me'] as List?)?.firstOrNull;
      if (me != null && me['id'] != null) {
        return me['username'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<CurrentlyReadingEntry>> getCurrentlyReading(String apiKey) async {
    try {
      final res = await _query(apiKey, '''
        { me { user_books(where: {status_id: {_eq: 2}}) {
          id
          book { id title slug }
          user_book_reads(order_by: {started_at: desc}, limit: 1) {
            id edition_id progress_seconds progress_pages started_at
          }
        } } }
      ''');
      final list = ((res['me'] as List?)?.firstOrNull?['user_books'] as List?) ?? [];
      return list.map<CurrentlyReadingEntry?>((ub) {
        if (ub == null) return null;
        final bookJson = ub['book'] as Map<String, dynamic>?;
        if (bookJson == null) return null;
        final reads = ub['user_book_reads'] as List? ?? [];
        final read = reads.isNotEmpty ? reads[0] as Map<String, dynamic>? : null;
        return CurrentlyReadingEntry(
          userBookId: ub['id'] as int,
          book: HardcoverBook(
            id: bookJson['id'] as int,
            title: bookJson['title'] ?? '',
            slug: bookJson['slug'] as String?,
            hasAudiobook: bookJson['has_audiobook'] == true,
          ),
          readId: read?['id'] as int?,
          editionId: read?['edition_id'] as int?,
          progressSeconds: read?['progress_seconds'] as int?,
          progressPages: read?['progress_pages'] as int?,
          startedAt: read?['started_at'] as String?,
        );
      }).whereType<CurrentlyReadingEntry>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<HardcoverBook>> searchBooks(String apiKey, String query, {int perPage = 3}) async {
    try {
      final safeQuery = query.replaceAll('"', '\\"').replaceAll('\n', ' ');
      final res = await _query(apiKey, '''
        query { search(query: "$safeQuery", query_type: "Book", per_page: $perPage) { results } }
      ''');
      final raw = res['search']?['results'];
      if (raw is Map) {
        final hits = raw['hits'] as List? ?? [];
        return hits.map((h) {
          final doc = h['document'] as Map<String, dynamic>? ?? {};
          return HardcoverBook.fromJson(doc);
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<CurrentlyReadingEntry?> getProgressForBook(String apiKey, int bookId) async {
    try {
      final res = await _query(apiKey, '''
        { me { user_books(where: {book_id: {_eq: $bookId}}, limit: 1) {
          id status_id
          book { id title slug }
          user_book_reads(order_by: {started_at: desc}, limit: 1) {
            id edition_id progress_seconds progress_pages started_at
          }
        } } }
      ''');
      final list = ((res['me'] as List?)?.firstOrNull?['user_books'] as List?) ?? [];
      if (list.isEmpty) return null;
      final ub = list[0] as Map<String, dynamic>;
      final bookJson = ub['book'] as Map<String, dynamic>?;
      if (bookJson == null) return null;
      final reads = ub['user_book_reads'] as List? ?? [];
      final read = reads.isNotEmpty ? reads[0] as Map<String, dynamic>? : null;
      return CurrentlyReadingEntry(
        userBookId: ub['id'] as int,
        book: HardcoverBook(
          id: bookJson['id'] as int,
          title: bookJson['title'] ?? '',
          slug: bookJson['slug'] as String?,
        ),
        readId: read?['id'] as int?,
        editionId: read?['edition_id'] as int?,
        progressSeconds: read?['progress_seconds'] as int?,
        progressPages: read?['progress_pages'] as int?,
        startedAt: read?['started_at'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProgress(String apiKey, int readId, int editionId, int progressSeconds) async {
    try {
      final res = await _query(apiKey, '''
        mutation {
          update_user_book_read(id: $readId, object: {
            edition_id: $editionId
            progress_seconds: $progressSeconds
          }) {
            error
            user_book_read { id progress_seconds edition_id }
          }
        }
      ''');
      final updated = res['update_user_book_read'];
      print('[HardcoverApiService] updateProgress response: updated=$updated');
      if (updated == null || updated['error'] != null) {
        print('[HardcoverApiService] updateProgress: error=${updated?['error']}');
        return false;
      }
      // If the record was deleted, user_book_read will be null.
      final read = updated['user_book_read'] as Map<String, dynamic>?;
      final ok = read != null && read['id'] != null;
      print('[HardcoverApiService] updateProgress: ok=$ok read=$read');
      return ok;
    } catch (e) {
      print('[HardcoverApiService] updateProgress exception: $e');
      return false;
    }
  }

  /// Set the user_book to Want to Read (status_id: 1).
  Future<bool> setWantToRead(String apiKey, int userBookId) async {
    try {
      final res = await _query(apiKey, '''
        mutation {
          update_user_book(id: $userBookId, object: { status_id: 1 }) {
            error
            user_book { id status_id }
          }
        }
      ''');
      final updated = res['update_user_book'];
      return updated != null && updated['error'] == null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setReadingStatus(String apiKey, int userBookId) async {
    try {
      final res = await _query(apiKey, '''
        mutation {
          update_user_book(id: $userBookId, object: { status_id: 2 }) {
            error
            user_book { id status_id }
          }
        }
      ''');
      final updated = res['update_user_book'];
      return updated != null && updated['error'] == null;
    } catch (_) {
      return false;
    }
  }

  /// Find an audiobook edition (has audio_seconds) for the given book.
  Future<int?> findAudiobookEdition(String apiKey, int bookId) async {
    try {
      final res = await _query(apiKey, '''
        query {
          editions(
            where: {_and: [{book_id: {_eq: $bookId}}, {audio_seconds: {_is_null: false}}]}
            limit: 1
          ) { id audio_seconds }
        }
      ''');
      final editionsList = res['editions'] as List? ?? [];
      if (editionsList.isEmpty) return null;
      return (editionsList.first as Map<String, dynamic>)['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Add a book to the user's library (Want to Read status).
  /// Returns the new user_book id, or null on failure.
  Future<int?> addBookToLibrary(String apiKey, int bookId) async {
    try {
      final res = await _query(apiKey, '''
        mutation {
          insert_user_book(object: { book_id: $bookId, status_id: 1 }) {
            error
            user_book { id status_id }
          }
        }
      ''');
      final inserted = res['insert_user_book'];
      if (inserted == null || inserted['error'] != null) return null;
      return (inserted['user_book'] as Map<String, dynamic>?)?['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Delete a user_book from the user's library.
  Future<bool> deleteUserBook(String apiKey, int userBookId) async {
    try {
      final res = await _query(apiKey, '''
        mutation {
          delete_user_book(id: $userBookId) {
            user_book { id }
          }
        }
      ''');
      return res['delete_user_book']?['user_book']?['id'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Set the user_book to Currently Reading (status_id: 2) and return the
  /// auto-created user_book_read record's id and edition_id.
  Future<({int readId, int? editionId})?> setCurrentlyReading(String apiKey, int userBookId) async {
    try {
      final res = await _query(apiKey, '''
        mutation {
          update_user_book(id: $userBookId, object: { status_id: 2 }) {
            error
            user_book { id status_id }
          }
        }
      ''');
      final updated = res['update_user_book'];
      if (updated == null || updated['error'] != null) return null;

      return fetchLatestUserBookRead(apiKey, userBookId);
    } catch (_) {
      return null;
    }
  }

  /// Full flow: ensure the book is in the user's library as Currently Reading.
  /// Returns the same info as [getProgressForBook], or null on failure.
  Future<CurrentlyReadingEntry?> ensureBookInLibrary(String apiKey, HardcoverBook book) async {
    try {
      // 1. Find audiobook edition
      final editionId = await findAudiobookEdition(apiKey, book.id);

      // 2. Add book to library
      final userBookId = await addBookToLibrary(apiKey, book.id);
      if (userBookId == null) return null;

      // 3. Set as Currently Reading
      final readInfo = await setCurrentlyReading(apiKey, userBookId);
      if (readInfo == null) return null;

      return CurrentlyReadingEntry(
        userBookId: userBookId,
        book: book,
        readId: readInfo.readId,
        editionId: readInfo.editionId ?? editionId,
        progressSeconds: 0,
        progressPages: null,
        startedAt: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch the latest user_book_read record for a user_book.
  /// Returns {readId, editionId} or null.
  Future<({int readId, int? editionId})?> fetchLatestUserBookRead(String apiKey, int userBookId) async {
    try {
      final readRes = await _query(apiKey, '''
        query {
          user_books_by_pk(id: $userBookId) {
            user_book_reads(order_by: {started_at: desc}, limit: 1) {
              id edition_id
            }
          }
        }
      ''');
      final ub = readRes['user_books_by_pk'] as Map<String, dynamic>?;
      final reads = ub?['user_book_reads'] as List? ?? [];
      if (reads.isEmpty) return null;
      final read = reads.first as Map<String, dynamic>;
      return (
        readId: read['id'] as int,
        editionId: read['edition_id'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _query(String apiKey, String query) async {
    final response = await _dio.post(_endpoint,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {'query': query},
    );
    final body = response.data as Map<String, dynamic>;
    if (body.containsKey('errors')) {
      throw Exception(body['errors']);
    }
    return body['data'] as Map<String, dynamic>;
  }
}
