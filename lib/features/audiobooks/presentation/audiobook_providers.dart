import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:audiotags/audiotags.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/audiobook_models.dart';
import '../data/audiobook_repository.dart';
import '../data/audiobook_addon_service.dart';
import '../../../core/di/injection.dart';
import '../../music/presentation/music_providers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/database.dart';

/// Tab toggle for Discovery screen (shared between music and audiobooks).
final discoveryTabProvider = StateProvider<String>((ref) => 'music');

/// Tracks when the last directory restore scan completed to avoid redundant
/// filesystem I/O on every provider load. Scans are skipped if < 30s old.
final lastDirectoryRestoreScanProvider = StateProvider<DateTime?>((ref) => null);

/// Provider for the AudiobookRepository singleton.
final audiobookRepositoryProvider = Provider<AudiobookRepository>((ref) {
  return getIt<AudiobookRepository>();
});

/// Audiobook search state management.
final audiobookSearchProvider = StateNotifierProvider<AudiobookSearchNotifier, AudiobookSearchState>((ref) {
  final repo = ref.read(audiobookRepositoryProvider);
  return AudiobookSearchNotifier(repo);
});

class AudiobookSearchNotifier extends StateNotifier<AudiobookSearchState> {
  final AudiobookRepository _repo;
  
  AudiobookSearchNotifier(this._repo) : super(const AudiobookSearchState());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AudiobookSearchState();
      return;
    }
    
    state = state.copyWith(isLoading: true, query: query, error: null);
    
    try {
      final results = await _repo.searchBooks(query);
      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Search failed: ${e.toString()}',
      );
    }
  }

  void clear() {
    state = const AudiobookSearchState();
  }
}

/// Currently selected audiobook for detail view.
final selectedAudiobookProvider = StateProvider<AudiobookResult?>((ref) => null);

/// Fetch chapters for a given book ID.
final bookChaptersProvider = FutureProvider.family<List<AudiobookChapter>, String>((ref, bookId) async {
  final repo = ref.read(audiobookRepositoryProvider);
  return repo.getBookChapters(bookId);
});

/// Selected genre filter for book catalog.
final selectedGenreProvider = StateProvider<String>((ref) => 'All');

/// Browse the audiobook catalog (trending by default, or filtered by genre).
final audiobookCatalogProvider = FutureProvider.autoDispose<List<AudiobookResult>>((ref) async {
  final repo = ref.read(audiobookRepositoryProvider);
  final genre = ref.watch(selectedGenreProvider);
  if (genre == 'All') {
    return repo.browseCatalog();
  } else {
    return repo.fetchCatalogByGenre(genre);
  }
});

/// Trending audiobooks from Apple RSS top chart.
final trendingAudiobooksProvider = FutureProvider.autoDispose<List<AudiobookResult>>((ref) async {
  final repo = ref.read(audiobookRepositoryProvider);
  return repo.browseCatalog();
});

/// Top-rated audiobooks weighted by rating and popularity.
final topRatedAudiobooksProvider = FutureProvider.autoDispose<List<AudiobookResult>>((ref) async {
  final repo = ref.read(audiobookRepositoryProvider);
  return repo.fetchTopRated();
});

/// Audiobooks by a specific author (for "More from Author" section).
final authorAudiobooksProvider = FutureProvider.family.autoDispose<List<AudiobookResult>, String>((ref, author) async {
  final repo = ref.read(audiobookRepositoryProvider);
  return repo.fetchBooksByAuthor(author);
});

final genreAudiobooksProvider = FutureProvider.family.autoDispose<List<AudiobookResult>, String>((ref, genre) async {
  final repo = ref.read(audiobookRepositoryProvider);
  return repo.searchItunesCatalog(genre, limit: 20);
});

/// Listens to the repository's progressChanged stream so that any
/// provider watching this will re-evaluate after each progress save.
final _audiobookProgressInvalidator = StreamProvider<void>((ref) {
  final repo = ref.watch(audiobookRepositoryProvider);
  return repo.progressChanged;
});

/// Get all in-progress audiobooks for "Continue Listening" section.
final inProgressAudiobooksProvider = FutureProvider<List<AudiobookWithProgress>>((ref) async {
  // Re-evaluate whenever progress is saved
  ref.watch(_audiobookProgressInvalidator);
  try {
    final repo = ref.read(audiobookRepositoryProvider);

    final allProgress = await repo.getAllInProgressBooks();
    final dismissedBooks = await repo.getDismissedBooksFromContinueListening();

    // Resolve metadata for each progress entry
    final List<_ResolvedProgress> resolved = [];
    for (final p in allProgress) {
      if (dismissedBooks.contains(p.bookId)) continue;
      final cached = await repo.getCachedMetadata(p.bookId);
      final summary = await repo.getBookProgressSummary(p.bookId);
      resolved.add(_ResolvedProgress(
        progress: p,
        title: cached?.title ?? 'Audiobook',
        author: cached?.author ?? 'Unknown Author',
        artworkUrl: cached?.artworkUrl,
        totalCh: cached?.totalChapters,
        progressPercent: (summary?['progressPercent'] as num?)?.toDouble() ?? 0.0,
      ));
    }

    // Deduplicate by normalized bookId first, then by title+author
    final Map<String, _ResolvedProgress> byNormId = {};
    for (final r in resolved) {
      final normId = AudiobookRepository.normalizeBookId(r.progress.bookId);
      final existing = byNormId[normId];
      if (existing == null || r.progress.lastListenedAt.isAfter(existing.progress.lastListenedAt)) {
        byNormId[normId] = r;
      }
    }

    // If still duplicates by title+author (different normalized IDs for same book),
    // keep only the most recent
    final List<_ResolvedProgress> deduped = [];
    final Set<String> seenTitleAuthor = {};
    final sorted = byNormId.values.toList()
      ..sort((a, b) => b.progress.lastListenedAt.compareTo(a.progress.lastListenedAt));
    for (final r in sorted) {
      final key = '${r.title}|${r.author}';
      if (seenTitleAuthor.add(key)) {
        deduped.add(r);
      }
    }

    return deduped.map((r) => AudiobookWithProgress(
      book: AudiobookResult(
        id: r.progress.bookId,
        title: r.title,
        author: r.author,
        artworkUrl: r.artworkUrl,
        totalChapters: r.totalCh,
      ),
      currentChapter: r.progress.chapterIndex,
      positionMillis: r.progress.positionMillis,
      totalChapters: r.totalCh ?? 0,
      lastListenedAt: r.progress.lastListenedAt,
      progressPercent: r.progressPercent,
    )).toList();
  } catch (e, stack) {
    print('[inProgressAudiobooksProvider] Error: $e\n$stack');
    return [];
  }
});

/// Get book details (fetches from addon and caches, enriched with ratings).
final bookDetailsProvider = FutureProvider.family<AudiobookResult?, String>((ref, bookId) async {
  final repo = ref.read(audiobookRepositoryProvider);
  
  AudiobookResult? bookResult;
  final cached = await repo.getCachedMetadata(bookId);
  if (cached != null) {
    bookResult = repo.metadataToResult(cached);
  } else {
    final details = await repo.getBookDetails(bookId);
    if (details != null) {
      await repo.cacheBookMetadata(details);
      bookResult = details;
    }
  }

  // Fetch rating from Open Library dynamically (only if iTunes didn't provide one)
  if (bookResult != null && bookResult.rating == null && bookResult.ratingCount == null) {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 2);
      dio.options.receiveTimeout = const Duration(seconds: 2);
      final query = Uri.encodeComponent(bookResult.title);
      final url = 'https://openlibrary.org/search.json?q=$query&fields=title,ratings_average,ratings_count&limit=3';
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final docs = response.data['docs'] as List<dynamic>?;
        if (docs != null && docs.isNotEmpty) {
          final doc = docs.first;
          final avg = doc['ratings_average'] as num?;
          final count = doc['ratings_count'] as int?;
          if (avg != null && count != null) {
            bookResult = bookResult.copyWith(
              rating: avg.toDouble(),
              ratingCount: count,
            );
          }
        }
      }
    } catch (e) {
      print('[bookDetailsProvider] Error fetching ratings from Open Library: $e');
    }
  }

  return bookResult;
});

/// Future provider for tracking the cache/library status of a torrent book.
final torrentStatusProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, bookId) async {
  final repo = ref.read(audiobookRepositoryProvider);
  return repo.checkTorrentStatus(bookId);
});

/// Get all chapter-level progress entries for a specific book on the detail screen.
final bookChapterProgressProvider = FutureProvider.autoDispose.family<List<DbAudiobookProgress>, String>((ref, bookId) async {
  final repo = ref.read(audiobookRepositoryProvider);

  final existingProgress = await repo.getBookChapterProgress(bookId);
  if (existingProgress.isEmpty) {
    // Try restoring from legacy per-book progress.json (migration path)
    try {
      final dirPath = await repo.getLocalBookDirectoryForBackup(bookId);
      if (dirPath != null) {
        await repo.restoreProgressFromLocalFolder(bookId, dirPath);
        await repo.restoreBookmarksFromLocalFolder(bookId, dirPath);
      }
    } catch (e) {
      print('[bookChapterProgressProvider] Error restoring progress from local folder: $e');
    }
    return repo.getBookChapterProgress(bookId);
  }

  return existingProgress;
});

/// Audio file extensions recognized as audiobook chapters.
const Set<String> _audioExtensions = {
  '.mp3',
  '.m4a',
  '.m4b',
  '.aac',
  '.ogg',
  '.wav',
  '.flac',
};

/// Helper: count audio/epub files directly inside a directory (non-recursive).
Future<int> _countAudioFiles(Directory dir) async {
  int count = 0;
  await for (final entity in dir.list()) {
    if (entity is File) {
      final ext = _getExt(entity.path);
      if (_audioExtensions.contains(ext) || ext == '.epub') count++;
    }
  }
  return count;
}

String _getExt(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1) return '';
  return path.substring(dot).toLowerCase();
}

/// Helper: read metadata and extract artwork for a directory
Future<AudiobookResult> _getAudiobookMetadata(Directory dir, String id, String defaultTitle) async {
  String title = defaultTitle;
  String author = 'Local Library';
  String? artworkPath;
  String? description;
  int audioCount = 0;

  // Check metadata.json and cover image inside the directory first
  final metaFile = File(p.join(dir.path, 'metadata.json'));
  String? narrator;
  String? language;
  String? genre;
  int? tc;

  if (await metaFile.exists()) {
    try {
      final content = await metaFile.readAsString();
      if (content.trim().isEmpty) {
        print('[localAudiobooksProvider] metadata.json is empty. Deleting.');
        await metaFile.delete();
      } else {
        final data = jsonDecode(content) as Map<String, dynamic>;
        title = data['title'] as String? ?? title;
        author = data['author'] as String? ?? author;
        String? rawDescription = data['description'] as String?;
        // Decode JSON_EXT: wrapper if present
        if (rawDescription != null && rawDescription.startsWith('JSON_EXT:')) {
          try {
            final rawJson = rawDescription.substring('JSON_EXT:'.length);
            final extData = jsonDecode(rawJson) as Map<String, dynamic>;
            description = extData['description'] as String?;
          } catch (_) {
            description = null;
          }
        } else {
          description = rawDescription;
        }
        // Safety: ensure no raw JSON_EXT: prefix leaks to UI
        if (description != null && description!.startsWith('JSON_EXT:')) {
          description = null;
        }
        narrator = data['narrator'] as String?;
        language = data['language'] as String?;
        genre = data['genre'] as String?;
        tc = data['totalChapters'] as int?;
      }
    } catch (e) {
      print('[localAudiobooksProvider] Error reading local metadata.json: $e');
      try {
        await metaFile.delete();
        print('[localAudiobooksProvider] Deleted corrupted metadata.json file');
      } catch (_) {}
    }
  }

  final coverNames = ['cover.jpg', 'cover.png', 'folder.jpg', 'folder.png', 'poster.jpg', 'poster.png', 'AlbumArt.jpg', 'AlbumArt.png', 'front.jpg', 'front.png'];
  for (final name in coverNames) {
    final f = File(p.join(dir.path, name));
    if (await f.exists()) {
      artworkPath = f.path;
      break;
    }
  }

  // If metadata has totalChapters, return fast without listing all files
  if (tc != null && tc > 0) {
    return AudiobookResult(
      id: id,
      title: title,
      author: author,
      artworkUrl: artworkPath,
      description: description,
      narrator: narrator,
      language: language,
      genre: genre,
      totalChapters: tc,
    );
  }

  File? firstAudioFile;
  await for (final entity in dir.list()) {
    if (entity is File) {
      final ext = _getExt(entity.path);
      if (_audioExtensions.contains(ext)) {
        audioCount++;
        firstAudioFile ??= entity;
      }
    }
  }

  if (audioCount == 0) {
    return AudiobookResult(
      id: id,
      title: title,
      author: author,
      artworkUrl: artworkPath,
      description: description,
      totalChapters: 0,
    );
  }

  if (firstAudioFile != null && artworkPath == null) {
    try {
      final tag = await AudioTags.read(firstAudioFile.path);
      if (tag != null) {
        if (title == defaultTitle && tag.album != null && tag.album!.trim().isNotEmpty) {
          title = tag.album!.trim();
        } else if (title == defaultTitle && tag.title != null && tag.title!.trim().isNotEmpty && audioCount == 1) {
          title = tag.title!.trim();
        }
        
        if (author == 'Local Library' && tag.artist != null && tag.artist!.trim().isNotEmpty) {
          author = tag.artist!.trim();
        }

        if (tag.pictures != null && tag.pictures!.isNotEmpty) {
          final picture = tag.pictures!.first;
          final bytes = picture.bytes;
          if (bytes != null && bytes.isNotEmpty) {
            final tempDir = Directory.systemTemp;
            final pathHash = id.hashCode.abs();
            final ext = picture.mimeType == MimeType.png ? 'png' : 'jpg';
            final artFile = File('${tempDir.path}/local_book_art_$pathHash.$ext');
            await artFile.writeAsBytes(bytes);
            artworkPath = artFile.path;
          }
        }
      }
    } catch (e) {
      print('[localAudiobooksProvider] Error reading tags: $e');
    }
  }

  return AudiobookResult(
    id: id,
    title: title,
    author: author,
    artworkUrl: artworkPath,
    description: description,
    narrator: narrator,
    language: language,
    genre: genre,
    totalChapters: audioCount,
  );
}

/// Helper: read metadata and extract artwork for a single audio file
Future<AudiobookResult> _getBookMetadataFromAudioFile(File file, String id, String defaultTitle) async {
  String title = defaultTitle;
  String author = 'Local Library';
  String? artworkPath;

  try {
    final tag = await AudioTags.read(file.path);
    if (tag != null) {
      if (tag.album != null && tag.album!.trim().isNotEmpty) {
        title = tag.album!.trim();
      } else if (tag.title != null && tag.title!.trim().isNotEmpty) {
        title = tag.title!.trim();
      }
      if (tag.artist != null && tag.artist!.trim().isNotEmpty) {
        author = tag.artist!.trim();
      }
      if (tag.pictures != null && tag.pictures!.isNotEmpty) {
        final picture = tag.pictures!.first;
        final bytes = picture.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          final tempDir = Directory.systemTemp;
          final pathHash = id.hashCode.abs();
          final ext = picture.mimeType == MimeType.png ? 'png' : 'jpg';
          final artFile = File('${tempDir.path}/local_book_art_$pathHash.$ext');
          await artFile.writeAsBytes(bytes);
          artworkPath = artFile.path;
          }
        }
      }
    } catch (e) {
    print('[localAudiobooksProvider] Error reading tags from file: $e');
  }

  return AudiobookResult(
    id: id,
    title: title,
    author: author,
    artworkUrl: artworkPath,
    totalChapters: 1,
  );
}

/// Scan the user's local audiobook folder.
///
/// Both subfolders (Layout B) and individual audio files directly in the root are supported.
final localAudiobooksProvider = FutureProvider<List<AudiobookResult>>((ref) async {
  try {
    final repo = ref.read(audiobookRepositoryProvider);
    final List<AudiobookResult> results = [];

    final settings = ref.read(settingsProvider);
    final folderPath = settings.audiobookFolder;
    if (folderPath != null && folderPath.isNotEmpty) {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        await for (final entity in dir.list().timeout(const Duration(seconds: 15))) {
          if (entity is Directory) {
            final bookId = 'local:${entity.path}';
            final metaFile = File(p.join(entity.path, 'metadata.json'));

            bool isBook = false;
            if (await metaFile.exists()) {
              isBook = true;
            } else {
              final audioCount = await _countAudioFiles(entity);
              isBook = audioCount > 0;
            }

            if (isBook) {
              final folderName = entity.path.split('/').last;
              final book = await _getAudiobookMetadata(entity, bookId, folderName);
              results.add(book);
              repo.cacheBookMetadata(book, writeLocalBackup: false).catchError((_) {});
              repo.restoreBookmarksFromLocalFolder(book.id, entity.path).catchError((_) {});
            }
          } else if (entity is File) {
            final ext = _getExt(entity.path);
            final isAudio = _audioExtensions.contains(ext);
            final isEpub = ext == '.epub';
            if (isAudio || isEpub) {
              final fileName = entity.path.split('/').last;
              final defaultTitle = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
              // Organize loose files into their own subfolder
              if (entity.parent.path == folderPath) {
                final folderName = defaultTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
                if (folderName.isNotEmpty) {
                  final bookDir = Directory(p.join(folderPath, folderName));
                  if (!await bookDir.exists()) await bookDir.create();
                  final destPath = p.join(bookDir.path, fileName);
                  if (!await File(destPath).exists()) {
                    await entity.rename(destPath);
                    // Process as a directory-based book
                    final bookId = 'local:${bookDir.path}';
                    final book = await _getAudiobookMetadata(bookDir, bookId, defaultTitle);
                    results.add(book);
                    repo.cacheBookMetadata(book, writeLocalBackup: false).catchError((_) {});
                  }
                  continue;
                }
              }
              // If not organizing (not in root or no valid name), fall back to loose file handling
              final bookId = 'local:${entity.path}';
              AudiobookResult book;
              if (isEpub) {
                book = AudiobookResult(
                  id: bookId,
                  title: defaultTitle,
                  author: 'Local Library',
                  artworkUrl: null,
                  totalChapters: 1,
                );
              } else {
                book = await _getBookMetadataFromAudioFile(entity, bookId, defaultTitle);
              }
              results.add(book);
              repo.cacheBookMetadata(book, writeLocalBackup: false).catchError((_) {});
            }
          }
        }
      }
    }

    if (settings.isValid) {
      final torBoxBooks = await repo.getTorBoxLibraryAudiobooks();
      results.addAll(torBoxBooks);
    }

    final Map<String, AudiobookResult> uniqueBooks = {};
    for (final book in results) {
      uniqueBooks[book.id] = book;
    }

    final List<AudiobookResult> finalResults = uniqueBooks.values.toList();
    finalResults.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return finalResults;
  } catch (e, stack) {
    print('[localAudiobooksProvider] Error: $e\n$stack');
    return [];
  }
});

final bookTorrentSearchProvider = FutureProvider.autoDispose.family<List<AudiobookResult>, String>((ref, query) async {
  final repo = ref.read(audiobookRepositoryProvider);
  if (query.trim().isEmpty) return [];
  final results = await repo.searchBooks(query);
  return results.where((b) => b.id.startsWith('torrent:') || b.id.startsWith('audiobookbay:')).toList();
});

class AudiobookDownloadState {
  final double progress;
  final String currentChapterTitle;
  final int currentChapterIndex;
  final int totalChapters;
  final int downloadedBytes;
  final int totalBytes;
  final String status; // 'downloading', 'paused', 'failed', 'completed', 'deleting'

  const AudiobookDownloadState({
    required this.progress,
    required this.currentChapterTitle,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.status,
  });

  factory AudiobookDownloadState.initial() {
    return const AudiobookDownloadState(
      progress: 0.0,
      currentChapterTitle: '',
      currentChapterIndex: 0,
      totalChapters: 0,
      downloadedBytes: 0,
      totalBytes: -1,
      status: 'downloading',
    );
  }

  AudiobookDownloadState copyWith({
    double? progress,
    String? currentChapterTitle,
    int? currentChapterIndex,
    int? totalChapters,
    int? downloadedBytes,
    int? totalBytes,
    String? status,
  }) {
    return AudiobookDownloadState(
      progress: progress ?? this.progress,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      totalChapters: totalChapters ?? this.totalChapters,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
    );
  }
}
/// Tracks downloading states of audiobook IDs to their progress details

/// Increment to trigger bookmark list refresh (e.g. from notification action).
final bookmarkRefreshTrigger = StateProvider<int>((ref) => 0);

final audiobookBookmarksProvider = FutureProvider.family<List<AudiobookBookmark>, String>((ref, bookId) async {
  ref.watch(bookmarkRefreshTrigger);
  final repo = ref.read(audiobookRepositoryProvider);
  return repo.getBookmarks(bookId);
});

final audiobookDownloadProvider = StateNotifierProvider<AudiobookDownloadNotifier, Map<String, AudiobookDownloadState>>((ref) {
  final repo = ref.read(audiobookRepositoryProvider);
  return AudiobookDownloadNotifier(repo, ref);
});

class AudiobookDownloadNotifier extends StateNotifier<Map<String, AudiobookDownloadState>> {
  final AudiobookRepository _repo;
  final Ref _ref;
  final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  final Set<String> _pausedBooks = {};

  AudiobookDownloadNotifier(this._repo, this._ref) : super({});

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
    _notificationsInitialized = true;
  }

  String _formatBytes(int bytes) {
    if (bytes < 0) return '?';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _showProgressNotification(String bookId, String title, double progress, {int downloadedBytes = 0, int totalBytes = -1}) async {
    try {
      await _initNotifications();
      final isDone = progress >= 1.0;
      final isFailed = progress < 0.0 && progress != -4.0;
      final isPaused = progress == -4.0;
      
      final notificationId = bookId.hashCode.abs();

      if (isDone) {
        final body = totalBytes > 0 ? '${_formatBytes(totalBytes)} — Complete' : title;
        final androidDetails = AndroidNotificationDetails(
          'audiobook_downloads',
          'Audiobook Downloads',
          channelDescription: 'Notifications for audiobook download progress',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: false,
          autoCancel: true,
        );
        await _notificationsPlugin.show(
          notificationId,
          'Download Complete',
          body,
          NotificationDetails(android: androidDetails),
        );
      } else if (isPaused) {
        final body = totalBytes > 0 ? '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)} — Paused' : title;
        final androidDetails = AndroidNotificationDetails(
          'audiobook_downloads',
          'Audiobook Downloads',
          channelDescription: 'Notifications for audiobook download progress',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: false,
        );
        await _notificationsPlugin.show(
          notificationId,
          'Download Paused',
          body,
          NotificationDetails(android: androidDetails),
        );
      } else if (isFailed) {
        final body = totalBytes > 0 ? '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)} — Failed' : title;
        final androidDetails = AndroidNotificationDetails(
          'audiobook_downloads',
          'Audiobook Downloads',
          channelDescription: 'Notifications for audiobook download progress',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
        );
        await _notificationsPlugin.show(
          notificationId,
          'Download Failed',
          body,
          NotificationDetails(android: androidDetails),
        );
      } else {
        final percent = (progress * 100).round();
        final body = totalBytes > 0
            ? '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)} ($percent%)'
            : '$percent%';
        final androidDetails = AndroidNotificationDetails(
          'audiobook_downloads',
          'Audiobook Downloads',
          channelDescription: 'Notifications for audiobook download progress',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          ongoing: true,
          onlyAlertOnce: true,
        );
        await _notificationsPlugin.show(
          notificationId,
          body,
          title,
          NotificationDetails(android: androidDetails),
        );
      }
    } catch (e) {
      print('[AudiobookDownloadNotifier] Error showing notification: $e');
    }
  }

  Future<void> downloadBook(AudiobookResult book, List<AudiobookChapter> chapters) async {
    final settings = _ref.read(settingsProvider);
    final downloadDirPath = settings.audiobookFolder;
    
    if (downloadDirPath == null || downloadDirPath.isEmpty) {
      state = {
        ...state,
        book.id: AudiobookDownloadState(
          progress: -1.0,
          currentChapterTitle: '',
          currentChapterIndex: 0,
          totalChapters: 0,
          downloadedBytes: 0,
          totalBytes: -1,
          status: 'failed',
        ),
      };
      return;
    }

    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          state = {
            ...state,
            book.id: AudiobookDownloadState(
              progress: -2.0,
              currentChapterTitle: '',
              currentChapterIndex: 0,
              totalChapters: 0,
              downloadedBytes: 0,
              totalBytes: -1,
              status: 'failed',
            ),
          };
          return;
        }
      }
      
      // Request notification permission for background tasks/downloads
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    }

    if (state.containsKey(book.id) && state[book.id]!.progress >= 0.0 && state[book.id]!.progress < 1.0) {
      return; // Already downloading
    }

    _pausedBooks.remove(book.id);
    
    // Group chapters by unique stream URL to avoid downloading the same file multiple times
    final Map<String, List<AudiobookChapter>> urlToChapters = {};
    for (final ch in chapters) {
      final url = ch.streamUrl;
      if (url != null && url.isNotEmpty) {
        urlToChapters.putIfAbsent(url, () => []).add(ch);
      }
    }

    final uniqueUrls = urlToChapters.keys.toList();
    if (uniqueUrls.isEmpty) {
      state = {
        ...state,
        book.id: AudiobookDownloadState(
          progress: -3.0,
          currentChapterTitle: '',
          currentChapterIndex: 0,
          totalChapters: 0,
          downloadedBytes: 0,
          totalBytes: -1,
          status: 'failed',
        ),
      };
      return;
    }

    final totalTasks = uniqueUrls.length;
    final initialChapters = urlToChapters[uniqueUrls[0]]!;
    
    state = {
      ...state,
      book.id: AudiobookDownloadState(
        progress: 0.0,
        currentChapterTitle: initialChapters.isNotEmpty ? initialChapters[0].title : '',
        currentChapterIndex: 1,
        totalChapters: totalTasks,
        downloadedBytes: 0,
        totalBytes: -1,
        status: 'downloading',
      ),
    };
    _showProgressNotification(book.id, book.title, 0.0, downloadedBytes: 0, totalBytes: -1);
    
    try {
      final sanitizedTitle = book.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final bookDir = Directory(p.join(downloadDirPath, sanitizedTitle));
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }

      final Map<String, String> urlToRelativeFilename = {};
      int completedTasks = 0;

      for (int i = 0; i < uniqueUrls.length; i++) {
        if (_pausedBooks.contains(book.id)) {
          break;
        }

        final url = uniqueUrls[i];
        final currentChapters = urlToChapters[url]!;
        final firstChapter = currentChapters.first;
        
        // Update state with the current task we are starting to download
        final current = state[book.id]!;
        state = {
          ...state,
          book.id: current.copyWith(
            currentChapterTitle: firstChapter.title,
            currentChapterIndex: i + 1,
            downloadedBytes: 0,
            totalBytes: -1,
          ),
        };

        final streamUrl = await _repo.resolveChapterStream(firstChapter);
        if (streamUrl == null || streamUrl.isEmpty) {
          continue;
        }

        // Determine file extension
        String ext = '.mp3';
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        
        int? torrentId;
        int? fileId;
        if (segments.length >= 2) {
          torrentId = int.tryParse(segments[0]);
          fileId = int.tryParse(segments[1]);
        }

        if (torrentId != null && fileId != null) {
          final db = getIt<AppDatabase>();
          final allFiles = await db.getAllFiles();
          final dbFile = allFiles.where((f) => f.id == fileId && f.torrentId == torrentId).firstOrNull;
          if (dbFile != null) {
            final dot = dbFile.name.lastIndexOf('.');
            if (dot != -1) {
              ext = dbFile.name.substring(dot).toLowerCase();
            }
          }
        } else {
          final lowerUrl = url.toLowerCase();
          if (lowerUrl.contains('.m4b')) {
            ext = '.m4b';
          } else if (lowerUrl.contains('.m4a')) {
            ext = '.m4a';
          } else {
            final dot = firstChapter.title.lastIndexOf('.');
            if (dot != -1) {
              ext = firstChapter.title.substring(dot).toLowerCase();
            } else {
              final urlPath = uri.path.toLowerCase();
              final urlDot = urlPath.lastIndexOf('.');
              if (urlDot != -1) {
                ext = urlPath.substring(urlDot);
                if (ext.length > 5) ext = '.mp3';
              }
            }
          }
        }

        final displayName = uniqueUrls.length == 1 
            ? book.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim()
            : '${(i + 1).toString().padLeft(3, '0')} - ${firstChapter.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim()}';
        final fileName = '$displayName$ext';
        urlToRelativeFilename[url] = fileName;
        final savePath = p.join(bookDir.path, fileName);

        final fileToSave = File(savePath);
        int downloadedBytes = 0;
        int totalBytes = -1;
        int retryCount = 0;
        int socketErrorCount = 0;
        const maxRetries = 30;

        // Check if file exists and get size for resuming
        if (await fileToSave.exists()) {
          downloadedBytes = await fileToSave.length();
        }

        while (downloadedBytes < totalBytes || totalBytes == -1) {
          if (_pausedBooks.contains(book.id)) {
            break;
          }

          try {
            final client = HttpClient();
            client.connectionTimeout = const Duration(seconds: 15);
            final request = await client.getUrl(Uri.parse(streamUrl));
            
            if (downloadedBytes > 0) {
              request.headers.add('Range', 'bytes=$downloadedBytes-');
            }
            
            final response = await request.close();
            if (response.statusCode != 200 && response.statusCode != 206) {
              if (response.statusCode == 416) {
                // Range Not Satisfiable: file is already fully downloaded
                break;
              }
              throw HttpException('Server returned status code ${response.statusCode}');
            }

            if (totalBytes == -1) {
              if (response.statusCode == 206) {
                final rangeHeader = response.headers.value('content-range');
                if (rangeHeader != null) {
                  final parts = rangeHeader.split('/');
                  if (parts.length > 1) {
                    totalBytes = int.tryParse(parts[1]) ?? -1;
                  }
                }
              }
              if (totalBytes == -1) {
                totalBytes = response.contentLength;
              }
            }

            final sink = fileToSave.openWrite(mode: FileMode.writeOnlyAppend);
            
            await for (final data in response) {
              if (_pausedBooks.contains(book.id)) {
                break;
              }
              sink.add(data);
              downloadedBytes += data.length;
              
              final double taskProgress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
              final overallProgress = (completedTasks + taskProgress) / totalTasks;
              
              final currentLiveState = state[book.id]!;
              final currentProgress = currentLiveState.progress;
              final bytesDiff = downloadedBytes - currentLiveState.downloadedBytes;
              
              if ((overallProgress - currentProgress) >= 0.01 || overallProgress >= 0.99 || bytesDiff.abs() >= 500 * 1024) {
                state = {
                  ...state,
                  book.id: currentLiveState.copyWith(
                    progress: overallProgress,
                    downloadedBytes: downloadedBytes,
                    totalBytes: totalBytes,
                  ),
                };
                _showProgressNotification(book.id, book.title, overallProgress, downloadedBytes: downloadedBytes, totalBytes: totalBytes);
              }
            }
            await sink.flush();
            await sink.close();

            if (_pausedBooks.contains(book.id)) {
              print('[AudiobookDownloadNotifier] Download paused for ${book.title}');
              _showProgressNotification(book.id, book.title, -4.0, downloadedBytes: downloadedBytes, totalBytes: totalBytes);
              return;
            }
            
            if (totalBytes > 0 && downloadedBytes >= totalBytes) {
              break;
            }
            if (totalBytes == -1) {
              break;
            }
          } catch (e) {
            print('[AudiobookDownloadNotifier] Temp download error at byte $downloadedBytes/$totalBytes for $fileName: $e');
            
            final isSocketError = e is SocketException || e.toString().contains('SocketException') || e.toString().contains('Failed host lookup');
            final int delaySeconds;
            
            if (isSocketError) {
              delaySeconds = 30;
              socketErrorCount++;
              if (socketErrorCount % 5 == 0) {
                retryCount++;
              }
            } else {
              retryCount++;
              delaySeconds = (5 * retryCount).clamp(5, 30);
            }
            
            if (retryCount > maxRetries) {
              rethrow;
            }
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }

        if (_pausedBooks.contains(book.id)) {
          break;
        }

        // Update database if it's a TorBox file so it plays locally next time
        if (torrentId != null && fileId != null) {
          final db = getIt<AppDatabase>();
          await db.updateFileLocalPath(torrentId, fileId, savePath);
        }

        completedTasks++;
        final currentLive = state[book.id]!;
        state = {
          ...state,
          book.id: currentLive.copyWith(
            progress: completedTasks / totalTasks,
            downloadedBytes: 0,
            totalBytes: -1,
          ),
        };
      }

      if (_pausedBooks.contains(book.id)) {
        final cur = state[book.id];
        _showProgressNotification(book.id, book.title, -4.0, downloadedBytes: cur?.downloadedBytes ?? 0, totalBytes: cur?.totalBytes ?? -1);
        return;
      }

      // Mark the book meta totalChapters correctly in DB cache
      await _repo.cacheBookMetadata(book.copyWith(
        totalChapters: totalTasks,
      ));

      // Save metadata.json and cover image to the downloaded subfolder
      try {
        final metaFile = File(p.join(bookDir.path, 'metadata.json'));
        final Map<String, dynamic> metaMap = {
          'title': book.title,
          'author': book.author,
          'description': book.description,
          'chapters': chapters.map((ch) {
            final fileName = urlToRelativeFilename[ch.streamUrl ?? ''];
            return {
              'id': ch.id,
              'title': ch.title,
              'chapterNumber': ch.chapterNumber,
              'startTimeMillis': ch.startTimeMillis,
              'durationMillis': ch.durationMillis,
              'streamUrl': fileName ?? ch.streamUrl,
            };
          }).toList(),
        };
        await metaFile.writeAsString(jsonEncode(metaMap));

        if (book.artworkUrl != null && book.artworkUrl!.isNotEmpty) {
          final coverFile = File(p.join(bookDir.path, 'cover.jpg'));
          if (book.artworkUrl!.startsWith('/') || book.artworkUrl!.startsWith('file://')) {
            final srcPath = book.artworkUrl!.startsWith('file://') 
                ? Uri.parse(book.artworkUrl!).toFilePath() 
                : book.artworkUrl!;
            final srcFile = File(srcPath);
            if (await srcFile.exists()) {
              await srcFile.copy(coverFile.path);
            }
          } else {
            try {
              final client = HttpClient();
              final request = await client.getUrl(Uri.parse(book.artworkUrl!));
              final response = await request.close();
              if (response.statusCode == 200) {
                final bytes = await response.expand((b) => b).toList();
                await coverFile.writeAsBytes(bytes);
              }
            } catch (e) {
              print('[AudiobookDownloadNotifier] Error downloading cover image: $e');
            }
          }
        }
      } catch (e) {
        print('[AudiobookDownloadNotifier] Error writing local files: $e');
      }

      final finalCurrent = state[book.id]!;
      state = {
        ...state,
        book.id: finalCurrent.copyWith(
          progress: 1.0,
          status: 'completed',
        ),
      };
      _showProgressNotification(book.id, book.title, 1.0, downloadedBytes: finalCurrent.downloadedBytes, totalBytes: finalCurrent.totalBytes);
      
      _ref.invalidate(localAudiobooksProvider);
      _ref.invalidate(inProgressAudiobooksProvider);
      
    } catch (e) {
      print('[AudiobookDownloadNotifier] Download failed: $e');
      final current = state[book.id];
      state = {
        ...state,
        book.id: (current ?? AudiobookDownloadState.initial()).copyWith(
          progress: -3.0,
          status: 'failed',
        ),
      };
      _showProgressNotification(book.id, book.title, -3.0, downloadedBytes: current?.downloadedBytes ?? 0, totalBytes: current?.totalBytes ?? -1);
    }
  }
  void pauseBook(String bookId) {
    _pausedBooks.add(bookId);
    if (state.containsKey(bookId)) {
      state = {
        ...state,
        bookId: state[bookId]!.copyWith(status: 'paused', progress: -4.0),
      };
    } else {
      state = {
        ...state,
        bookId: AudiobookDownloadState(
          progress: -4.0,
          currentChapterTitle: '',
          currentChapterIndex: 0,
          totalChapters: 0,
          downloadedBytes: 0,
          totalBytes: -1,
          status: 'paused',
        ),
      };
    }
  }

  Future<void> deleteDownloadedBook(AudiobookResult book, List<AudiobookChapter> chapters) async {
    _pausedBooks.add(book.id);
    final current = state[book.id];
    state = {
      ...state,
      book.id: (current ?? AudiobookDownloadState.initial()).copyWith(
        status: 'deleting',
        progress: -5.0,
      ),
    };
    
    final settings = _ref.read(settingsProvider);
    final downloadDirPath = settings.audiobookFolder;
    if (downloadDirPath != null && downloadDirPath.isNotEmpty) {
      final sanitizedTitle = book.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final bookDir = Directory(p.join(downloadDirPath, sanitizedTitle));
      if (await bookDir.exists()) {
        try {
          await bookDir.delete(recursive: true);
        } catch (e) {
          print('[AudiobookDownloadNotifier] Error deleting directory: $e');
        }
      }
    }

    final db = getIt<AppDatabase>();
    for (final chapter in chapters) {
      final uri = Uri.tryParse(chapter.streamUrl ?? '');
      if (uri != null && uri.pathSegments.length >= 2) {
        final torrentId = int.tryParse(uri.pathSegments[0]);
        final fileId = int.tryParse(uri.pathSegments[1]);
        if (torrentId != null && fileId != null) {
          await db.updateFileLocalPath(torrentId, fileId, null);
        }
      }
    }

    // Cancel notification
    final notificationId = book.id.hashCode.abs();
    await _notificationsPlugin.cancel(notificationId);

    state = Map.from(state)..remove(book.id);
    _ref.invalidate(localAudiobooksProvider);
    _ref.invalidate(inProgressAudiobooksProvider);
  }

  void clearStatus(String bookId) {
    state = Map.from(state)..remove(bookId);
  }
}

/// Provider to check if a book has a local EPUB file and return its path.
final bookEpubPathProvider = FutureProvider.family<String?, String>((ref, bookId) async {
  try {
    String? folderPath;
    if (bookId.startsWith('local:')) {
      final rawPath = bookId.substring('local:'.length);
      final entityType = FileSystemEntity.typeSync(rawPath);
      if (entityType == FileSystemEntityType.directory) {
        folderPath = rawPath;
      } else {
        folderPath = File(rawPath).parent.path;
      }
    } else if (bookId.startsWith('torrent:')) {
      final settings = ref.read(settingsProvider);
      final audiobookFolder = settings.audiobookFolder;
      if (audiobookFolder != null && audiobookFolder.isNotEmpty) {
        final repo = ref.read(audiobookRepositoryProvider);
        final matched = await repo.getLocalBookDirectoryForBackup(bookId);
        if (matched != null) {
          folderPath = matched;
        }
      }
    }
    
    if (folderPath != null) {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.epub')) {
            return entity.path;
          } else if (entity is Directory) {
            try {
              await for (final subEntity in entity.list()) {
                if (subEntity is File && subEntity.path.toLowerCase().endsWith('.epub')) {
                  return subEntity.path;
                }
              }
            } catch (_) {}
          }
        }
      }
    }
  } catch (_) {}
  return null;
});

/// Provider to retrieve EPUB reading progress from progress.json (primary) with SharedPreferences fallback.
final epubProgressProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, bookId) async {
  // Try progress.json first (primary source)
  try {
    final repo = ref.read(audiobookRepositoryProvider);
    final epubProg = await repo.getEpubProgress(bookId);
    if (epubProg != null) {
      return {
        'currentChapter': epubProg['currentChapter'] ?? 0,
        'totalChapters': epubProg['totalChapters'] ?? 0,
        'scrollOffset': (epubProg['scrollOffset'] as num?)?.toDouble() ?? 0.0,
        'pagesRead': epubProg['pagesRead'] ?? 0,
        'totalPages': epubProg['totalPages'] ?? 0,
        'progress': (epubProg['progress'] as num?)?.toDouble() ?? 0.0,
      };
    }
  } catch (_) {}

  // Fallback to SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final currentChapter = prefs.getInt('epub_chapter_$bookId') ?? 0;
  final totalChapters = prefs.getInt('epub_total_chapters_$bookId') ?? 0;
  final scrollOffset = prefs.getDouble('epub_scroll_$bookId') ?? 0.0;
  final pagesRead = prefs.getInt('epub_pages_read_$bookId') ?? 0;
  final totalPages = prefs.getInt('epub_total_pages_$bookId') ?? 0;
  final progress = prefs.getDouble('epub_progress_$bookId') ?? 0.0;
  
  return {
    'currentChapter': currentChapter,
    'totalChapters': totalChapters,
    'scrollOffset': scrollOffset,
    'pagesRead': pagesRead,
    'totalPages': totalPages,
    'progress': progress,
  };
});

// ─── COLLECTIONS / WISHLIST ──────────────────────────────────────────

class AudiobookCollectionItem {
  final String bookId;
  final String title;
  final String author;
  final String? artworkUrl;
  final DateTime addedAt;

  const AudiobookCollectionItem({
    required this.bookId,
    required this.title,
    required this.author,
    this.artworkUrl,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'title': title,
    'author': author,
    'artworkUrl': artworkUrl,
    'addedAt': addedAt.toIso8601String(),
  };

  factory AudiobookCollectionItem.fromJson(Map<String, dynamic> json) => AudiobookCollectionItem(
    bookId: json['bookId'] as String,
    title: json['title'] as String? ?? '',
    author: json['author'] as String? ?? '',
    artworkUrl: json['artworkUrl'] as String?,
    addedAt: DateTime.parse(json['addedAt'] as String),
  );
}

/// Check if a book is already in the local or TorBox library.
final isBookInLibraryProvider = FutureProvider.family<bool, String>((ref, bookId) async {
  final libraryBooks = await ref.watch(localAudiobooksProvider.future);
  final normId = AudiobookRepository.normalizeBookId(bookId);
  return libraryBooks.any((b) => AudiobookRepository.normalizeBookId(b.id) == normId);
});

/// Check if a book is in the wishlist.
final isBookInWishlistProvider = FutureProvider.family<bool, String>((ref, bookId) async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('audiobook_wishlist') ?? [];
  return list.any((entry) {
    try {
      final map = jsonDecode(entry) as Map<String, dynamic>;
      return map['bookId'] == bookId;
    } catch (_) {
      return false;
    }
  });
});

/// Full wishlist as a list of items.
final audiobookWishlistProvider = FutureProvider<List<AudiobookCollectionItem>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('audiobook_wishlist') ?? [];
  return list.map((entry) {
    try {
      return AudiobookCollectionItem.fromJson(jsonDecode(entry) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }).whereType<AudiobookCollectionItem>().toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
});

/// Toggle a book in/out of the wishlist.
Future<void> toggleWishlist(AudiobookResult book) async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('audiobook_wishlist') ?? [];
  final existingIndex = list.indexWhere((entry) {
    try {
      return (jsonDecode(entry) as Map<String, dynamic>)['bookId'] == book.id;
    } catch (_) {
      return false;
    }
  });
  if (existingIndex >= 0) {
    list.removeAt(existingIndex);
  } else {
    list.add(jsonEncode(AudiobookCollectionItem(
      bookId: book.id,
      title: book.title,
      author: book.author,
      artworkUrl: book.artworkUrl,
      addedAt: DateTime.now(),
    ).toJson()));
  }
  await prefs.setStringList('audiobook_wishlist', list);
}

class _ResolvedProgress {
  final DbAudiobookProgress progress;
  final String title;
  final String author;
  final String? artworkUrl;
  final int? totalCh;
  final double progressPercent;
  _ResolvedProgress({
    required this.progress,
    required this.title,
    required this.author,
    this.artworkUrl,
    this.totalCh,
    this.progressPercent = 0.0,
  });
}
