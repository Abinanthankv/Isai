import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../music/presentation/music_providers.dart';
import '../data/hardcover_api_service.dart';

final hardcoverApiServiceProvider = Provider<HardcoverApiService>((ref) {
  return HardcoverApiService();
});

final hardcoverCurrentlyReadingProvider = FutureProvider<List<CurrentlyReadingEntry>>((ref) async {
  final apiKey = ref.watch(settingsProvider.select((s) => s.hardcoverApiKey));
  if (apiKey.isEmpty) return [];
  final service = ref.watch(hardcoverApiServiceProvider);
  final result = await service.getCurrentlyReading(apiKey);
  return result;
});

/// Normalize a book title for Hardcover search by stripping common cruft.
String normalizeBookTitle(String title) {
  var clean = title;
  clean = clean.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
  clean = clean.replaceAll(RegExp(r'[._\-]'), ' ');
  clean = clean.replaceAll(RegExp(r'\[[^\]]*\]'), '');
  clean = clean.replaceAll(RegExp(r'\([^)]*\)'), '');
  clean = clean.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '');
  clean = clean.replaceAll(RegExp(r':.*$'), '');
  clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  return clean;
}

/// Check whether [searchTitle] loosely matches [bookTitle] (case-insensitive).
bool titleMatches(String bookTitle, String searchTitle) {
  final a = bookTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
  final b = searchTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
  return a.contains(b) || b.contains(a);
}

/// Check whether the local author name loosely matches the Hardcover author (case-insensitive).
bool authorMatches(String? localAuthor, String? hcAuthor) {
  if (localAuthor == null || hcAuthor == null) return false;
  final a = localAuthor.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
  final b = hcAuthor.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
  return a.contains(b) || b.contains(a);
}

/// From a list of title-matching results, pick the best match.
/// Prefers (in order): exact normalized match, match without colon (no subtitle),
/// then the first result.
HardcoverBook pickBestTitleMatch(List<HardcoverBook> matches, String normalizedTitle) {
  final cleanSearch = normalizedTitle.toLowerCase().trim();
  // Exact match
  for (final b in matches) {
    if (normalizeBookTitle(b.title).toLowerCase().trim() == cleanSearch) return b;
  }
  // Prefer match without colon (no subtitle)
  for (final b in matches) {
    if (!b.title.contains(':')) return b;
  }
  return matches.first;
}

final hardcoverBookProgressProvider = FutureProvider.family<CurrentlyReadingEntry?, ({String title, String author})>((ref, params) async {
  final apiKey = ref.watch(settingsProvider.select((s) => s.hardcoverApiKey));
  if (apiKey.isEmpty) return null;
  final service = ref.watch(hardcoverApiServiceProvider);

  final normalizedTitle = normalizeBookTitle(params.title);
  if (normalizedTitle.isEmpty) return null;

  final results = await service.searchBooks(apiKey, normalizedTitle, perPage: 8);
  if (results.isEmpty) return null;

  // Find best matching book
  final authorMatch = results.where((b) =>
    titleMatches(normalizedTitle, b.title) &&
    authorMatches(params.author, b.author)
  ).toList();
  final matchedBook = authorMatch.isNotEmpty
      ? pickBestTitleMatch(authorMatch, normalizedTitle)
      : (() {
          final titleMatch = results.where((b) => titleMatches(normalizedTitle, b.title)).toList();
          return titleMatch.isNotEmpty ? pickBestTitleMatch(titleMatch, normalizedTitle) : null;
        })();
  if (matchedBook == null) return null;

  // Check if already in user's library
  var entry = await service.getProgressForBook(apiKey, matchedBook.id);
  if (entry != null && entry.progressHours > 0) return entry;

  // Not in library → auto-add as Currently Reading
  entry = await service.ensureBookInLibrary(apiKey, matchedBook);
  return entry;
});

class HardcoverCurrentlyReadingSection extends ConsumerWidget {
  const HardcoverCurrentlyReadingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    if (!settings.hardcoverHasKey) return const SizedBox.shrink();

    final readingAsync = ref.watch(hardcoverCurrentlyReadingProvider);
    return readingAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Hardcover: No books currently reading',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          );
        }
        return _buildSection(
          context,
          title: 'Hardcover Currently Reading (${entries.length})',
          child: SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _buildBookCard(context, ref, entry);
              },
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text('Hardcover: $err', style: const TextStyle(fontSize: 12, color: Colors.redAccent))),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, WidgetRef ref, CurrentlyReadingEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showProgressSheet(context, ref, entry),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 120,
                color: isDark ? Colors.white12 : Colors.black12,
                child: entry.book.artworkUrl != null
                    ? CachedNetworkImage(imageUrl: entry.book.artworkUrl!, fit: BoxFit.cover)
                    : Icon(Icons.book, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
            ),
            if (entry.progressHours > 0)
              Text(
                '${entry.progressHours.toStringAsFixed(1)}h',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
              ),
          ],
        ),
      ),
    );
  }

  void _showProgressSheet(BuildContext context, WidgetRef ref, CurrentlyReadingEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final hoursCtl = TextEditingController(text: entry.progressHours > 0 ? entry.progressHours.toStringAsFixed(1) : '');
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.book.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (entry.book.author != null)
                Text(entry.book.author!, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 16),
              Text('Current: ${entry.progressHours.toStringAsFixed(1)}h'),
              const SizedBox(height: 8),
              TextField(
                controller: hoursCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Hours',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final hours = double.tryParse(hoursCtl.text.trim());
                    if (hours == null || hours < 0) return;
                    final secs = (hours * 3600).round();
                    final apiKey = ref.read(settingsProvider).hardcoverApiKey;
                    final service = ref.read(hardcoverApiServiceProvider);
                    if (entry.readId != null && entry.editionId != null) {
                      await service.updateProgress(apiKey, entry.readId!, entry.editionId!, secs);
                      await service.setReadingStatus(apiKey, entry.userBookId);
                      ref.invalidate(hardcoverCurrentlyReadingProvider);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Update Progress'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        child,
        const SizedBox(height: 8),
      ],
    );
  }
}
