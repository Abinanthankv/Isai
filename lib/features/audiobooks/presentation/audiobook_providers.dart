import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:audiotags/audiotags.dart';
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
final audiobookCatalogProvider = FutureProvider<List<AudiobookResult>>((ref) async {
  final repo = ref.read(audiobookRepositoryProvider);
  final genre = ref.watch(selectedGenreProvider);
  if (genre == 'All') {
    return repo.browseCatalog();
  } else {
    return repo.fetchCatalogByGenre(genre);
  }
});

/// Get all in-progress audiobooks for "Continue Listening" section.
final inProgressAudiobooksProvider = FutureProvider.autoDispose<List<AudiobookWithProgress>>((ref) async {
  final repo = ref.read(audiobookRepositoryProvider);

  // Proactively scan local audiobook directory to restore progress/metadata for cloud/torbox books
  final settings = ref.watch(settingsProvider);
  final downloadDirPath = settings.audiobookFolder;
  if (downloadDirPath != null && downloadDirPath.isNotEmpty) {
    try {
      final dir = Directory(downloadDirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            final metaFile = File(p.join(entity.path, 'metadata.json'));
            final progressFile = File(p.join(entity.path, 'progress.json'));
            if (await metaFile.exists() && await progressFile.exists()) {
              try {
                final content = await metaFile.readAsString();
                final data = jsonDecode(content) as Map<String, dynamic>;
                final bookId = data['bookId'] as String?;
                if (bookId != null) {
                  // Restore progress and cache metadata
                  await repo.restoreProgressFromLocalFolder(bookId, entity.path);
                  await repo.getCachedMetadata(bookId);
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      print('[inProgressAudiobooksProvider] Error scanning for cloud book restore: $e');
    }
  }

  final allProgress = await repo.getAllInProgressBooks();
  
  // Group all progress entries by bookId
  final Map<String, List<dynamic>> progressByBook = {};
  for (final progress in allProgress) {
    progressByBook.putIfAbsent(progress.bookId, () => []).add(progress);
  }
  
  // Get latest progress for each book (first in list since DB query orders by lastListenedAt DESC)
  final Map<String, dynamic> latestByBook = {};
  for (final entry in progressByBook.entries) {
    if (entry.value.isNotEmpty) {
      latestByBook[entry.key] = entry.value.first;
    }
  }
  
  final dismissedBooks = await repo.getDismissedBooksFromContinueListening();

  // Convert to AudiobookWithProgress with cached metadata and proper overall progressPercent
  final List<AudiobookWithProgress> result = [];
  for (final entry in latestByBook.entries) {
    if (dismissedBooks.contains(entry.key)) continue;
    final progress = entry.value;
    final cached = await repo.getCachedMetadata(entry.key);
    final bookId = entry.key;
    final bookProgressList = progressByBook[bookId] ?? [];
    
    final totalCh = (cached != null && cached.totalChapters > 0)
        ? cached.totalChapters
        : (progress.chapterIndex + 1);
        
    double progressPercent = 0.0;
    if (totalCh > 0) {
      double totalProgressValue = 0.0;
      for (final p in bookProgressList) {
        double chProgressRatio = 0.0;
        if (p.isCompleted) {
          chProgressRatio = 1.0;
        } else if (p.durationMillis > 0) {
          // If this is a single-file audiobook, we have chapters within a single file.
          // Let's determine if p.durationMillis is the total book duration or chapter duration.
          // If it is total book duration, then (p.positionMillis / p.durationMillis) is already the overall progress.
          // We can check this by comparing p.durationMillis with a large value or if it is the only progress record.
          if (bookProgressList.length == 1 && p.durationMillis > 3600000) {
            // Probably single-file overall progress
            chProgressRatio = (p.positionMillis / p.durationMillis).clamp(0.0, 1.0);
            totalProgressValue = chProgressRatio * totalCh; // scaled up so when divided by totalCh it returns correct ratio
            break;
          } else {
            chProgressRatio = (p.positionMillis / p.durationMillis).clamp(0.0, 1.0);
          }
        }
        totalProgressValue += chProgressRatio;
      }
      progressPercent = (totalCh == 1) ? (totalProgressValue).clamp(0.0, 1.0) : (totalProgressValue / totalCh).clamp(0.0, 1.0);
    }

    if (cached != null) {
      result.add(AudiobookWithProgress(
        book: repo.metadataToResult(cached),
        currentChapter: progress.chapterIndex,
        positionMillis: progress.positionMillis,
        totalChapters: cached.totalChapters,
        lastListenedAt: progress.lastListenedAt,
        progressPercent: progressPercent,
      ));
    } else {
      final isTorrent = progress.bookId.startsWith('torrent:');
      final title = isTorrent ? 'Torrent Audiobook' : 'Audiobook';
      result.add(AudiobookWithProgress(
        book: AudiobookResult(
          id: progress.bookId,
          title: title,
          author: isTorrent ? 'Torrent Source' : 'Unknown Author',
        ),
        currentChapter: progress.chapterIndex,
        positionMillis: progress.positionMillis,
        totalChapters: 0,
        lastListenedAt: progress.lastListenedAt,
        progressPercent: progressPercent,
      ));
    }
  }
  
  return result;
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

  // Fetch rating from Open Library dynamically
  if (bookResult != null && bookResult.rating == null) {
    try {
      final dio = Dio();
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
final bookChapterProgressProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, bookId) async {
  final repo = ref.read(audiobookRepositoryProvider);
  
  // Proactively restore progress from local progress.json if it exists
  try {
    final dirPath = await repo.getLocalBookDirectoryForBackup(bookId);
    if (dirPath != null) {
      await repo.restoreProgressFromLocalFolder(bookId, dirPath);
    }
  } catch (e) {
    print('[bookChapterProgressProvider] Error restoring progress from local folder: $e');
  }

  return repo.getBookChapterProgress(bookId);
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

/// Helper: count audio files directly inside a directory (non-recursive).
Future<int> _countAudioFiles(Directory dir) async {
  int count = 0;
  await for (final entity in dir.list()) {
    if (entity is File) {
      final ext = _getExt(entity.path);
      if (_audioExtensions.contains(ext)) count++;
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
  if (await metaFile.exists()) {
    try {
      final content = await metaFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      title = data['title'] as String? ?? title;
      author = data['author'] as String? ?? author;
      description = data['description'] as String?;
    } catch (e) {
      print('[localAudiobooksProvider] Error reading local metadata.json: $e');
    }
  }

  final coverJpg = File(p.join(dir.path, 'cover.jpg'));
  final coverPng = File(p.join(dir.path, 'cover.png'));
  if (await coverJpg.exists()) {
    artworkPath = coverJpg.path;
  } else if (await coverPng.exists()) {
    artworkPath = coverPng.path;
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
final localAudiobooksProvider = FutureProvider.autoDispose<List<AudiobookResult>>((ref) async {
  final repo = ref.read(audiobookRepositoryProvider);
  final List<AudiobookResult> results = [];

  // 1. Fetch Local Audiobooks if folder path is configured
  final settings = ref.watch(settingsProvider);
  final folderPath = settings.audiobookFolder;
  if (folderPath != null && folderPath.isNotEmpty) {
    final dir = Directory(folderPath);
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final audioCount = await _countAudioFiles(entity);
          if (audioCount > 0) {
            final folderName = entity.path.split('/').last;
            final bookId = 'local:${entity.path}';
            
            final cached = await repo.getCachedMetadata(bookId);
            if (cached != null) {
              results.add(repo.metadataToResult(cached));
            } else {
              final book = await _getAudiobookMetadata(entity, bookId, folderName);
              results.add(book);
            }
            
            // Proactively restore progress if progress.json exists
            await repo.restoreProgressFromLocalFolder(bookId, entity.path);
          }
        } else if (entity is File) {
          final ext = _getExt(entity.path);
          if (_audioExtensions.contains(ext)) {
            final fileName = entity.path.split('/').last;
            final defaultTitle = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
            final bookId = 'local:${entity.path}';

            final cached = await repo.getCachedMetadata(bookId);
            if (cached != null) {
              results.add(repo.metadataToResult(cached));
            } else {
              final book = await _getBookMetadataFromAudioFile(entity, bookId, defaultTitle);
              results.add(book);
            }
          }
        }
      }
    }
  }

  // 2. Fetch TorBox Torrent Audiobooks
  final torBoxBooks = await repo.getTorBoxLibraryAudiobooks();
  results.addAll(torBoxBooks);

  // 3. De-duplicate based on book ID
  final Map<String, AudiobookResult> uniqueBooks = {};
  for (final book in results) {
    uniqueBooks[book.id] = book;
  }
  
  final List<AudiobookResult> finalResults = uniqueBooks.values.toList();
  finalResults.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return finalResults;
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

  Future<void> _showProgressNotification(String bookId, String title, double progress) async {
    try {
      await _initNotifications();
      final isDone = progress >= 1.0;
      final isFailed = progress < 0.0 && progress != -4.0;
      final isPaused = progress == -4.0;
      
      final notificationId = bookId.hashCode.abs();

      if (isDone) {
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
          title,
          NotificationDetails(android: androidDetails),
        );
      } else if (isPaused) {
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
          title,
          NotificationDetails(android: androidDetails),
        );
      } else if (isFailed) {
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
          title,
          NotificationDetails(android: androidDetails),
        );
      } else {
        final percent = (progress * 100).round();
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
          'Downloading... $percent%',
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
    _showProgressNotification(book.id, book.title, 0.0);
    
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
                _showProgressNotification(book.id, book.title, overallProgress);
              }
            }
            await sink.flush();
            await sink.close();

            if (_pausedBooks.contains(book.id)) {
              print('[AudiobookDownloadNotifier] Download paused for ${book.title}');
              _showProgressNotification(book.id, book.title, -4.0);
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
        _showProgressNotification(book.id, book.title, -4.0);
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
      _showProgressNotification(book.id, book.title, 1.0);
      
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
      _showProgressNotification(book.id, book.title, -3.0);
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
