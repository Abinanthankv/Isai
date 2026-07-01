# Hardcover API Reference

**Endpoint:** `https://api.hardcover.app/v1/graphql`  
**Auth:** Bearer token in `Authorization` header  
**Content-Type:** `application/json`  
**User-Agent:** `Isai-Test/1.0`

## Auth Setup

```dart
final dio = Dio(BaseOptions(
  headers: {'Content-Type': 'application/json', 'User-Agent': 'Isai-Test/1.0'},
));

final response = await dio.post(
  'https://api.hardcover.app/v1/graphql',
  options: Options(headers: {'Authorization': 'Bearer <API_KEY>'}),
  data: {'query': query},
);
```

The API key is a JWT — check expiry if calls stop working.

---

## Queries

### 1. Get Current User

```graphql
{ me { id username } }
```

Response: `me` is a **list** — access via `data['me'][0]['id']`.

### 2. Search Books

```graphql
query {
  search(query: "Dungeon Crawler Carl", query_type: "Book", per_page: 5) {
    results
  }
}
```

The `results` field returns a **JSON blob** (not typed GraphQL fields). Parse with:

```dart
List<Map<String, dynamic>> extractHits(Map<String, dynamic> data) {
  final results = data['search']?['results'] as Map<String, dynamic>?;
  if (results == null) return [];
  final hits = results['hits'] as List? ?? [];
  return hits.map((h) => Map<String, dynamic>.from(h['document'] ?? {})).toList();
}
```

**Available document fields:** `id`, `title`, `slug`, `author_names`, `rating`, `ratings_count`, `genres`, `has_audiobook`, `pages`, `release_date`, `series_names`, `featured_series_position`, `description`, `image`, `cover_color`, `tags`, `moods`, `content_warnings`, `isbns`, `alternative_titles`.

### 3. Book by Primary Key

```graphql
{ books_by_pk(id: 446681) { id title default_cover_edition_id } }
```

Note: `default_cover_edition_id` is typically a **print/ebook edition**, not audiobook.

### 4. List Editions with Audio

```graphql
query {
  editions(
    where: {_and: [{book_id: {_eq: 446681}}, {audio_seconds: {_is_null: false}}]}
    limit: 5
  ) { id audio_seconds }
}
```

**Valid edition fields:** `id`, `audio_seconds`, `book_id`. (Field `format` does NOT exist on the `editions` type.)

### 5. Edition by PK

```graphql
{ editions_by_pk(id: 32146161) { id audio_seconds book_id } }
```

### 6. Currently Reading List

```graphql
{ me { user_books(where: {status_id: {_eq: 2}}) {
  id status_id
  book { id title slug has_audiobook }
  user_book_reads(order_by: {started_at: desc}, limit: 1) {
    id edition_id progress_seconds progress_pages started_at
  }
} } }
```

**Status IDs:**
| ID | Status |
|----|--------|
| 1  | Want to Read |
| 2  | Currently Reading |
| 3  | Read |

### 7. Specific User Book

```graphql
{ user_books_by_pk(id: 15847544) {
  user_book_reads(order_by: {started_at: desc}, limit: 1) { id progress_seconds }
} }
```

---

## Mutations

### 1. Add Book to Library

```graphql
mutation {
  insert_user_book(object: { book_id: 446681, status_id: 1 }) {
    error
    user_book { id status_id }
  }
}
```

Returns `user_book.id` = the `ub_id` needed for all future mutations.  
**Always check `error` field** — if non-null the mutation failed.

### 2. Change Book Status

```graphql
mutation {
  update_user_book(id: 15847544, object: { status_id: 2 }) {
    error
    user_book { id status_id }
  }
}
```

### 3. Set Reading Progress

**Important:** When you set status to `Currently Reading` (status_id: 2), Hardcover **auto-creates** a `user_book_read` record. Do NOT try to insert one — it will fail with a webhook error. Instead, find and update the auto-created record:

```dart
// 1. Change status to Reading (this auto-creates a user_book_read)
mutation { update_user_book(id: $ubId, object: { status_id: 2 }) { error ... } }

// 2. Find the auto-created read record
query { user_books_by_pk(id: $ubId) {
  user_book_reads(order_by: {started_at: desc}, limit: 1) { id edition_id }
} }

// 3. Update progress on that record
mutation {
  update_user_book_read(id: $readId, object: {
    edition_id: 32146161        # audiobook edition (NOT default_cover_edition_id!)
    progress_seconds: 18000     # 5 hours
    # or progress_pages: 50     # page-based progress
  }) {
    error
    user_book_read { id edition_id progress_seconds }
  }
}
```

**For audiobook progress**, you MUST use an edition that has `audio_seconds > 0`, otherwise the app won't display the progress. Find the correct audiobook edition via the `editions` query.

### 4. Remove from Library

```graphql
mutation { delete_user_book(id: 15847544) { user_book { id } } }
```

---

## Critical Gotchas

1. **Search `results` is a JSON blob** — must use `extractHits()` helper (see above). Do NOT try to cast `results` directly to `List`.

2. **`me` returns a list** — access via `data['me'][0]`, not `data['me']`.

3. **Don't use `insert_user_book_read`** — the webhook that auto-creates read records on status change conflicts with manual inserts. Always use `update_user_book_read` on the auto-created record.

4. **Audiobook edition vs print edition** — `default_cover_edition_id` on a book is usually a print/ebook edition (no `audio_seconds`). For audiobook progress, query `editions` filtered by `audio_seconds: {_is_null: false}` and use that edition_id.

5. **The `format` field does NOT exist** on the `editions` type. Use `audio_seconds` to detect audiobooks.

---

## Example: Full Flow (Audiobook Progress)

```
1. search("Dungeon Crawler Carl")        → get book_id=446681
2. editions(where: book_id=446681, audio_seconds not null) → pick edition_id=32146161
3. insert_user_book(book_id=446681, status_id=1) → get ub_id
4. update_user_book(id=ub_id, status_id=2) → auto-creates user_book_read
5. query user_book_read → get read_id
6. update_user_book_read(id=read_id, edition_id=32146161, progress_seconds=18000)
7. Verify: query me → user_books where status_id=2
```

See `scratch/test_dcc_progress.dart` for the working implementation.
