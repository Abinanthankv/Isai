import 'dart:io' as io;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:audiotags/audiotags.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/database.dart';
import '../../music/data/music_repository.dart';
import '../../music/data/music_models.dart';
import 'audiobook_addon_service.dart';
import 'audiobook_models.dart';
import 'hardcover_api_service.dart';
import 'm4b_parser.dart';
import 'mp3_parser.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../../settings/data/hardcover_settings_repository.dart';
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
      // parts[0]='torrent', parts[1]=hash
      if (parts.length >= 3) {
        final fileId = int.tryParse(parts[2]);
        if (fileId != null) {
          // parts[2] is a numeric file ID → preserve it
          return 'torrent:${parts[1]}:$fileId';
        }
      }
      // parts[2+] was an encoded magnet or empty → strip it
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

  /// Returns true if the torrent name suggests it is NOT an audiobook/book
  /// (e.g. porn, games, applications, software, music albums).
  bool _looksLikeUnwantedContent(String name) {
    final nameLower = name.toLowerCase();
    final words = nameLower.split(RegExp(r'[\s._-]+'));

    // Porn/adult keywords
    final adultKeywords = [
      'porn', 'xxx', 'porno', 'sex', 'erotic', 'onlyfans', 'adult',
      'milf', 'teen', 'anal', 'cock', 'dick', 'pussy', 'blowjob',
      'camgirl', 'webcam', 'nude', 'naked', 'nsfw',
    ];
    if (adultKeywords.any((k) => nameLower.contains(k))) return true;

    // Gaming keywords
    final gameKeywords = [
      'game', 'pc game', 'xbox', 'playstation', 'ps4', 'ps5', 'nintendo',
      'torrentgame', 'repack', 'crack', 'hack', 'cheat', 'trainer',
      'gog', 'steam', 'update', 'dlc', 'expansion pack', 'fitgirl',
      'codex', 'plaza', 'cpy', 'multiplayer', 'mod', 'mods',
    ];
    if (gameKeywords.any((k) => nameLower.contains(k))) return true;

    // Software/applications
    final softwareKeywords = [
      'software', 'application', 'app ', 'installer', 'setup.exe', 'setup.exe',
      'portable', 'keygen', 'cracked', 'activation', 'license key',
      'windows', 'office', 'adobe', 'photoshop', 'illustrator', 'premiere',
      'autocad', 'solidworks', 'visual studio', 'vmware', 'virtualbox',
      'android studio', 'idm', 'internet download manager',
      'alcohol', 'nero', 'daemon tools', 'utorrent', 'bitdefender',
      'kaspersky', 'norton', 'mcafee', 'avg', 'avast', 'malwarebytes',
    ];
    if (softwareKeywords.any((k) => nameLower.contains(k))) return true;

    // Common non-book file extensions / media types
    final nonBookExtensions = [
      '.exe', '.msi', '.dmg', '.iso', '.bin', '.cue', '.apk',
      '.ipa', '.jar', '.sis', '.deb', '.rpm',
    ];
    if (nonBookExtensions.any((ext) => nameLower.endsWith(ext) || nameLower.contains('$ext '))) return true;

    // Category patterns from torrent sites
    final categoryPatterns = [
      'applications', 'games', 'pc software', 'mac software',
      'mobile phone', 'android', 'jailbreak',
      'adult only', 'hentai', 'anime', 'cartoon',
    ];
    if (categoryPatterns.any((k) => nameLower.contains(k))) return true;

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

  /// Strip extension and trailing part/volume/CD/disc numbers from a file name
  /// to derive a base title for grouping multi-file audiobooks.
  static String _extractBaseTitle(String fileName) {
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    name = name.replaceAll(RegExp(r'[-–—]\s*(Part|Vol(?:ume)?|Book|Chapter|Ch|CD|Disc|Track)\s*\d+.*$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s*[-–—]\s*\d+(\s*of\s*\d+)?\s*$'), '');
    name = name.replaceAll(RegExp(r'\s*[([]\d+[)\]]\s*$'), '');
    name = name.replaceAll(RegExp(r'\s+\d+\s*$'), '');
    return name.trim();
  }

  /// Fetch all torrent audiobooks that are present in the user's TorBox library.
  /// Groups files sharing the same base title (stripping extensions and part numbers)
  /// into a single book entry so multi-part audiobooks appear as one item.
  Future<List<AudiobookResult>> getTorBoxLibraryAudiobooks() async {
    final List<AudiobookResult> results = [];
    try {
      final library = await _musicRepo.getLibrary();
      if (library.isEmpty) return [];

      final cachedMetadataList = await (_db.select(_db.audiobookMetadataCache)).get();

      for (final torrent in library) {
        final hash = torrent.hash.toLowerCase();
        final hasCached = cachedMetadataList.any((m) => m.bookId.toLowerCase().contains(hash));
        if (!hasCached && !_looksLikeAudiobook(torrent)) continue;

        // Find torrent-level cached metadata (old format, no file ID)
        DbAudiobookMetadataCache? torrentMatch;
        for (final m in cachedMetadataList) {
          if (m.bookId.toLowerCase().contains(hash)) {
            torrentMatch = m;
            break;
          }
        }

        // Group files by base title
        final Map<String, List<TorBoxFile>> groups = {};
        for (final file in torrent.files) {
          final base = _extractBaseTitle(file.displayName);
          groups.putIfAbsent(base, () => []).add(file);
        }

        for (final groupEntry in groups.entries) {
          final baseTitle = groupEntry.key;
          final groupFiles = groupEntry.value;
          final firstFile = groupFiles.first;
          final bookId = 'torrent:$hash:${firstFile.id}';

          // Check for file-specific cached metadata
          DbAudiobookMetadataCache? fileMatch;
          for (final m in cachedMetadataList) {
            if (m.bookId == bookId) { fileMatch = m; break; }
          }
          if (fileMatch != null) {
            results.add(metadataToResult(fileMatch));
            continue;
          }

          AudiobookResult book;
          if (torrentMatch != null) {
            book = AudiobookResult(
              id: bookId,
              title: baseTitle,
              author: torrentMatch.author ?? 'TorBox Library',
              artworkUrl: torrentMatch.artworkUrl,
              description: groupFiles.length > 1 ? '${groupFiles.length} parts' : torrentMatch.description,
              totalChapters: groupFiles.length > 1 ? groupFiles.length : null,
            );
          } else {
            book = AudiobookResult(
              id: bookId,
              title: baseTitle,
              author: 'TorBox Library',
              description: groupFiles.length > 1 ? '${groupFiles.length} parts' : 'From TorBox library',
              totalChapters: groupFiles.length > 1 ? groupFiles.length : null,
            );
          }
          results.add(book);

          // Cache metadata eagerly so getBookChapters can use it for group matching
          // (TorBox API file IDs don't match DB auto-increment IDs, so getBookChapters
          // relies on cached metadata to determine which file group belongs to this book)
          final hasCachedBookId = cachedMetadataList.any((m) => m.bookId == bookId);
          if (!hasCachedBookId) {
            await cacheBookMetadata(book, writeLocalBackup: false).catchError((_) {});
          }
        }
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
      _addonService.searchBooks(query).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      ),
      _musicRepo.searchAllTorrents(query).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      ),
      _searchAudiobookBay(query).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      ),
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

      // 3. Add Torrent Results (only from audiobook-friendly sources)
      final allowedSources = {'apibay', 'bitsearch', 'nyaa'};
      final torrentResults = allResults[1] as List<dynamic>;
      for (final t in torrentResults) {
        final source = t.source as String? ?? '';
        if (!allowedSources.contains(source)) {
          continue; // Only show results from apibay, bitsearch, nyaa
        }
        final name = t.name as String? ?? '';
        if (_looksLikeVideo(name)) {
          continue; // Skip videos (movies, TV shows, etc.)
        }
        if (_looksLikeUnwantedContent(name)) {
          continue; // Skip porn, games, software, etc.
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
      
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
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
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
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
              durationMillis: item['duration'] as int? ?? item['durationMillis'] as int?,
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
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
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
              durationMillis: item['trackTimeMillis'] as int?,
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
        final hasExtendedMeta = _parseExtendedField(cached.description, 'releaseDate') != null ||
                               _parseExtendedField(cached.description, 'previewUrl') != null;
        if (hasExtendedMeta) {
          return metadataToResult(cached);
        }
      }
      
      final parts = bookId.split(':');
      if (parts.length > 1) {
        final itemId = parts[1];
        final enriched = await _lookupItunes(itemId);
        if (enriched != null) {
          final resolvedBook = enriched.copyWith(id: bookId);
          await cacheBookMetadata(resolvedBook);
          return resolvedBook;
        }
      }
      
      if (cached != null) {
        return metadataToResult(cached);
      }
      return null; // Fallback to passed book in detail screen
    }

    if (bookId.startsWith('audiobookbay:')) {
      final detailUrl = Uri.decodeComponent(bookId.substring('audiobookbay:'.length));
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));
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
        final hasExtendedMeta = _parseExtendedField(cached.description, 'releaseDate') != null ||
                               _parseExtendedField(cached.description, 'previewUrl') != null;
        if (hasExtendedMeta) {
          return metadataToResult(cached);
        }
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
      
      final mergedBook = AudiobookResult(
        id: bookId,
        title: title,
        author: 'Torrent Result',
        description: 'From TorBox library',
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
                final parsed = await M4bParser.parseChapters(firstAudioFile.path).timeout(const Duration(seconds: 15));
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
  Future<List<AudiobookChapter>> getBookChapters(String bookId, {bool forceParse = false}) async {
    if (bookId.startsWith('local:')) {
      return _getLocalChapters(bookId);
    }

    // Check if we have a local backup folder containing metadata.json for this book
    try {
      final localDir = await getLocalBookDirectoryForBackup(bookId);
      if (localDir != null) {
        final metaFile = io.File(p.join(localDir, 'metadata.json'));
        if (await metaFile.exists()) {
          final content = await metaFile.readAsString();
          if (content.trim().isEmpty) {
            print('[AudiobookRepository] metadata.json is empty, skipping.');
          } else {
            final data = jsonDecode(content) as Map<String, dynamic>;
            final jsonChapters = data['chapters'] as List<dynamic>?;
            if (jsonChapters != null && jsonChapters.isNotEmpty) {
              return jsonChapters.map((chMap) {
                final map = chMap as Map<String, dynamic>;
                return AudiobookChapter(
                  id: map['id'] as String? ?? 'local_ch_${map['chapterNumber']}',
                  title: map['title'] as String? ?? 'Chapter',
                  chapterNumber: map['chapterNumber'] as int? ?? 1,
                  startTimeMillis: map['startTimeMillis'] as int? ?? 0,
                  durationMillis: map['durationMillis'] as int? ?? 0,
                  streamUrl: map['streamUrl'] as String?,
                  source: 'Local metadata.json (Backup)',
                );
              }).toList();
            }
          }
        } else {
          final localChapters = await _getLocalChapters('local:$localDir');
          if (localChapters.isNotEmpty) {
            print('[AudiobookRepository] localDir found without metadata.json, scanned local files directly.');
            return localChapters;
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Error reading chapters from backup metadata.json in getBookChapters: $e');
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
            final audioFiles = torrentFiles.where((f) => validExtensions.any((ext) => f.name.toLowerCase().endsWith(ext))).toList();
            
            // If the bookId includes a fileId, only show files from the same group
            final int? bookFileId = parts.length >= 3 ? int.tryParse(parts[2]) : null;
            
            // Group files by base title so only files from the same group appear as chapters
            final Map<String, List<DbFile>> groups = {};
            for (final f in audioFiles) {
              final shortName = f.name.split('/').last.split('\\').last;
              final base = _extractBaseTitle(shortName);
              groups.putIfAbsent(base, () => []).add(f);
            }
            
            // Find the group that contains the book's fileId
            final Set<int> allowedFileIds = {};
            if (bookFileId != null) {
              for (final g in groups.values) {
                if (g.any((f) => f.id == bookFileId)) {
                  allowedFileIds.addAll(g.map((f) => f.id));
                  break;
                }
              }
            // If ID matching failed (local DB IDs != TorBox API IDs),
            // fall back to matching by base title from cached metadata
            if (allowedFileIds.isEmpty) {
              final cached = await getCachedMetadata(bookId);
              if (cached != null) {
                final cachedBase = _extractBaseTitle(cached.title);
                for (final g in groups.entries) {
                  if (g.key.toLowerCase() == cachedBase.toLowerCase()) {
                    allowedFileIds.addAll(g.value.map((f) => f.id));
                    break;
                  }
                }
              }
            }

            // Safe fallback: if we still can't determine the group
            // (no cached metadata or base title mismatch), return ALL audio files
            // so the book remains playable rather than showing zero chapters
            if (allowedFileIds.isEmpty) {
              allowedFileIds.addAll(audioFiles.map((f) => f.id));
            }
            } else {
              allowedFileIds.addAll(audioFiles.map((f) => f.id));
            }
            
            int idx = 0;
            for (final f in audioFiles) {
              if (!allowedFileIds.contains(f.id)) continue;
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
      } catch (e) {
        print('[AudiobookRepository] Error reading chapters from local DB: $e');
      }
    }
    
    if (chapters.isEmpty) {
      chapters = await _addonService.getBookChapters(bookId);
    }
    
    // For TorBox books, skip auto-parsing by default.
    // Refresh Chapters button can call with forceParse: true.
    if (bookId.startsWith('torrent:') && !forceParse) return chapters;

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

    // Determine the candidate(s) to try parsing:
    // Prioritize M4B/M4A files if they exist (single file with embedded chapters).
    // If no M4B/M4A files exist, try each MP3 file as a candidate.
    // This handles TorBox multi-file MP3 collections where any file may have embedded chapters.
    final List<AudiobookChapter> candidates;
    if (m4bFiles.isNotEmpty) {
      candidates = m4bFiles;
    } else if (mp3Files.isNotEmpty) {
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
            final parsedChapters = await M4bParser.parseChapters(resolvedUrl).timeout(const Duration(seconds: 15));
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
            final parsedChapters = await Mp3Parser.parseChapters(resolvedUrl).timeout(const Duration(seconds: 15));
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
    String path = bookId.substring('local:'.length);
    if (path.startsWith('file://')) {
      try {
        path = Uri.parse(path).toFilePath();
      } catch (_) {}
    }
    if (path.contains('%')) {
      try {
        path = Uri.decodeComponent(path);
      } catch (_) {}
    }
    final isFile = io.FileSystemEntity.isFileSync(path);
    
    if (isFile) {
      final file = io.File(path);
      final ext = file.path.split('.').last.toLowerCase();
      List<AudiobookChapter> parsed = [];
      
      bool looksLikeM4b = false;
      bool looksLikeMp3 = false;
      try {
        final raf = await file.open(mode: io.FileMode.read);
        final header = await raf.read(8);
        await raf.close();
        if (header.length >= 8) {
          if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
            looksLikeMp3 = true;
          }
          final typeStr = String.fromCharCodes(header.sublist(4, 8));
          if (typeStr == 'ftyp' || (header[0] == 0 && header[1] == 0 && header[2] == 0)) {
            looksLikeM4b = true;
          }
        }
      } catch (e) {
        print('[AudiobookRepository] Error detecting file format magic bytes: $e');
      }

      print('[AudiobookRepository] Single file auto-detect: looksLikeM4b=$looksLikeM4b, looksLikeMp3=$looksLikeMp3 (extension=$ext)');

      // If it looks like M4B or we default to it, try M4B first, fallback to MP3
      if (looksLikeM4b || (!looksLikeMp3 && (ext == 'm4b' || ext == 'm4a'))) {
        try {
          final parsedChapters = await M4bParser.parseChapters(file.path).timeout(const Duration(seconds: 15));
          if (parsedChapters.isNotEmpty) {
            parsed = List.generate(parsedChapters.length, (i) {
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
          print('[AudiobookRepository] Failed to parse as M4B: $e');
        }

        if (parsed.isEmpty) {
          try {
            final parsedChapters = await Mp3Parser.parseChapters(file.path).timeout(const Duration(seconds: 15));
            if (parsedChapters.isNotEmpty) {
              parsed = List.generate(parsedChapters.length, (i) {
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
            print('[AudiobookRepository] Fallback parse as MP3 failed: $e');
          }
        }
      } else {
        // Try MP3 first, fallback to M4B
        try {
          final parsedChapters = await Mp3Parser.parseChapters(file.path).timeout(const Duration(seconds: 15));
          if (parsedChapters.isNotEmpty) {
            parsed = List.generate(parsedChapters.length, (i) {
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
          print('[AudiobookRepository] Failed to parse as MP3: $e');
        }

        if (parsed.isEmpty) {
          try {
            final parsedChapters = await M4bParser.parseChapters(file.path).timeout(const Duration(seconds: 15));
            if (parsedChapters.isNotEmpty) {
              parsed = List.generate(parsedChapters.length, (i) {
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
            print('[AudiobookRepository] Fallback parse as M4B failed: $e');
          }
        }
      }

      if (parsed.isNotEmpty) {
        return parsed;
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

    // Find candidates: M4B/M4A files, or MP3 files in the directory
    final localM4bCandidates = audioFiles.where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return ext == 'm4b' || ext == 'm4a';
    }).toList();

    final localMp3Candidates = audioFiles.where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return ext == 'mp3';
    }).toList();

    final List<AudiobookChapter> expandedChapters = [];
    int globalChapterIndex = 0;

    for (final file in audioFiles) {
      final ext = file.path.split('.').last.toLowerCase();
      List<dynamic> parsedChapters = [];
      
      bool looksLikeM4b = false;
      bool looksLikeMp3 = false;
      try {
        final raf = await file.open(mode: io.FileMode.read);
        final header = await raf.read(8);
        await raf.close();
        if (header.length >= 8) {
          if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
            looksLikeMp3 = true;
          }
          final typeStr = String.fromCharCodes(header.sublist(4, 8));
          if (typeStr == 'ftyp' || (header[0] == 0 && header[1] == 0 && header[2] == 0)) {
            looksLikeM4b = true;
          }
        }
      } catch (_) {}

      // Try M4B first, fallback to MP3
      if (looksLikeM4b || (!looksLikeMp3 && (ext == 'm4b' || ext == 'm4a'))) {
        try {
          parsedChapters = await M4bParser.parseChapters(file.path).timeout(const Duration(seconds: 15));
        } catch (_) {}
        if (parsedChapters.isEmpty) {
          try {
            parsedChapters = await Mp3Parser.parseChapters(file.path).timeout(const Duration(seconds: 15));
          } catch (_) {}
        }
      } else {
        // Try MP3 first, fallback to M4B
        try {
          parsedChapters = await Mp3Parser.parseChapters(file.path).timeout(const Duration(seconds: 15));
        } catch (_) {}
        if (parsedChapters.isEmpty) {
          try {
            parsedChapters = await M4bParser.parseChapters(file.path).timeout(const Duration(seconds: 15));
          } catch (_) {}
        }
      }

      if (parsedChapters.isNotEmpty) {
        for (final ch in parsedChapters) {
          expandedChapters.add(AudiobookChapter(
            id: 'local_ch_${globalChapterIndex}_offset_${ch.startTimeMillis}',
            title: ch.title,
            chapterNumber: globalChapterIndex + 1,
            startTimeMillis: ch.startTimeMillis,
            durationMillis: ch.durationMillis,
            streamUrl: file.path,
          ));
          globalChapterIndex++;
        }
      } else {
        final fileName = file.path.split('/').last;
        final title = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
        expandedChapters.add(AudiobookChapter(
          id: 'local_ch_$globalChapterIndex',
          title: title,
          chapterNumber: globalChapterIndex + 1,
          streamUrl: file.path,
        ));
        globalChapterIndex++;
      }
    }

    return expandedChapters;
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

    final normalizedId = normalizeBookId(bookId);

    // If we already have cached metadata, the book is known to be in library
    final existing = await _db.getAudiobookMetadata(normalizedId);
    if (existing != null) {
      return {'inLibrary': true, 'cached': true};
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

  /// In-memory cache of the unified progress.json data.
  Map<String, dynamic>? _progressData;
  bool _progressMigrated = false;
  Timer? _debounceFlushTimer;
  int _flushBacklog = 0;

  /// Returns the path to the unified progress.json file.
  Future<io.File> _getProgressFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return io.File(p.join(dir.path, 'audiobook_progress.json'));
  }

  /// Loads the unified progress.json into memory. Creates an empty file if
  /// none exists. On first load, migrates any existing DB entries into the file.
  Future<Map<String, dynamic>> _loadProgressData() async {
    if (_progressData != null) return _progressData!;
    final file = await _getProgressFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      _progressData = jsonDecode(content) as Map<String, dynamic>;
    } else {
      _progressData = {
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'books': <String, dynamic>{},
      };
    }
    if (!_progressMigrated) {
      _progressMigrated = true;
      await _migrateDbToProgressIfNeeded();
      await _restorePerBookProgressIfNeeded();
    }
    return _progressData!;
  }

  /// Flushes the in-memory progress data to disk (atomic write via temp file).
  /// If [debounced] is true, coalesces rapid calls via a 5-second debounce timer.
  Future<void> _flushProgressData({bool debounced = false}) async {
    if (_progressData == null) return;
    _progressData!['lastUpdated'] = DateTime.now().toIso8601String();

    if (!debounced) {
      _debounceFlushTimer?.cancel();
      _debounceFlushTimer = null;
      _flushBacklog = 0;
      await _writeProgressToDisk();
      return;
    }

    _flushBacklog++;
    _debounceFlushTimer?.cancel();
    _debounceFlushTimer = Timer(const Duration(seconds: 5), () async {
      _flushBacklog = 0;
      await _writeProgressToDisk();
    });
  }

  /// Actually writes the in-memory progress data to disk.
  Future<void> _writeProgressToDisk() async {
    try {
      final file = await _getProgressFile();
      final tempFile = io.File('${file.path}.tmp');
      await tempFile.writeAsString(jsonEncode(_progressData));
      await tempFile.rename(file.path);
    } catch (e) {
      print('[AudiobookRepository] Error writing progress to disk: $e');
    }
  }

  /// On first launch after migration, copies existing DB progress entries into
  /// the unified progress.json so nothing is lost.
  Future<void> _migrateDbToProgressIfNeeded() async {
    final data = _progressData!;
    final books = data['books'] as Map<String, dynamic>;
    if (books.isNotEmpty) return;

    final dbEntries = await _db.getAllAudiobookProgress();
    if (dbEntries.isEmpty) return;

    for (final entry in dbEntries) {
      final normId = normalizeBookId(entry.bookId);
      final bookObj = books.putIfAbsent(normId, () => <String, dynamic>{}) as Map<String, dynamic>;
      final chapters = bookObj.putIfAbsent('chapters', () => <dynamic>[]) as List<dynamic>;
      chapters.add({
        'chapterIndex': entry.chapterIndex,
        'positionMillis': entry.positionMillis,
        'durationMillis': entry.durationMillis,
        'isCompleted': entry.isCompleted,
        'lastListenedAt': entry.lastListenedAt.toIso8601String(),
        'originalBookId': entry.bookId,
      });
    }

    // Populate book-level summary fields from metadata cache and chapters
    for (final entry in books.entries) {
      final bookObj = entry.value as Map<String, dynamic>;
      final chapters = bookObj['chapters'] as List<dynamic>? ?? [];
      int completed = 0;
      int maxPos = 0;
      int totalListened = 0;
      int totalDuration = 0;
      for (final ch in chapters) {
        final chMap = ch as Map<String, dynamic>;
        if (chMap['isCompleted'] == true) completed++;
        final pos = (chMap['positionMillis'] as int?) ?? 0;
        if (pos > maxPos) maxPos = pos;
        totalListened += pos;
        totalDuration += (chMap['durationMillis'] as int?) ?? 0;
      }
      final cached = await getCachedMetadata(entry.key);
      int totalCh = cached?.totalChapters ?? 0;
      if (totalCh <= 0 && chapters.isNotEmpty) {
        int maxIdx = 0;
        for (final ch in chapters) {
          final idx = (ch as Map<String, dynamic>)['chapterIndex'] as int? ?? 0;
          if (idx > maxIdx) maxIdx = idx;
        }
        totalCh = maxIdx + 1;
      }
      final pct = totalCh > 0 ? (completed / totalCh).clamp(0.0, 1.0) : 0.0;
      bookObj['listenedMillis'] = maxPos;
      bookObj['totalDurationMillis'] = totalDuration;
      bookObj['completedChapters'] = completed;
      bookObj['totalChapters'] = totalCh;
      bookObj['progressPercent'] = pct;
      if (cached != null) {
        bookObj['title'] = cached.title;
        bookObj['author'] = cached.author ?? 'Unknown Author';
        bookObj['artworkUrl'] = cached.artworkUrl;
      }
    }

    await _flushProgressData();
  }

  /// Scans the audiobookFolder for legacy per-book progress.json files and
  /// imports them into the unified progress.json. Only runs on fresh starts
  /// where the unified file has no data yet.
  Future<void> _restorePerBookProgressIfNeeded() async {
    final data = _progressData!;
    final books = data['books'] as Map<String, dynamic>;
    // Only run if we have no progress data yet (fresh install or cleared)
    if (books.isNotEmpty) return;

    try {
      final settings = getIt<TorBoxSettingsRepository>();
      final downloadDirPath = settings.audiobookFolder;
      if (downloadDirPath == null || downloadDirPath.isEmpty) return;

      final dir = io.Directory(downloadDirPath);
      if (!await dir.exists()) return;

      await for (final entity in dir.list()) {
        if (entity is io.Directory) {
          final progressFile = io.File(p.join(entity.path, 'progress.json'));
          if (!await progressFile.exists()) continue;

          try {
            final content = await progressFile.readAsString();
            final legacyData = jsonDecode(content) as Map<String, dynamic>;
            final bookId = legacyData['bookId'] as String?;
            final jsonProgress = legacyData['progress'] as List<dynamic>?;
            if (bookId == null || jsonProgress == null || jsonProgress.isEmpty) continue;

            await restoreProgressFromLocalFolder(bookId, entity.path);
            await restoreBookmarksFromLocalFolder(bookId, entity.path);
            print('[AudiobookRepository] Restored legacy progress from ${progressFile.path}');
          } catch (e) {
            print('[AudiobookRepository] Error restoring legacy progress from ${progressFile.path}: $e');
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Error scanning for legacy progress files: $e');
    }
  }

  Future<String?> _findLocalFolderForBookId(String bookId) async {
    if (bookId.startsWith('local:')) {
      final path = bookId.substring(6);
      if (await io.Directory(path).exists()) {
        return path;
      }
      String parsedPath = path;
      if (parsedPath.startsWith('file://')) {
        try {
          parsedPath = Uri.parse(parsedPath).toFilePath();
        } catch (_) {}
      }
      if (parsedPath.contains('%')) {
        try {
          parsedPath = Uri.decodeComponent(parsedPath);
        } catch (_) {}
      }
      if (await io.Directory(parsedPath).exists()) {
        return parsedPath;
      }
      return null;
    }

    try {
      final settings = getIt<TorBoxSettingsRepository>();
      final downloadDirPath = settings.audiobookFolder;
      if (downloadDirPath == null || downloadDirPath.isEmpty) return null;
      
      final dir = io.Directory(downloadDirPath);
      if (!await dir.exists()) return null;
      
      final normalizedId = normalizeBookId(bookId);
      
      await for (final entity in dir.list()) {
        if (entity is io.Directory) {
          final metaFile = io.File(p.join(entity.path, 'metadata.json'));
          if (await metaFile.exists()) {
            try {
              final content = await metaFile.readAsString();
              final data = jsonDecode(content) as Map<String, dynamic>;
              final fileBookId = data['bookId'] as String?;
              if (fileBookId != null && normalizeBookId(fileBookId) == normalizedId) {
                return entity.path;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getOrCreateLocalBookDirectoryForBackup(String bookId) async {
    final existing = await getLocalBookDirectoryForBackup(bookId);
    if (existing != null) return existing;

    if (bookId.startsWith('local:')) return null;

    try {
      final settings = getIt<TorBoxSettingsRepository>();
      final downloadDirPath = settings.audiobookFolder;
      final cached = await _db.getAudiobookMetadata(normalizeBookId(bookId));
      if (downloadDirPath != null && downloadDirPath.isNotEmpty && cached != null) {
        final sanitizedTitle = cached.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
        final bookDir = io.Directory(p.join(downloadDirPath, sanitizedTitle));
        if (!await bookDir.exists()) {
          await bookDir.create(recursive: true);
        }
        
        final metaFile = io.File(p.join(bookDir.path, 'metadata.json'));
        if (!await metaFile.exists()) {
          final chapters = await getBookChapters(bookId);
          final Map<String, dynamic> metaMap = {
            'bookId': bookId,
            'title': cached.title,
            'author': cached.author,
            'description': cached.description,
            'narrator': cached.narrator,
            'artworkUrl': cached.artworkUrl,
            'totalChapters': cached.totalChapters,
            'language': cached.language,
            'genre': cached.genre,
            'chapters': chapters.map((ch) => {
              'id': ch.id,
              'title': ch.title,
              'chapterNumber': ch.chapterNumber,
              'startTimeMillis': ch.startTimeMillis,
              'durationMillis': ch.durationMillis,
              'streamUrl': ch.streamUrl,
            }).toList(),
          };
          await metaFile.writeAsString(jsonEncode(metaMap));
        }

        if (cached.artworkUrl != null && cached.artworkUrl!.isNotEmpty) {
          final coverFile = io.File(p.join(bookDir.path, 'cover.jpg'));
          if (!await coverFile.exists()) {
            if (cached.artworkUrl!.startsWith('/') || cached.artworkUrl!.startsWith('file://')) {
              final srcPath = cached.artworkUrl!.startsWith('file://') 
                  ? Uri.parse(cached.artworkUrl!).toFilePath() 
                  : cached.artworkUrl!;
              final srcFile = io.File(srcPath);
              if (await srcFile.exists()) {
                await srcFile.copy(coverFile.path);
              }
            } else {
              try {
                final client = io.HttpClient();
                final request = await client.getUrl(Uri.parse(cached.artworkUrl!));
                final response = await request.close();
                if (response.statusCode == 200) {
                  final bytes = await response.expand((b) => b).toList();
                  await coverFile.writeAsBytes(bytes);
                }
              } catch (e) {
                print('[AudiobookRepository] Error downloading cover image for backup: $e');
              }
            }
          }
        }
        return bookDir.path;
      }
    } catch (e) {
      print('[AudiobookRepository] Error in getOrCreateLocalBookDirectoryForBackup: $e');
    }
    return null;
  }

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
    
    final matchedPath = await _findLocalFolderForBookId(bookId);
    if (matchedPath != null) {
      return matchedPath;
    }
    
    try {
      final settings = getIt<TorBoxSettingsRepository>();
      final downloadDirPath = settings.audiobookFolder;
      final cached = await _db.getAudiobookMetadata(normalizeBookId(bookId));
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
  /// Writes into the unified progress.json (primary) and DB (secondary).
  Future<void> restoreProgressFromLocalFolder(String bookId, String folderPath) async {
    try {
      final progressFile = io.File(p.join(folderPath, 'progress.json'));
      if (!await progressFile.exists()) return;

      final content = await progressFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Determine bookId from the file if not provided
      final resolvedBookId = bookId.isNotEmpty ? bookId : (data['bookId'] as String? ?? '');
      if (resolvedBookId.isEmpty) return;

      // Restore EPUB reading progress if present
      final epubProg = data['epubProgress'] as Map<String, dynamic>?;
      if (epubProg != null) {
        final prefs = await SharedPreferences.getInstance();
        if (epubProg.containsKey('currentChapter')) {
          await prefs.setInt('epub_chapter_$resolvedBookId', epubProg['currentChapter'] as int);
        }
        if (epubProg.containsKey('scrollOffset')) {
          await prefs.setDouble('epub_scroll_$resolvedBookId', (epubProg['scrollOffset'] as num).toDouble());
        }
        if (epubProg.containsKey('fontSize')) {
          await prefs.setDouble('epub_fontsize_$resolvedBookId', (epubProg['fontSize'] as num).toDouble());
        }
        if (epubProg.containsKey('totalChapters')) {
          await prefs.setInt('epub_total_chapters_$resolvedBookId', epubProg['totalChapters'] as int);
        }
        if (epubProg.containsKey('pagesRead')) {
          await prefs.setInt('epub_pages_read_$resolvedBookId', epubProg['pagesRead'] as int);
        }
        if (epubProg.containsKey('totalPages')) {
          await prefs.setInt('epub_total_pages_$resolvedBookId', epubProg['totalPages'] as int);
        }
        if (epubProg.containsKey('progress')) {
          await prefs.setDouble('epub_progress_$resolvedBookId', (epubProg['progress'] as num).toDouble());
        }

        // Also persist epubProgress in unified progress.json
        try {
          final progressData = await _loadProgressData();
          final books = progressData['books'] as Map<String, dynamic>;
          final normId = normalizeBookId(resolvedBookId);
          final bookObj = books.putIfAbsent(normId, () => <String, dynamic>{}) as Map<String, dynamic>;
          bookObj['epubProgress'] = {
            'currentChapter': epubProg['currentChapter'],
            'totalChapters': epubProg['totalChapters'],
            'scrollOffset': epubProg['scrollOffset'],
            'pagesRead': epubProg['pagesRead'],
            'totalPages': epubProg['totalPages'],
            'progress': epubProg['progress'],
            'fontSize': epubProg['fontSize'],
            'lastReadAt': DateTime.now().toIso8601String(),
          };
          await _flushProgressData();
        } catch (_) {}
      }

      // Restore listening progress
      final jsonProgress = data['progress'] as List<dynamic>?;
      if (jsonProgress != null) {
        final progressData = await _loadProgressData();
        final books = progressData['books'] as Map<String, dynamic>;
        final normId = normalizeBookId(resolvedBookId);
        final bookObj = books.putIfAbsent(normId, () => <String, dynamic>{}) as Map<String, dynamic>;
        final chapters = bookObj.putIfAbsent('chapters', () => <dynamic>[]) as List<dynamic>;

        for (final entry in jsonProgress) {
          try {
            final map = entry as Map<String, dynamic>;
            final chIdx = map['chapterIndex'] as int;
            final lastListenedStr = map['lastListenedAt'] as String? ?? DateTime.now().toIso8601String();
            final localLastListened = DateTime.parse(lastListenedStr);

            final existingIdx = chapters.indexWhere(
              (c) => (c as Map<String, dynamic>)['chapterIndex'] == chIdx,
            );
            final entryMap = {
              'chapterIndex': chIdx,
              'positionMillis': map['positionMillis'] as int? ?? 0,
              'durationMillis': map['durationMillis'] as int? ?? 0,
              'isCompleted': map['isCompleted'] as bool? ?? false,
              'lastListenedAt': lastListenedStr,
              'originalBookId': resolvedBookId,
            };
            if (existingIdx >= 0) {
              chapters[existingIdx] = entryMap;
            } else {
              chapters.add(entryMap);
            }

            // Sync to DB (secondary)
            final existing = await _db.getAudiobookProgress(resolvedBookId, chIdx);
            if (existing == null || existing.lastListenedAt.isBefore(localLastListened)) {
              await _db.saveAudiobookProgress(AudiobookProgressCompanion.insert(
                bookId: resolvedBookId,
                chapterIndex: chIdx,
                positionMillis: Value(map['positionMillis'] as int? ?? 0),
                durationMillis: Value(map['durationMillis'] as int? ?? 0),
                lastListenedAt: localLastListened,
                isCompleted: Value(map['isCompleted'] as bool? ?? false),
              ));
            }
          } catch (e) {
            print('[AudiobookRepository] Error restoring single chapter progress entry: $e');
          }
        }
        await _flushProgressData();
        print('[AudiobookRepository] Restored progress from ${progressFile.path}');
      }
    } catch (e) {
      print('[AudiobookRepository] Error restoring progress from local folder: $e');
    }
  }

  /// Save listening progress for a specific chapter.
  /// Writes to unified progress.json (primary source), per-book progress.json
  /// (local folder backup), and DB (secondary).
  Future<void> saveProgress({
    required String bookId,
    required int chapterIndex,
    required int positionMillis,
    required int durationMillis,
    bool isCompleted = false,
  }) async {
    // 1. Write to unified progress.json (primary source)
    int completed = 0;
    int maxPos = 0;
    int totalCh = 0;
    int totalDuration = 0;
    List<dynamic>? chapters;
    String? cachedTitle;
    String? cachedAuthor;
    double pct = 0.0;
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books.putIfAbsent(normId, () => <String, dynamic>{}) as Map<String, dynamic>;
      chapters = bookObj.putIfAbsent('chapters', () => <dynamic>[]) as List<dynamic>;

      final existingIdx = chapters.indexWhere(
        (c) => (c as Map<String, dynamic>)['chapterIndex'] == chapterIndex,
      );
      final entry = {
        'chapterIndex': chapterIndex,
        'positionMillis': positionMillis,
        'durationMillis': durationMillis,
        'isCompleted': isCompleted,
        'lastListenedAt': DateTime.now().toIso8601String(),
        'originalBookId': bookId,
      };
      if (existingIdx >= 0) {
        chapters[existingIdx] = entry;
      } else {
        chapters.add(entry);
      }

      // Recompute book-level summary using time-based progress
      int totalListened = 0;
      for (final ch in chapters) {
        final chMap = ch as Map<String, dynamic>;
        totalListened += (chMap['positionMillis'] as int?) ?? 0;
        totalDuration += (chMap['durationMillis'] as int?) ?? 0;
        final pos = (chMap['positionMillis'] as int?) ?? 0;
        if (pos > maxPos) maxPos = pos;
        if (chMap['isCompleted'] == true) completed++;
      }

      final cachedMeta = await getCachedMetadata(normId);
      totalCh = cachedMeta?.totalChapters ?? 0;
      // If metadata doesn't have total chapters, estimate from max chapter index
      if (totalCh <= 0 && chapters.isNotEmpty) {
        int maxIdx = 0;
        for (final ch in chapters) {
          final idx = (ch as Map<String, dynamic>)['chapterIndex'] as int? ?? 0;
          if (idx > maxIdx) maxIdx = idx;
        }
        totalCh = maxIdx + 1;
      }
      cachedTitle = cachedMeta?.title;
      cachedAuthor = cachedMeta?.author;
      pct = totalCh > 0 ? (completed / totalCh).clamp(0.0, 1.0) : 0.0;

      bookObj['listenedMillis'] = maxPos;
      bookObj['totalDurationMillis'] = totalDuration;
      bookObj['completedChapters'] = completed;
      bookObj['totalChapters'] = totalCh;
      bookObj['lastListenedAt'] = DateTime.now().toIso8601String();
      bookObj['progressPercent'] = pct;
      bookObj['originalBookId'] = bookId;
      if (cachedMeta != null) {
        bookObj['title'] = cachedMeta.title;
        bookObj['author'] = cachedMeta.author ?? 'Unknown Author';
        bookObj['artworkUrl'] = cachedMeta.artworkUrl;
      }

      await _flushProgressData(debounced: true);
    } catch (e) {
      print('[AudiobookRepository] Error saving progress to progress.json: $e');
    }

    // 2. Backup to per-book progress.json in local folder if available
    try {
      final dirPath = await getOrCreateLocalBookDirectoryForBackup(bookId);
      if (dirPath != null && chapters != null) {
        final List<Map<String, dynamic>> jsonList = chapters.map((ch) {
          final chMap = ch as Map<String, dynamic>;
          return Map<String, dynamic>.from(chMap)..remove('originalBookId');
        }).cast<Map<String, dynamic>>().toList();
        
        final progressFile = io.File(p.join(dirPath, 'progress.json'));
        final backupData = {
          'bookId': bookId,
          'title': cachedTitle ?? 'Audiobook',
          'author': cachedAuthor ?? 'Unknown Author',
          'maxPositionMillis': maxPos,
          'totalDurationMillis': totalDuration,
          'completedChapters': completed,
          'totalChapters': totalCh,
          'lastListenedAt': DateTime.now().toIso8601String(),
          'progressPercent': pct,
          'progress': jsonList,
        };
        await progressFile.writeAsString(jsonEncode(backupData));
        print('[AudiobookRepository] Backed up progress to ${progressFile.path}');
      }
    } catch (e) {
      print('[AudiobookRepository] Error backing up progress to local folder: $e');
    }

    // 3. Sync to DB (secondary / backward-compatibility)
    await _db.saveAudiobookProgress(AudiobookProgressCompanion.insert(
      bookId: bookId,
      chapterIndex: chapterIndex,
      positionMillis: Value(positionMillis),
      durationMillis: Value(durationMillis),
      lastListenedAt: DateTime.now(),
      isCompleted: Value(isCompleted),
    ));
  }

  /// Get progress for a specific book's chapter.
  /// Reads from progress.json (primary), falls back to DB.
  Future<DbAudiobookProgress?> getChapterProgress(String bookId, int chapterIndex) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books[normId] as Map<String, dynamic>?;
      final chaptersJson = bookObj?['chapters'] as List<dynamic>?;
      if (chaptersJson != null) {
        for (final ch in chaptersJson) {
          final chMap = ch as Map<String, dynamic>;
          if ((chMap['chapterIndex'] as int?) == chapterIndex) {
            final lastListenedStr = chMap['lastListenedAt'] as String?;
            return DbAudiobookProgress(
              id: 0,
              bookId: bookId,
              chapterIndex: chapterIndex,
              positionMillis: chMap['positionMillis'] as int? ?? 0,
              durationMillis: chMap['durationMillis'] as int? ?? 0,
              lastListenedAt: DateTime.tryParse(lastListenedStr ?? '') ?? DateTime(2000),
              isCompleted: chMap['isCompleted'] as bool? ?? false,
            );
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Error reading chapter progress from progress.json: $e');
    }
    return _db.getAudiobookProgress(bookId, chapterIndex);
  }

  /// Get the latest progress for a book (most recently listened chapter).
  /// Reads from progress.json (primary), falls back to DB.
  Future<DbAudiobookProgress?> getLatestBookProgress(String bookId) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books[normId] as Map<String, dynamic>?;
      final chaptersJson = bookObj?['chapters'] as List<dynamic>?;
      if (chaptersJson != null && chaptersJson.isNotEmpty) {
        DbAudiobookProgress? latest;
        for (final ch in chaptersJson) {
          final chMap = ch as Map<String, dynamic>;
          final lastListenedStr = chMap['lastListenedAt'] as String?;
          final dt = DateTime.tryParse(lastListenedStr ?? '') ?? DateTime(2000);
          if (latest == null || dt.isAfter(latest.lastListenedAt)) {
            latest = DbAudiobookProgress(
              id: 0,
              bookId: bookId,
              chapterIndex: chMap['chapterIndex'] as int? ?? 0,
              positionMillis: chMap['positionMillis'] as int? ?? 0,
              durationMillis: chMap['durationMillis'] as int? ?? 0,
              lastListenedAt: dt,
              isCompleted: chMap['isCompleted'] as bool? ?? false,
            );
          }
        }
        if (latest != null) return latest;
      }
    } catch (e) {
      print('[AudiobookRepository] Error reading latest progress from progress.json: $e');
    }
    return _db.getLatestAudiobookProgress(bookId);
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
  /// Reads from progress.json (primary), falls back to DB.
  Future<List<DbAudiobookProgress>> getBookChapterProgress(String bookId) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books[normId] as Map<String, dynamic>?;
      final chaptersJson = bookObj?['chapters'] as List<dynamic>?;

      if (chaptersJson != null && chaptersJson.isNotEmpty) {
        return chaptersJson.map((ch) {
          final chMap = ch as Map<String, dynamic>;
          final lastListenedStr = chMap['lastListenedAt'] as String?;
          return DbAudiobookProgress(
            id: 0,
            bookId: bookId,
            chapterIndex: chMap['chapterIndex'] as int? ?? 0,
            positionMillis: chMap['positionMillis'] as int? ?? 0,
            durationMillis: chMap['durationMillis'] as int? ?? 0,
            lastListenedAt: DateTime.tryParse(lastListenedStr ?? '') ?? DateTime(2000),
            isCompleted: chMap['isCompleted'] as bool? ?? false,
          );
        }).toList()
          ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
      }
    } catch (e) {
      print('[AudiobookRepository] Error reading book chapter progress from progress.json: $e');
    }
    return _db.getBookChapterProgress(bookId);
  }

  /// Get all chapter progress entries across all books (used for stats).
  Future<List<DbAudiobookProgress>> getAllProgress() async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final allProgress = <DbAudiobookProgress>[];
      for (final entry in books.entries) {
        final bookId = entry.key;
        final bookObj = entry.value as Map<String, dynamic>;
        final chaptersJson = bookObj['chapters'] as List<dynamic>?;
        if (chaptersJson != null) {
          for (final ch in chaptersJson) {
            final chMap = ch as Map<String, dynamic>;
            final lastListenedStr = chMap['lastListenedAt'] as String?;
            allProgress.add(DbAudiobookProgress(
              id: 0,
              bookId: bookId,
              chapterIndex: chMap['chapterIndex'] as int? ?? 0,
              positionMillis: chMap['positionMillis'] as int? ?? 0,
              durationMillis: chMap['durationMillis'] as int? ?? 0,
              lastListenedAt: DateTime.tryParse(lastListenedStr ?? '') ?? DateTime(2000),
              isCompleted: chMap['isCompleted'] as bool? ?? false,
            ));
          }
        }
      }
      if (allProgress.isNotEmpty) return allProgress;
    } catch (e) {
      print('[AudiobookRepository] Error reading all progress: $e');
    }
    return _db.getAllAudiobookProgress();
  }

  /// Clear all progress for a book.
  Future<void> clearBookProgress(String bookId) async {
    // Remove from progress.json (primary)
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      books.remove(normId);
      await _flushProgressData();
    } catch (e) {
      print('[AudiobookRepository] Error clearing progress from progress.json: $e');
    }

    await _db.clearAudiobookProgress(bookId);

    // Also remove legacy per-book progress.json
    try {
      final localDir = await getLocalBookDirectoryForBackup(bookId);
      if (localDir != null) {
        final progressFile = io.File(p.join(localDir, 'progress.json'));
        if (await progressFile.exists()) {
          await progressFile.delete();
          print('[AudiobookRepository] Deleted local progress file: ${progressFile.path}');
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Error deleting local progress file: $e');
    }
  }

  /// Clear ALL audiobook data: progress history, metadata cache, dismissed list, goals.
  Future<void> clearAllAudiobookData() async {
    // Clear progress.json (primary)
    try {
      _progressData = {
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'books': <String, dynamic>{},
      };
      await _flushProgressData();
    } catch (e) {
      print('[AudiobookRepository] Error clearing progress.json: $e');
    }

    await _db.clearAllAudiobookProgress();
    await _db.clearAllAudiobookMetadataCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('goal_daily_min');
    await prefs.remove('goal_weekly_min');
  }

  /// Clear metadata cache for a book.
  Future<void> clearBookMetadataCache(String bookId) {
    return _db.deleteAudiobookMetadata(normalizeBookId(bookId));
  }

  /// Get EPUB reading progress from the unified progress.json.
  Future<Map<String, dynamic>?> getEpubProgress(String bookId) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books[normId] as Map<String, dynamic>?;
      return bookObj?['epubProgress'] as Map<String, dynamic>?;
    } catch (e) {
      print('[AudiobookRepository] Error reading epub progress from progress.json: $e');
    }
    return null;
  }

  /// Save EPUB reading progress to the unified progress.json.
  Future<void> saveEpubProgress(String bookId, Map<String, dynamic> epubProgress) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books.putIfAbsent(normId, () => <String, dynamic>{}) as Map<String, dynamic>;
      epubProgress['lastReadAt'] = DateTime.now().toIso8601String();
      bookObj['epubProgress'] = epubProgress;
      await _flushProgressData();
    } catch (e) {
      print('[AudiobookRepository] Error saving epub progress to progress.json: $e');
    }
  }

  /// Get book-level progress summary (completedChapters, totalChapters, progressPercent)
  /// from the unified progress.json. Returns null if no progress exists for this book.
  Future<Map<String, dynamic>?> getBookProgressSummary(String bookId) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books[normId] as Map<String, dynamic>?;
      if (bookObj == null) return null;

      final epubProgress = bookObj['epubProgress'] as Map<String, dynamic>?;
      final epubPercent = (epubProgress?['progress'] as num?)?.toDouble() ?? 0.0;
      final lastReadStr = epubProgress?['lastReadAt'] as String?;
      final lastRead = lastReadStr != null ? DateTime.tryParse(lastReadStr) : null;

      final double audioPercent = (bookObj['progressPercent'] as num?)?.toDouble() ?? 0.0;
      final lastListenedStr = bookObj['lastListenedAt'] as String?;
      final lastListened = lastListenedStr != null ? DateTime.tryParse(lastListenedStr) : null;

      // Determine which one is more recent
      bool useEpub = false;
      if (lastRead != null && lastListened != null) {
        useEpub = lastRead.isAfter(lastListened);
      } else if (lastRead != null) {
        useEpub = true;
      }

      return {
        'completedChapters': bookObj['completedChapters'] ?? 0,
        'totalChapters': bookObj['totalChapters'] ?? 0,
        'progressPercent': useEpub ? epubPercent : audioPercent,
        'listenedMillis': bookObj['listenedMillis'] ?? 0,
        'lastListenedAt': useEpub ? lastReadStr : lastListenedStr,
        'isEpub': useEpub,
      };
    } catch (e) {
      print('[AudiobookRepository] Error reading book progress summary: $e');
    }
    return null;
  }

  /// Move a loose local audio file into its own subfolder.
  /// Creates a subfolder named after the book title and moves the file there.
  Future<void> _organizeLocalFile(AudiobookResult book, String filePath, String title) async {
    final settings = getIt<TorBoxSettingsRepository>();
    final rootFolder = settings.audiobookFolder;
    if (rootFolder == null || rootFolder.isEmpty) return;

    final srcFile = io.File(filePath);
    if (!await srcFile.exists()) return;

    // Only organize files that are directly in the root folder
    if (srcFile.parent.path != rootFolder) return;

    // Create subfolder named after the book title
    final folderName = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (folderName.isEmpty) return;

    final bookDir = io.Directory(p.join(rootFolder, folderName));
    if (await bookDir.exists()) {
      // Folder already exists — just move the file in
      final destPath = p.join(bookDir.path, srcFile.path.split('/').last);
      if (await io.File(destPath).exists()) return;
      await srcFile.rename(destPath);
    } else {
      await bookDir.create();
      await srcFile.rename(p.join(bookDir.path, srcFile.path.split('/').last));
    }

    print('[AudiobookRepository] Organized loose file into: ${bookDir.path}');
  }

  // ─── Metadata Cache ────────────────────────────────────────────

  /// Save audiobook metadata to local cache.
  Future<void> cacheBookMetadata(AudiobookResult book, {bool writeLocalBackup = true, List<AudiobookChapter>? chapters}) async {
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
      // 1. Keep richer description (decode JSON_EXT: wrapper first)
      String existingDescription = existing.description ?? '';
      if (existingDescription.startsWith('JSON_EXT:')) {
        try {
          final rawJson = existingDescription.substring('JSON_EXT:'.length);
          final data = jsonDecode(rawJson) as Map<String, dynamic>;
          existingDescription = data['description'] as String? ?? '';
        } catch (_) {
          existingDescription = '';
        }
      }
      if (!isPlaceholderDescription(existingDescription)) {
        if (isPlaceholderDescription(description)) {
          description = existingDescription;
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

    final Map<String, dynamic> extendedDesc = {
      'description': description,
      'releaseDate': book.releaseDate ?? (existing != null ? _parseExtendedField(existing.description, 'releaseDate') : null),
      'publisher': book.publisher ?? (existing != null ? _parseExtendedField(existing.description, 'publisher') : null),
      'previewUrl': book.previewUrl ?? (existing != null ? _parseExtendedField(existing.description, 'previewUrl') : null),
      'durationMillis': book.durationMillis ?? (existing != null ? _parseExtendedField(existing.description, 'durationMillis') : null),
      'rating': book.rating ?? (existing != null ? _parseExtendedField(existing.description, 'rating') : null),
      'ratingCount': book.ratingCount ?? (existing != null ? _parseExtendedField(existing.description, 'ratingCount') : null),
    };
    final dbDescription = 'JSON_EXT:' + jsonEncode(extendedDesc);

    await _db.saveAudiobookMetadataEntry(AudiobookMetadataCacheCompanion.insert(
      bookId: normalizedId,
      title: title,
      author: Value(author),
      narrator: Value(narrator),
      artworkUrl: Value(artworkUrl),
      description: Value(dbDescription),
      totalChapters: Value(totalChapters),
      language: Value(language),
      genre: Value(genre),
      lastUpdated: DateTime.now(),
    ));

    // Try to update local metadata.json if the backup directory exists
    if (writeLocalBackup) {
      try {
        final localDir = await getLocalBookDirectoryForBackup(book.id);
        if (localDir != null) {
          final metaFile = io.File(p.join(localDir, 'metadata.json'));
          
          Map<String, dynamic> metaMap = {};
          List<Map<String, dynamic>> finalChaptersList = [];
          
          if (await metaFile.exists()) {
            try {
              final content = await metaFile.readAsString();
              metaMap = jsonDecode(content) as Map<String, dynamic>;
            } catch (_) {}
          }

          final List<dynamic>? existingChapters = metaMap['chapters'] as List<dynamic>?;
          
          if (chapters != null && chapters.isNotEmpty) {
            finalChaptersList = chapters.map((ch) => {
              'id': ch.id,
              'title': ch.title,
              'chapterNumber': ch.chapterNumber,
              'startTimeMillis': ch.startTimeMillis,
              'durationMillis': ch.durationMillis,
              'streamUrl': ch.streamUrl,
            }).toList();
          } else if (existingChapters != null && existingChapters.isNotEmpty) {
            // Chapters already cached on disk — skip re-parsing entirely
            finalChaptersList = existingChapters.map((ch) => Map<String, dynamic>.from(ch as Map)).toList();
          } else {
            // No cached chapters — parse and persist
            final parsed = await getBookChapters(book.id);
            finalChaptersList = parsed.map((ch) => {
              'id': ch.id,
              'title': ch.title,
              'chapterNumber': ch.chapterNumber,
              'startTimeMillis': ch.startTimeMillis,
              'durationMillis': ch.durationMillis,
              'streamUrl': ch.streamUrl,
            }).toList();
          }

          metaMap['bookId'] = book.id;
          metaMap['title'] = title;
          metaMap['author'] = author;
          metaMap['description'] = dbDescription;
          if (narrator != null) metaMap['narrator'] = narrator;
          if (artworkUrl != null) metaMap['artworkUrl'] = artworkUrl;
          if (totalChapters != null && totalChapters > 0) metaMap['totalChapters'] = totalChapters;
          if (language != null) metaMap['language'] = language;
          if (genre != null) metaMap['genre'] = genre;
          metaMap['chapters'] = finalChaptersList;

          await metaFile.writeAsString(jsonEncode(metaMap));

          // Copy or download cover art to cover.jpg inside local folder
          if (artworkUrl != null && artworkUrl.isNotEmpty) {
            final coverFile = io.File(p.join(localDir, 'cover.jpg'));
            if (artworkUrl.startsWith('/') || artworkUrl.startsWith('file://')) {
              final srcPath = artworkUrl.startsWith('file://') 
                  ? Uri.parse(artworkUrl).toFilePath() 
                  : artworkUrl;
              final srcFile = io.File(srcPath);
              if (await srcFile.exists() && srcFile.path != coverFile.path) {
                await srcFile.copy(coverFile.path);
              }
            } else {
              try {
                final client = io.HttpClient();
                final request = await client.getUrl(Uri.parse(artworkUrl));
                final response = await request.close();
                if (response.statusCode == 200) {
                  final bytes = await response.expand((b) => b).toList();
                  await coverFile.writeAsBytes(bytes);
                }
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        print('[AudiobookRepository] Error updating local metadata file in cacheBookMetadata: $e');
      }
    }
  }

  /// Get cached metadata for a book.
  Future<DbAudiobookMetadataCache?> getCachedMetadata(String bookId) async {
    final dbResult = await _db.getAudiobookMetadata(normalizeBookId(bookId));
    if (dbResult != null) return dbResult;

    try {
      final folderPath = await _findLocalFolderForBookId(bookId);
      if (folderPath != null) {
        final metaFile = io.File(p.join(folderPath, 'metadata.json'));
        if (await metaFile.exists()) {
          final content = await metaFile.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          
          final coverNames = ['cover.jpg', 'cover.png', 'folder.jpg', 'folder.png', 'poster.jpg', 'poster.png', 'AlbumArt.jpg', 'AlbumArt.png', 'front.jpg', 'front.png'];
          String? artworkUrl = data['artworkUrl'] as String?;
          for (final name in coverNames) {
            final cf = io.File(p.join(folderPath, name));
            if (await cf.exists()) {
              artworkUrl = 'file://${cf.path}';
              break;
            }
          }
          
          final bookResult = AudiobookResult(
            id: bookId,
            title: data['title'] as String? ?? 'Audiobook',
            author: data['author'] as String? ?? 'Unknown Author',
            narrator: data['narrator'] as String?,
            artworkUrl: artworkUrl,
            description: data['description'] as String?,
            totalChapters: data['totalChapters'] as int?,
            language: data['language'] as String?,
            genre: data['genre'] as String?,
          );
          
          await cacheBookMetadata(bookResult, writeLocalBackup: false);
          return await _db.getAudiobookMetadata(normalizeBookId(bookId));
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Error restoring cached metadata from local folder: $e');
    }

    return null;
  }

  dynamic _parseExtendedField(String? dbDesc, String key) {
    if (dbDesc == null || !dbDesc.startsWith('JSON_EXT:')) return null;
    try {
      final rawJson = dbDesc.substring('JSON_EXT:'.length);
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      return data[key];
    } catch (_) {}
    return null;
  }

  /// Convert cached DB metadata back to an AudiobookResult.
  AudiobookResult metadataToResult(DbAudiobookMetadataCache meta) {
    String? description = meta.description;
    String? releaseDate;
    String? publisher;
    String? previewUrl;
    int? durationMillis;
    double? rating;
    int? ratingCount;

    if (meta.description != null && meta.description!.startsWith('JSON_EXT:')) {
      try {
        final rawJson = meta.description!.substring('JSON_EXT:'.length);
        final data = jsonDecode(rawJson) as Map<String, dynamic>;
        description = data['description'] as String?;
        releaseDate = data['releaseDate'] as String?;
        publisher = data['publisher'] as String?;
        previewUrl = data['previewUrl'] as String?;
        durationMillis = data['durationMillis'] as int?;
        rating = (data['rating'] as num?)?.toDouble();
        ratingCount = data['ratingCount'] as int?;
      } catch (_) {
        description = null;
      }
    }

    // Safety: ensure no raw JSON_EXT: prefix leaks to the UI
    if (description != null && description!.startsWith('JSON_EXT:')) {
      description = null;
    }

    return AudiobookResult(
      id: meta.bookId,
      title: meta.title,
      author: meta.author ?? 'Unknown Author',
      narrator: meta.narrator,
      artworkUrl: meta.artworkUrl,
      description: description,
      totalChapters: meta.totalChapters,
      language: meta.language,
      genre: meta.genre,
      releaseDate: releaseDate,
      publisher: publisher,
      previewUrl: previewUrl,
      durationMillis: durationMillis,
      rating: rating,
      ratingCount: ratingCount,
    );
  }

  /// Query online APIs (iTunes and Open Library in parallel) for book details.
  Future<Map<String, dynamic>?> _fetchOnlineMetadata(String title) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final results = await Future.wait([
      _fetchItunesMetadata(dio, title),
      _fetchOpenLibraryMetadata(dio, title),
    ]);
    return results.firstWhere((r) => r != null, orElse: () => null);
  }

  Future<Map<String, dynamic>?> _fetchItunesMetadata(Dio dio, String title) async {
    try {
      final res = await dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': title,
          'entity': 'audiobook',
          'limit': 1,
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
        if (items != null && items.isNotEmpty) {
          final item = items.first as Map<String, dynamic>;
          final author = item['artistName'] as String? ?? '';
          final description = item['description'] as String? ?? '';
          final artworkUrl100 = item['artworkUrl100'] as String?;
          final artworkUrl = artworkUrl100 != null 
              ? artworkUrl100.replaceAll('100x100bb', '600x600bb') 
              : null;
          
          String? narrator;
          if (author.toLowerCase().contains('narrated by')) {
            final parts = author.split(RegExp(r',?\s*narrated by\s*', caseSensitive: false));
            if (parts.length > 1) {
              narrator = parts[1].trim();
            }
          }

          return {
            'author': author,
            'narrator': narrator,
            'description': description,
            if (artworkUrl != null) 'artworkUrl': artworkUrl,
            'genre': item['primaryGenreName'] as String?,
            'releaseDate': item['releaseDate'] as String?,
            'publisher': item['copyright'] as String?,
            'previewUrl': item['previewUrl'] as String?,
            'durationMillis': item['trackTimeMillis'] as int?,
            'rating': (item['averageUserRating'] as num?)?.toDouble(),
            'ratingCount': item['userRatingCount'] as int?,
          };
        }
      }
    } catch (e) {
      print('[AudiobookRepository] iTunes online lookup failed: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOpenLibraryMetadata(Dio dio, String title) async {
    try {
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

  /// Helper to lookup a specific item on iTunes.
  Future<AudiobookResult?> _lookupItunes(String itemId) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get(
        'https://itunes.apple.com/lookup',
        queryParameters: {'id': itemId},
      );
      if (res.statusCode == 200 && res.data != null) {
        final Map<String, dynamic> data;
        if (res.data is String) {
          data = jsonDecode(res.data as String) as Map<String, dynamic>;
        } else {
          data = res.data as Map<String, dynamic>;
        }
        final items = data['results'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final item = items.first as Map<String, dynamic>;
          final title = item['collectionName'] as String? ?? item['trackName'] as String? ?? 'Unknown Title';
          final author = item['artistName'] as String? ?? 'Unknown Author';
          final description = item['description'] as String? ?? '';
          final artworkUrl100 = item['artworkUrl100'] as String?;
          final artworkUrl = artworkUrl100 != null 
              ? artworkUrl100.replaceAll('100x100bb', '600x600bb') 
              : null;
          
          String? narrator;
          if (author.toLowerCase().contains('narrated by')) {
            final parts = author.split(RegExp(r',?\s*narrated by\s*', caseSensitive: false));
            if (parts.length > 1) {
              narrator = parts[1].trim();
            }
          }

          return AudiobookResult(
            id: 'itunes_meta:$itemId',
            title: title,
            author: author,
            narrator: narrator,
            description: description,
            artworkUrl: artworkUrl,
            language: 'EN',
            genre: item['primaryGenreName'] as String?,
            releaseDate: item['releaseDate'] as String?,
            publisher: item['copyright'] as String?,
            previewUrl: item['previewUrl'] as String?,
            durationMillis: item['trackTimeMillis'] as int?,
            rating: (item['averageUserRating'] as num?)?.toDouble(),
            ratingCount: item['userRatingCount'] as int?,
          );
        }
      }
    } catch (e) {
      print('[AudiobookRepository] iTunes lookup failed for id $itemId: $e');
    }
    return null;
  }

  /// Fetch top-rated audiobooks by searching iTunes for popular/bestseller terms
  /// and sorting by weighted rating (rating × log(ratingCount)).
  Future<List<AudiobookResult>> fetchTopRated({int limit = 50}) async {
    final Set<String> seen = {};
    final List<AudiobookResult> all = [];

    for (final term in ['bestseller audiobook', 'top audiobook', 'popular audiobook']) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
        final res = await dio.get(
          'https://itunes.apple.com/search',
          queryParameters: {
            'term': term,
            'entity': 'audiobook',
            'limit': 50,
            'country': 'us',
            'lang': 'en_us',
          },
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data is String ? jsonDecode(res.data) : res.data;
          final items = data['results'] as List<dynamic>?;
          if (items != null) {
            for (final item in items) {
              final collectionId = item['collectionId'];
              final trackId = item['trackId'];
              final title = item['collectionName'] as String? ?? item['trackName'] as String? ?? '';
              if (title.isEmpty) continue;
              final dedupKey = collectionId ?? trackId ?? title;
              if (seen.contains(dedupKey.toString())) continue;
              seen.add(dedupKey.toString());

              final artworkUrl100 = item['artworkUrl100'] as String?;
              all.add(AudiobookResult(
                id: 'itunes_meta:${collectionId ?? trackId ?? title.hashCode}',
                title: title,
                author: item['artistName'] as String? ?? 'Unknown Author',
                artworkUrl: artworkUrl100?.replaceAll('100x100bb', '600x600bb'),
                genre: item['primaryGenreName'] as String?,
                durationMillis: item['trackTimeMillis'] as int?,
                rating: (item['averageUserRating'] as num?)?.toDouble(),
                ratingCount: item['userRatingCount'] as int?,
              ));
            }
          }
        }
      } catch (e) {
        print('[AudiobookRepository] Top-rated search failed for "$term": $e');
      }
    }

    // Sort by weighted rating (rating × log(ratingCount)), items without rating sink to bottom
    all.sort((a, b) {
      final aRating = a.rating ?? 0;
      final aCount = (a.ratingCount ?? 0).toDouble();
      final bRating = b.rating ?? 0;
      final bCount = (b.ratingCount ?? 0).toDouble();
      final aScore = (aRating > 0 && aCount > 0) ? aRating * _log10(aCount + 1) : 0;
      final bScore = (bRating > 0 && bCount > 0) ? bRating * _log10(bCount + 1) : 0;
      return bScore.compareTo(aScore);
    });

    return all.take(limit).toList();
  }

  double _log10(double x) => log(x) / log(10);

  /// Fetch audiobooks by a specific author from iTunes.
  /// Results with ratings are sorted first (trending/popular).
  Future<List<AudiobookResult>> fetchBooksByAuthor(String author, {int limit = 50}) async {
    if (author.isEmpty) return [];
    final Set<String> seen = {};
    final List<AudiobookResult> all = [];
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': author,
          'entity': 'audiobook',
          'limit': limit.clamp(1, 200),
          'country': 'us',
          'lang': 'en_us',
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        final items = data['results'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            final collectionId = item['collectionId'];
            final trackId = item['trackId'];
            final title = item['collectionName'] as String? ?? item['trackName'] as String? ?? '';
            if (title.isEmpty) continue;
            final dedupKey = collectionId ?? trackId ?? title;
            if (seen.contains(dedupKey.toString())) continue;
            seen.add(dedupKey.toString());

            // Skip the current book matching the title too closely
            final artworkUrl100 = item['artworkUrl100'] as String?;
            all.add(AudiobookResult(
              id: 'itunes_meta:${collectionId ?? trackId ?? title.hashCode}',
              title: title,
              author: item['artistName'] as String? ?? author,
              artworkUrl: artworkUrl100?.replaceAll('100x100bb', '600x600bb'),
              genre: item['primaryGenreName'] as String?,
              durationMillis: item['trackTimeMillis'] as int?,
              releaseDate: item['releaseDate'] as String?,
              rating: (item['averageUserRating'] as num?)?.toDouble(),
              ratingCount: item['userRatingCount'] as int?,
            ));
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Author search failed for "$author": $e');
    }

    // Sort: rated books first (by weighted rating), then unrated
    all.sort((a, b) {
      final aRating = (a.rating ?? 0) * ((a.ratingCount ?? 0) > 0 ? _log10((a.ratingCount! + 1).toDouble()) : 0);
      final bRating = (b.rating ?? 0) * ((b.ratingCount ?? 0) > 0 ? _log10((b.ratingCount! + 1).toDouble()) : 0);
      return bRating.compareTo(aRating);
    });

    return all;
  }

  /// Search iTunes catalog with the given query.
  /// Returns up to [limit] results (max 200 per iTunes API).
  /// Sanitize a query string for iTunes API search by removing problematic characters.
  String _sanitizeItunesQuery(String query) {
    return query
        .replaceAll(':', ' ')
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<List<AudiobookResult>> searchItunesCatalog(String query, {int limit = 50}) async {
    final List<AudiobookResult> results = [];
    final sanitized = _sanitizeItunesQuery(query);
    if (sanitized.isEmpty) return results;
    try {
      print('[AudiobookRepository] Searching iTunes catalog for "$sanitized"...');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': sanitized,
          'entity': 'audiobook',
          'limit': limit.clamp(1, 200),
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
          print('[AudiobookRepository] iTunes catalog returned ${items.length} items');
          for (final item in items) {
            final title = item['collectionName'] as String? ?? item['trackName'] as String? ?? 'Unknown Title';
            final author = item['artistName'] as String? ?? 'Unknown Author';
            final description = item['description'] as String? ?? '';
            final artworkUrl100 = item['artworkUrl100'] as String?;
            final artworkUrl = artworkUrl100 != null
                ? artworkUrl100.replaceAll('100x100bb', '600x600bb')
                : null;

            String? narrator;
            if (author.toLowerCase().contains('narrated by')) {
              final parts = author.split(RegExp(r',?\s*narrated by\s*', caseSensitive: false));
              if (parts.length > 1) {
                narrator = parts[1].trim();
              }
            }

            results.add(AudiobookResult(
              id: 'itunes_meta:${item['collectionId'] ?? item['trackId'] ?? title.hashCode}',
              title: title,
              author: author,
              narrator: narrator,
              description: description,
              artworkUrl: artworkUrl,
              language: 'EN',
              genre: item['primaryGenreName'] as String?,
              releaseDate: item['releaseDate'] as String?,
              publisher: item['copyright'] as String?,
              previewUrl: item['previewUrl'] as String?,
              durationMillis: item['trackTimeMillis'] as int?,
              rating: (item['averageUserRating'] as num?)?.toDouble(),
              ratingCount: item['userRatingCount'] as int?,
            ));
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] iTunes catalog search failed: $e');
    }
    return results;
  }

  /// Helper to search iTunes.
  Future<List<AudiobookResult>> _searchItunes(String query) async {
    final List<AudiobookResult> results = [];
    final sanitized = _sanitizeItunesQuery(query);
    if (sanitized.isEmpty) return results;
    try {
      print('[AudiobookRepository] Searching iTunes for "$sanitized"...');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': sanitized,
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
            
            String? narrator;
            if (author.toLowerCase().contains('narrated by')) {
              final parts = author.split(RegExp(r',?\s*narrated by\s*', caseSensitive: false));
              if (parts.length > 1) {
                narrator = parts[1].trim();
              }
            }

            results.add(AudiobookResult(
              id: 'itunes_meta:${item['collectionId'] ?? item['trackId'] ?? title.hashCode}',
              title: title,
              author: author,
              narrator: narrator,
              description: description,
              artworkUrl: artworkUrl,
              language: 'EN',
              genre: item['primaryGenreName'] as String?,
              releaseDate: item['releaseDate'] as String?,
              publisher: item['copyright'] as String?,
              previewUrl: item['previewUrl'] as String?,
              durationMillis: item['trackTimeMillis'] as int?,
              rating: (item['averageUserRating'] as num?)?.toDouble(),
              ratingCount: item['userRatingCount'] as int?,
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
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
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
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
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

  Future<List<AudiobookBookmark>> getBookmarks(String bookId) async {
    final rows = await (_db.select(_db.audiobookBookmarks)
      ..where((b) => b.bookId.equals(bookId))
      ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)])
    ).get();
    return rows.map((r) => AudiobookBookmark(
      id: r.id,
      bookId: r.bookId,
      chapterIndex: r.chapterIndex,
      positionMillis: r.positionMillis,
      label: r.label,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    )).toList();
  }

  Future<int> getBookmarkCount(String bookId) async {
    final count = await (_db.select(_db.audiobookBookmarks)
      ..where((b) => b.bookId.equals(bookId))
    ).get();
    return count.length;
  }

  Future<int> addBookmark(String bookId, int chapterIndex, int positionMillis, {String? label}) async {
    final id = await _db.into(_db.audiobookBookmarks).insert(AudiobookBookmarksCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      positionMillis: Value(positionMillis),
      label: Value(label),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    await _backupBookmarks(bookId);
    return id;
  }

  Future<void> deleteBookmark(int id) async {
    final bm = await (_db.select(_db.audiobookBookmarks)..where((b) => b.id.equals(id))).getSingleOrNull();
    await (_db.delete(_db.audiobookBookmarks)..where((b) => b.id.equals(id))).go();
    if (bm != null) await _backupBookmarks(bm.bookId);
  }

  Future<void> updateBookmarkLabel(int id, String label) async {
    await (_db.update(_db.audiobookBookmarks)..where((b) => b.id.equals(id))).write(
      AudiobookBookmarksCompanion(label: Value(label)),
    );
    final bm = await (_db.select(_db.audiobookBookmarks)..where((b) => b.id.equals(id))).getSingleOrNull();
    if (bm != null) await _backupBookmarks(bm.bookId);
  }

  Future<void> deleteAllBookmarks(String bookId) async {
    await (_db.delete(_db.audiobookBookmarks)..where((b) => b.bookId.equals(bookId))).go();
    await _backupBookmarks(bookId);
  }

  Future<void> _backupBookmarks(String bookId) async {
    try {
      final localDir = await getLocalBookDirectoryForBackup(bookId);
      if (localDir == null) return;
      final bookmarks = await getBookmarks(bookId);
      final data = bookmarks.map((b) => {
        'chapterIndex': b.chapterIndex,
        'positionMillis': b.positionMillis,
        'label': b.label,
        'createdAt': b.createdAt.millisecondsSinceEpoch,
      }).toList();
      final file = io.File(p.join(localDir, 'bookmarks.json'));
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('[AudiobookRepository] Error backing up bookmarks: $e');
    }
  }

  Future<void> restoreBookmarksFromLocalFolder(String bookId, String folderPath) async {
    try {
      final existing = await getBookmarks(bookId);
      if (existing.isNotEmpty) return;
      final file = io.File(p.join(folderPath, 'bookmarks.json'));
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final data = jsonDecode(content) as List<dynamic>;
      for (final item in data) {
        final map = item as Map<String, dynamic>;
        await _db.into(_db.audiobookBookmarks).insert(AudiobookBookmarksCompanion(
          bookId: Value(bookId),
          chapterIndex: Value(map['chapterIndex'] as int),
          positionMillis: Value(map['positionMillis'] as int),
          label: Value(map['label'] as String?),
          createdAt: Value(map['createdAt'] as int),
        ));
      }
    } catch (e) {
      print('[AudiobookRepository] Error restoring bookmarks: $e');
    }
  }

  /// Store the Hardcover read/edition mapping for a book so progress can
  /// be synced back automatically on pause/stop.
  Future<void> saveHardcoverMapping(String bookId, int userBookId, int? readId, int? editionId) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books.putIfAbsent(normId, () => <String, dynamic>{}) as Map<String, dynamic>;
      bookObj['hardcoverUserBookId'] = userBookId;
      bookObj['hardcoverReadId'] = readId;
      bookObj['hardcoverEditionId'] = editionId;
      await _flushProgressData(); // immediate write
    } catch (e) {
      print('[AudiobookRepository] Error saving Hardcover mapping: $e');
    }
  }

  /// Look up the saved Hardcover user_book_id for a given book.
  /// Returns null if no mapping exists.
  Future<int?> getHardcoverUserBookId(String bookId) async {
    try {
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final normId = normalizeBookId(bookId);
      final bookObj = books[normId] as Map<String, dynamic>?;
      return bookObj?['hardcoverUserBookId'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Sync current audiobook progress back to Hardcover.
  /// Reads chapter progress from the in-memory cache and pushes total
  /// seconds to Hardcover via its API.
  Future<void> syncHardcoverProgress(String bookId) async {
    try {
      final normId = normalizeBookId(bookId);
      final data = await _loadProgressData();
      final books = data['books'] as Map<String, dynamic>;
      final bookObj = books[normId] as Map<String, dynamic>?;
      if (bookObj == null) {
        print('[AudiobookRepository] syncHardcoverProgress: bookObj not found for normId=$normId');
        return;
      }

      final readId = bookObj['hardcoverReadId'] as int?;
      final editionId = bookObj['hardcoverEditionId'] as int?;
      if (readId == null || editionId == null) {
        print('[AudiobookRepository] syncHardcoverProgress: no mapping (readId=$readId editionId=$editionId)');
        return;
      }

      // Find the furthest VALID position across all chapters.
      // Entries where positionMillis exceeds durationMillis indicate
      // corrupted progress data (e.g. from earlier save bugs) and are skipped.
      int maxValidPos = 0;
      int bookTotalMs = 0;
      final chapters = bookObj['chapters'] as List<dynamic>?;
      print('[AudiobookRepository] syncHardcoverProgress: chapters count=${chapters?.length ?? 0}');
      if (chapters != null) {
        for (final ch in chapters) {
          final chMap = ch as Map<String, dynamic>;
          final pos = (chMap['positionMillis'] as int?) ?? 0;
          final dur = (chMap['durationMillis'] as int?) ?? 0;
          bookTotalMs += dur;
          final valid = pos > 0 && (dur <= 0 || pos <= dur);
          print('[AudiobookRepository] syncHardcoverProgress: ch=${chMap['chapterIndex']} pos=$pos dur=$dur valid=$valid');
          if (valid) {
            if (pos > maxValidPos) maxValidPos = pos;
          }
        }
      }

      int totalProgressMs = maxValidPos;
      print('[AudiobookRepository] syncHardcoverProgress: maxValidPos=$maxValidPos bookTotalMs=$bookTotalMs');
      if (totalProgressMs <= 0) {
        print('[AudiobookRepository] syncHardcoverProgress: totalProgressMs <= 0, skipping');
        return;
      }

      // Cap at 95% so Hardcover does not auto-mark as "read" (status 3).
      if (bookTotalMs > 0 && totalProgressMs >= bookTotalMs) {
        totalProgressMs = (bookTotalMs * 0.95).round();
        print('[AudiobookRepository] syncHardcoverProgress: capped to 95%: $totalProgressMs');
      }

      final settingsRepo = getIt<HardcoverSettingsRepository>();
      final apiKey = settingsRepo.apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        print('[AudiobookRepository] syncHardcoverProgress: no apiKey');
        return;
      }

      final hcService = HardcoverApiService();
      final progressSecs = (totalProgressMs / 1000).round();
      print('[AudiobookRepository] syncHardcoverProgress: sending progressSecs=$progressSecs (readId=$readId editionId=$editionId)');
      var success = await hcService.updateProgress(apiKey, readId, editionId, progressSecs);
      if (!success) {
        // The readId may be stale (e.g. setReadingStatus created a new
        // user_book_read elsewhere). Try refreshing the mapping and retrying.
        final userBookId = bookObj['hardcoverUserBookId'] as int?;
        if (userBookId != null) {
          final fresh = await hcService.fetchLatestUserBookRead(apiKey, userBookId);
          if (fresh != null && fresh.readId != readId) {
            bookObj['hardcoverReadId'] = fresh.readId;
            bookObj['hardcoverEditionId'] = fresh.editionId;
            await _flushProgressData(debounced: false);
            print('[AudiobookRepository] Recovered stale mapping: readId=$readId → ${fresh.readId}');
            success = await hcService.updateProgress(apiKey, fresh.readId, fresh.editionId ?? editionId, progressSecs);
            print('[AudiobookRepository] Retry after mapping refresh: success=$success');
          }
        }
      }
      print('[AudiobookRepository] syncHardcoverProgress: updateProgress success=$success');
      if (success) {
        print('[AudiobookRepository] Synced progress to Hardcover: ${progressSecs}s');
        // Refresh the mapping after every successful update to pick up any
        // changes that Hardcover may have made (e.g. auto-creating a new
        // user_book_read when status is set to "Currently Reading").
        final userBookId = bookObj['hardcoverUserBookId'] as int?;
        if (userBookId != null) {
          final fresh = await hcService.fetchLatestUserBookRead(apiKey, userBookId);
          if (fresh != null && fresh.readId != readId) {
            bookObj['hardcoverReadId'] = fresh.readId;
            bookObj['hardcoverEditionId'] = fresh.editionId;
            await _flushProgressData(debounced: false);
            print('[AudiobookRepository] Refreshed hardcover mapping: readId=${fresh.readId} editionId=${fresh.editionId}');
          }
        }
      }
    } catch (e) {
      print('[AudiobookRepository] Hardcover sync error: $e');
    }
  }
}
