// Debug script for Hardcover API
import 'dart:convert';
import 'package:dio/dio.dart';

const String endpoint = 'https://api.hardcover.app/v1/graphql';
String _apiKey = "";
final Dio _dio = Dio(BaseOptions(
  headers: {'Content-Type': 'application/json', 'User-Agent': 'Isai-Debug/1.0'},
));

void main() async {
  _apiKey = "eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJIYXJkY292ZXIiLCJ2ZXJzaW9uIjoiOCIsImp0aSI6IjM5OTMxZTQzLTlhMmItNGZjYS1iOWQ2LTY0MzRkYzljNWQ4NiIsImFwcGxpY2F0aW9uSWQiOjIsInN1YiI6IjEyMTUwOSIsImF1ZCI6IjEiLCJpZCI6IjEyMTUwOSIsImxvZ2dlZEluIjp0cnVlLCJpYXQiOjE3ODI4MjQ0MjEsImV4cCI6MTgxNDM2MDQyMSwiaHR0cHM6Ly9oYXN1cmEuaW8vand0L2NsYWltcyI6eyJ4LWhhc3VyYS1hbGxvd2VkLXJvbGVzIjpbInVzZXIiXSwieC1oYXN1cmEtZGVmYXVsdC1yb2xlIjoidXNlciIsIngtaGFzdXJhLXJvbGUiOiJ1c2VyIiwiWC1oYXN1cmEtdXNlci1pZCI6IjEyMTUwOSJ9LCJ1c2VyIjp7ImlkIjoxMjE1MDl9fQ.LPTaUn1hCnQB61EBw8pqoN-TO6l6YeKvoLM_gYzj58w";
  print('API key loaded\n');

  void p(String label, dynamic d) {
    print('$label:\n${const JsonEncoder.withIndent("  ").convert(d)}\n');
  }

  int passed = 0, failed = 0;
  void check(String name, bool ok, [String? detail]) {
    print('${ok ? "✅" : "❌"} $name${detail != null ? ": $detail" : ""}');
    if (ok) passed++; else failed++;
  }

  // ── 1. me ──
  var res = await _q('{ me { id username } }');
  final uid = res['me'][0]['id'] as int;
  check('me { id, username }', uid > 0, 'userId=$uid');

  // ── 2. search books ──
  res = await _q('''
    query {
      search(query: "Sherlock Holmes", query_type: "Book", per_page: 3) {
        results
      }
    }
  ''');
  var raw = res['search']?['results'];
  print('   raw results type: ${raw.runtimeType}');
  if (raw is List) {
    check('search books', raw.isNotEmpty, 'found ${raw.length}');
    if (raw.isNotEmpty) print('   First: id=${raw[0]['id']} title="${raw[0]['title']}"');
  } else if (raw is Map) {
    check('search books', raw.isNotEmpty, 'map with ${raw.length} keys: ${raw.keys}');
    print('   First entry: ${raw[raw.keys.first]}');
  } else {
    check('search books', false, 'unexpected type: $raw');
  }

  // ── 3. search with fields ──
  res = await _q('''
    query {
      search(query: "Sherlock Holmes", query_type: "Book", per_page: 3) {
        results {
          id
          title
          slug
          rating
          ratings_count
          author_names
          genres
          has_audiobook
          audio_seconds
        }
      }
    }
  ''');
  final detailed = res['search']?['results'] as List? ?? [];
  check('search with fields', detailed.isNotEmpty);
  if (detailed.isNotEmpty) {
    final b = detailed[0];
    print('   "${b['title']}" by ${b['author_names']} ★${b['rating']} (${b['ratings_count']}) '
        'genre=${b['genres']} audiobook=${b['has_audiobook']}');
  }

  // ── 4. user_books (currently reading) ──
  res = await _q('{ me { user_books(where: {status_id: {_eq: 2}}) { id status_id book { id title } } } }');
  final curReading = ((res['me']?[0]?['user_books'] as List?) ?? []);
  check('user_books (reading)', true, '${curReading.length} books');
  int testBookId = 0;
  int testEditionId = 0;
  if (curReading.isNotEmpty) {
    testBookId = curReading[0]['book']['id'] as int;
    // get edition
    res = await _q('{ books_by_pk(id: $testBookId) { id title default_cover_edition_id } }');
    testEditionId = res['books_by_pk']?['default_cover_edition_id'] as int? ?? 0;
    check('books_by_pk', testEditionId > 0, 'edition_id=$testEditionId');
  }

  // ── 5. search by author ──
  res = await _q('''
    query {
      search(query: "Stephen King", query_type: "Book", per_page: 3) {
        results { id title slug rating ratings_count author_names }
      }
    }
  ''');
  final authorResults = res['search']?['results'] as List? ?? [];
  check('search by author', authorResults.isNotEmpty, 'found ${authorResults.length}');

  // ── 6. mutation: add book to library ──
  if (testBookId > 0) {
    res = await _q('''
      mutation {
        insert_user_book(object: { book_id: $testBookId, status_id: 1 }) {
          error
          user_book { id status_id }
        }
      }
    ''');
    final inserted = res['insert_user_book'];
    final ok = inserted != null && inserted['error'] == null;
    check('insert_user_book', ok, ok ? 'ub_id=${inserted['user_book']['id']}' : '${inserted!['error']}');

    if (ok) {
      final ubId = inserted['user_book']['id'] as int;

      // ── 7. update_user_book (status: Reading) ──
      res = await _q('''
        mutation {
          update_user_book(id: $ubId, object: { status_id: 2 }) {
            error
            user_book { id status_id }
          }
        }
      ''');
      final updated = res['update_user_book'];
      check('update_user_book → Reading', updated != null && updated['error'] == null, 'status=${updated?['user_book']?['status_id']}');

      // ── 8. insert_user_book_read ──
      res = await _q('''
        mutation {
          insert_user_book_read(
            user_book_id: $ubId
            user_book_read: {
              edition_id: $testEditionId
              started_at: "2026-06-30"
              progress_pages: 25
            }
          ) {
            error
            user_book_read { id progress_pages }
          }
        }
      ''');
      final readInsert = res['insert_user_book_read'];
      if (readInsert != null && readInsert['error'] == null) {
        check('insert_user_book_read', true, 'read_id=${readInsert['user_book_read']['id']} pages=25');

        // ── 9. update_user_book_read ──
        final readId = readInsert['user_book_read']['id'] as int;
        res = await _q('''
          mutation {
            update_user_book_read(id: $readId, object: { progress_pages: 50 }) {
              error
              user_book_read { id progress_pages }
            }
          }
        ''');
        final readUpdate = res['update_user_book_read'];
        check('update_user_book_read', readUpdate != null && readUpdate['error'] == null, 'pages=50');
      } else {
        check('insert_user_book_read', false, '${readInsert?['error'] ?? "no response"}');
      }

      // ── 10. delete_user_book ──
      res = await _q('mutation { delete_user_book(id: $ubId) { user_book { id } } }');
      check('delete_user_book', res['delete_user_book'] != null, 'deleted ub_id=$ubId');
    }
  }

  print('\n═══════════════════════════════');
  print('RESULTS: $passed passed, $failed failed');
  print('═══════════════════════════════');
}

Future<Map<String, dynamic>> _q(String query) async {
  try {
    final response = await _dio.post(endpoint,
      options: Options(headers: {'Authorization': 'Bearer $_apiKey'}),
      data: {'query': query},
    );
    final body = response.data as Map<String, dynamic>;
    if (body.containsKey('errors')) {
      return {'_error': 'GraphQL: ${(body['errors'] as List).map((e) => e['message']).join("; ")}'};
    }
    return body['data'] as Map<String, dynamic>;
  } catch (e) {
    return {'_error': e.toString()};
  }
}
