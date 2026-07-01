import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:isai/core/theme/apple_music_theme.dart';
import 'package:isai/core/theme/glassmorphism.dart';
import 'package:isai/core/database/database.dart';
import '../../music/presentation/music_providers.dart';
import 'audiobook_providers.dart';
import 'hardcover_section.dart';
import '../data/hardcover_api_service.dart';
import '../data/audiobook_models.dart';
import '../data/audiobook_repository.dart';
import 'audiobook_now_playing_screen.dart';
import 'epub_reader_screen.dart';
import 'package:isai/main.dart'; // For audioHandler
import 'package:audio_service/audio_service.dart';

/// Provider to track if the chapters list is expanded for a given audiobook ID.
final chaptersExpandedProvider = StateProvider.family<bool, String>((ref, bookId) => false);

/// Provider to track which tab is selected inside the progress card: 'listening' or 'reading'
final selectedProgressTabProvider = StateProvider.family<String, String>((ref, bookId) => 'listening');

class AudiobookDetailScreen extends ConsumerWidget {
  final AudiobookResult book;

  const AudiobookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalBook = book.id.startsWith('torrent:')
        ? book.copyWith(id: AudiobookRepository.normalizeBookId(book.id))
        : book;

    final _chaptersExpanded = ref.watch(chaptersExpandedProvider(normalBook.id));

    final chaptersAsync = ref.watch(bookChaptersProvider(normalBook.id));
    final detailsAsync = ref.watch(bookDetailsProvider(normalBook.id));
    final chapterProgressAsync = ref.watch(bookChapterProgressProvider(normalBook.id));
    final torrentStatusAsync = normalBook.id.startsWith('torrent:') 
        ? ref.watch(torrentStatusProvider(normalBook.id)) 
        : null;
    final epubPathAsync = ref.watch(bookEpubPathProvider(normalBook.id));
    final epubProgressAsync = ref.watch(epubProgressProvider(normalBook.id));

    // Build a map of chapterIndex -> DbAudiobookProgress for quick lookup
    final Map<int, DbAudiobookProgress> chapterProgressMap = {};
    final progressList = chapterProgressAsync.value;
    if (progressList != null) {
      for (final progress in progressList) {
        chapterProgressMap[progress.chapterIndex] = progress;
      }
    }
    final hasProgress = chapterProgressMap.isNotEmpty;
    final epubPath = epubPathAsync.value;
    final epubProgress = epubProgressAsync.value;
    
    // Use enriched details if available, else fallback to passed book
    final displayBook = detailsAsync.value ?? normalBook;
    final downloadState = ref.watch(audiobookDownloadProvider)[displayBook.id];

    // Only search torrents for books not already local or torrent-based
    final bool needsTorrentSearch = !normalBook.id.startsWith('local:') && !normalBook.id.startsWith('torrent:');
    final torrentSearchQuery = needsTorrentSearch
        ? _sanitizeTorrentQuery(displayBook.title, displayBook.author)
        : '';
    final torrentSearchAsync = needsTorrentSearch
        ? ref.watch(bookTorrentSearchProvider(torrentSearchQuery))
        : null;

    // Proactively cache metadata to ensure the DB registers the correct title/author immediately.
    // We cache displayBook which contains enriched details if loaded, rather than normalBook.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(audiobookRepositoryProvider);
      final chaptersAsync = ref.read(bookChaptersProvider(normalBook.id));
      final cachedChapters = chaptersAsync.asData?.value;
      repo.cacheBookMetadata(displayBook, chapters: cachedChapters);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Header with Blurred Background
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (displayBook.artworkUrl != null) ...[
                    _buildArtworkImage(displayBook.artworkUrl, isBlur: true, context: context),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        margin: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildArtworkImage(displayBook.artworkUrl, isBlur: false, context: context),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.book,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Book Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AUTHOR',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayBook.author,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (displayBook.narrator != null && displayBook.narrator!.isNotEmpty) ...[
                        const SizedBox(
                          height: 32,
                          child: VerticalDivider(width: 24, thickness: 1),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NARRATOR',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayBook.narrator!,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (displayBook.rating != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                          ...List.generate(5, (index) {
                            final starVal = index + 1;
                            if (displayBook.rating! >= starVal) {
                              return const Icon(Icons.star_rounded, color: Colors.amber, size: 18);
                            } else if (displayBook.rating! >= starVal - 0.5) {
                              return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 18);
                            } else {
                              return const Icon(Icons.star_outline_rounded, color: Colors.amber, size: 18);
                            }
                          }),
                        const SizedBox(width: 8),
                        Text(
                          displayBook.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (displayBook.ratingCount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${displayBook.ratingCount} ratings)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (displayBook.previewUrl != null && displayBook.previewUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AudiobookPreviewWidget(previewUrl: displayBook.previewUrl!),
                  ],
                   if (displayBook.id.startsWith('local:') || displayBook.id.startsWith('torrent:')) ...[
                     const SizedBox(height: 12),
                     Row(
                       children: [
                         Expanded(
                           child: OutlinedButton.icon(
                             onPressed: () => _showMetadataSearchSheet(context, ref, displayBook),
                             icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                             label: const Text('Fetch Metadata'),
                             style: OutlinedButton.styleFrom(
                               visualDensity: VisualDensity.compact,
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                             ),
                           ),
                         ),
                         const SizedBox(width: 8),
                         Expanded(
                           child: OutlinedButton.icon(
                             onPressed: () async {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Re-extracting chapters from files...')),
                               );
                               final repo = ref.read(audiobookRepositoryProvider);
                               print('[RefreshChapters] Refreshing chapters for: ${displayBook.id}');
                               final localDir = await repo.getLocalBookDirectoryForBackup(displayBook.id);
                               print('[RefreshChapters] Local directory: $localDir');
                               if (localDir != null) {
                                 final metaFile = File(p.join(localDir, 'metadata.json'));
                                 if (await metaFile.exists()) {
                                   print('[RefreshChapters] Deleting existing metadata.json');
                                   await metaFile.delete();
                                 }
                               }
                               
                                ref.invalidate(bookChaptersProvider(displayBook.id));
                                ref.invalidate(bookDetailsProvider(displayBook.id));
                                ref.invalidate(bookChapterProgressProvider(displayBook.id));
                                
                                try {
                                  final freshChapters = await repo.getBookChapters(displayBook.id, forceParse: true);
                                  print('[RefreshChapters] Scanned chapters count: ${freshChapters.length}');
                                  await repo.cacheBookMetadata(displayBook);
                                  if (freshChapters.isNotEmpty && localDir != null) {
                                    final metaFile = File(p.join(localDir, 'metadata.json'));
                                    final chaptersList = freshChapters.map((ch) => {
                                      'id': ch.id,
                                      'title': ch.title,
                                      'chapterNumber': ch.chapterNumber,
                                      'startTimeMillis': ch.startTimeMillis,
                                      'durationMillis': ch.durationMillis,
                                      'streamUrl': ch.streamUrl,
                                    }).toList();
                                    Map<String, dynamic> metaMap = {};
                                    if (await metaFile.exists()) {
                                      try {
                                        metaMap = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
                                      } catch (_) {}
                                    }
                                    metaMap['chapters'] = chaptersList;
                                    metaMap['bookId'] = displayBook.id;
                                    metaMap['title'] = displayBook.title;
                                    metaMap['author'] = displayBook.author;
                                    if (displayBook.totalChapters != null) metaMap['totalChapters'] = displayBook.totalChapters;
                                   await metaFile.writeAsString(jsonEncode(metaMap));
                                   }
                                   if (!context.mounted) return;
                                   ref.invalidate(bookChaptersProvider(displayBook.id));
                                   print('[RefreshChapters] Successfully regenerated metadata.json and invalidated provider');
                                } catch (e) {
                                  print('[RefreshChapters] Error rebuilding chapters: $e');
                                }
                             },
                             icon: const Icon(Icons.refresh_rounded, size: 18),
                             label: const Text('Refresh Chapters'),
                             style: OutlinedButton.styleFrom(
                               visualDensity: VisualDensity.compact,
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                             ),
                           ),
                         ),
                       ],
                     ),
                   ],
                    const SizedBox(height: 12),
                    // Plan to Read button — hidden if book is already in library
                    Consumer(builder: (context, ref, _) {
                      final inLibrary = ref.watch(isBookInLibraryProvider(normalBook.id)).asData?.value ?? false;
                      if (inLibrary) return const SizedBox.shrink();
                      return ref.watch(isBookInWishlistProvider(normalBook.id)).when(
                        data: (inWishlist) => Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await toggleWishlist(displayBook);
                                    if (!context.mounted) return;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(inWishlist ? 'Removed from Plan to Read' : 'Added to Plan to Read')),
                                      );
                                    }
                                    // When adding to Plan to Read, also sync to Hardcover as Want to Read
                                    if (!inWishlist) {
                                      final settings = ref.read(settingsProvider);
                                      if (settings.hardcoverHasKey) {
                                        final service = ref.read(hardcoverApiServiceProvider);
                                        final repo = ref.read(audiobookRepositoryProvider);
                                        final normalizedTitle = normalizeBookTitle(displayBook.title);
                                        print('[PlanToRead] Hardcover sync: title="${displayBook.title}" author="${displayBook.author}" normalized="$normalizedTitle"');
                                        if (normalizedTitle.isNotEmpty) {
                                          try {
                                            final results = await service.searchBooks(settings.hardcoverApiKey, normalizedTitle, perPage: 8);
                                            print('[PlanToRead] searchBooks returned ${results.length} results');
                                            HardcoverBook? matched;
                                            final authorMatch = results.where((b) =>
                                              titleMatches(normalizedTitle, b.title) &&
                                              authorMatches(displayBook.author, b.author)
                                            ).toList();
                                            if (authorMatch.isNotEmpty) {
                                              matched = pickBestTitleMatch(authorMatch, normalizedTitle);
                                              print('[PlanToRead] author+title matched: id=${matched.id} "${matched.title}"');
                                            } else {
                                              final titleMatch = results.where((b) => titleMatches(normalizedTitle, b.title)).toList();
                                              print('[PlanToRead] titleMatch count=${titleMatch.length} (no author match)');
                                              if (titleMatch.isNotEmpty) matched = pickBestTitleMatch(titleMatch, normalizedTitle);
                                            }
                                            if (matched != null) {
                                              print('[PlanToRead] matched book id=${matched.id} title="${matched.title}"');
                                              final existing = await service.getProgressForBook(settings.hardcoverApiKey, matched.id);
                                              print('[PlanToRead] existing entry=$existing');
                                              if (existing == null) {
                                                final userBookId = await service.addBookToLibrary(settings.hardcoverApiKey, matched.id);
                                                print('[PlanToRead] addBookToLibrary userBookId=$userBookId');
                                                if (userBookId != null) {
                                                  await repo.saveHardcoverMapping(
                                                    displayBook.id, userBookId, null, null,
                                                  );
                                                  print('[PlanToRead] saved mapping: bookId=${displayBook.id} userBookId=$userBookId');
                                                }
                                              } else {
                                                print('[PlanToRead] book already in library (userBookId=${existing.userBookId}), switching to Want to Read');
                                                final ok = await service.setWantToRead(settings.hardcoverApiKey, existing.userBookId);
                                                print('[PlanToRead] setWantToRead ok=$ok');
                                                if (ok) {
                                                  await repo.saveHardcoverMapping(
                                                    displayBook.id, existing.userBookId, null, null,
                                                  );
                                                  print('[PlanToRead] saved mapping (switched): bookId=${displayBook.id} userBookId=${existing.userBookId}');
                                                }
                                              }
                                            } else {
                                              print('[PlanToRead] no title match found on Hardcover');
                                            }
                                          } catch (e) {
                                            print('[PlanToRead] error: $e');
                                          }
                                        }
                                      } else {
                                        print('[PlanToRead] Hardcover not configured, skipping');
                                      }
                                    } else {
                                      print('[PlanToRead] removing from wishlist, also removing from Hardcover');
                                      final settings = ref.read(settingsProvider);
                                      if (settings.hardcoverHasKey) {
                                        final service = ref.read(hardcoverApiServiceProvider);
                                        final repo = ref.read(audiobookRepositoryProvider);
                                        final userBookId = await repo.getHardcoverUserBookId(displayBook.id);
                                        if (userBookId != null) {
                                          print('[PlanToRead] found userBookId=$userBookId, deleting from Hardcover');
                                          final ok = await service.deleteUserBook(settings.hardcoverApiKey, userBookId);
                                          print('[PlanToRead] deleteUserBook ok=$ok');
                                        } else {
                                          print('[PlanToRead] no mapping found, searching on Hardcover');
                                          try {
                                            final normalizedTitle = normalizeBookTitle(displayBook.title);
                                            if (normalizedTitle.isNotEmpty) {
                                              final results = await service.searchBooks(settings.hardcoverApiKey, normalizedTitle, perPage: 5);
                                              final matched = results.isNotEmpty ? pickBestTitleMatch(results, normalizedTitle) : null;
                                              if (matched != null) {
                                                final existing = await service.getProgressForBook(settings.hardcoverApiKey, matched.id);
                                                if (existing != null) {
                                                  print('[PlanToRead] found via search userBookId=${existing.userBookId}, deleting');
                                                  await service.deleteUserBook(settings.hardcoverApiKey, existing.userBookId);
                                                }
                                              }
                                            }
                                          } catch (e) {
                                            print('[PlanToRead] error removing from Hardcover: $e');
                                          }
                                        }
                                      }
                                    }
                                    try {
                                      if (context.mounted) {
                                        ref.invalidate(isBookInWishlistProvider(normalBook.id));
                                        ref.invalidate(audiobookWishlistProvider);
                                      }
                                    } catch (_) {}
                                  },
                                  icon: Icon(
                                    inWishlist ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    size: 18,
                                  ),
                                  label: Text(inWishlist ? 'In Plan to Read' : 'Plan to Read'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    foregroundColor: inWishlist ? Theme.of(context).colorScheme.primary : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }),
                    const SizedBox(height: 8),
                    // Bookmarks button — always shown even for local audiobooks
                    Consumer(builder: (context, ref, child) {
                      final bookmarksAsync = ref.watch(audiobookBookmarksProvider(normalBook.id));
                      final bookmarks = bookmarksAsync.asData?.value ?? [];
                      return OutlinedButton.icon(
                        onPressed: bookmarks.isEmpty
                            ? null
                            : () => showModalBottomSheet(
                              context: context,
                              builder: (ctx) => Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 40, height: 4, decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    )),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Bookmarks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const Divider(),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: bookmarks.length,
                                      itemBuilder: (ctx2, i) {
                                        final bm = bookmarks[i];
                                        final ts = Duration(milliseconds: bm.positionMillis);
                                        return ListTile(
                                          title: Text(bm.label ?? 'Bookmark ${i + 1}'),
                                          subtitle: Text('Ch. ${bm.chapterIndex + 1} at ${ts.inMinutes}:${(ts.inSeconds % 60).toString().padLeft(2, '0')}'),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18),
                                            onPressed: () async {
                                              await ref.read(audiobookRepositoryProvider).deleteBookmark(bm.id);
                                              ref.invalidate(audiobookBookmarksProvider(normalBook.id));
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        icon: Icon(
                          bookmarks.isNotEmpty ? Icons.bookmarks_rounded : Icons.bookmarks_outlined,
                          size: 18,
                        ),
                        label: Text(bookmarks.isNotEmpty ? '${bookmarks.length}' : 'Bookmarks'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    }),
                    if (torrentStatusAsync != null) ...[
                    const SizedBox(height: 12),
                    torrentStatusAsync.when(
                      data: (status) {
                        final inLibrary = status['inLibrary'] as bool? ?? false;
                        final cached = status['cached'] as bool? ?? false;
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cached 
                                  ? Colors.green.withValues(alpha: 0.15) 
                                  : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: cached ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cached ? Icons.check_circle_rounded : Icons.offline_bolt_rounded,
                                    size: 14,
                                    color: cached ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    cached ? 'Cached on TorBox' : 'Uncached',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: cached ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: inLibrary 
                                  ? Colors.blue.withValues(alpha: 0.15) 
                                  : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: inLibrary ? Colors.blue.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    inLibrary ? Icons.folder_special_rounded : Icons.create_new_folder_rounded,
                                    size: 14,
                                    color: inLibrary ? Colors.blue : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    inLibrary ? 'In Library' : 'Add to TorBox',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: inLibrary ? Colors.blue : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (e, _) => const SizedBox.shrink(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (displayBook.description != null && 
                      displayBook.description!.isNotEmpty &&
                      !displayBook.description!.startsWith('JSON_EXT:')) ...[
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpandableDescription(
                      htmlText: displayBook.description!,
                      baseStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ) ?? const TextStyle(),
                    ),
                  ],
                  if (displayBook.genre != null && displayBook.genre!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayBook.genre!.split(',').map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: Text(
                            g.trim(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (displayBook.releaseDate != null || displayBook.publisher != null) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Product Information',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (displayBook.releaseDate != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Released',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            Text(
                              displayBook.releaseDate!.split('T').first,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (displayBook.publisher != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Publisher & Copyright',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayBook.publisher!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  // Show progress summary card if user has listening progress OR has associated epub file
                  if (hasProgress || epubPath != null) ...[
                    const SizedBox(height: 16),
                    _buildOverallProgressCard(
                      context,
                      ref,
                      displayBook,
                      chapterProgressMap,
                      chaptersAsync.value?.length ?? 0,
                      chaptersAsync.value ?? [],
                      epubPath,
                      epubProgress,
                    ),
                  ]
                  // Show download button ONLY if it's a torrent that is NOT yet in library
                  else if (displayBook.id.startsWith('torrent:')) ...[  
                    Builder(builder: (context) {
                      // Check if the torrent is already in the user's TorBox library
                      final inLibrary = torrentStatusAsync?.value?['inLibrary'] == true;
                      if (inLibrary) {
                        // Already in library — no need to download, chapters will appear above
                        return const SizedBox.shrink();
                      }
                      // Not yet in library - show download button
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.cloud_download_rounded),
                            label: const Text('Download Torrent to TorBox'),

                            onPressed: () async {
                              String bookId = book.id;
                              if (bookId.startsWith('audiobookbay:')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Resolving AudiobookBay torrent info...')),
                                );
                                final resolved = await ref.read(audiobookRepositoryProvider).getBookDetails(bookId);
                                if (resolved != null && resolved.id.startsWith('torrent:')) {
                                  bookId = resolved.id;
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to resolve AudiobookBay torrent.')),
                                    );
                                  }
                                  return;
                                }
                              }
                              final parts = bookId.split(':');
                              final magnet = parts.length > 2 ? Uri.decodeComponent(parts[2]) : '';
                              if (magnet.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Adding torrent to TorBox...')),
                                );
                                final success = await ref.read(audiobookRepositoryProvider).addTorrent(magnet);
                                if (context.mounted) {
                                  if (success) {
                                    ref.invalidate(bookChaptersProvider(displayBook.id));
                                    ref.invalidate(torrentStatusProvider(displayBook.id));
                                    ref.invalidate(localAudiobooksProvider);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success 
                                        ? 'Torrent added to TorBox successfully! Refreshing details...' 
                                        : 'Failed to add torrent to TorBox.'),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No magnet link available for this torrent.')),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                  // Local Download Options for Library Book
                  chaptersAsync.when(
                    data: (chapters) {
                      if (chapters.isEmpty) return const SizedBox.shrink();
                      final isLibraryBook = displayBook.id.startsWith('torrent:') && torrentStatusAsync?.value?['inLibrary'] == true;
                      if (!isLibraryBook) return const SizedBox.shrink();

                      final allLocal = chapters.every((ch) => ch.streamUrl != null && (ch.streamUrl!.startsWith('/') || ch.streamUrl!.startsWith('file://')));
                      final progress = downloadState?.progress ?? -100.0; // dummy initial value

                      if (allLocal) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.offline_pin_rounded, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Downloaded to Device',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text('Delete'),
                                onPressed: () {
                                  ref.read(audiobookDownloadProvider.notifier).deleteDownloadedBook(displayBook, chapters);
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      if (downloadState != null && downloadState.status == 'downloading' && progress >= 0.0 && progress < 1.0) {
                        final downloadedMB = (downloadState.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
                        final totalMB = downloadState.totalBytes > 0 
                            ? '${(downloadState.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB' 
                            : 'Unknown size';
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Title
                  Text(
                    displayBook.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                                          children: [
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              downloadState.totalChapters > 1
                                                  ? 'Downloading: File ${downloadState.currentChapterIndex}/${downloadState.totalChapters}'
                                                  : 'Downloading audiobook...',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          downloadState.currentChapterTitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$downloadedMB MB / $totalMB (${(progress * 100).round()}%)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.pause_rounded, size: 18),
                                    label: const Text('Pause'),
                                    onPressed: () {
                                      ref.read(audiobookDownloadProvider.notifier).pauseBook(displayBook.id);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: progress),
                            ],
                          ),
                        );
                      }

                      if (progress == -4.0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.pause_circle_outline_rounded, size: 18, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Download Paused',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                        label: const Text('Resume'),
                                        onPressed: () {
                                          ref.read(audiobookDownloadProvider.notifier).downloadBook(displayBook, chapters);
                                        },
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        label: const Text('Clear'),
                                        onPressed: () {
                                          ref.read(audiobookDownloadProvider.notifier).deleteDownloadedBook(displayBook, chapters);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      if (progress == -5.0) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Spacer(),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Deleting files...', style: TextStyle(fontSize: 13)),
                              Spacer(),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download_for_offline_rounded),
                            label: const Text('Download Book to Device'),
                            onPressed: () {
                              ref.read(audiobookDownloadProvider.notifier).downloadBook(displayBook, chapters);
                            },
                          ),
                          if (progress < 0.0 && progress != -4.0 && progress != -5.0 && progress != -100.0) ...[
                            const SizedBox(height: 4),
                            Text(
                              progress == -1.0
                                  ? 'Error: Please set an audiobook folder in Settings first.'
                                  : progress == -2.0
                                      ? 'Error: Storage permission denied.'
                                      : 'Error: Download failed. Please try again.',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          ref.read(chaptersExpandedProvider(displayBook.id).notifier).state = !_chaptersExpanded;
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Chapters',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _chaptersExpanded ? Icons.expand_less : Icons.expand_more,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.primary),
                        tooltip: 'Manage progress',
                        onSelected: (value) async {
                          final repo = ref.read(audiobookRepositoryProvider);
                          final chaptersList = chaptersAsync.value ?? [];
                          if (value == 'mark_all_completed') {
                            for (int i = 0; i < chaptersList.length; i++) {
                              final ch = chaptersList[i];
                              final durationToUse = ch.durationMillis > 0 ? ch.durationMillis : 600000;
                              await repo.saveProgress(
                                bookId: displayBook.id,
                                chapterIndex: i,
                                positionMillis: ch.startTimeMillis + durationToUse,
                                durationMillis: durationToUse,
                                isCompleted: true,
                              );
                            }
                          } else if (value == 'clear_all_progress') {
                            for (int i = 0; i < chaptersList.length; i++) {
                              final ch = chaptersList[i];
                              await repo.saveProgress(
                                bookId: displayBook.id,
                                chapterIndex: i,
                                positionMillis: ch.startTimeMillis,
                                durationMillis: ch.durationMillis > 0 ? ch.durationMillis : 0,
                                isCompleted: false,
                              );
                            }
                          }
                          if (!context.mounted) return;
                          ref.invalidate(bookChapterProgressProvider(displayBook.id));
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'mark_all_completed',
                            child: Row(
                              children: [
                                Icon(Icons.done_all_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Mark all completed'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'clear_all_progress',
                            child: Row(
                              children: [
                                Icon(Icons.cleaning_services_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Clear all progress'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          
          // Chapter List
          if (_chaptersExpanded)
            chaptersAsync.when(
            data: (chapters) {
              if (chapters.isEmpty) {
                if (torrentSearchAsync == null) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No chapters found.'),
                      ),
                    ),
                  );
                }
                return torrentSearchAsync.when(
                  data: (torrents) {
                    if (torrents.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text('No chapters or torrent search results found.'),
                          ),
                        ),
                      );
                    }
                    
                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Text(
                              'No direct streams found. Search results from torrents:',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: torrents.length,
                            itemBuilder: (context, index) {
                              final torrentBook = torrents[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: torrentBook.artworkUrl != null && torrentBook.artworkUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: torrentBook.artworkUrl!,
                                            memCacheWidth: 40,
                                            memCacheHeight: 40,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              color: Theme.of(context).colorScheme.tertiaryContainer,
                                              child: Icon(
                                                Icons.download_for_offline_rounded,
                                                color: Theme.of(context).colorScheme.onTertiaryContainer,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Theme.of(context).colorScheme.tertiaryContainer,
                                            child: Icon(
                                              Icons.download_for_offline_rounded,
                                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  torrentBook.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  torrentBook.description ?? 'Torrent file',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.cloud_download_rounded),
                                  color: Theme.of(context).colorScheme.primary,
                                  iconSize: 28,
                                  onPressed: () async {
                                    String bookId = torrentBook.id;
                                    if (bookId.startsWith('audiobookbay:')) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Resolving AudiobookBay torrent info...')),
                                      );
                                      final resolved = await ref.read(audiobookRepositoryProvider).getBookDetails(bookId);
                                      if (resolved != null && resolved.id.startsWith('torrent:')) {
                                        bookId = resolved.id;
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to resolve AudiobookBay torrent.')),
                                          );
                                        }
                                        return;
                                      }
                                    }
                                    
                                    final parts = bookId.split(':');
                                    final magnet = parts.length > 2 ? Uri.decodeComponent(parts[2]) : '';
                                    if (magnet.isNotEmpty) {
                                      try {
                                        await ref.read(audiobookRepositoryProvider).addTorrent(magnet);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Torrent added to TorBox!'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to add torrent: $e')),
                                          );
                                        }
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to extract magnet link.')),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Searching torrents...'),
                        ],
                      ),
                    ),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('Failed to search torrents: $e'),
                      ),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chapter = chapters[index];
                    final chProgress = chapterProgressMap[index];
                    final bool isCompleted = chProgress?.isCompleted ?? false;
                    final double chapterPercent = (chProgress != null && chProgress.durationMillis > 0)
                        ? (chProgress.positionMillis / chProgress.durationMillis).clamp(0.0, 1.0)
                        : (isCompleted ? 1.0 : 0.0);

                    return StreamBuilder<MediaItem?>(
                      stream: audioHandler.mediaItem,
                      initialData: audioHandler.mediaItem.value,
                      builder: (context, mediaSnapshot) {
                        final currentMedia = mediaSnapshot.data;
                        final isCurrentBook = currentMedia?.extras?['bookId'] == normalBook.id;
                        final hasOffsets = chapters.any((ch) => ch.startTimeMillis > 0);

                        bool isCurrent = false;
                        if (isCurrentBook) {
                          if (hasOffsets) {
                            final currentPosMs = audioHandler.playbackState.value.position.inMilliseconds;
                            final start = chapter.startTimeMillis;
                            final end = (index + 1 < chapters.length)
                                ? chapters[index + 1].startTimeMillis
                                : double.infinity;
                            isCurrent = currentPosMs >= start && currentPosMs < end;
                          } else {
                            isCurrent = (currentMedia?.extras?['chapterIndex'] == index) || (currentMedia?.title == chapter.title);
                          }
                        }

                        if (isCurrent) {
                          return StreamBuilder<Duration>(
                            stream: AudioService.position,
                            initialData: Duration.zero,
                            builder: (context, posSnapshot) {
                              final currentPos = posSnapshot.data ?? Duration.zero;
                              final currentPosMs = currentPos.inMilliseconds;
                              
                              return _buildChapterTile(
                                context: context,
                                index: index,
                                chapter: chapter,
                                chProgress: chProgress,
                                isCompleted: isCompleted,
                                chapterPercent: chapterPercent,
                                downloadState: downloadState,
                                isCurrent: true,
                                displayBook: displayBook,
                                normalizedId: normalBook.id,
                                currentPosMs: currentPosMs,
                                chapters: chapters,
                              );
                            },
                          );
                        } else {
                          return _buildChapterTile(
                            context: context,
                            index: index,
                            chapter: chapter,
                            chProgress: chProgress,
                            isCompleted: isCompleted,
                            chapterPercent: chapterPercent,
                            downloadState: downloadState,
                            isCurrent: false,
                            displayBook: displayBook,
                            normalizedId: normalBook.id,
                            chapters: chapters,
                          );
                        }
                      },
                    );
                  },
                  childCount: chapters.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, st) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Error loading chapters',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ),
          )
          else
            const SliverToBoxAdapter(child: SizedBox.shrink()),

          // More from Author
          _buildMoreFromAuthorSection(context, ref, displayBook),

          // More from Genre
          _buildMoreFromGenreSection(context, ref, displayBook),

          const SliverToBoxAdapter(child: SizedBox(height: 100)), // padding for bottom bar
        ],
      ),
    );
  }

  Widget _buildChapterTile({
    required BuildContext context,
    required int index,
    required AudiobookChapter chapter,
    required DbAudiobookProgress? chProgress,
    required bool isCompleted,
    required double chapterPercent,
    required dynamic downloadState,
    required bool isCurrent,
    required AudiobookResult displayBook,
    required String normalizedId,
    int? currentPosMs,
    required List<AudiobookChapter> chapters,
  }) {
    final start = chapter.startTimeMillis;
    final hasOffsets = chapters.any((ch) => ch.startTimeMillis > 0);
    
    int chDuration = chapter.durationMillis;
    if (hasOffsets) {
      final end = (index + 1 < chapters.length)
          ? chapters[index + 1].startTimeMillis
          : 0;
      if (end > start) {
        chDuration = (end - start).toInt();
      } else if (chProgress != null && chProgress.durationMillis > 0) {
        chDuration = chProgress.durationMillis;
      } else {
        final totalDurationMs = audioHandler.mediaItem.value?.duration?.inMilliseconds;
        if (totalDurationMs != null && totalDurationMs > start) {
          chDuration = (totalDurationMs - start).toInt();
        }
      }
    }
    if (chDuration <= 0) {
      chDuration = chapter.durationMillis > 0 ? chapter.durationMillis : 1;
    }

    int displayPos = 0;
    double percent = 0.0;
    if (isCurrent) {
      final activePos = currentPosMs ?? audioHandler.playbackState.value.position.inMilliseconds;
      if (hasOffsets) {
        displayPos = (activePos - start).clamp(0, chDuration);
      } else {
        displayPos = activePos.clamp(0, chDuration);
      }
      percent = (chDuration > 0) ? (displayPos / chDuration).clamp(0.0, 1.0) : 0.0;
    } else if (isCompleted) {
      displayPos = chDuration;
      percent = 1.0;
    } else if (chProgress != null) {
      if (hasOffsets) {
        // chProgress.positionMillis is absolute in DB
        displayPos = (chProgress.positionMillis - start).clamp(0, chDuration);
      } else {
        displayPos = chProgress.positionMillis.clamp(0, chDuration);
      }
      percent = (chDuration > 0) ? (displayPos / chDuration).clamp(0.0, 1.0) : 0.0;
    }

    return Consumer(
      builder: (context, ref, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary),
                            title: const Text('Mark as Completed'),
                            onTap: () async {
                              final repo = ref.read(audiobookRepositoryProvider);
                              final durationToUse = chapter.durationMillis > 0 
                                  ? chapter.durationMillis 
                                  : (chProgress?.durationMillis != null && chProgress!.durationMillis > 0
                                      ? chProgress.durationMillis
                                      : 600000);
                              final endPos = chapter.startTimeMillis + durationToUse;
                              await repo.saveProgress(
                                bookId: normalizedId,
                                chapterIndex: index,
                                positionMillis: endPos,
                                durationMillis: durationToUse,
                                isCompleted: true,
                              );
                              ref.invalidate(bookChapterProgressProvider(normalizedId));
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.cleaning_services_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            title: const Text('Clear Progress (Mark as Incomplete)'),
                            onTap: () async {
                              final repo = ref.read(audiobookRepositoryProvider);
                              await repo.saveProgress(
                                bookId: normalizedId,
                                chapterIndex: index,
                                positionMillis: chapter.startTimeMillis,
                                durationMillis: chapter.durationMillis > 0 ? chapter.durationMillis : (chProgress?.durationMillis ?? 0),
                                isCompleted: false,
                              );
                              ref.invalidate(bookChapterProgressProvider(normalizedId));
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              leading: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primaryContainer
                          : (isCompleted
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                              : Theme.of(context).colorScheme.secondaryContainer),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCurrent
                          ? Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 18)
                          : (isCompleted
                              ? Icon(Icons.check_rounded, size: 20, color: Theme.of(context).colorScheme.primary)
                              : (downloadState != null && downloadState.status == 'downloading' && downloadState.currentChapterIndex == index + 1)
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )),
                    ),
                  ),
                  if (!isCompleted && percent > 0.0)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: percent,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.transparent,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              title: Text(
                chapter.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : (isCompleted ? Theme.of(context).colorScheme.onSurfaceVariant : null),
                ),
              ),
              subtitle: (downloadState != null && downloadState.status == 'downloading' && downloadState.currentChapterIndex == index + 1)
                  ? Text(
                      'Downloading... ${(downloadState.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB' +
                          (downloadState.totalBytes > 0
                              ? ' / ${(downloadState.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                              : ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : (isCurrent
                      ? Text(
                          'Playing • ${_formatDuration(displayPos)} / ${_formatDuration(chDuration)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : (percent > 0.0
                          ? Text(
                              isCompleted
                                  ? 'Completed'
                                  : '${_formatDuration(displayPos)} / ${_formatDuration(chDuration)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isCompleted
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : (chDuration > 0 && chDuration != 1
                              ? Text(
                                  _formatDuration(chDuration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isCompleted
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    tooltip: isCompleted ? 'Mark as incomplete' : 'Mark as completed',
                    onPressed: () async {
                      final repo = ref.read(audiobookRepositoryProvider);
                      if (isCompleted) {
                        // Reset progress for this chapter
                        await repo.saveProgress(
                          bookId: normalizedId,
                          chapterIndex: index,
                          positionMillis: chapter.startTimeMillis,
                          durationMillis: chapter.durationMillis > 0 ? chapter.durationMillis : (chProgress?.durationMillis ?? 0),
                          isCompleted: false,
                        );
                      } else {
                        // Mark as completed by setting progress to duration/end
                        final durationToUse = chapter.durationMillis > 0 
                            ? chapter.durationMillis 
                            : (chProgress?.durationMillis != null && chProgress!.durationMillis > 0
                                ? chProgress.durationMillis
                                : 600000); // 10 min fallback
                        final endPos = chapter.startTimeMillis + durationToUse;
                        await repo.saveProgress(
                          bookId: normalizedId,
                          chapterIndex: index,
                          positionMillis: endPos,
                          durationMillis: durationToUse,
                          isCompleted: true,
                        );
                      }
                       if (!context.mounted) return;
                       ref.invalidate(bookChapterProgressProvider(normalizedId));
                    },
                  ),
                  IconButton(
                    icon: Icon(isCurrent 
                        ? Icons.pause_circle_filled_rounded 
                        : (isCompleted ? Icons.replay_circle_filled_rounded : Icons.play_circle_fill)),
                    color: Theme.of(context).colorScheme.primary,
                    iconSize: 36,
                    onPressed: () async {
                      if (isCurrent) {
                        final playbackState = audioHandler.playbackState.value;
                        if (playbackState.playing) {
                          await audioHandler.pause();
                        } else {
                          await audioHandler.play();
                        }
                        return;
                      }

                  // Cache metadata and save initial progress immediately to DB
                  final repo = ref.read(audiobookRepositoryProvider);
                  
                  // Show loading feedback while resolving
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Resolving stream URL...'),
                          ],
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                  
                  final resolvedUrl = await repo.resolveChapterStream(chapter);
                  if (resolvedUrl == null || resolvedUrl.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to resolve stream URL.')),
                      );
                    }
                    return;
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }

                  await repo.cacheBookMetadata(displayBook.copyWith(id: normalizedId));

                  final initialPos = (chProgress?.positionMillis != null && chProgress!.positionMillis > 0)
                      ? chProgress.positionMillis
                      : chapter.startTimeMillis;
                  final totalDur = chProgress?.durationMillis ?? chapter.durationMillis;

                  await repo.saveProgress(
                    bookId: normalizedId,
                    chapterIndex: index,
                    positionMillis: initialPos,
                    durationMillis: totalDur,
                  );

                  // CRITICAL: Play via AudioHandler with mediaType guard
                  await audioHandler.customAction('play', {
                    'url': resolvedUrl,
                    'title': chapter.title,
                    'artist': displayBook.author,
                    'artworkUrl': displayBook.artworkUrl ?? '',
                    'duration': '${chapter.durationMillis}',
                    'forceReplace': true,
                    'mediaType': 'audiobook', // CRITICAL GUARD
                    'extras': {
                      'bookId': normalizedId,
                      'chapterIndex': index,
                      'initialPositionMillis': initialPos,
                    },
                  });
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AudiobookNowPlayingScreen(book: displayBook.copyWith(id: normalizedId)),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
            ),
            if (chProgress != null && !isCompleted && !isCurrent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LinearProgressIndicator(
                  value: chapterPercent,
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(1),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build an overall progress summary card.
  Widget _buildOverallProgressCard(
    BuildContext context,
    WidgetRef ref,
    AudiobookResult displayBook,
    Map<int, DbAudiobookProgress> progressMap,
    int totalChapters,
    List<AudiobookChapter> chapters,
    String? epubPath,
    Map<String, dynamic>? epubProgress,
  ) {
    final settings = ref.watch(settingsProvider);
    final hasHardcover = settings.hardcoverHasKey;
    final hardcoverEntryAsync = hasHardcover
        ? ref.watch(hardcoverBookProgressProvider((title: displayBook.title, author: displayBook.author)))
        : null;

    final hasEpub = epubPath != null;
    final showTabs = hasEpub || hasHardcover;
    final selectedTab = showTabs
        ? ref.watch(selectedProgressTabProvider(displayBook.id))
        : 'listening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTabs) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(selectedProgressTabProvider(displayBook.id).notifier).state = 'listening',
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedTab == 'listening'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.headphones_rounded,
                              size: 16,
                              color: selectedTab == 'listening'
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Listening',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: selectedTab == 'listening'
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(selectedProgressTabProvider(displayBook.id).notifier).state = 'reading',
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedTab == 'reading'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 16,
                              color: selectedTab == 'reading'
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reading',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: selectedTab == 'reading'
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (selectedTab == 'listening') ...[
            Builder(builder: (context) {
              final completedChapters = progressMap.values.where((p) => p.isCompleted).length;
              final listenedChapters = progressMap.length;
              final hasOffsets = chapters.any((ch) => ch.startTimeMillis > 0);

              int totalListenedMillis = 0;
              int totalDurationMillis = 0;

              if (hasOffsets && chapters.isNotEmpty) {
                for (int i = 0; i < chapters.length; i++) {
                  final chapter = chapters[i];
                  final start = chapter.startTimeMillis;
                  final end = (i + 1 < chapters.length)
                      ? chapters[i + 1].startTimeMillis
                      : 0;
                  
                  int chDuration = chapter.durationMillis;
                  if (end > start) {
                    chDuration = (end - start).toInt();
                  } else if (progressMap.isNotEmpty) {
                    final overallProgressEntry = progressMap.values.firstWhere((p) => p.durationMillis > 3600000, orElse: () => progressMap.values.first);
                    if (overallProgressEntry.durationMillis > start) {
                      chDuration = (overallProgressEntry.durationMillis - start).toInt();
                    }
                  }
                  if (chDuration <= 0) {
                    chDuration = chapter.durationMillis > 0 ? chapter.durationMillis : 1;
                  }

                  totalDurationMillis += chDuration;

                  final chProgress = progressMap[i];
                  if (chProgress != null) {
                    if (chProgress.isCompleted) {
                      totalListenedMillis += chDuration;
                    } else {
                      final relativePos = (chProgress.positionMillis - start).clamp(0, chDuration);
                      totalListenedMillis += relativePos;
                    }
                  }
                }
              } else {
                // Sum duration of ALL chapters in the book
                for (final chapter in chapters) {
                  totalDurationMillis += chapter.durationMillis;
                }
                for (int i = 0; i < chapters.length; i++) {
                  final p = progressMap[i];
                  if (p != null) {
                    final chapter = chapters[i];
                    final chDuration = chapter.durationMillis > 0 ? chapter.durationMillis : p.durationMillis;
                    if (p.isCompleted) {
                      totalListenedMillis += chDuration;
                    } else {
                      totalListenedMillis += p.positionMillis.clamp(0, chDuration);
                    }
                  }
                }
              }

              final double overallPercent;
              if (totalDurationMillis > 0) {
                overallPercent = (totalListenedMillis / totalDurationMillis).clamp(0.0, 1.0);
              } else if (totalChapters > 0) {
                overallPercent = (completedChapters / totalChapters).clamp(0.0, 1.0);
              } else {
                overallPercent = 0.0;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Listening Progress',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(overallPercent * 100).round()}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: overallPercent,
                      minHeight: 6,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildProgressStat(
                        context,
                        Icons.check_circle_outline_rounded,
                        '$completedChapters / ${totalChapters > 0 ? totalChapters : listenedChapters}',
                        'Chapters done',
                      ),
                      const SizedBox(width: 24),
                      _buildProgressStat(
                        context,
                        Icons.timer_outlined,
                        totalDurationMillis > 0 
                            ? '${_formatDuration(totalListenedMillis)} / ${_formatDuration(totalDurationMillis)}'
                            : _formatDuration(totalListenedMillis),
                        'Time listened',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _resumeListeningPlayback(
                        context, ref, displayBook, progressMap, chapters,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(listenedChapters > 0 ? 'Resume' : 'Start Listening'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (hardcoverEntryAsync != null)
                    hardcoverEntryAsync.when(
                      data: (hcEntry) {
                        if (hcEntry == null) return const SizedBox.shrink();

                        final localTotalSecs = totalDurationMillis > 0
                            ? totalDurationMillis / 1000.0
                            : 0.0;
                        final hcTotalSecs = hcEntry.book.audioSeconds != null
                            ? hcEntry.book.audioSeconds!.toDouble()
                            : 0.0;
                        final bestTotalSecs = hcTotalSecs > 0 ? hcTotalSecs : localTotalSecs;
                        final double hcPercent = hcEntry.progressSeconds != null && bestTotalSecs > 0
                            ? (hcEntry.progressSeconds! / bestTotalSecs).clamp(0.0, 1.0)
                            : 0.0;

                        // Store Hardcover mapping for auto-sync on pause/stop
                        if (hcEntry.readId != null && hcEntry.editionId != null) {
                          final repo = ref.read(audiobookRepositoryProvider);
                          repo.saveHardcoverMapping(displayBook.id, hcEntry.userBookId, hcEntry.readId!, hcEntry.editionId!);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.menu_book_rounded,
                                    color: Theme.of(context).colorScheme.primary, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Hardcover',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary)),
                                  const Spacer(),
                                  Text('${(hcPercent * 100).round()}%',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: hcPercent,
                                  minHeight: 6,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildProgressStat(context, Icons.timer_outlined,
                                    hcEntry.progressSeconds != null
                                        ? _formatDuration(hcEntry.progressSeconds! * 1000)
                                        : '0h', 'Hardcover'),
                                  if (bestTotalSecs > 0) ...[
                                    const SizedBox(width: 24),
                                    _buildProgressStat(context, Icons.schedule_rounded,
                                      _formatDuration((bestTotalSecs * 1000).round()),
                                      'Total'),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      error: (err, _) => const SizedBox.shrink(),
                    ),
                ],
              );
            }),
          ] else if (selectedTab == 'reading') ...[
            if (epubPath != null) ...[
              Builder(builder: (context) {
                final double epubPercent = epubProgress?['progress'] ?? 0.0;
                final int currentChapter = epubProgress?['currentChapter'] ?? 0;
                final int epubTotalChapters = epubProgress?['totalChapters'] ?? 0;
                final int pagesRead = epubProgress?['pagesRead'] ?? 0;
                final int totalPages = epubProgress?['totalPages'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reading Progress',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(epubPercent * 100).round()}%',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: epubPercent,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildProgressStat(
                          context,
                          Icons.format_list_numbered_rounded,
                          epubTotalChapters > 0 ? 'Ch. ${currentChapter + 1} / $epubTotalChapters' : 'Ch. ${currentChapter + 1}',
                          'Current Chapter',
                        ),
                        if (totalPages > 0) ...[
                          const SizedBox(width: 24),
                          _buildProgressStat(
                            context,
                            Icons.auto_stories_rounded,
                            '$pagesRead / $totalPages',
                            'Pages read',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EpubReaderScreen(
                                epubFilePath: epubPath,
                                bookId: displayBook.id,
                                onClose: () {
                                  Navigator.pop(context);
                                  ref.invalidate(epubProgressProvider(displayBook.id));
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chrome_reader_mode_rounded),
                        label: const Text('Continue Reading'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ] else if (hardcoverEntryAsync != null) ...[
              Builder(builder: (context) {
                return hardcoverEntryAsync!.when(
                  data: (entry) {
                    if (entry == null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.menu_book_rounded, size: 48,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              Text('No Hardcover reading progress found',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      );
                    }
                    final totalHours = entry.book.audioSeconds != null
                        ? entry.book.audioSeconds! / 3600.0
                        : 0.0;
                    final double hcPercent = entry.progressHours > 0 && totalHours > 0
                        ? (entry.progressHours / totalHours).clamp(0.0, 1.0)
                        : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.menu_book_rounded,
                              color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('Hardcover Progress',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary)),
                            const Spacer(),
                            Text('${(hcPercent * 100).round()}%',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: hcPercent,
                            minHeight: 6,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildProgressStat(context, Icons.timer_outlined,
                              '${entry.progressHours.toStringAsFixed(1)}h',
                              'Progress'),
                            if (totalHours > 0) ...[
                              const SizedBox(width: 24),
                              _buildProgressStat(context, Icons.schedule_rounded,
                                '${totalHours.toStringAsFixed(1)}h',
                                'Total'),
                            ],
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Hardcover error: $err',
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildProgressStat(BuildContext context, IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Format milliseconds to a human readable duration string.
  String _formatDuration(int millis) {
    final duration = Duration(milliseconds: millis);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildArtworkImage(String? url, {required bool isBlur, required BuildContext context}) {
    if (url == null || url.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.book,
            size: isBlur ? 120 : 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final cleanPath = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;

    if (isLocal) {
      return Image.file(
        File(cleanPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.book,
              size: isBlur ? 120 : 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: url,
        memCacheWidth: 400,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
        errorWidget: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.book,
              size: isBlur ? 120 : 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _resumeListeningPlayback(
    BuildContext context,
    WidgetRef ref,
    AudiobookResult displayBook,
    Map<int, DbAudiobookProgress> progressMap,
    List<AudiobookChapter> chapters,
  ) async {
    int? lastChapterIndex;
    for (final entry in progressMap.entries) {
      if (entry.value.isCompleted) continue;
      if (lastChapterIndex == null || entry.key > lastChapterIndex) {
        lastChapterIndex = entry.key;
      }
    }
    if (lastChapterIndex == null || chapters.isEmpty) {
      lastChapterIndex = 0;
    }

    final chapterIndex = lastChapterIndex.clamp(0, chapters.length - 1);
    final chapter = chapters[chapterIndex];
    final progress = progressMap[chapterIndex];

    final repo = ref.read(audiobookRepositoryProvider);
    final normalizedId = AudiobookRepository.normalizeBookId(displayBook.id);

    final resolvedUrl = await repo.resolveChapterStream(chapter);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resolve stream URL.')),
        );
      }
      return;
    }

    final initialPos = (progress?.positionMillis != null && progress!.positionMillis > 0)
        ? progress.positionMillis
        : chapter.startTimeMillis;
    final totalDur = progress?.durationMillis ?? chapter.durationMillis;

    await repo.saveProgress(
      bookId: normalizedId,
      chapterIndex: chapterIndex,
      positionMillis: initialPos,
      durationMillis: totalDur,
    );

    await audioHandler.customAction('play', {
      'url': resolvedUrl,
      'title': chapter.title,
      'artist': displayBook.author,
      'artworkUrl': displayBook.artworkUrl ?? '',
      'duration': '${chapter.durationMillis}',
      'forceReplace': true,
      'mediaType': 'audiobook',
      'extras': {
        'bookId': normalizedId,
        'chapterIndex': chapterIndex,
        'initialPositionMillis': initialPos,
      },
    });

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudiobookNowPlayingScreen(book: displayBook.copyWith(id: normalizedId)),
        ),
      );
    }
  }

  Widget _buildMoreFromAuthorSection(BuildContext context, WidgetRef ref, AudiobookResult book) {
    const placeholderAuthors = {
      'torrent result', 'torrent source', 'local library', 'unknown author',
      'torbox library', 'unknown',
    };
    final author = book.author.trim().toLowerCase();
    if (author.isEmpty || placeholderAuthors.contains(author)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final async = ref.watch(authorAudiobooksProvider(book.author));
    return async.when(
      data: (books) {
        // Filter out the current book by similar title
        final filtered = books.where((b) {
          final t1 = b.title.toLowerCase().trim();
          final t2 = book.title.toLowerCase().trim();
          return t1 != t2 && !t1.contains(t2) && !t2.contains(t1);
        }).toList();
        if (filtered.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final theme = Theme.of(context);
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.person_rounded, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'More from ${book.author}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AuthorCatalogScreen(author: book.author),
                            ),
                          );
                        },
                        child: const Text('See More'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final b = filtered[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AudiobookDetailScreen(book: b),
                            ),
                          );
                        },
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: ClipRect(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: b.artworkUrl != null && b.artworkUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: b.artworkUrl!,
                                          memCacheWidth: 140,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            child: const Icon(Icons.book, size: 40),
                                          ),
                                        )
                                      : Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.book, size: 40),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (b.rating != null) ...[
                                    Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        b.rating!.toStringAsFixed(1),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (b.durationMillis != null && b.durationMillis! > 0) ...[
                                    const Spacer(),
                                    Icon(Icons.timer_outlined, size: 11, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        _formatDuration(b.durationMillis!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              ),
            ),
          );
        },
        loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      );
  }


  Widget _buildMoreFromGenreSection(BuildContext context, WidgetRef ref, AudiobookResult book) {
    final cached = ref.watch(bookDetailsProvider(book.id)).value;
    final genre = cached?.genre ?? book.genre?.split(',').first.trim();
    if (genre == null || genre.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return ref.watch(genreAudiobooksProvider(genre)).when(
      data: (books) {
        final filtered = books.where((b) {
          final t1 = b.title.toLowerCase().trim();
          final t2 = book.title.toLowerCase().trim();
          return b.id != book.id && t1 != t2 && !t1.contains(t2) && !t2.contains(t1);
        }).toList();
        if (filtered.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final theme = Theme.of(context);
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.category_rounded, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'More $genre',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GenreCatalogScreen(genre: genre),
                            ),
                          );
                        },
                        child: const Text('See More'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final b = filtered[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AudiobookDetailScreen(book: b),
                            ),
                          );
                        },
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: ClipRect(
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: b.artworkUrl != null && b.artworkUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: b.artworkUrl!,
                                          memCacheWidth: 140,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            child: const Icon(Icons.book, size: 40),
                                          ),
                                        )
                                      : Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.book, size: 40),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.author ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  static String _sanitizeTorrentQuery(String title, String author) {
    String cleanTitle = title.replaceAll(RegExp(r'\([^)]*\)'), '');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    if (cleanTitle.contains(':')) {
      cleanTitle = cleanTitle.split(':').first;
    }
    if (cleanTitle.contains(' - ')) {
      cleanTitle = cleanTitle.split(' - ').first;
    }
    cleanTitle = cleanTitle
        .replaceAll(RegExp(r'\b(unabridged|abridged|novel|audiobook|book \d+)\b', caseSensitive: false), '')
        .trim();
    return '$cleanTitle $author'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _showMetadataSearchSheet(BuildContext context, WidgetRef ref, AudiobookResult currentBook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return MetadataSearchWidget(
              currentBook: currentBook,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

class MetadataSearchWidget extends ConsumerStatefulWidget {
  final AudiobookResult currentBook;
  final ScrollController scrollController;

  const MetadataSearchWidget({
    required this.currentBook,
    required this.scrollController,
  });

  @override
  ConsumerState<MetadataSearchWidget> createState() => _MetadataSearchWidgetState();
}

class _MetadataSearchWidgetState extends ConsumerState<MetadataSearchWidget> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  List<AudiobookResult> _results = [];
  String _error = '';

  StreamSubscription<List<AudiobookResult>>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentBook.title);
    _performSearch();
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    await _searchSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _error = '';
      _results = [];
    });

    final repo = ref.read(audiobookRepositoryProvider);
    _searchSubscription = repo.searchOnlineMetadataStream(query).listen(
      (results) {
        if (mounted) {
          setState(() {
            _results = results;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _selectBook(AudiobookResult selectedBook) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(audiobookRepositoryProvider);
      final fullBook = await repo.fetchFullOnlineMetadata(selectedBook);

      final mergedBook = AudiobookResult(
        id: widget.currentBook.id,
        title: fullBook.title,
        author: fullBook.author,
        narrator: fullBook.narrator ?? widget.currentBook.narrator,
        artworkUrl: fullBook.artworkUrl ?? widget.currentBook.artworkUrl,
        description: (fullBook.description != null && fullBook.description!.isNotEmpty) 
            ? fullBook.description! 
            : 'Audiobook stored locally/in library',
        totalChapters: widget.currentBook.totalChapters,
        language: fullBook.language ?? widget.currentBook.language,
        genre: fullBook.genre ?? widget.currentBook.genre,
        releaseDate: fullBook.releaseDate,
        publisher: fullBook.publisher,
        previewUrl: fullBook.previewUrl,
        durationMillis: fullBook.durationMillis,
        rating: fullBook.rating,
        ratingCount: fullBook.ratingCount,
      );

      await repo.cacheBookMetadata(mergedBook);

      if (mounted) {
        ref.invalidate(bookDetailsProvider(widget.currentBook.id));
        ref.invalidate(localAudiobooksProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metadata updated successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to apply metadata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Search book title...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _controller.clear(),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _performSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _results.isEmpty
                        ? const Center(child: Text('No metadata results found.'))
                        : ListView.builder(
                            controller: widget.scrollController,
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: item.artworkUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: item.artworkUrl!,
                                          memCacheWidth: 45,
                                          memCacheHeight: 45,
                                          width: 45,
                                          height: 45,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 45,
                                          height: 45,
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.book, size: 20),
                                        ),
                                ),
                                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(
                                  children: [
                                    Builder(builder: (context) {
                                      final isItunes = item.id.startsWith('itunes_meta:');
                                      final sourceName = isItunes ? 'iTunes' : 'Open Library';
                                      final sourceBgColor = isItunes 
                                          ? Colors.pink.withValues(alpha: 0.15) 
                                          : Colors.teal.withValues(alpha: 0.15);
                                      final sourceTextColor = isItunes 
                                          ? Colors.pink.shade700 
                                          : Colors.teal.shade700;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: sourceBgColor,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: sourceTextColor.withValues(alpha: 0.3), width: 0.5),
                                        ),
                                        child: Text(
                                          sourceName,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                            color: sourceTextColor,
                                          ),
                                        ),
                                      );
                                    }),
                                    if (item.language != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.language!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(item.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _selectBook(item),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

Widget _buildHtmlDescription(BuildContext context, String htmlText, TextStyle baseStyle, {int? maxLines}) {
  var text = htmlText
      .replaceAll('<br>', '\n')
      .replaceAll('<br/>', '\n')
      .replaceAll('<br />', '\n')
      .replaceAll('<p>', '')
      .replaceAll('</p>', '\n\n')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  final tagRegex = RegExp(r'(<[^>]+>)');
  final parts = text.split(tagRegex);
  final matches = tagRegex.allMatches(text).toList();

  final List<TextSpan> spans = [];
  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;

  for (int i = 0; i < parts.length; i++) {
    if (parts[i].isNotEmpty) {
      spans.add(TextSpan(
        text: parts[i],
        style: baseStyle.copyWith(
          fontWeight: isBold ? FontWeight.bold : baseStyle.fontWeight,
          fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
          decoration: isUnderline ? TextDecoration.underline : baseStyle.decoration,
        ),
      ));
    }

    if (i < matches.length) {
      final tag = matches[i].group(0)!.toLowerCase();
      if (tag == '<b>' || tag == '<strong>') {
        isBold = true;
      } else if (tag == '</b>' || tag == '</strong>') {
        isBold = false;
      } else if (tag == '<i>' || tag == '<em>') {
        isItalic = true;
      } else if (tag == '</i>' || tag == '</em>') {
        isItalic = false;
      } else if (tag == '<u>') {
        isUnderline = true;
      } else if (tag == '</u>') {
        isUnderline = false;
      }
    }
  }

  return RichText(
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    text: TextSpan(
      children: spans,
      style: baseStyle,
    ),
  );
}

class ExpandableDescription extends StatefulWidget {
  final String htmlText;
  final TextStyle baseStyle;

  const ExpandableDescription({
    super.key,
    required this.htmlText,
    required this.baseStyle,
  });

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Approximate calculation to check if text exceeds 4 lines
        final cleanText = widget.htmlText.replaceAll(RegExp(r'<[^>]+>'), '');
        final span = TextSpan(text: cleanText, style: widget.baseStyle);
        final tp = TextPainter(
          text: span,
          maxLines: 4,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);
        final exceeds = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHtmlDescription(
              context,
              widget.htmlText,
              widget.baseStyle,
              maxLines: _isExpanded ? null : 4,
            ),
            if (exceeds) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(
                  _isExpanded ? 'Read Less' : 'Read More',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class AudiobookPreviewWidget extends StatefulWidget {
  final String previewUrl;
  const AudiobookPreviewWidget({super.key, required this.previewUrl});

  @override
  State<AudiobookPreviewWidget> createState() => _AudiobookPreviewWidgetState();
}

class _AudiobookPreviewWidgetState extends State<AudiobookPreviewWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading = state.processingState == ProcessingState.loading ||
                       state.processingState == ProcessingState.buffering;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _player.seek(Duration.zero);
            _player.pause();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_player.duration == null || _player.duration == Duration.zero) {
          setState(() => _isLoading = true);
          await _player.setUrl(widget.previewUrl);
        }
        await _player.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play preview: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _togglePlay,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
      label: Text(_isPlaying ? 'Pause Preview' : 'Listen to Preview'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class AuthorCatalogScreen extends ConsumerStatefulWidget {
  final String author;

  const AuthorCatalogScreen({super.key, required this.author});

  @override
  ConsumerState<AuthorCatalogScreen> createState() => _AuthorCatalogScreenState();
}

class _AuthorCatalogScreenState extends ConsumerState<AuthorCatalogScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(authorAudiobooksProvider(widget.author));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.author),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Switch to list view' : 'Switch to grid view',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: async.when(
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No audiobooks found for ${widget.author}',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final trending = books.where((b) => b.rating != null && b.rating! > 0).toList();

          return CustomScrollView(
            slivers: [
              if (trending.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up_rounded, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Trending',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isGridView)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _responsiveCrossAxisCount(context),
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildGridCard(context, trending[index], theme),
                        childCount: trending.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildListTile(context, trending[index], theme),
                        childCount: trending.length,
                      ),
                    ),
                  ),
              ],

              // All Books section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.library_books_rounded, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'All Books by ${widget.author}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${books.length} books',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _responsiveCrossAxisCount(context),
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildGridCard(context, books[index], theme),
                      childCount: books.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildListTile(context, books[index], theme),
                      childCount: books.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load books by ${widget.author}',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _responsiveCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 700) return 4;
    if (width > 500) return 3;
    return 2;
  }

  Widget _buildGridCard(BuildContext context, AudiobookResult book, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: book.artworkUrl != null && book.artworkUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: book.artworkUrl!,
                      memCacheWidth: 200,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.book, size: 40),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.book, size: 40),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (book.rating != null) ...[
                Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  book.rating!.toStringAsFixed(1),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                if (book.ratingCount != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    '(${book.ratingCount})',
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, AudiobookResult book, ThemeData theme) {
    final durationStr = book.durationMillis != null && book.durationMillis! > 0
        ? _formatDurationStatic(book.durationMillis!)
        : '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: book.artworkUrl != null && book.artworkUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: book.artworkUrl!,
                    memCacheWidth: 56,
                    memCacheHeight: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.book, size: 28),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.book, size: 28),
                  ),
          ),
        ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                if (book.rating != null) ...[
                  Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    '${book.rating!.toStringAsFixed(1)} (${book.ratingCount ?? 0})',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                ],
                if (durationStr.isNotEmpty) ...[
                  Icon(Icons.timer_outlined, size: 11, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    durationStr,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
          );
        },
      ),
    );
  }

  static String _formatDurationStatic(int millis) {
    final duration = Duration(milliseconds: millis);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class GenreCatalogScreen extends ConsumerStatefulWidget {
  final String genre;
  const GenreCatalogScreen({super.key, required this.genre});

  @override
  ConsumerState<GenreCatalogScreen> createState() => _GenreCatalogScreenState();
}

class _GenreCatalogScreenState extends ConsumerState<GenreCatalogScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(genreAudiobooksProvider(widget.genre));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genre),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Switch to list view' : 'Switch to grid view',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: async.when(
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No audiobooks found in ${widget.genre}',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              if (_isGridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _responsiveCrossAxisCount(context),
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildGridCard(context, books[index], theme),
                      childCount: books.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildListTile(context, books[index], theme),
                      childCount: books.length,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load books')),
      ),
    );
  }

  int _responsiveCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 700) return 4;
    if (width > 500) return 3;
    return 2;
  }

  Widget _buildGridCard(BuildContext context, AudiobookResult book, ThemeData theme) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: book.artworkUrl != null && book.artworkUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: book.artworkUrl!, memCacheWidth: 200, width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                      errorWidget: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.book, size: 40),
                      ),
                    )
                  : Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.book, size: 40)),
            ),
          ),
          const SizedBox(height: 8),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (book.author != null && book.author!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, AudiobookResult book, ThemeData theme) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48, height: 48,
          child: book.artworkUrl != null && book.artworkUrl!.isNotEmpty
              ? CachedNetworkImage(imageUrl: book.artworkUrl!, memCacheWidth: 48, memCacheHeight: 48, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Icon(Icons.book, color: theme.colorScheme.onSurfaceVariant))
              : Icon(Icons.book, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: book.author != null && book.author!.isNotEmpty
          ? Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book))),
    );
  }
}
