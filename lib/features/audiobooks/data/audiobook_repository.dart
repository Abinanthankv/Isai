import 'dart:io' as io;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:audiotags/audiotags.dart';
import 'package:injectable/injectable.dart';
import '../../../core/database/database.dart';
import '../../music/data/music_repository.dart';
import '../../music/data/music_models.dart';
import 'audiobook_addon_service.dart';
import 'audiobook_models.dart';
import 'm4b_parser.dart';
import 'mp3_parser.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../../settings/data/torbox_settings_repository.dart';
import '../../../core/di/injection.dart';

/// Repository for audiobook data operations.
@lazySingleton
class AudiobookRepository {
  final AudiobookAddonService _addonService;
  final AppDatabase _db;
  final MusicRepository _musicRepo;
  
  AudiobookRepository(this._addonService, this._db, this._musicRepo);

  /// Normalize a book ID so progress and metadata are always stored
  /// consistently. For torrent IDs, strips the magnet part so that
  /// 'torrent:hash:encodedMagnet' becomes 'torrent:hash:'.
  /// This makes progress saved from a search result findable when the
  /// same torrent is later opened from the library.
  static String normalizeBookId(String bookId) {
    if (bookId.startsWith('torrent:')) {
      final parts = bookId.split(':');
      // parts[0]='torrent', parts[1]=hash, parts[2+]=encoded magnet
      return 'torrent:${parts[1]}:';
    }
    return bookId;
  }

  /// Audiobook name keywords used to identify audiobook torrents in TorBox library.
  static const _audiobookKeywords = [
    'audiobook', 'audio book', 'audio-book', 'unabridged', 'narrated by',
    'read by', ' mp3 book', 'librivox',
  ];

  /// Returns true if a TorBox torrent looks like an audiobook.
  bool _looksLikeAudiobook(TorBoxTorrent torrent) {
    final nameLower = torrent.name.toLowerCase();

    // 1. Name contains audiobook-specific keywords
    if (_audiobookKeywords.any((kw) => nameLower.contains(kw))) return true;

    // 2. Has .m4b files — the audiobook-dedicated container format.
    //    Music files never use .m4b; only audiobooks do.
    final hasM4b = torrent.files.any((f) => f.name.toLowerCase().endsWith('.m4b'));
    if (hasM4b) return true;

    return false;
  }

  /// Returns true if the torrent name suggests it is a video (movie, TV show).
  bool _looksLikeVideo(String name) {
    final nameLower = name.toLowerCase();
    
    // Video quality, source, codec, and group terms
    final videoTerms = [
      '1080p', '720p', '4k', '2160p', 'bluray', 'blu-ray', 'dvdrip', 'webrip', 
      'web-dl', 'webdl', 'hdrip', 'hdtv', 'hevc', 'x264', 'x265', 'h264', 'h265', 
      'mkv', 'mp4', 'avi', 'yify', 'remux', 's01', 's02', 's03', 's04', 's05', 
      's06', 's07', 's08', 's09', 's10', 'season', 'episode', 'complete series'
    ];
    
    if (videoTerms.any((term) => nameLower.contains(term))) {
      return true;
    }
    
    // Regex for season/episode pattern e.g. S01E02 or s1e1
    final seasonEpisodeRegex = RegExp(r'[sS]\d+[eE]\d+');
    if (seasonEpisodeRegex.hasMatch(name)) {
      return true;
    }
    
    return false;
  }

  /// Clean/sanitize a torrent filename/name by removing dot, underscores,
  /// hyphens, bracket content, years, quotes, and common release/format keywords.
  static String cleanTorrentName(String name) {
    var clean = name;
    
    // 1. Remove common file extensions at the end
    clean = clean.replaceAll(RegExp(r'\.(mp3|m4b|m4a|epub|pdf|mobi|zip|rar|tar|gz|txt)$', caseSensitive: false), '');
    
    // 2. Replace dots, underscores, and hyphens with spaces
    clean = clean.replaceAll(RegExp(r'[._\-]'), ' ');
    
    // 3. Remove brackets content e.g. [Unabridged], (Abridged), [1998]
    clean = clean.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    clean = clean.replaceAll(RegExp(r'\([^)]*\)'), '');
    
    // 4. Remove common torrent/release tags
    final releaseTags = RegExp(
      r'\b(unabridged|abridged|audiobook|audio book|mp3|m4b|m4a|epub|pdf|mobi|h264|x264|x265|bluray|rip|webrip|web|1080p|720p|480p|aac|ac3|flac|cue|log|lossless|cd|dvd|multi|eng|fr|ger|es|it)\b', 
      caseSensitive: false
    );
    clean = clean.replaceAll(releaseTags, '');
    
    // 5. Remove years (e.g. 1998, 2023)
    clean = clean.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '');
    
    // 6. Remove quotes
    clean = clean.replaceAll(RegExp(r'["`“”‘’]'), '');
    clean = clean.replaceAll("'", "");
    
    // 7. Collapse multiple spaces and trim
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return clean;
  }

  /// Fetch all torrent audiobooks that are present in the user's TorBox library.
  /// Only includes torrents that look like audiobooks (cached metadata, m4b files,
  /// audiobook keywords in name, or many audio chapter files).
  Future<List<AudiobookResult>> getTorBoxLibraryAudiobooks() async {
    final List<AudiobookResult> results = [];
    try {
      final library = await _musicRepo.getLibrary();
      if (library.isEmpty) return [];

      final cachedMetadataList = await (_db.select(_db.audiobookMetadataCache)).get();

      for (final torrent in library) {
        final hash = torrent.hash.toLowerCase();

        // Check if we have cached metadata for this torrent hash (user previously opened it)
        DbAudiobookMetadataCache? match;
        for (final m in cachedMetadataList) {
          if (m.bookId.toLowerCase().contains(hash)) {
            match = m;
            break;
          }
        }

        if (match != null) {
          // Use cached metadata (rich title, author, artwork)
          results.add(metadataToResult(match));
        } else if (_looksLikeAudiobook(torrent)) {
          // No cached metadata yet, but torrent passes audiobook heuristics
          results.add(AudiobookResult(
            id: 'torrent:$hash:',
            title: cleanTorrentName(torrent.name),
            author: 'TorBox Library',
            description: 'From TorBox library',
          ));
        }
        // Skip torrents that don't look like audiobooks (music files etc.)
      }
    } catch (e) {
      print('[AudiobookRepository] getTorBoxLibraryAudiobooks error: $e');
    }
    return results;
  }

  // ─── Search & Browse ───────────────────────────────────────────

  /// Search for audiobooks via the Stremio addon and Torrent indexers.
  Future<List<AudiobookResult>> searchBooks(String query) async {
    if (query.trim().isEmpty) return [];

    final tasks = <Future<List<dynamic>>>[
      _addonService.searchBooks(query),
      _musicRepo.searchAllTorrents(query),
      _searchAudiobookBay(query),
    ];

    try {
      final allResults = await Future.wait(tasks);
      final List<AudiobookResult> merged = [];

      // 1. Add AudiobookBay Results
      final abbResults = allResults[2] as List<AudiobookResult>;
      merged.addAll(abbResults);

      // 2. Add Addon Results
      final addonResults = allResults[0] as List<AudiobookResult>;
      merged.addAll(addonResults);

      // 3. Add Torrent Results
      final torrentResults = allResults[1] as List<dynamic>;
      for (final t in torrentResults) {
        final name = t.name as String? ?? '';
        if (_looksLikeVideo(name)) {
          continue; // Skip videos (movies, TV shows, etc.)
        }

        String magnet = t.magnetLink ?? '';
        if (magnet.isEmpty && t.infoHash.isNotEmpty) {
          magnet = 'magnet:?xt=urn:btih:${t.infoHash}&dn=${Uri.encodeComponent(name)}';
        }
        final encodedMagnet = Uri.encodeComponent(magnet);
        merged.add(AudiobookResult(
          id: 'torrent:${t.infoHash}:$encodedMagnet',
          title: name,
          author: 'Torrent Result',
          artworkUrl: null,
          description: 'Source: ${t.source} | Seeders: ${t.seeders} | Size: ${t.formattedSize}',
        ));
      }

      return merged;
    } catch (e) {
      print('[AudiobookRepository] Merged search error: $e');
      return _addonService.searchBooks(query);
    }
  }

  /// Search AudiobookBay and parse results.
  Future<List<AudiobookResult>> _searchAudiobookBay(String query) async {
    final List<AudiobookResult> results = [];
    try {
      final cleanQuery = Uri.encodeComponent(query.toLowerCase().trim());
      final url = "https://audiobookbay.lu/?s=$cleanQuery";
      
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        final posts = html.split('<div class="post"');
        
        if (posts.length > 1) {
          for (int i = 1; i < posts.length; i++) {
            final postHtml = posts[i];
            
            // Extract link and title
            final linkMatch = RegExp(r'<div class="postTitle">.*?href="([^"]+)".*?>(.*?)</a>', dotAll: true).firstMatch(postHtml);
            if (linkMatch == null) continue;
            
            String link = linkMatch.group(1)!;
            if (!link.startsWith('http')) {
              link = 'https://audiobookbay.lu$link';
            }
            
            String title = linkMatch.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
            
            // Extract cover image
            final imgMatch = RegExp(r'<img.*?src="([^"]+)"').firstMatch(postHtml);
            String? artworkUrl = imgMatch?.group(1);
            
            // Extract metadata stats
            final descMatch = RegExp(r'File Size:\s*([\d\.]+\s*[MGBs]+)').firstMatch(postHtml);
            final size = descMatch?.group(1) ?? '';
            
            final formatMatch = RegExp(r'Format:\s*([a-zA-Z\d]+)').firstMatch(postHtml);
            final format = formatMatch?.group(1) ?? 'M4B';
            
            final postedMatch = RegExp(r'Posted:\s*([^\n<]+)').firstMatch(postHtml);
            final postedDate = postedMatch?.group(1)?.trim() ?? '';
            
            String desc = 'Source: AudiobookBay';
            if (size.isNotEmpty) desc += ' | Size: $size';
            if (format.isNotEmpty) desc += ' | Format: $format';
            if (postedDate.isNotEmpty) desc += ' | Date: $postedDate';
            
            results.add(AudiobookResult(
              id: 'audiobookbay:${Uri.encodeComponent(link)}',
              title: title,
              author: 'AudiobookBay',
              artworkUrl: artworkUrl,
              description: desc,
            ));
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] AudiobookBay search error: $e');
    }
    return results;
  }

  /// Browse the audiobook catalog (fetches top trending from iTunes RSS).
  Future<List<AudiobookResult>> browseCatalog({int skip = 0}) async {
    try {
      final dio = Dio();
      final res = await dio.get('https://rss.marketingtools.apple.com/api/v2/us/audio-books/top/50/audio-books.json');
      if (res.statusCode == 200 && res.data != null) {
        final Map<String, dynamic> data = res.data is String ? jsonDecode(res.data) : res.data;
        final feed = data['feed'] as Map<String, dynamic>?;
        final results = feed?['results'] as List<dynamic>?;
        if (results != null) {
          final List<AudiobookResult> books = [];
          for (final item in results) {
            final title = item['name'] as String? ?? 'Unknown Title';
            final author = item['artistName'] as String? ?? 'Unknown Author';
            final id = 'itunes_trending:${item['id']}';
            final artworkUrl100 = item['artworkUrl100'] as String?;
            final artworkUrl = artworkUrl100?.replaceAll('100x100bb', '600x600bb');
            
            books.add(AudiobookResult(
              id: id,
              title: title,
              author: author,
              artworkUrl: artworkUrl,
              description: 'Trending Audiobook',
            ));
          }
          return books;
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Failed to fetch trending audiobooks: $e');
    }
    return _addonService.getCatalog(skip: skip);
  }

  /// Fetch audiobooks based on selected genre.
  Future<List<AudiobookResult>> fetchCatalogByGenre(String genre) async {
    print('[AudiobookRepository] fetchCatalogByGenre called for genre: $genre');
    final List<AudiobookResult> results = [];
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': genre,
          'media': 'audiobook',
          'limit': 30,
        },
      );
      print('[AudiobookRepository] fetchCatalogByGenre status: ${res.statusCode}');
      if (res.statusCode == 200 && res.data != null) {
        final Map<String, dynamic> data = res.data is String ? jsonDecode(res.data) : res.data;
        final items = data['results'] as List<dynamic>?;
        print('[AudiobookRepository] fetchCatalogByGenre returned ${items?.length} items');
        if (items != null) {
          for (final item in items) {
            final title = item['collectionName'] as String? ?? item['trackName'] as String? ?? 'Unknown Title';
            final author = item['artistName'] as String? ?? 'Unknown Author';
            final description = item['description'] as String? ?? '';
            final artworkUrl100 = item['artworkUrl100'] as String?;
            final artworkUrl = artworkUrl100?.replaceAll('100x100bb', '600x600bb');
            
            results.add(AudiobookResult(
              id: 'itunes_meta:${item['collectionId'] ?? item['trackId'] ?? title.hashCode}',
              title: title,
              author: author,
              description: description,
              artworkUrl: artworkUrl,
              language: 'EN',
            ));
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Failed to fetch genre audiobooks: $e');
    }
    return results;
  }

  /// Get detailed metadata for a book.
  Future<AudiobookResult?> getBookDetails(String bookId) async {
    if (bookId.startsWith('itunes_trending:') || bookId.startsWith('itunes_meta:')) {
      final cached = await getCachedMetadata(bookId);
      if (cached != null) {
        return metadataToResult(cached);
      }
      return null; // Fallback to passed book in detail screen
    }

    if (bookId.startsWith('audiobookbay:')) {
      final detailUrl = Uri.decodeComponent(bookId.substring('audiobookbay:'.length));
      try {
        final dio = Dio();
        final res = await dio.get(
          detailUrl,
          options: Options(headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          }),
        );
        if (res.statusCode == 200 && res.data != null) {
          final html = res.data.toString();
          
          // Parse Info Hash from the detail page
          final hashPattern = RegExp(r'\b([0-9a-fA-F]{40})\b');
          String? infoHash;
          
          final matches = hashPattern.allMatches(html);
          if (matches.isNotEmpty) {
            infoHash = matches.first.group(1);
          }
          
          if (infoHash != null) {
            final trackers = [
              "udp://tracker.coppersurfer.tk:6969/announce",
              "udp://tracker.opentrackr.org:1337/announce",
              "udp://tracker.leechers-paradise.org:6969/announce",
              "udp://open.demonii.com:1337/announce",
              "udp://tracker.openedd.org:2710/announce"
            ];
            
            final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
            String titleText = titleMatch?.group(1)?.replaceAll(' - AudioBook Bay', '').trim() ?? 'Audiobook';
            
            final encodedTitle = Uri.encodeComponent(titleText);
            final trackerParams = trackers.map((t) => '&tr=${Uri.encodeComponent(t)}').join();
            final magnet = 'magnet:?xt=urn:btih:$infoHash&dn=$encodedTitle$trackerParams';
            
            final realBookId = 'torrent:${infoHash.toLowerCase()}:${Uri.encodeComponent(magnet)}';
            
            String description = 'Source: AudiobookBay';
            final descMatch = RegExp(r'<div class="postContent">(.*?)</div>', dotAll: true).firstMatch(html);
            if (descMatch != null) {
              description = descMatch.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
              if (description.length > 500) description = '${description.substring(0, 500)}...';
            }
            
            String? artworkUrl;
            final imgMatch = RegExp(r'<div class="postContent">.*?<img.*?src="([^"]+)"', dotAll: true).firstMatch(html);
            artworkUrl = imgMatch?.group(1);
            
            final resolvedBook = AudiobookResult(
              id: realBookId,
              title: titleText,
              author: 'AudiobookBay',
              artworkUrl: artworkUrl,
              description: description,
            );
            
            await cacheBookMetadata(resolvedBook);
            return resolvedBook;
          }
        }
      } catch (e) {
        print('[AudiobookRepository] AudiobookBay details extraction failed: $e');
      }
      return AudiobookResult(
        id: bookId,
        title: 'AudiobookBay Book',
        author: 'AudiobookBay',
      );
    }

    if (bookId.startsWith('torrent:')) {
      final cached = await getCachedMetadata(bookId);
      if (cached != null) {
        return metadataToResult(cached);
      }
      
      // Cache is empty, let's look up the torrent in TorBox library to get its original name
      String? torrentName;
      try {
        final parts = bookId.split(':');
        if (parts.length > 1) {
          final hash = parts[1].toLowerCase();
          final library = await _musicRepo.getLibrary();
          final torrent = library.where((t) => t.hash.toLowerCase() == hash).firstOrNull;
          if (torrent != null) {
            torrentName = torrent.name;
          }
        }
      } catch (e) {
        print('[AudiobookRepository] Error getting torrent name from library: $e');
      }
      
      final title = cleanTorrentName(torrentName ?? 'Torrent Audiobook');
      
      // Let's try online metadata lookup using the clean title!
      String? description;
      String? onlineAuthor;
      String? onlineArtwork;
      
      try {
        final onlineData = await _fetchOnlineMetadata(title);
        if (onlineData != null) {
          description = onlineData['description'];
          onlineAuthor = onlineData['author'];
          onlineArtwork = onlineData['artworkUrl'];
        }
      } catch (e) {
        print('[AudiobookRepository] Online metadata lookup failed for $title: $e');
      }
      
      final mergedBook = AudiobookResult(
        id: bookId,
        title: title,
        author: (onlineAuthor != null && onlineAuthor.isNotEmpty) ? onlineAuthor : 'Torrent Result',
        artworkUrl: onlineArtwork,
        description: description ?? 'From TorBox library',
      );
      
      await cacheBookMetadata(mergedBook);
      return mergedBook;
    }

    if (bookId.startsWith('local:')) {
      final cached = await getCachedMetadata(bookId);
      if (cached != null && cached.description != null && cached.description!.isNotEmpty) {
        return metadataToResult(cached);
      }

      final path = bookId.substring('local:'.length);
      final isFile = io.FileSystemEntity.isFileSync(path);

      String title = path.split('/').last;
      String author = 'Local Library';
      String? artworkPath;
      int audioCount = 1;

      if (isFile) {
        final file = io.File(path);
        title = title.contains('.') ? title.substring(0, title.lastIndexOf('.')) : title;
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
                final tempDir = io.Directory.systemTemp;
                final pathHash = bookId.hashCode.abs();
                final ext = picture.mimeType == MimeType.png ? 'png' : 'jpg';
                final artFile = io.File('${tempDir.path}/local_book_art_$pathHash.$ext');
                await artFile.writeAsBytes(bytes);
                artworkPath = artFile.path;
              }
            }
          }
        } catch (e) {
          print('[AudiobookRepository] Error reading tags in getBookDetails: $e');
        }
      } else {
        final dir = io.Directory(path);
        if (!await dir.exists()) return null;

        audioCount = 0;
        io.File? firstAudioFile;
        await for (final entity in dir.list()) {
          if (entity is io.File) {
            final dot = entity.path.lastIndexOf('.');
            final ext = dot == -1 ? '' : entity.path.substring(dot).toLowerCase();
            if (_audioExtensions.contains(ext)) {
              audioCount++;
              firstAudioFile ??= entity;
            }
          }
        }

        if (firstAudioFile != null) {
          if (audioCount == 1) {
            final ext = firstAudioFile.path.split('.').last.toLowerCase();
            if (ext == 'm4b' || ext == 'm4a') {
              try {
                final parsed = await M4bParser.parseChapters(firstAudioFile.path);
                if (parsed.isNotEmpty) {
                  audioCount = parsed.length;
                }
              } catch (e) {
                print('[AudiobookRepository] Failed to parse chapter count in details: $e');
              }
            }
          }
          try {
            final tag = await AudioTags.read(firstAudioFile.path);
            if (tag != null) {
              if (tag.album != null && tag.album!.trim().isNotEmpty) {
                title = tag.album!.trim();
              } else if (tag.title != null && tag.title!.trim().isNotEmpty && audioCount == 1) {
                title = tag.title!.trim();
              }
              if (tag.artist != null && tag.artist!.trim().isNotEmpty) {
                author = tag.artist!.trim();
              }
              if (tag.pictures != null && tag.pictures!.isNotEmpty) {
                final picture = tag.pictures!.first;
                final bytes = picture.bytes;
                if (bytes != null && bytes.isNotEmpty) {
                  final tempDir = io.Directory.systemTemp;
                  final pathHash = bookId.hashCode.abs();
                  final ext = picture.mimeType == MimeType.png ? 'png' : 'jpg';
                  final artFile = io.File('${tempDir.path}/local_book_art_$pathHash.$ext');
                  await artFile.writeAsBytes(bytes);
                  artworkPath = artFile.path;
                }
              }
            }
          } catch (e) {
            print('[AudiobookRepository] Error reading tags in getBookDetails: $e');
          }
        }
      }

      String? description;
      String? onlineAuthor;
      String? onlineArtwork;

      final onlineData = await _fetchOnlineMetadata(title);
      if (onlineData != null) {
        description = onlineData['description'];
        onlineAuthor = onlineData['author'];
        onlineArtwork = onlineData['artworkUrl'];
      }

      final mergedBook = AudiobookResult(
        id: bookId,
        title: title,
        author: (onlineAuthor != null && onlineAuthor.isNotEmpty) ? onlineAuthor : author,
        artworkUrl: artworkPath ?? onlineArtwork,
        description: description ?? 'Local audiobook stored at $path',
        totalChapters: audioCount,
      );

      await cacheBookMetadata(mergedBook);
      return mergedBook;
    }

    return _addonService.getBookDetails(bookId);
  }

  /// Audio file extensions recognized for local audiobooks.
  static const _audioExtensions = {'.mp3', '.m4a', '.m4b', '.ogg', '.opus', '.flac', '.aac', '.wav', '.wma'};

  /// Get all chapters/streams for a book.
  Future<List<AudiobookChapter>> getBookChapters(String bookId) async {
    if (bookId.startsWith('local:')) {
      return _getLocalChapters(bookId);
    }
    
    List<AudiobookChapter> chapters = [];
    
    // Check if we have torrent files in our local DB first to avoid network requests
    if (bookId.startsWith('torrent:')) {
      try {
        final parts = bookId.split(':');
        if (parts.length > 1) {
          final hash = parts[1].toLowerCase();
          final dbTorrents = await _db.getAllTorrents();
          final torrent = dbTorrents.where((t) => t.hash.toLowerCase() == hash).firstOrNull;
          if (torrent != null) {
            final dbFiles = await _db.getAllFiles();
            final torrentFiles = dbFiles.where((f) => f.torrentId == torrent.id).toList();
            
            final validExtensions = ['.mp3', '.flac', '.aac', '.m4a', '.m4b', '.ogg', '.opus', '.wav'];
            int idx = 0;
            
            for (final f in torrentFiles) {
              final isAudio = validExtensions.any((ext) => f.name.toLowerCase().endsWith(ext));
              if (isAudio) {
                final streamUrl = 'https://lazy.torbox.internal/${torrent.id}/${f.id}';
                chapters.add(AudiobookChapter(
                  id: '${bookId}_ch_$idx',
                  title: f.name,
                  chapterNumber: idx + 1,
                  streamUrl: streamUrl,
                  source: 'TorBox Torrent (Local DB)',
                ));
                idx++;
              }
            }
          }
        }
      } catch (e) {
        print('[AudiobookRepository] Error reading chapters from local DB: $e');
      }
    }
    
    if (chapters.isEmpty) {
      chapters = await _addonService.getBookChapters(bookId);
    }
    
    List<AudiobookChapter> workingChapters = chapters;
    
    // 1. Find candidates that look like M4B/M4A files
    final m4bFiles = chapters.where((ch) {
      final name = ch.title.toLowerCase();
      return name.endsWith('.m4b') || name.endsWith('.m4a');
    }).toList();

    // 2. Find MP3 files in the playlist
    final mp3Files = chapters.where((ch) {
      final name = ch.title.toLowerCase();
      return name.endsWith('.mp3');
    }).toList();

    // Determine the single-file candidate to try parsing:
    // Prioritize M4B/M4A files if they exist.
    // If no M4B/M4A files exist, but there is exactly 1 MP3 audio file, treat it as the candidate.
    final List<AudiobookChapter> candidates;
    if (m4bFiles.isNotEmpty) {
      candidates = m4bFiles;
    } else if (mp3Files.length == 1) {
      candidates = mp3Files;
    } else {
      candidates = [];
    }

    bool parsedSuccessfully = false;

    for (final candidate in candidates) {
      if (parsedSuccessfully) break;
      try {
        final resolvedUrl = await resolveChapterStream(candidate);
        if (resolvedUrl != null) {
          final lowerUrl = resolvedUrl.toLowerCase().split('?').first;
          final isM4b = lowerUrl.endsWith('.m4b') || 
                        lowerUrl.endsWith('.m4a') || 
                        resolvedUrl.contains('/dld/') || 
                        candidate.title.toLowerCase().endsWith('.m4b') || 
                        candidate.title.toLowerCase().endsWith('.m4a');
          
          final isMp3 = lowerUrl.endsWith('.mp3') || 
                        candidate.title.toLowerCase().endsWith('.mp3');
                        
          if (isM4b) {
            final parsedChapters = await M4bParser.parseChapters(resolvedUrl);
            if (parsedChapters.isNotEmpty) {
              workingChapters = List.generate(parsedChapters.length, (i) {
                final ch = parsedChapters[i];
                return AudiobookChapter(
                  id: '${bookId}_ch_${i}_offset_${ch.startTimeMillis}',
                  title: ch.title,
                  chapterNumber: i + 1,
                  startTimeMillis: ch.startTimeMillis,
                  durationMillis: ch.durationMillis,
                  streamUrl: resolvedUrl,
                  source: 'Remote Stream: ${candidate.source ?? ""}',
                );
              });
              parsedSuccessfully = true;
            }
          } else if (isMp3) {
            final parsedChapters = await Mp3Parser.parseChapters(resolvedUrl);
            if (parsedChapters.isNotEmpty) {
              workingChapters = List.generate(parsedChapters.length, (i) {
                final ch = parsedChapters[i];
                return AudiobookChapter(
                  id: '${bookId}_ch_${i}_offset_${ch.startTimeMillis}',
                  title: ch.title,
                  chapterNumber: i + 1,
                  startTimeMillis: ch.startTimeMillis,
                  durationMillis: ch.durationMillis,
                  streamUrl: resolvedUrl,
                  source: 'Remote Stream: ${candidate.source ?? ""}',
                );
              });
              parsedSuccessfully = true;
            }
          }
        }
      } catch (e) {
        print('[AudiobookRepository] Remote candidate chapter parsing error: $e');
      }
    }
    
    // Check if any of these chapters have been downloaded locally
    try {
      final db = _db;
      final allFiles = await db.getAllFiles();
      
      int? targetTorrentId;
      if (bookId.startsWith('torrent:')) {
        final parts = bookId.split(':');
        if (parts.length > 1) {
          final hash = parts[1].toLowerCase();
          final torrents = await db.getAllTorrents();
          final torrent = torrents.where((t) => t.hash.toLowerCase() == hash).firstOrNull;
          targetTorrentId = torrent?.id;
        }
      }
      
      final List<AudiobookChapter> resolvedChapters = [];
      for (final chapter in workingChapters) {
        String? localStreamUrl;
        final streamUrl = chapter.streamUrl;
        
        if (streamUrl != null) {
          if (streamUrl.startsWith('/') || streamUrl.startsWith('file://')) {
            localStreamUrl = streamUrl;
          } else if (streamUrl.contains('lazy.torbox.internal')) {
            final uri = Uri.parse(streamUrl);
            final torrentId = int.tryParse(uri.pathSegments[0]);
            final fileId = int.tryParse(uri.pathSegments[1]);
            
            if (torrentId != null && fileId != null) {
              final dbFile = allFiles.where((f) => f.id == fileId && f.torrentId == torrentId).firstOrNull;
              if (dbFile != null && dbFile.localPath != null && dbFile.localPath!.isNotEmpty) {
                final localFile = io.File(dbFile.localPath!);
                if (await localFile.exists()) {
                  localStreamUrl = dbFile.localPath!;
                }
              }
            }
          } else if (targetTorrentId != null) {
            final dbFile = allFiles.where((f) => f.torrentId == targetTorrentId).firstOrNull;
            if (dbFile != null && dbFile.localPath != null && dbFile.localPath!.isNotEmpty) {
              final localFile = io.File(dbFile.localPath!);
              if (await localFile.exists()) {
                localStreamUrl = dbFile.localPath!;
              }
            }
          }
        }
        
        if (localStreamUrl != null) {
          resolvedChapters.add(AudiobookChapter(
            id: chapter.id,
            title: chapter.title,
            chapterNumber: chapter.chapterNumber,
            startTimeMillis: chapter.startTimeMillis,
            durationMillis: chapter.durationMillis,
            streamUrl: localStreamUrl,
            source: 'Local Cache: ${chapter.source ?? ""}',
          ));
        } else {
          resolvedChapters.add(chapter);
        }
      }
      return resolvedChapters;
    } catch (e) {
      print('[AudiobookRepository] Error substituting local paths for chapters: $e');
      return workingChapters;
    }
  }

  /// Scan a local folder or file for audio streams.
  Future<List<AudiobookChapter>> _getLocalChapters(String bookId) async {
    final path = bookId.substring('local:'.length);
    final isFile = io.FileSystemEntity.isFileSync(path);
    
    if (isFile) {
      final file = io.File(path);
      final ext = file.path.split('.').last.toLowerCase();
      if (ext == 'm4b' || ext == 'm4a') {
        try {
          final parsedChapters = await M4bParser.parseChapters(file.path);
          if (parsedChapters.isNotEmpty) {
            return List.generate(parsedChapters.length, (i) {
              final ch = parsedChapters[i];
              return AudiobookChapter(
                id: 'local_ch_${i}_offset_${ch.startTimeMillis}',
                title: ch.title,
                chapterNumber: i + 1,
                startTimeMillis: ch.startTimeMillis,
                durationMillis: ch.durationMillis,
                streamUrl: file.path,
              );
            });
          }
        } catch (e) {
          print('[AudiobookRepository] Failed to parse M4B chapters: $e');
        }
      } else if (ext == 'mp3') {
        try {
          final parsedChapters = await Mp3Parser.parseChapters(file.path);
          if (parsedChapters.isNotEmpty) {
            return List.generate(parsedChapters.length, (i) {
              final ch = parsedChapters[i];
              return AudiobookChapter(
                id: 'local_ch_${i}_offset_${ch.startTimeMillis}',
                title: ch.title,
                chapterNumber: i + 1,
                startTimeMillis: ch.startTimeMillis,
                durationMillis: ch.durationMillis,
                streamUrl: file.path,
              );
            });
          }
        } catch (e) {
          print('[AudiobookRepository] Failed to parse MP3 chapters: $e');
        }
      }
      final fileName = file.path.split('/').last;
      final title = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      return [
        AudiobookChapter(
          id: 'local_ch_0',
          title: title,
          chapterNumber: 1,
          streamUrl: file.path,
        )
      ];
    }

    final dir = io.Directory(path);
    if (!await dir.exists()) return [];

    // Check if metadata.json exists inside the directory to load fast
    final metaFile = io.File(p.join(path, 'metadata.json'));
    if (await metaFile.exists()) {
      try {
        final content = await metaFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final jsonChapters = data['chapters'] as List<dynamic>?;
        if (jsonChapters != null && jsonChapters.isNotEmpty) {
          return jsonChapters.map((chMap) {
            final map = chMap as Map<String, dynamic>;
            final relativePath = map['streamUrl'] as String? ?? '';
            final absolutePath = relativePath.startsWith('/') || relativePath.startsWith('file://')
                ? relativePath
                : p.join(path, relativePath);
            return AudiobookChapter(
              id: map['id'] as String? ?? 'local_ch_${map['chapterNumber']}',
              title: map['title'] as String? ?? 'Chapter',
              chapterNumber: map['chapterNumber'] as int? ?? 1,
              startTimeMillis: map['startTimeMillis'] as int? ?? 0,
              durationMillis: map['durationMillis'] as int? ?? 0,
              streamUrl: absolutePath,
              source: 'Local metadata.json',
            );
          }).toList();
        }
      } catch (e) {
        print('[AudiobookRepository] Error reading local metadata.json: $e');
      }
    }

    final List<io.File> audioFiles = [];
    await for (final entity in dir.list()) {
      if (entity is io.File) {
        final dot = entity.path.lastIndexOf('.');
        final ext = dot == -1 ? '' : entity.path.substring(dot).toLowerCase();
        if (_audioExtensions.contains(ext)) {
          audioFiles.add(entity);
        }
      }
    }

    audioFiles.sort((a, b) => a.path.split('/').last.toLowerCase().compareTo(b.path.split('/').last.toLowerCase()));

    // Find candidates: M4B/M4A files, or a single MP3 file in the directory
    final localM4bCandidates = audioFiles.where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return ext == 'm4b' || ext == 'm4a';
    }).toList();

    final localMp3Candidates = audioFiles.where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return ext == 'mp3';
    }).toList();

    final List<io.File> candidates;
    if (localM4bCandidates.isNotEmpty) {
      candidates = localM4bCandidates;
    } else if (localMp3Candidates.length == 1) {
      candidates = localMp3Candidates;
    } else {
      candidates = [];
    }

    for (final file in candidates) {
      final ext = file.path.split('.').last.toLowerCase();
      try {
        if (ext == 'm4b' || ext == 'm4a') {
          final parsedChapters = await M4bParser.parseChapters(file.path);
          if (parsedChapters.isNotEmpty) {
            return List.generate(parsedChapters.length, (i) {
              final ch = parsedChapters[i];
              return AudiobookChapter(
                id: 'local_ch_${i}_offset_${ch.startTimeMillis}',
                title: ch.title,
                chapterNumber: i + 1,
                startTimeMillis: ch.startTimeMillis,
                durationMillis: ch.durationMillis,
                streamUrl: file.path,
              );
            });
          }
        } else if (ext == 'mp3') {
          final parsedChapters = await Mp3Parser.parseChapters(file.path);
          if (parsedChapters.isNotEmpty) {
            return List.generate(parsedChapters.length, (i) {
              final ch = parsedChapters[i];
              return AudiobookChapter(
                id: 'local_ch_${i}_offset_${ch.startTimeMillis}',
                title: ch.title,
                chapterNumber: i + 1,
                startTimeMillis: ch.startTimeMillis,
                durationMillis: ch.durationMillis,
                streamUrl: file.path,
              );
            });
          }
        }
      } catch (e) {
        print('[AudiobookRepository] Failed to parse local candidate $ext chapters: $e');
      }
    }

    return List.generate(audioFiles.length, (i) {
      final file = audioFiles[i];
      final fileName = file.path.split('/').last;
      final title = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      return AudiobookChapter(
        id: 'local_ch_$i',
        title: title,
        chapterNumber: i + 1,
        streamUrl: file.path,
      );
    });
  }

  /// Resolve a chapter's direct stream URL.
  Future<String?> resolveChapterStream(AudiobookChapter chapter) async {
    // Local chapters already have their path as streamUrl
    if (chapter.streamUrl != null && (chapter.streamUrl!.startsWith('/') || chapter.streamUrl!.startsWith('file://'))) {
      return chapter.streamUrl;
    }
    
    final streamUrl = chapter.streamUrl;
    if (streamUrl != null && (streamUrl.contains('lazy.torbox.internal') || streamUrl.contains('lazy.flac.internal'))) {
      try {
        final uri = Uri.parse(streamUrl);
        final torrentId = int.parse(uri.pathSegments[0]);
        final fileId = int.parse(uri.pathSegments[1]);
        final resolved = await _musicRepo.getStreamUrl(torrentId, fileId);
        if (resolved != null && resolved.isNotEmpty) {
          return resolved;
        }
      } catch (e) {
        print('[AudiobookRepository] Error resolving lazy TorBox URL $streamUrl: $e');
      }
    }
    
    return _addonService.resolveChapterStream(chapter);
  }

  /// Add a torrent to TorBox.
  Future<bool> addTorrent(String magnetLink) {
    return _musicRepo.addTorrent(magnetLink);
  }

  /// Check the cache and library status of a torrent audiobook.
  Future<Map<String, dynamic>> checkTorrentStatus(String bookId) async {
    if (!bookId.startsWith('torrent:')) {
      return {'inLibrary': false, 'cached': false};
    }
    
    final parts = bookId.split(':');
    final hash = parts[1].toLowerCase();
    
    bool inLibrary = false;
    bool cached = false;
    
    try {
      // 1. Check if cached on TorBox servers
      final cachedHashes = await _musicRepo.checkCached([hash]);
      cached = cachedHashes.any((h) => h.toLowerCase() == hash);
      
      // 2. Check if in user's library
      final library = await _musicRepo.getLibrary();
      final match = library.firstWhere(
        (t) => t.hash.toLowerCase() == hash,
        orElse: () => TorBoxTorrent(id: 0, name: '', hash: '', cached: false, files: []),
      );
      
      if (match.id != 0) {
        inLibrary = true;
      }
    } catch (e) {
      print('[AudiobookRepository] Error checking torrent status: $e');
    }
    
    return {
      'inLibrary': inLibrary,
      'cached': cached,
    };
  }

  // ─── Progress Tracking ─────────────────────────────────────────

  Future<String?> getLocalBookDirectoryForBackup(String bookId) async {
    if (bookId.startsWith('local:')) {
      final path = bookId.substring(6);
      if (await io.Directory(path).exists()) {
        return path;
      }
      return null;
    }
    
    if (bookId.startsWith('torrent:')) {
      final parts = bookId.split(':');
      if (parts.length > 1) {
        final hash = parts[1].toLowerCase();
        final torrents = await _db.getAllTorrents();
        final torrent = torrents.where((t) => t.hash.toLowerCase() == hash).firstOrNull;
        if (torrent != null) {
          final files = await _db.getAllFiles();
          final bookFiles = files.where((f) => f.torrentId == torrent.id && f.localPath != null && f.localPath!.isNotEmpty).toList();
          for (final f in bookFiles) {
            final file = io.File(f.localPath!);
            if (await file.exists()) {
              return file.parent.path;
            }
          }
        }
      }
    }
    
    try {
      final settings = getIt<TorBoxSettingsRepository>();
      final downloadDirPath = settings.audiobookFolder;
      final cached = await getCachedMetadata(normalizeBookId(bookId));
      if (downloadDirPath != null && downloadDirPath.isNotEmpty && cached != null) {
        final sanitizedTitle = cached.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
        final bookDir = io.Directory(p.join(downloadDirPath, sanitizedTitle));
        if (await bookDir.exists()) {
          return bookDir.path;
        }
      }
    } catch (_) {}
    
    return null;
  }

  /// Restore listening progress from a local folder's progress.json if it exists.
  Future<void> restoreProgressFromLocalFolder(String bookId, String folderPath) async {
    try {
      final progressFile = io.File(p.join(folderPath, 'progress.json'));
      if (await progressFile.exists()) {
        final content = await progressFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final jsonProgress = data['progress'] as List<dynamic>?;
        if (jsonProgress != null) {
          for (final entry in jsonProgress) {
            final map = entry as Map<String, dynamic>;
            final chIdx = map['chapterIndex'] as int;
            
            final existing = await _db.getAudiobookProgress(bookId, chIdx);
            final localLastListened = DateTime.parse(map['lastListenedAt'] as String);
            
            if (existing == null || existing.lastListenedAt.isBefore(localLastListened)) {
              await _db.saveAudiobookProgress(AudiobookProgressCompanion.insert(
                bookId: bookId,
                chapterIndex: chIdx,
                positionMillis: Value(map['positionMillis'] as int? ?? 0),
                durationMillis: Value(map['durationMillis'] as int? ?? 0),
                lastListenedAt: localLastListened,
                isCompleted: Value(map['isCompleted'] as bool? ?? false),
              ));
            }
          }
          print('[AudiobookRepository] Restored progress from ${progressFile.path}');
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Error restoring progress from local folder: $e');
    }
  }

  /// Save listening progress for a specific chapter.
  Future<void> saveProgress({
    required String bookId,
    required int chapterIndex,
    required int positionMillis,
    required int durationMillis,
    bool isCompleted = false,
  }) async {
    await _db.saveAudiobookProgress(AudiobookProgressCompanion.insert(
      bookId: bookId,
      chapterIndex: chapterIndex,
      positionMillis: Value(positionMillis),
      durationMillis: Value(durationMillis),
      lastListenedAt: DateTime.now(),
      isCompleted: Value(isCompleted),
    ));

    // Back up progress to the local download folder if it exists
    try {
      final dirPath = await getLocalBookDirectoryForBackup(bookId);
      if (dirPath != null) {
        final progressList = await getBookChapterProgress(bookId);
        final List<Map<String, dynamic>> jsonList = [];
        final Set<int> processedIndices = {};
        
        jsonList.add({
          'chapterIndex': chapterIndex,
          'positionMillis': positionMillis,
          'durationMillis': durationMillis,
          'isCompleted': isCompleted,
          'lastListenedAt': DateTime.now().toIso8601String(),
        });
        processedIndices.add(chapterIndex);
        
        for (final p in progressList) {
          if (!processedIndices.contains(p.chapterIndex)) {
            jsonList.add({
              'chapterIndex': p.chapterIndex,
              'positionMillis': p.positionMillis,
              'durationMillis': p.durationMillis,
              'isCompleted': p.isCompleted,
              'lastListenedAt': p.lastListenedAt.toIso8601String(),
            });
            processedIndices.add(p.chapterIndex);
          }
        }
        
        final data = {
          'bookId': bookId,
          'lastListenedAt': DateTime.now().toIso8601String(),
          'progress': jsonList,
        };
        
        final progressFile = io.File(p.join(dirPath, 'progress.json'));
        await progressFile.writeAsString(jsonEncode(data));
        print('[AudiobookRepository] Progress backed up to ${progressFile.path}');
      }
    } catch (e) {
      print('[AudiobookRepository] Error backing up progress to local folder: $e');
    }
  }

  /// Get progress for a specific book's chapter.
  Future<DbAudiobookProgress?> getChapterProgress(String bookId, int chapterIndex) {
    return _db.getAudiobookProgress(bookId, chapterIndex);
  }

  /// Get the latest progress for a book (most recently listened chapter).
  Future<DbAudiobookProgress?> getLatestBookProgress(String bookId) {
    return _db.getLatestAudiobookProgress(bookId);
  }

  /// Get all books with progress (for "Continue Listening" section).
  Future<List<DbAudiobookProgress>> getAllInProgressBooks() {
    return _db.getAllAudiobookProgress();
  }

  /// Mark a chapter as completed.
  Future<void> markChapterCompleted(String bookId, int chapterIndex) {
    return saveProgress(
      bookId: bookId,
      chapterIndex: chapterIndex,
      positionMillis: 0,
      durationMillis: 0,
      isCompleted: true,
    );
  }

  /// Get all chapter-level progress entries for a specific book.
  Future<List<DbAudiobookProgress>> getBookChapterProgress(String bookId) {
    return _db.getBookChapterProgress(bookId);
  }

  /// Clear all progress for a book.
  Future<void> clearBookProgress(String bookId) {
    return _db.clearAudiobookProgress(bookId);
  }

  /// Clear metadata cache for a book.
  Future<void> clearBookMetadataCache(String bookId) {
    return _db.deleteAudiobookMetadata(normalizeBookId(bookId));
  }

  // ─── Metadata Cache ────────────────────────────────────────────

  /// Save audiobook metadata to local cache.
  Future<void> cacheBookMetadata(AudiobookResult book) async {
    final normalizedId = normalizeBookId(book.id);
    final existing = await getCachedMetadata(normalizedId);

    String title = book.title;
    String author = book.author;
    String? narrator = book.narrator;
    String? artworkUrl = book.artworkUrl;
    String? description = book.description;
    int totalChapters = book.totalChapters ?? 0;
    String? language = book.language;
    String? genre = book.genre;

    // Helper checkers to identify placeholder metadata
    const basicAuthors = {
      'torrent result', 'torrent source', 'local library', 'unknown author', 
      'torbox library'
    };
    bool isPlaceholderAuthor(String? auth) {
      if (auth == null || auth.trim().isEmpty) return true;
      return basicAuthors.contains(auth.toLowerCase().trim());
    }

    bool isPlaceholderDescription(String? desc) {
      if (desc == null || desc.trim().isEmpty) return true;
      final lower = desc.toLowerCase().trim();
      return lower == 'audiobook stored locally/in library' ||
             lower == 'from torbox library' ||
             lower == 'trending audiobook' ||
             lower.startsWith('source:') ||
             lower.startsWith('torrent source:');
    }

    if (existing != null) {
      // 1. Keep richer description
      if (!isPlaceholderDescription(existing.description)) {
        if (isPlaceholderDescription(description)) {
          description = existing.description;
        }
      }

      // 2. Keep richer author
      if (!isPlaceholderAuthor(existing.author)) {
        if (isPlaceholderAuthor(author)) {
          author = existing.author!;
        }
      }

      // 3. Keep richer artwork
      if (existing.artworkUrl != null && existing.artworkUrl!.isNotEmpty) {
        if (artworkUrl == null || artworkUrl.isEmpty) {
          artworkUrl = existing.artworkUrl;
        }
      }

      // 4. Keep richer narrator
      if (existing.narrator != null && existing.narrator!.isNotEmpty) {
        if (narrator == null || narrator.isEmpty) {
          narrator = existing.narrator;
        }
      }

      // 5. Keep richer language
      if (existing.language != null && existing.language!.isNotEmpty) {
        if (language == null || language.isEmpty) {
          language = existing.language;
        }
      }

      // 6. Keep richer genre
      if (existing.genre != null && existing.genre!.isNotEmpty) {
        if (genre == null || genre.isEmpty) {
          genre = existing.genre;
        }
      }

      // 7. Keep richer title (don't revert to basic torrent name if we fetched a proper book title)
      if (existing.title.isNotEmpty && isPlaceholderAuthor(book.author) && book.title != existing.title) {
        title = existing.title;
      }

      // 8. Keep totalChapters if incoming is 0
      if (totalChapters == 0 && existing.totalChapters != null && existing.totalChapters! > 0) {
        totalChapters = existing.totalChapters!;
      }
    }

    await _db.saveAudiobookMetadataEntry(AudiobookMetadataCacheCompanion.insert(
      bookId: normalizedId,
      title: title,
      author: Value(author),
      narrator: Value(narrator),
      artworkUrl: Value(artworkUrl),
      description: Value(description),
      totalChapters: Value(totalChapters),
      language: Value(language),
      genre: Value(genre),
      lastUpdated: DateTime.now(),
    ));
  }

  /// Get cached metadata for a book.
  Future<DbAudiobookMetadataCache?> getCachedMetadata(String bookId) {
    return _db.getAudiobookMetadata(normalizeBookId(bookId));
  }

  /// Convert cached DB metadata back to an AudiobookResult.
  AudiobookResult metadataToResult(DbAudiobookMetadataCache meta) {
    return AudiobookResult(
      id: meta.bookId,
      title: meta.title,
      author: meta.author ?? 'Unknown Author',
      narrator: meta.narrator,
      artworkUrl: meta.artworkUrl,
      description: meta.description,
      totalChapters: meta.totalChapters,
      language: meta.language,
      genre: meta.genre,
    );
  }

  /// Query online APIs (Open Library) for book details.
  Future<Map<String, String>?> _fetchOnlineMetadata(String title) async {
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://openlibrary.org/search.json',
        queryParameters: {'title': title, 'limit': 1},
      );
      if (res.statusCode == 200 && res.data != null) {
        final docs = res.data['docs'] as List<dynamic>?;
        if (docs != null && docs.isNotEmpty) {
          final doc = docs.first as Map<String, dynamic>;
          final authorName = doc['author_name'] as List<dynamic>?;
          final author = authorName != null && authorName.isNotEmpty ? authorName.first.toString() : '';
          
          String description = '';
          final key = doc['key'] as String?;
          if (key != null) {
            final workRes = await dio.get('https://openlibrary.org$key.json');
            if (workRes.statusCode == 200 && workRes.data != null) {
              final descObj = workRes.data['description'];
              if (descObj is String) {
                description = descObj;
              } else if (descObj is Map && descObj['value'] != null) {
                description = descObj['value'].toString();
              }
            }
          }

          final coverId = doc['cover_i'] as num?;
          final artworkUrl = coverId != null ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg' : null;

          return {
            'description': description,
            'author': author,
            if (artworkUrl != null) 'artworkUrl': artworkUrl,
          };
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Open Library lookup failed: $e');
    }

    return null;
  }

  /// Helper to search iTunes.
  Future<List<AudiobookResult>> _searchItunes(String query) async {
    final List<AudiobookResult> results = [];
    try {
      print('[AudiobookRepository] Searching iTunes for "$query"...');
      final dio = Dio();
      final res = await dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': query,
          'entity': 'audiobook',
          'limit': 8,
          'country': 'us',
          'lang': 'en_us',
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final Map<String, dynamic> data;
        if (res.data is String) {
          data = jsonDecode(res.data as String) as Map<String, dynamic>;
        } else {
          data = res.data as Map<String, dynamic>;
        }
        final items = data['results'] as List<dynamic>?;
        if (items != null) {
          print('[AudiobookRepository] iTunes returned ${items.length} items');
          for (final item in items) {
            final title = item['collectionName'] as String? ?? item['trackName'] as String? ?? 'Unknown Title';
            final author = item['artistName'] as String? ?? 'Unknown Author';
            final description = item['description'] as String? ?? '';
            final artworkUrl100 = item['artworkUrl100'] as String?;
            final artworkUrl = artworkUrl100 != null 
                ? artworkUrl100.replaceAll('100x100bb', '600x600bb') 
                : null;
            
            results.add(AudiobookResult(
              id: 'itunes_meta:${item['collectionId'] ?? item['trackId'] ?? title.hashCode}',
              title: title,
              author: author,
              description: description,
              artworkUrl: artworkUrl,
              language: 'EN',
            ));
          }
          print('[AudiobookRepository] Parsed ${results.length} results from iTunes');
        }
      }
    } catch (e) {
      print('[AudiobookRepository] iTunes search failed: $e');
    }
    return results;
  }

  /// Helper to search Open Library.
  Future<List<AudiobookResult>> _searchOpenLibrary(String query) async {
    final List<AudiobookResult> results = [];
    try {
      print('[AudiobookRepository] Searching Open Library for "$query"...');
      final dio = Dio();
      final res = await dio.get(
        'https://openlibrary.org/search.json',
        queryParameters: {'title': query, 'limit': 8},
      );
      if (res.statusCode == 200 && res.data != null) {
        final docs = res.data['docs'] as List<dynamic>?;
        if (docs != null) {
          print('[AudiobookRepository] Open Library returned ${docs.length} docs');
          for (final doc in docs) {
            final title = doc['title'] as String? ?? 'Unknown Title';
            final authorName = doc['author_name'] as List<dynamic>?;
            final author = authorName != null && authorName.isNotEmpty ? authorName.first.toString() : 'Unknown Author';
            
            final coverId = doc['cover_i'] as num?;
            final artworkUrl = coverId != null ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg' : null;
            final keyPath = doc['key'] as String? ?? '';
            
            final languages = doc['language'] as List<dynamic>?;
            String language = 'EN';
            if (languages != null && languages.isNotEmpty) {
              final firstLang = languages.first.toString().toLowerCase();
              if (firstLang == 'eng' || firstLang == 'en') {
                language = 'EN';
              } else {
                language = firstLang.length > 2 ? firstLang.substring(0, 2).toUpperCase() : firstLang.toUpperCase();
              }
            }

            results.add(AudiobookResult(
              id: 'openlibrary_meta:$keyPath',
              title: title,
              author: author,
              artworkUrl: artworkUrl,
              description: '',
              language: language,
            ));
          }
          print('[AudiobookRepository] Parsed ${results.length} results from Open Library');
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Open Library search failed: $e');
    }
    return results;
  }

  /// Search online APIs (iTunes, Open Library) for book details.
  Future<List<AudiobookResult>> searchOnlineMetadata(String query) async {
    final List<AudiobookResult> results = [];
    final Set<String> seenTitles = {};
    print('[AudiobookRepository] Starting online metadata search for: "$query"');

    final futures = [
      _searchItunes(query),
      _searchOpenLibrary(query),
    ];

    final lists = await Future.wait(futures);
    for (final list in lists) {
      for (final book in list) {
        final key = '${book.title}|${book.author}'.toLowerCase();
        if (!seenTitles.contains(key)) {
          seenTitles.add(key);
          results.add(book);
        }
      }
    }

    print('[AudiobookRepository] Search completed. Returning total of ${results.length} metadata results.');
    return results;
  }

  /// Search online APIs (iTunes, Open Library) yielding results incrementally as they complete.
  Stream<List<AudiobookResult>> searchOnlineMetadataStream(String query) async* {
    final List<AudiobookResult> results = [];
    final Set<String> seenTitles = {};
    print('[AudiobookRepository] Starting online metadata search stream for: "$query"');

    final itunesFuture = _searchItunes(query);
    final olFuture = _searchOpenLibrary(query);

    void addList(List<AudiobookResult> list) {
      for (final book in list) {
        final key = '${book.title}|${book.author}'.toLowerCase();
        if (!seenTitles.contains(key)) {
          seenTitles.add(key);
          results.add(book);
        }
      }
    }

    await for (final list in Stream.fromFutures([itunesFuture, olFuture])) {
      addList(list);
      yield List.from(results);
    }
  }

  /// Resolve full details (like description) for an Open Library book search result.
  Future<AudiobookResult> fetchFullOnlineMetadata(AudiobookResult partialBook) async {
    if (partialBook.id.startsWith('openlibrary_meta:')) {
      final workKey = partialBook.id.substring('openlibrary_meta:'.length);
      try {
        final dio = Dio();
        final workRes = await dio.get('https://openlibrary.org$workKey.json');
        if (workRes.statusCode == 200 && workRes.data != null) {
          final descObj = workRes.data['description'];
          String description = '';
          if (descObj is String) {
            description = descObj;
          } else if (descObj is Map && descObj['value'] != null) {
            description = descObj['value'].toString();
          }
          return partialBook.copyWith(description: description);
        }
      } catch (e) {
        print('[AudiobookRepository] Error fetching full Open Library metadata: $e');
      }
    }
    return partialBook;
  }
}
