import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:injectable/injectable.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../settings/data/torbox_settings_repository.dart';
import 'music_models.dart';
import 'scrapers/music_scraper.dart';
import 'scrapers/youtube_scraper.dart';
import 'scrapers/last_fm_scraper.dart';
import 'musicbrainz_service.dart';
import 'itunes_metadata_service.dart';
import 'deezer_service.dart';
import 'plugins/js_plugin.dart';
import 'plugins/eclipse_addon.dart';
import 'plugins/plugin_manager.dart';
import 'scrapers/js_plugin_scraper.dart';
import 'scrapers/eclipse_addon_scraper.dart';
import 'package:drift/drift.dart';
import 'package:isai/core/database/database.dart';
import 'lastfm_service.dart';


abstract class MusicRepository {
  Future<List<ItunesTrack>> searchItunes(String query, {int limit = 30});
  Future<List<ApibayResult>> searchTorrents(String query);
  Future<List<TorrentSearchResult>> searchAllTorrents(String query);
  Future<bool> addTorrent(String magnetLink);
  Future<List<TorBoxTorrent>> getLibrary();
  Future<int> getLibraryHash();
  Future<String?> getStreamUrl(int torrentId, int fileId);
  Future<bool> validateApiKey(String key);
  Future<List<String>> checkCached(List<String> hashes);
  Future<List<ItunesTrack>> getTopSongs({int limit = 30, String countryCode = 'us', int? genreId});
  Future<List<ItunesTrack>> getNewReleases({int limit = 30, String countryCode = 'us'});
  Future<List<ItunesTrack>> getYearlyHits(int year, {int limit = 30, String countryCode = 'us'});
  Future<List<ItunesTrack>> getArtistTopSongs(String artistName, {int limit = 50});
  Future<List<ItunesTrack>> getArtistAlbums(String artistName, {int limit = 50});
  Future<List<ItunesTrack>> getAlbumTracks(int collectionId);
  Future<List<ItunesTrack>> searchItunesAlbums(String query);
  Future<List<ItunesTrack>> searchItunesArtists(String query);
  Future<List<YouTubeResult>> searchYouTube(String query);
  Future<String?> getYouTubeStreamUrl(String videoId);
  Future<bool> addWebDownload(String url);
  Future<String?> getArtistImage(String artistName, {bool highRes = true, String? artistUrl});
  Future<List<ScraperResult>> searchFLAC(String query);
  Stream<ScraperResult> searchFLACStream(String query);
  Future<List<ItunesTrack>> getTopArtists();
  Future<void> recordPlayback(TorBoxFile file, ItunesMeta? meta, {String? artworkUrlLow, String? artworkUrlHigh, int? duration});
  Future<List<DbPlaybackHistory>> getRecentTracks();
  Stream<List<DbPlaybackHistory>> watchRecentTracks();
  Future<List<DbTrackMetadata>> getLikedSongs();
  Future<List<AppleMusicPlaylist>> getRegionalPlaylists({required String region, int limit = 25});
  Future<List<ItunesTrack>> getAppleMusicPlaylistTracks(String playlistUrl);
  Future<List<ItunesTrack>> getRecommendedTracks(String title, String artist, String category);
  
  // Followed Artists
  Future<ItunesArtist?> getArtistDetails(String artistName);
  Future<void> followArtist(ItunesArtist artist, String? artworkUrl);
  Future<void> unfollowArtist(int artistId);
  Stream<bool> isArtistFollowed(int artistId);
  Future<List<DbFollowedArtist>> getFollowedArtists();
  Stream<List<DbFollowedArtist>> watchFollowedArtists();

  // Last.fm specific
  Future<String?> getArtistBio(String artistName);
  Future<List<String>> getSimilarArtists(String artistName);

  // MusicBrainz specific
  Future<Map<String, dynamic>?> getArtistMetadata(String artistName);

  // Deezer specific
  Future<List<DeezerPlaylist>> getDeezerArtistPlaylists(String artistName);
  Future<List<String>> getDeezerRelatedArtists(String artistName);
  Future<List<ItunesTrack>> getDeezerArtistTopTracks(String artistName);
  Future<List<ItunesTrack>> getDeezerPlaylistTracks(String playlistId, {int index = 0, int limit = 50});
  Future<Map<String, dynamic>?> getDeezerArtistDetails(String artistName);
  Future<List<DeezerGenre>> getDeezerGenres();
  Future<List<DeezerPlaylist>> getDeezerGenrePlaylists(int genreId, {String? genreName});
  
  // Metadata Research
  Future<List<ItunesMeta>> searchDeezerMeta(String query);
  
  // Deezer Charts
  // New recommendation methods using Deezer API

  Future<List<ItunesTrack>> getBecauseYouListenedToRecommendations(String artistName, {int limit = 20});
  Future<List<ItunesTrack>> getRecommendationsBasedOnRecentHistory();
}

@LazySingleton(as: MusicRepository)
class MusicRepositoryImpl implements MusicRepository {
  final Dio _dio;
  final TorBoxSettingsRepository _settings;
  final ItunesMetadataService _itunesMeta;
  final LastFmScraper _lastFm;
  final AppDatabase _db;
  final MusicBrainzService _mb;
  final DeezerService _deezer;
  final LastFmService _lastFmService;
  final PluginManager _pluginManager;
  final _yt = YoutubeExplode();

  static const _torboxBase = 'https://api.torbox.app/v1/api';
  static const _itunesBase = 'https://itunes.apple.com';
  static const _apibayBase = 'https://apibay.org';

  late final List<MusicScraper> _scrapers;

  MusicRepositoryImpl(
    this._dio,
    this._settings,
    this._itunesMeta,
    this._lastFm,
    this._db,
    this._mb,
    this._deezer,
    this._lastFmService,
    this._pluginManager,
  ) {
    _scrapers = [
      YouTubeScraper(),
    ];
  }

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer ${_settings.apiKey}',
      };

  // ─── iTunes Search ──────────────────────────────────────────────────────────
  @override
  Future<List<ItunesTrack>> searchItunes(String query, {int limit = 30}) async {
    try {
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': query,
          'entity': 'song',
          'limit': limit,
          'media': 'music',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      final results = (data['results'] as List<dynamic>? ?? []);
      return results.map((r) => ItunesTrack.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[Music] iTunes search error: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> searchItunesAlbums(String query) async {
    try {
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': query,
          'entity': 'album',
          'limit': 30,
          'media': 'music',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      final results = (data['results'] as List<dynamic>? ?? []);
      return results.map((r) => ItunesTrack.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[Music] iTunes album search error: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> searchItunesArtists(String query) async {
    try {
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': query,
          'entity': 'musicArtist',
          'limit': 30,
          'media': 'music',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      final results = (data['results'] as List<dynamic>? ?? []);
      
      return results.map((json) {
        final artistId = (json['artistId'] as num?)?.toInt() ?? 0;
        return ItunesTrack(
          trackId: artistId,
          trackName: json['artistName'] as String? ?? 'Unknown Artist',
          artistName: json['artistName'] as String? ?? 'Unknown Artist',
          collectionName: '',
          artworkUrl: '', 
          artistViewUrl: json['artistViewUrl'] as String?,
        );
      }).toList();
    } catch (e) {
      print('[Music] searchItunesArtists error: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> getArtistTopSongs(String artistName, {int limit = 50}) async {
    try {
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': artistName,
          'entity': 'song',
          'attribute': 'artistTerm',
          'limit': limit,
          'media': 'music',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      dynamic data = response.data;
      if (data is String) data = jsonDecode(data);
      
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((r) => ItunesTrack.fromJson(r as Map<String, dynamic>))
          .toList();
          
      // Sort locally by releaseDate descending (newest first)
      results.sort((a, b) {
        if (a.releaseDate == null && b.releaseDate == null) return 0;
        if (a.releaseDate == null) return 1;
        if (b.releaseDate == null) return -1;
        return b.releaseDate!.compareTo(a.releaseDate!);
      });
      
      return results;
    } catch (e) {
      print('[Music] iTunes getArtistTopSongs error: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> getArtistAlbums(String artistName, {int limit = 50}) async {
    try {
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': artistName,
          'entity': 'album',
          'attribute': 'artistTerm',
          'limit': limit,
          'media': 'music',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      dynamic data = response.data;
      if (data is String) data = jsonDecode(data);
      
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((r) => ItunesTrack.fromJson(r as Map<String, dynamic>))
          .toList();
          
      // Sort locally by releaseDate descending (newest first)
      results.sort((a, b) {
        if (a.releaseDate == null && b.releaseDate == null) return 0;
        if (a.releaseDate == null) return 1;
        if (b.releaseDate == null) return -1;
        return b.releaseDate!.compareTo(a.releaseDate!);
      });
      
      return results;
    } catch (e) {
      print('[Music] iTunes getArtistAlbums error: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> getNewReleases({int limit = 30, String countryCode = 'us'}) async {
    try {
      // 1. Primary Source: Deezer Search-based New Releases (Usually very reliable)
      print('[MusicRepository] Fetching new releases via Deezer search');
      final deezerNew = await _deezer.searchNewReleases(limit: limit);
      if (deezerNew.isNotEmpty) {
        return deezerNew.map((t) {
           final album = t['album'] as Map<String, dynamic>?;
           return ItunesTrack(
             trackId: int.tryParse(t['id'].toString()) ?? 0,
             trackName: (t['title_short'] ?? t['title'] ?? 'Unknown') as String,
             artistName: (t['artist']?['name'] ?? 'Unknown Artist') as String,
             collectionName: (album?['title'] ?? 'Single') as String,
             artworkUrl: (album?['cover_big'] ?? album?['cover_medium'] ?? '') as String,
             trackTimeMillis: t['duration'] != null ? (t['duration'] as int) * 1000 : 0,
           );
        }).toList();
      }

      // 2. Fallback: iTunes top charts
      print('[MusicRepository] Falling back to iTunes RSS');
      final response = await _dio.get('https://itunes.apple.com/$countryCode/rss/top-songs/limit=$limit/json');
      dynamic data = response.data;
      if (data is String) data = jsonDecode(data);
      
      final List<dynamic> results = (data is Map && data['feed'] != null) ? (data['feed']['entry'] ?? []) : [];
      return results.map((e) => ItunesTrack.fromJson(e)).toList();
    } catch (e) {
      print('[MusicRepository] All new releases sources failed: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> getYearlyHits(int year, {int limit = 30, String countryCode = 'us'}) async {
    try {
      // For yearly hits, we use the search API with a query for the year or "Best of [Year]"
      // iTunes search doesn't have a direct "top of year" feed, so we search for year + country hits
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': '$year hits',
          'entity': 'song',
          'country': countryCode,
          'limit': limit,
          'media': 'music',
          'sort': 'popular',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      dynamic data = response.data;
      if (data is String) data = jsonDecode(data);
      final results = (data['results'] as List<dynamic>? ?? []);
      return results.map((r) => ItunesTrack.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[Music] Get yearly hits error: $e');
      return [];
    }
  }

  @override
  Future<String?> getArtistImage(String artistName, {bool highRes = true, String? artistUrl}) async {
    return _itunesMeta.fetchArtistImage(artistName, highRes: highRes, artistViewUrl: artistUrl);
  }

  @override
  Future<List<ItunesTrack>> getAlbumTracks(int collectionId) async {
    try {
      final response = await _dio.get(
        '$_itunesBase/lookup',
        queryParameters: {
          'id': collectionId,
          'entity': 'song',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      final results = (data['results'] as List<dynamic>? ?? []);
      
      // The first result is usually the album itself, we want the songs
      return results
          .where((r) => r['wrapperType'] == 'track')
          .map((r) => ItunesTrack.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[Music] getAlbumTracks error: $e');
      return [];
    }
  }

  // ─── Apibay Torrent Search ──────────────────────────────────────────────────
  @override
  Future<List<ApibayResult>> searchTorrents(String query) async {
    try {
      final cleanQuery = _refineQuery(query);
      
      final response = await _dio.get(
        'https://apibay.org/q.php',
        queryParameters: {'q': cleanQuery, 'cat': '0'}, 
        options: Options(headers: {'Accept': 'application/json'}),
      );
      
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      
      if (data is! List) return [];
      var results = data
          .map((r) => ApibayResult.fromJson(r as Map<String, dynamic>))
          .where((r) => r.infoHash != '0000000000000000000000000000000000000000' && r.name != 'No results returned')
          .toList();
          
      if (results.isEmpty) {
        final fallbackResponse = await _dio.get(
          'https://apibay.org/q.php',
          queryParameters: {'q': cleanQuery},
          options: Options(headers: {'Accept': 'application/json'}),
        );
        dynamic fallbackData = fallbackResponse.data;
        if (fallbackData is String) fallbackData = jsonDecode(fallbackData);
        if (fallbackData is List) {
          results = fallbackData
              .map((r) => ApibayResult.fromJson(r as Map<String, dynamic>))
              .where((r) => r.infoHash != '0000000000000000000000000000000000000000' && r.name != 'No results returned')
              .toList();
        }
      }
      
      results = results.where((r) => r.infoHash.isNotEmpty && r.seeders > 0).toList();
      results.sort((a, b) => b.seeders.compareTo(a.seeders));
      return results;
    } catch (e) {
      print('[Music] Torrent search error: $e');
      return [];
    }
  }

  // ─── Multi-Source Torrent Search ─────────────────────────────────────────────
  @override
  Future<List<TorrentSearchResult>> searchAllTorrents(String query) async {
    final results = <TorrentSearchResult>[];
    final refinedQuery = _refineQuery(query);
    print('[MusicRepository] searchAllTorrents: query="$query", refinedQuery="$refinedQuery"');
    
    final tasks = <Future<List<TorrentSearchResult>>>[
      searchTorrents(query).then((items) => items.map((r) => TorrentSearchResult.fromApibay(r)).toList()).catchError((_) => <TorrentSearchResult>[]),
      _searchBitSearch(refinedQuery).catchError((_) => <TorrentSearchResult>[]),
      _search1337x(refinedQuery).catchError((_) => <TorrentSearchResult>[]),
      _searchPirateBay(refinedQuery).catchError((_) => <TorrentSearchResult>[]),
      _searchRutracker(refinedQuery).catchError((_) => <TorrentSearchResult>[]),
      _searchNyaa(refinedQuery).catchError((_) => <TorrentSearchResult>[]),
    ];

    try {
      final allResults = await Future.wait(tasks).timeout(
        const Duration(seconds: 25),
        onTimeout: () => [],
      );
      
      for (final list in allResults) {
        results.addAll(list);
      }
      
      final validResults = results.where((r) => r.infoHash.isNotEmpty && r.seeders > 0).toList();
      
      final Map<String, TorrentSearchResult> uniqueMap = {};
      
      for (final r in validResults) {
        final hash = r.infoHash.toLowerCase();
        if (!uniqueMap.containsKey(hash) || r.seeders > uniqueMap[hash]!.seeders) {
          uniqueMap[hash] = r;
        }
      }
      
      final sortedResults = uniqueMap.values.toList()
        ..sort((a, b) => b.seeders.compareTo(a.seeders));
        
      return sortedResults;
    } catch (e) {
      print('[Music] searchAllTorrents critical error: $e');
      return [];
    }
  }

  // ─── BitSearch API ────────────────────────────────────────────────────────────
  Future<List<TorrentSearchResult>> _searchBitSearch(String query) async {
    try {
      final response = await _dio.get(
        'https://bitsearch.to/api/v1/search',
        queryParameters: {
          'q': query, 
          'category': 'audio',
          'sort': 'seeders',
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      if (data == null || data is! Map || data['success'] != true) return [];

      final results = data['results'] as List<dynamic>? ?? [];

      return results.map((r) {
        final map = r as Map<String, dynamic>;
        return TorrentSearchResult.fromBitsearch(map);
      }).toList();
    } catch (e) {
      print('[Music] BitSearch error: $e');
      return [];
    }
  }

  // ─── Rutracker Scraper (via Knaben Proxy) ────────────────────────────────────
  Future<List<TorrentSearchResult>> _searchRutracker(String query) async {
    try {
      final response = await _dio.get(
        'https://knaben.org/search/${Uri.encodeComponent(query)}',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final html = response.data.toString();
      final results = <TorrentSearchResult>[];
      final rowRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
      
      for (final match in rowRegex.allMatches(html)) {
        final rowHtml = match.group(1) ?? '';
        
        // Find the anchor that contains the magnet link to avoid metadata icons
        final magnetLinkRegex = RegExp(r'<a[^>]+href="(magnet:\?xt=[^"]+)"[^>]*>(.*?)</a>', dotAll: true, caseSensitive: false);
        final magnetLinkMatch = magnetLinkRegex.firstMatch(rowHtml);
        if (magnetLinkMatch == null) continue;
        
        final magnetLink = magnetLinkMatch.group(1) ?? '';
        final anchorContent = magnetLinkMatch.group(2) ?? '';
        
        // Extract title from the specific anchor's title attribute
        final titleAttrRegex = RegExp(r'title="([^"]+)"', caseSensitive: false);
        final titleAttrMatch = titleAttrRegex.firstMatch(magnetLinkMatch.group(0)!);
        
        var name = titleAttrMatch?.group(1)?.trim() ?? '';
        if (name.isEmpty || name == 'Download with magnet' || name == 'Copy info hash') {
           name = anchorContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        }
        if (name.isEmpty) name = 'Unknown Knaben Result';
        
        final tdRegex = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
        final tds = tdRegex.allMatches(rowHtml).map((m) => m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '').toList();
        
        int seeders = 0;
        String sizeStr = '0';
        
        if (tds.length >= 6) {
          sizeStr = tds[2];
          seeders = int.tryParse(tds[4]) ?? 0;
        }

        final infoHashRegex = RegExp(r'btih:([a-fA-F0-9]{40})', caseSensitive: false);
        final hashMatch = infoHashRegex.firstMatch(magnetLink);
        final infoHash = hashMatch?.group(1) ?? '';

        if (infoHash.isEmpty) continue;

        results.add(TorrentSearchResult(
          name: name,
          infoHash: infoHash.toLowerCase(),
          seeders: seeders,
          leechers: 0,
          size: _parseSize(sizeStr),
          source: name.toLowerCase().contains('rutracker') ? 'rutracker' : 'knaben',
          magnetLink: magnetLink,
        ));
      }

      if (results.isNotEmpty) {
        results.sort((a, b) {
          if (a.source == 'rutracker' && b.source != 'rutracker') return -1;
          if (b.source == 'rutracker' && a.source != 'rutracker') return 1;
          return b.seeders.compareTo(a.seeders);
        });
      }

      return results;
    } catch (e) {
      print('[Music] Rutracker/Knaben search error: $e');
      return [];
    }
  }

  // ─── 1337x Scraper ────────────────────────────────────────────────────────────
  Future<List<TorrentSearchResult>> _search1337x(String query) async {
    try {
      final cleanQuery = query.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), ' ');
      
      final response = await _dio.get(
        'https://1337x.to/search/$cleanQuery/1/',
        options: Options(
          headers: {
            'Accept': 'text/html',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      
      final html = response.data as String;
      final results = <TorrentSearchResult>[];
      
      // Parse table rows - 1337x uses a table structure
      final rowRegex = RegExp(
        r'<tr>.*?<a href="/torrent/(\d+)/[^"]*">([^<]+)</a>.*?'
        r'<td class="[^"]*size[^"]*">([^<]+)</td>.*?'
        r'<td class="[^"]*seeders[^"]*">(\d+)</td>.*?'
        r'<td class="[^"]*leechers[^"]*">(\d+)</td>',
        dotAll: true,
      );
      
      for (final match in rowRegex.allMatches(html)) {
        try {
          final name = match.group(2)?.trim() ?? '';
          final sizeStr = match.group(3)?.trim() ?? '0';
          final seeders = int.tryParse(match.group(4) ?? '0') ?? 0;
          final leechers = int.tryParse(match.group(5) ?? '0') ?? 0;
          
          if (name.isEmpty) continue;
          
          // Extract info hash from the detail page link or generate placeholder
          // 1337x doesn't directly show info hash in search results, we need to get it from detail page
          // For now, use a placeholder that won't match, but allow adding
          final infoHash = '';
          
          // Parse size (could be in MB, GB, etc)
          final size = _parseSize(sizeStr);
          
          results.add(TorrentSearchResult(
            name: name,
            infoHash: infoHash,
            seeders: seeders,
            leechers: leechers,
            size: size,
            source: '1337x',
          ));
        } catch (e) {
          continue;
        }
      }
      
      // If regex didn't work, try alternative pattern
      if (results.isEmpty) {
        // Try simpler pattern for name and seeders
        final simpleRegex = RegExp(
          r'<a href="/torrent/\d+/[^"]*">([^<]+)</a>.*?(\d+)\s*(?:Seeders|seeders)',
          dotAll: true,
        );
        for (final match in simpleRegex.allMatches(html)) {
          final name = match.group(1)?.trim() ?? '';
          final seeders = int.tryParse(match.group(2) ?? '0') ?? 0;
          if (name.isNotEmpty && seeders > 0) {
            results.add(TorrentSearchResult(
              name: name,
              infoHash: '',
              seeders: seeders,
              leechers: 0,
              size: 0,
              source: '1337x',
            ));
          }
        }
      }
      
      return results;
    } catch (e) {
      print('[Music] 1337x scraper error: $e');
      return [];
    }
  }

  // ─── Pirate Bay Scraper ───────────────────────────────────────────────────────
  Future<List<TorrentSearchResult>> _searchPirateBay(String query) async {
    try {
      final cleanQuery = query.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), ' ');
      
      final response = await _dio.get(
        'https://thepiratebay.org/search.php',
        queryParameters: {'q': cleanQuery, 'audio': 'yes'},
        options: Options(
          headers: {
            'Accept': 'text/html',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      
      final html = response.data as String;
      final results = <TorrentSearchResult>[];
      
      // Pirate Bay uses a detailed list format
      // Try to match the magnet link and extract info hash
      final magnetRegex = RegExp(
        r'<a href="(magnet:[^"]+)"[^>]*>.*?</a>.*?'
        r'<a[^>]*class="detLink"[^>]*>([^<]+)</a>.*?'
        r'<td[^>]*>(\d+\.\d+ [KMGT]?B?)</td>.*?'
        r'<td[^>]*>(\d+)</td>.*?'
        r'<td[^>]*>(\d+)</td>',
        dotAll: true,
      );
      
      for (final match in magnetRegex.allMatches(html)) {
        try {
          final magnetLink = match.group(1) ?? '';
          final name = match.group(2)?.trim() ?? '';
          final sizeStr = match.group(3)?.trim() ?? '0';
          final seeders = int.tryParse(match.group(4) ?? '0') ?? 0;
          final leechers = int.tryParse(match.group(5) ?? '0') ?? 0;
          
          if (name.isEmpty) continue;
          
          // Extract info hash from magnet link
          final infoHashRegex = RegExp(r'btih:([a-fA-F0-9]{40})');
          final hashMatch = infoHashRegex.firstMatch(magnetLink);
          final infoHash = hashMatch?.group(1) ?? '';
          
          final size = _parseSize(sizeStr);
          
          results.add(TorrentSearchResult(
            name: name,
            infoHash: infoHash.toLowerCase(),
            seeders: seeders,
            leechers: leechers,
            size: size,
            source: 'piratebay',
            magnetLink: magnetLink,
          ));
        } catch (e) {
          continue;
        }
      }
      
      return results;
    } catch (e) {
      print('[Music] PirateBay scraper error: $e');
      return [];
    }
  }

  // Helper to parse size string to bytes
  int _parseSize(String sizeStr) {
    sizeStr = sizeStr.trim().toUpperCase();
    final numRegex = RegExp(r'([\d.]+)');
    final numMatch = numRegex.firstMatch(sizeStr);
    if (numMatch == null) return 0;
    
    final num = double.tryParse(numMatch.group(1) ?? '0') ?? 0;
    
    if (sizeStr.contains('GB') || sizeStr.contains('GIB')) {
      return (num * 1024 * 1024 * 1024).toInt();
    } else if (sizeStr.contains('MB') || sizeStr.contains('MIB')) {
      return (num * 1024 * 1024).toInt();
    } else if (sizeStr.contains('KB') || sizeStr.contains('KIB')) {
      return (num * 1024).toInt();
    } else if (sizeStr.contains('TB') || sizeStr.contains('TIB')) {
      return (num * 1024 * 1024 * 1024 * 1024).toInt();
    }
    return num.toInt();
  }

  // ─── YouTube Search ─────────────────────────────────────────────────────────
  @override
  Future<List<YouTubeResult>> searchYouTube(String query) async {
    try {
      final videos = await _yt.search.search(query);
      return videos.map<YouTubeResult>((v) => YouTubeResult(
        id: v.id.value,
        title: v.title,
        author: v.author,
        duration: v.duration?.toString().split('.').first ?? 'Unknown',
        thumbnailUrl: v.thumbnails.highResUrl,
      )).toList();
    } catch (e) {
      print('[Music] YouTube search error: $e');
      return [];
    }
  }

  @override
  Future<String?> getYouTubeStreamUrl(String videoId) async {
    if (!_settings.isYouTubeScraperEnabled) {
      print('[Music] getYouTubeStreamUrl blocked: YouTube scraper is disabled in settings.');
      return null;
    }
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId, 
        ytClients: [YoutubeApiClient.android, YoutubeApiClient.ios, YoutubeApiClient.tv],
      );
      // Prefer M4A (mp4 container) as it's more compatible with native players
      final audioStreams = manifest.audioOnly.where((s) => s.container.toString().toLowerCase().contains('mp4'));
      final streamInfo = audioStreams.isNotEmpty 
          ? audioStreams.withHighestBitrate() 
          : manifest.audioOnly.withHighestBitrate();
      final resolved = streamInfo.url.toString();
      print('[Music] getYouTubeStreamUrl for $videoId: ${resolved.substring(0, resolved.length > 50 ? 50 : resolved.length)}...');
      return resolved;
    } catch (e) {
      print('[Music] YouTube get stream error: $e');
      return null;
    }
  }


  @override
  Future<bool> addWebDownload(String url) async {
    try {
      // Try the async endpoint first (more reliable for YT links)
      try {
        final response = await _dio.post(
          'https://api.torbox.app/v1/api/webdl/asynccreatewebdownload',
          data: {'link': url},
          options: Options(
            headers: {
              ..._authHeaders,
              'Content-Type': 'application/json',
            },
            validateStatus: (s) => true,
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        
        print('[Music] Async WebDL response: ${response.statusCode} - ${response.data}');
        
        if (response.data['success'] == true || response.statusCode == 200) {
          return true;
        }
        print('[Music] Async WebDL failed: ${response.data}');
      } catch (e) {
        print('[Music] Async WebDL error: $e');
      }

      // Try synchronous endpoint as fallback
      final syncResponse = await _dio.post(
        'https://api.torbox.app/v1/api/webdl/createwebdownload',
        data: {'link': url},
        options: Options(
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => true,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      
      print('[Music] Sync WebDL response: ${syncResponse.statusCode} - ${syncResponse.data}');
      
      return syncResponse.data['success'] == true || syncResponse.statusCode == 200;
    } catch (e) {
      if (e is DioException && e.response != null) {
        print('[Music] Add WebDL error: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        print('[Music] Add WebDL error: $e');
      }
      return false;
    }
  }
  @override
  Future<bool> addTorrent(String magnetLink) async {
    try {
      final response = await _dio.post(
        '$_torboxBase/torrents/createtorrent',
        data: FormData.fromMap({'magnet': magnetLink}),
        options: Options(headers: _authHeaders),
      );
      return response.data['success'] == true;
    } catch (e) {
      print('[Music] Add torrent error: $e');
      return false;
    }
  }

  @override
  Future<List<TorBoxTorrent>> getLibrary() async {
    try {
      final response = await _dio.get(
        '$_torboxBase/torrents/mylist',
        options: Options(headers: _authHeaders),
      );
      if (response.data['success'] != true) return [];
      final data = response.data['data'] as List<dynamic>? ?? [];
      final torrents = data
          .map((t) => TorBoxTorrent.fromJson(t as Map<String, dynamic>))
          .where((t) => t.files.isNotEmpty)
          .toList();
      return torrents;
    } catch (e) {
      print('[Music] Get library error: $e');
      return [];
    }
  }

  @override
  Future<int> getLibraryHash() async {
    try {
      final response = await _dio.head(
        '$_torboxBase/torrents/mylist',
        options: Options(headers: _authHeaders),
      );
      return response.hashCode;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<String?> getStreamUrl(int torrentId, int fileId) async {
    try {
      final response = await _dio.get(
        '$_torboxBase/torrents/requestdl',
        queryParameters: {
          'token': _settings.apiKey,
          'torrent_id': torrentId,
          'file_id': fileId,
          'zip_link': 'false',
        },
        options: Options(
          headers: _authHeaders,
          // Accept all status codes so we can inspect the body for error messages
          validateStatus: (s) => true,
        ),
      );

      print('[Music] requestdl status: ${response.statusCode}');
      print('[Music] requestdl body: ${response.data}');

      if (response.data is Map) {
        final body = response.data as Map<String, dynamic>;
        if (body['success'] == true) {
          // TorBox returns the URL as a string in `data`
          return body['data'] as String?;
        }
        // Surface TorBox error detail
        final detail = body['detail'] ?? body['error'] ?? 'File not ready yet';
        print('[Music] requestdl error from TorBox: $detail');
        throw Exception(detail.toString());
      }

      return null;
    } on DioException catch (e) {
      print('[Music] Get stream URL DioException: ${e.type} ${e.message}');
      rethrow;
    }
  }

  // --- Helpers for RSS Parsing ---
  String _getString(dynamic obj, String key) {
    if (obj is Map && obj.containsKey(key)) {
      final val = obj[key];
      if (val is Map && val.containsKey('label')) return val['label'].toString();
      return val.toString();
    }
    return '';
  }

  String _getArtwork(dynamic obj) {
    if (obj is Map && obj.containsKey('im:image')) {
      final images = obj['im:image'];
      if (images is List && images.isNotEmpty) {
        final last = images.last;
        if (last is Map && last.containsKey('label')) {
          return last['label'].toString().replaceAll(RegExp(r'\d+x\d+bb'), '600x600bb');
        }
      }
    }
    return '';
  }

  String _getId(dynamic obj) {
    if (obj is Map && obj.containsKey('id')) {
      final idObj = obj['id'];
      if (idObj is Map && idObj.containsKey('attributes')) {
        return idObj['attributes']['im:id']?.toString() ?? '0';
      }
    }
    return '0';
  }

  String _getArtistUrl(dynamic obj) {
    if (obj is Map && obj.containsKey('im:artist')) {
      final artistObj = obj['im:artist'];
      if (artistObj is Map && artistObj.containsKey('attributes')) {
        return artistObj['attributes']['href']?.toString() ?? '';
      }
    }
    return '';
  }

  @override
  Future<List<AppleMusicPlaylist>> getRegionalPlaylists({required String region, int limit = 25}) async {
    try {
      final response = await _dio.get('https://rss.marketingtools.apple.com/api/v2/$region/music/most-played/$limit/playlists.json');
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final results = (data['feed']['results'] as List<dynamic>? ?? []);
      return results.map((r) => AppleMusicPlaylist.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[Music] getRegionalPlaylists error: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> getAppleMusicPlaylistTracks(String playlistUrl) async {
    try {
      final response = await _dio.get(
        playlistUrl,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      final html = response.data as String;
      
      // Try to find the JSON-LD data which contains the track list
      final jsonLdMatch = RegExp(r'<script [^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true).allMatches(html);
      
      for (final match in jsonLdMatch) {
        try {
          final jsonStr = match.group(1)!;
          if (!jsonStr.contains('MusicPlaylist')) continue;
          
          final data = jsonDecode(jsonStr);
          final tracks = data['track'] as List<dynamic>? ?? [];
          if (tracks.isEmpty) continue;
          
          return tracks.map((t) {
            final track = t as Map<String, dynamic>;
            
            // Try to get artist name
            String artistName = '';
            if (track['byArtist'] != null) {
              final artist = track['byArtist'];
              if (artist is List && artist.isNotEmpty) {
                artistName = artist.first['name']?.toString() ?? '';
              } else if (artist is Map) {
                artistName = artist['name']?.toString() ?? '';
              }
            }

            // Try to get artwork
            String artworkUrl = '';
            if (track['audio'] != null && track['audio'] is Map) {
              artworkUrl = track['audio']['thumbnailUrl']?.toString() ?? '';
            } else if (track['image'] != null) {
              artworkUrl = track['image'].toString();
            }

            // Try to get track ID from URL
            int trackId = 0;
            final trackUrl = track['url']?.toString() ?? '';
            if (trackUrl.isNotEmpty) {
              final idMatch = RegExp(r'/(\d+)$').firstMatch(trackUrl);
              if (idMatch != null) {
                trackId = int.tryParse(idMatch.group(1)!) ?? 0;
              }
            }

            if (trackId == 0) {
              trackId = (track['name']?.toString().hashCode ?? 0) ^ (artistName.hashCode);
              if (trackId < 0) trackId = -trackId;
            }

            return ItunesTrack(
              trackId: trackId,
              trackName: track['name']?.toString() ?? 'Unknown Track',
              artistName: artistName,
              collectionName: data['name']?.toString() ?? 'Unknown Playlist',
              artworkUrl: artworkUrl,
              trackTimeMillis: _parseIsoDuration(track['duration']?.toString() ?? ''),
            );
          }).toList();
        } catch (e) {
          print('[Music] Error parsing JSON-LD script tag: $e');
          continue;
        }
      }

      // Fallback: search for songs in the HTML meta tags (provided by Apple)
      final songsList = <ItunesTrack>[];
      final songRegex = RegExp(r'<meta property="music:song" content="(https://music\.apple\.com/[^/]+/song/([^/]+)/(\d+))">');
      final matches = songRegex.allMatches(html);
      
      for (final m in matches) {
        final songUrl = m.group(1)!;
        final slug = m.group(2)!;
        final trackIdStr = m.group(3) ?? '0';
        final trackId = int.tryParse(trackIdStr) ?? 0;
        
        // Convert slug (pavazha-malli-from-think-indie) to readable name
        final name = slug.split('-').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ');
        
        songsList.add(ItunesTrack(
          trackId: trackId != 0 ? trackId : (slug.hashCode.abs()),
          trackName: name,
          artistName: '',
          collectionName: 'Playlist',
          artworkUrl: '',
        ));
      }
      
      return songsList;
    } catch (e) {
      print('[Music] getAppleMusicPlaylistTracks error: $e');
      return [];
    }
  }

  int _parseIsoDuration(String duration) {
    if (duration.isEmpty) return 0;
    // PT3M45S -> 225000ms
    try {
      final reg = RegExp(r'PT(?:(\d+)M)?(?:(\d+)S)?');
      final match = reg.firstMatch(duration);
      if (match == null) return 0;
      final m = int.tryParse(match.group(1) ?? '0') ?? 0;
      final s = int.tryParse(match.group(2) ?? '0') ?? 0;
      return (m * 60 + s) * 1000;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<ItunesTrack>> getTopSongs({int limit = 30, String countryCode = 'us', int? genreId}) async {
    try {
      final genrePath = genreId != null ? '/genre=$genreId' : '';
      final response = await _dio.get('https://itunes.apple.com/$countryCode/rss/topsongs/limit=$limit$genrePath/json');
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      
      final feed = data['feed'] as Map<String, dynamic>?;
      if (feed == null) return [];
      
      final entryObj = feed['entry'];
      List<dynamic> entries = [];
      if (entryObj is List) {
        entries = entryObj;
      } else if (entryObj is Map) {
        entries = [entryObj];
      }
      
      print('[Music] Fetched ${entries.length} top songs');
      
      return entries.map((e) {
        final map = e as Map<String, dynamic>;
        final id = _getId(map);
        final name = _getString(map, 'im:name');
        final artist = _getString(map, 'im:artist');
        final collection = _getString(map, 'im:collection');
        final artwork = _getArtwork(map);
        final artistUrl = _getArtistUrl(map);

        return ItunesTrack(
          trackId: int.tryParse(id) ?? 0,
          trackName: name.isEmpty ? 'Unknown' : name,
          artistName: artist.isEmpty ? 'Unknown Artist' : artist,
          collectionName: collection.isEmpty ? 'Single' : collection,
          artworkUrl: artwork,
          artistViewUrl: artistUrl,
        );
      }).toList();
    } catch (e) {
      print('[Music] Get top songs error: $e');
      return [];
    }
  }

  @override
  Future<List<ItunesTrack>> getTopAlbums({int limit = 10, String countryCode = 'us'}) async {
    try {
      final response = await _dio.get('https://itunes.apple.com/$countryCode/rss/topalbums/limit=$limit/json');
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      
      final feed = data['feed'] as Map<String, dynamic>?;
      if (feed == null) return [];
      
      final entryObj = feed['entry'];
      List<dynamic> entries = [];
      if (entryObj is List) {
        entries = entryObj;
      } else if (entryObj is Map) {
        entries = [entryObj];
      }

      print('[Music] Fetched ${entries.length} top albums');

      return entries.map((e) {
        final map = e as Map<String, dynamic>;
        final id = _getId(map);
        final name = _getString(map, 'im:name');
        final artist = _getString(map, 'im:artist');
        final artwork = _getArtwork(map);
        final artistUrl = _getArtistUrl(map);

        return ItunesTrack(
          trackId: int.tryParse(id) ?? 0,
          trackName: name.isEmpty ? 'Unknown' : name,
          artistName: artist.isEmpty ? 'Unknown Artist' : artist,
          collectionName: name.isEmpty ? 'Unknown Album' : name,
          artworkUrl: artwork,
          artistViewUrl: artistUrl,
        );
      }).toList();
    } catch (e) {
      print('[Music] Get top albums error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> checkCached(List<String> hashes) async {
    if (hashes.isEmpty) return [];
    
    final normalizedHashes = hashes.map((h) => h.toLowerCase()).toList();
    
    try {
      final response = await _dio.post(
        '$_torboxBase/torrents/checkcached',
        data: {
          'hashes': normalizedHashes,
          'list': true,
        },
        options: Options(
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        
        if (data is List) {
          return data.map((h) => h.toString().toLowerCase()).toList();
        } else if (data is Map) {
          final results = data.keys.map((h) => h.toString().toLowerCase()).toList();
          return results;
        }
      }
      return [];
    } catch (e) {
      print('[Music] checkCached error: $e');
      return [];
    }
  }

  @override
  Future<bool> validateApiKey(String key) async {
    try {
      final response = await _dio.get(
        '$_torboxBase/user/me',
        options: Options(headers: {'Authorization': 'Bearer $key'}),
      );
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
  @override
  Future<List<ScraperResult>> searchFLAC(String query) async {
    return searchFLACStream(query).toList();
  }

  @override
  Stream<ScraperResult> searchFLACStream(String query) async* {
    print('[MusicRepository] Beginning searchFLACStream for: "$query"');
    
    // 1. Addons first (sorted by user priority from Addon Manager)
    final addonScrapers = _pluginManager.prioritizedActiveAddons.map((addon) {
      if (addon is JsPlugin) {
        return JsPluginScraper(addon, _pluginManager) as MusicScraper;
      } else {
        return EclipseAddonScraper(addon as EclipseAddon, _pluginManager) as MusicScraper;
      }
    }).toList();

    // 2. Built-in YouTube last (fallback)
    final builtInActive = _scrapers.where((scraper) {
      bool enabled = true;
      if (scraper is YouTubeScraper) enabled = _settings.isYouTubeScraperEnabled;
      print('[MusicRepository] Built-in Scraper ${scraper.name} is ${enabled ? "ACTIVE" : "DISABLED"}');
      return enabled;
    }).toList();

    final activeScrapers = [...addonScrapers, ...builtInActive];

    if (activeScrapers.isEmpty) {
      print('[MusicRepository] No active scrapers found!');
      return;
    }

    final controller = StreamController<ScraperResult>();
    int completedCount = 0;

    for (final scraper in activeScrapers) {
      print('[MusicRepository] Starting scraper: ${scraper.name}');
      scraper.searchStream(query).listen(
        (result) {
          print('[MusicRepository] Result from ${scraper.name}: ${result.title}');
          controller.add(result);
        },
        onError: (e) => print('[MusicRepository] Scraper ${scraper.name} failed: $e'),
        onDone: () {
          print('[MusicRepository] Scraper ${scraper.name} completed.');
          completedCount++;
          if (completedCount == activeScrapers.length) {
            print('[MusicRepository] All scrapers finished.');
            controller.close();
          }
        },
      );
    }

    yield* controller.stream;
  }

  @override
  Future<List<ItunesTrack>> getTopArtists() async {
    return _lastFm.getTopArtists();
  }

  @override
  Future<void> recordPlayback(TorBoxFile file, ItunesMeta? meta, {String? artworkUrlLow, String? artworkUrlHigh, int? duration}) async {
    print('[MusicRepository] recordPlayback: ${file.name} (torrentId: ${file.torrentId}, fileId: ${file.id})');
    final parsed = _parseFilename(file.displayName);
    await _db.recordPlayback(PlaybackHistoryCompanion.insert(
      fileId: file.id,
      torrentId: file.torrentId,
      trackTitle: meta?.trackName ?? parsed.title,
      artist: meta?.artistName ?? parsed.artist,
      album: meta?.album ?? '',
      genre: meta?.genre ?? '',
      artworkUrlLow: Value(artworkUrlLow ?? meta?.artworkUrlLow),
      artworkUrlHigh: Value(artworkUrlHigh ?? meta?.artworkUrlHigh),
      playedAt: DateTime.now().millisecondsSinceEpoch,
      duration: Value(duration),
    ));
  }

  @override
  Future<List<DbPlaybackHistory>> getRecentTracks() async {
    return _db.getRecentPlayback();
  }

  @override
  Stream<List<DbPlaybackHistory>> watchRecentTracks() {
    return _db.watchRecentPlayback();
  }

  @override
  Future<List<DbTrackMetadata>> getLikedSongs() {
    return _db.getLikedTracks();
  }

  ({String title, String artist}) _parseFilename(String displayName) {
    var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
    name = name.replaceAll(RegExp(r'^\d+\s*[-.]? \s*'), '');
    final match = RegExp(r' [-–] ').firstMatch(name);
    if (match != null) {
      return (
        artist: name.substring(0, match.start).trim(),
        title: name.substring(match.end).trim(),
      );
    }
    return (title: name.trim(), artist: '');
  }

  // ─── Recommendations ────────────────────────────────────────────────────────
  @override
  Future<List<ItunesTrack>> getRecommendedTracks(String title, String artist, String category) async {
    try {
      if (category == 'All') return [];
      
      if (category == 'Popular') {
         return getTopSongs(limit: 30);
      }
      
      if (category == 'Familiar') {
         final liked = await _db.getLikedTracks();
         final recent = await _db.getRecentPlaybackUnique(limit: 100);
         
         final List<ItunesTrack> tracks = [];
         final Set<String> seen = {};
         
         void add(String tTitle, String tArtist, String tAlbum, String? art, int? dur) {
            if (tArtist.toLowerCase() != artist.toLowerCase() && category != 'Familiar') return;
            final key = '$tTitle|$tArtist';
            if (seen.contains(key)) return;
            seen.add(key);
            tracks.add(ItunesTrack(
              trackId: key.hashCode,
              trackName: tTitle,
              artistName: tArtist,
              collectionName: tAlbum,
              artworkUrl: art ?? '',
              trackTimeMillis: dur,
            ));
         }
         
         for (final l in liked) { add(l.trackTitle ?? '', l.artist ?? '', l.album ?? '', l.artworkUrlHigh ?? l.artworkUrlLow, l.trackTimeMillis); }
         for (final r in recent) { add(r.trackTitle, r.artist, r.album, r.artworkUrlHigh ?? r.artworkUrlLow, r.duration != null ? r.duration! * 1000 : null); }
         
         tracks.shuffle();
         return tracks.take(20).toList();
      }
      
      // ReccoBeats logic for Discover and Deep cuts
      final seedId = await _getReccoBeatsTrackId(title, artist);
      
      if (category == 'Discover') {
         if (seedId == null) {
            // Fallback to iTunes related artist
            return searchItunes(artist, limit: 20);
         }
         final response = await _dio.get(
           'https://api.reccobeats.com/v1/track/recommendation',
           queryParameters: {
             'seeds': seedId,
             'size': 20,
             'valence': 0.6,
             'energy': 0.7,
           },
         );
         return _parseReccoBeatsTracks(response.data);
      }
      
      if (category == 'Deep cuts') {
         return await _getDeepCutsFromArtist(artist);
      }
      
      return [];
    } catch (e) {
      print('[MusicRepository] getRecommendedTracks error: $e');
      return [];
    }
  }

  Future<String?> _getReccoBeatsTrackId(String title, String artist) async {
    try {
      final response = await _dio.get(
        'https://api.reccobeats.com/v1/artist/search',
        queryParameters: {'searchText': artist, 'size': 15},
      );
      final content = response.data['content'] as List<dynamic>? ?? [];
      if (content.isEmpty) return null;
      
      // Find exact basic match or fallback to first
      String artistId = content.first['id'] as String;
      for (final a in content) {
        if ((a['name'] as String).toLowerCase() == artist.toLowerCase()) {
           artistId = a['id'] as String;
           break;
        }
      }
      
      final tracksResponse = await _dio.get(
        'https://api.reccobeats.com/v1/artist/$artistId/track',
        queryParameters: {'size': 50},
      );
      final tracks = tracksResponse.data['content'] as List<dynamic>? ?? [];
      
      for (final t in tracks) {
        final tName = (t['trackTitle'] as String? ?? '').toLowerCase();
        if (tName.contains(title.toLowerCase()) || title.toLowerCase().contains(tName)) {
           return t['id'] as String;
        }
      }
      
      if (tracks.isNotEmpty) return tracks.first['id'] as String;
    } catch (e) {
      print('[MusicRepository] ReccoBeats ID fetch error: $e');
    }
    return null;
  }
  
  Future<List<ItunesTrack>> _getDeepCutsFromArtist(String artist) async {
    try {
      final response = await _dio.get(
        'https://api.reccobeats.com/v1/artist/search',
        queryParameters: {'searchText': artist, 'size': 5},
      );
      final content = response.data['content'] as List<dynamic>? ?? [];
      if (content.isEmpty) return getArtistTopSongs(artist, limit: 30);
      
      final artistId = content.first['id'] as String;
      
      final tracksResponse = await _dio.get(
        'https://api.reccobeats.com/v1/artist/$artistId/track',
        queryParameters: {'size': 50}, 
      );
      final tracks = tracksResponse.data['content'] as List<dynamic>? ?? [];
      
      // Deep cuts: popularity < 50
      final deepCuts = tracks.where((t) {
         final pop = (t['popularity'] as num?)?.toInt() ?? 100;
         return pop < 50; 
      }).toList();
      
      deepCuts.shuffle();
      if (deepCuts.isEmpty) {
        tracks.shuffle();
        return tracks.take(20).map((t) => _mapReccoTrack(t)).toList();
      }
      return deepCuts.take(20).map((t) => _mapReccoTrack(t)).toList();
    } catch (e) {
       print('[MusicRepository] Deep cuts error: $e');
       return getArtistTopSongs(artist, limit: 30);
    }
  }

  List<ItunesTrack> _parseReccoBeatsTracks(dynamic data) {
      final list = (data is List) ? data : (data['content'] as List? ?? data['tracks'] as List? ?? []);
      return list.map((t) => _mapReccoTrack(t)).toList();
  }
  
  ItunesTrack _mapReccoTrack(dynamic t) {
      final artists = t['artists'] as List<dynamic>? ?? [];
      final artistName = artists.isNotEmpty ? (artists.first['name'] as String? ?? 'Unknown') : 'Unknown';
      return ItunesTrack(
        trackId: t['id'].hashCode,
        trackName: t['trackTitle'] as String? ?? 'Unknown Track',
        artistName: artistName,
        collectionName: '', 
        artworkUrl: '', 
        trackTimeMillis: (t['durationMs'] as num?)?.toInt(),
      );
  }

  // ─── Nyaa.si Scraper (Audio Lossless) ───────────────────────────────────────
  Future<List<TorrentSearchResult>> _searchNyaa(String query) async {
    try {
      final response = await _dio.get(
        'https://nyaa.si/',
        queryParameters: {'f': '0', 'c': '2_1', 'q': query},
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0'},
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final html = response.data.toString();
      final results = <TorrentSearchResult>[];
      
      final rowRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
      for (final match in rowRegex.allMatches(html)) {
        final rowHtml = match.group(1) ?? '';
        
        final magnetRegex = RegExp(r'href="(magnet:\?xt=[^"]+)"', caseSensitive: false);
        final magnetMatch = magnetRegex.firstMatch(rowHtml);
        if (magnetMatch == null) continue;
        
        final magnetLink = magnetMatch.group(1) ?? '';
        
        final titleRegex = RegExp(r'<a[^>]*href="/view/[^"]*"[^>]*title="([^"]+)"', caseSensitive: false);
        var titleMatch = titleRegex.firstMatch(rowHtml);
        var name = titleMatch?.group(1)?.trim();
        if (name == null || name.isEmpty) {
          // Fallback: extract display text from the link
          final fallbackRegex = RegExp(r'<a[^>]*href="/view/[^>]*>([^<]+)</a>', caseSensitive: false);
          final fallbackMatch = fallbackRegex.firstMatch(rowHtml);
          name = fallbackMatch?.group(1)?.trim();
        }
        // Ensure name is never null
        name ??= 'Nyaa Result';
        
        final tdRegex = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
        final tds = tdRegex.allMatches(rowHtml).map((m) => m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '').toList();
        
        int seeders = 0;
        String sizeStr = '0';
        
        if (tds.length >= 8) {
          sizeStr = tds[3];
          seeders = int.tryParse(tds[5]) ?? 0;
        }

        final infoHashRegex = RegExp(r'btih:([a-fA-F0-9]{40})', caseSensitive: false);
        final hashMatch = infoHashRegex.firstMatch(magnetLink);
        final infoHash = hashMatch?.group(1) ?? '';

        if (infoHash.isEmpty) continue;

        results.add(TorrentSearchResult(
          name: name,
          infoHash: infoHash.toLowerCase(),
          seeders: seeders,
          leechers: 0,
          size: _parseSize(sizeStr),
          source: 'nyaa',
          magnetLink: magnetLink,
        ));
      }
      
      return results;
    } catch (e) {
      print('[Music] Nyaa search error: $e');
      return [];
    }
  }

  String _refineQuery(String query) {
    var refined = query;
    // Remove brackets and parenthetical metadata to avoid over-specification
    refined = refined.replaceAll(RegExp(r'\[.*?\]'), '');
    refined = refined.replaceAll(RegExp(r'\(.*?\)'), '');
    
    // Remove common suffixes often added by iTunes/Metadata but not in torrent names
    refined = refined.replaceAll(RegExp(r'Original Motion Picture Soundtrack', caseSensitive: false), '');
    refined = refined.replaceAll(RegExp(r'Remastered', caseSensitive: false), '');
    refined = refined.replaceAll(RegExp(r'Expanded Edition', caseSensitive: false), '');
    refined = refined.replaceAll(RegExp(r'Deluxe Edition', caseSensitive: false), '');
    
    // Normalize spaces and special characters
    refined = refined.replaceAll(RegExp(r'[^\w\s\-]'), ' ');
    refined = refined.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // If the query is still extremely long, take first 6-8 words
    final words = refined.split(' ');
    if (words.length > 8) {
      refined = words.take(8).join(' ');
    }
    
    return refined.isEmpty ? query : refined;
  }

  // --- Followed Artists Implementation ---

  @override
  Future<ItunesArtist?> getArtistDetails(String artistName) async {
    try {
      print('[MusicRepository] Searching iTunes artist details for: $artistName');
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': artistName,
          'entity': 'musicArtist',
          'limit': 1,
        },
      );

      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (e) {
          print('[MusicRepository] Failed to decode iTunes JSON: $e');
        }
      }

      List<dynamic> results = [];
      if (rawData is Map && rawData.containsKey('results')) {
        results = rawData['results'] as List<dynamic>;
      }

      print('[MusicRepository] iTunes artist search results count: ${results.length}');
      if (results.isNotEmpty) {
        final artist = ItunesArtist.fromJson(results.first as Map<String, dynamic>);
        print('[MusicRepository] Found artist: ${artist.artistName} (ID: ${artist.artistId})');
        return artist;
      } else {
        // Try fallback search without entity=musicArtist if not found
        print('[MusicRepository] No musicArtist found, trying general search...');
        final fallbackResponse = await _dio.get(
          '$_itunesBase/search',
          queryParameters: {
            'term': artistName,
            'limit': 5,
          },
        );
        
        dynamic fallbackRaw = fallbackResponse.data;
        if (fallbackRaw is String) {
          try {
            fallbackRaw = jsonDecode(fallbackRaw);
          } catch (_) {}
        }

        List<dynamic> fallbackResults = [];
        if (fallbackRaw is Map && fallbackRaw.containsKey('results')) {
          fallbackResults = fallbackRaw['results'] as List<dynamic>;
        }

        if (fallbackResults.isNotEmpty) {
           for (var res in fallbackResults) {
             if (res is Map<String, dynamic> && res['artistId'] != null) {
               final artist = ItunesArtist.fromJson(res);
               print('[MusicRepository] Found artist from fallback: ${artist.artistName} (ID: ${artist.artistId})');
               return artist;
             }
           }
        }
      }
    } catch (e) {
      print('[MusicRepository] Error fetching artist details: $e');
    }
    return null;
  }

  @override
  Future<void> followArtist(ItunesArtist artist, String? artworkUrl) async {
    print('[MusicRepository] Following artist: ${artist.artistName} (ID: ${artist.artistId})');
    await _db.followArtist(FollowedArtistsCompanion.insert(
      id: Value(artist.artistId),
      name: artist.artistName,
      artworkUrl: Value(artworkUrl),
      genre: Value(artist.primaryGenreName),
      followedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final all = await _db.getAllFollowedArtists();
    print('[MusicRepository] Total followed artists now: ${all.length}');
  }

  @override
  Future<void> unfollowArtist(int artistId) async {
    await _db.unfollowArtist(artistId);
  }

  @override
  Stream<bool> isArtistFollowed(int artistId) {
    return _db.watchFollowedArtists().map((list) => list.any((a) => a.id == artistId));
  }

  @override
  Future<List<DbFollowedArtist>> getFollowedArtists() => _db.getAllFollowedArtists();

  @override
  Stream<List<DbFollowedArtist>> watchFollowedArtists() => _db.watchFollowedArtists();

  @override
  Future<String?> getArtistBio(String artistName) => _lastFm.getArtistBio(artistName);

  @override
  Future<List<String>> getSimilarArtists(String artistName) => _lastFm.getSimilarArtists(artistName);

  @override
  Future<Map<String, dynamic>?> getArtistMetadata(String artistName) => _mb.getArtistInfo(artistName);

  @override
  Future<List<DeezerPlaylist>> getDeezerArtistPlaylists(String artistName) async {
    // Search for playlists by name exclusively (as requested/suggested)
    // Fetching multiple pages for variety: index=0 and index=25
    final p1 = await _deezer.searchPlaylists(artistName, index: 0);
    final p2 = await _deezer.searchPlaylists(artistName, index: 25);

    final allPlaylists = [...p1, ...p2];
    final seenIds = <String>{};
    final items = <DeezerPlaylist>[];

    for (final p in allPlaylists) {
      final playlist = DeezerPlaylist.fromJson(p);
      if (seenIds.add(playlist.id)) {
        items.add(playlist);
      }
    }

    return items;
  }

  @override
  Future<List<String>> getDeezerRelatedArtists(String artistName) async {
    final artist = await _deezer.searchArtist(artistName);
    if (artist == null) return [];
    final id = artist['id'].toString();
    final related = await _deezer.getArtistRelated(id);
    return related.map((r) => r['name'] as String).toList();
  }

  @override
  Future<List<ItunesTrack>> getDeezerArtistTopTracks(String artistName) async {
    final artist = await _deezer.searchArtist(artistName);
    if (artist == null) return [];
    final id = artist['id'].toString();
    final tracks = await _deezer.getArtistTopTracks(id, artistName);
    
    return tracks.map((t) {
      // Map Deezer track to ItunesTrack for UI consistency
      final album = t['album'] as Map<String, dynamic>?;
      return ItunesTrack(
        trackId: (t['id'] as num).toInt(),
        trackName: t['title'] as String,
        artistName: t['artist']['name'] as String,
        collectionName: album?['title'] as String? ?? '',
        artworkUrl: album?['cover_big'] as String? ?? album?['cover_medium'] as String? ?? '',
        previewUrl: t['preview'] as String?,
        trackTimeMillis: (t['duration'] as num).toInt() * 1000,
        artistViewUrl: t['link'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<ItunesTrack>> getDeezerPlaylistTracks(String playlistId, {int index = 0, int limit = 50}) async {
    final tracks = await _deezer.getPlaylistTracks(playlistId, index: index, limit: limit);
    return tracks.map((t) {
      final album = t['album'] as Map<String, dynamic>?;
      return ItunesTrack(
        trackId: (t['id'] as num).toInt(),
        trackName: t['title'] as String,
        artistName: t['artist']['name'] as String,
        collectionName: album?['title'] as String? ?? '',
        artworkUrl: album?['cover_big'] as String? ?? album?['cover_medium'] as String? ?? '',
        previewUrl: t['preview'] as String?,
        trackTimeMillis: (t['duration'] as num).toInt() * 1000,
        artistViewUrl: t['link'] as String?,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getDeezerArtistDetails(String artistName) async {
    final search = await _deezer.searchArtist(artistName);
    if (search == null) return null;
    return _deezer.getArtistDetails(search['id'].toString());
  }

  @override
  Future<List<DeezerGenre>> getDeezerGenres() async {
    final genres = await _deezer.getGenres();
    return genres.map((g) => DeezerGenre.fromJson(g)).toList();
  }

  @override
  Future<List<DeezerPlaylist>> getDeezerGenrePlaylists(int genreId, {String? genreName}) async {
    final playlists = await _deezer.getGenrePlaylists(genreId, genreName: genreName);
    return playlists.map((p) => DeezerPlaylist.fromJson(p)).toList();
  }
  
  
  // ─── New Recommendation Methods using Deezer API ─────────────────────────────

  @override
  Future<List<ItunesTrack>> getBecauseYouListenedToRecommendations(String artistName, {int limit = 20}) async {
    try {
      final deezerTracks = await _deezer.getBecauseYouListenedTo(
        artistName: artistName,
        limit: limit,
      );

      return deezerTracks.map((track) {
        final artist = track['artist'] as Map<String, dynamic>?;
        final album = track['album'] as Map<String, dynamic>?;
        
        return ItunesTrack(
          trackId: track['id'] as int,
          trackName: track['title'] as String? ?? 'Unknown',
          artistName: artist?['name'] as String? ?? 'Unknown',
          collectionName: album?['title'] as String? ?? '',
          artworkUrl: album?['cover_medium'] as String? ?? album?['cover_small'] as String? ?? '',
          trackTimeMillis: ((track['duration'] as int?) ?? 0) * 1000,
        );
      }).toList();
    } catch (e) {
      print('[MusicRepository] getBecauseYouListenedToRecommendations error: $e');
      // Fallback to iTunes search
      return searchItunes(artistName, limit: limit);
    }
  }

  @override
  Future<List<ItunesTrack>> getRecommendationsBasedOnRecentHistory() async {
    try {
      // Get user's recent playback history
      final recentTracks = await _db.getRecentPlaybackUnique(limit: 10);
      
      if (recentTracks.isEmpty) {
        return getTopSongs(limit: 20);
      }

      // Get recommendations based on each recent track and combine them
      final Set<ItunesTrack> allRecommendations = {};
      
      for (final track in recentTracks.take(3)) {
        if (track.artist != null && track.artist!.isNotEmpty) {
          final recommendations = await _deezer.getRecommendationsForTrack(
            trackTitle: track.trackTitle ?? '',
            artistName: track.artist!,
            limit: 10,
          );
          
          for (final r in recommendations) {
            final artist = r['artist'] as Map<String, dynamic>?;
            final album = r['album'] as Map<String, dynamic>?;
            
            final itunesTrack = ItunesTrack(
              trackId: r['id'] as int,
              trackName: r['title'] as String? ?? 'Unknown',
              artistName: artist?['name'] as String? ?? 'Unknown',
              collectionName: album?['title'] as String? ?? '',
              artworkUrl: album?['cover_medium'] as String? ?? album?['cover_small'] as String? ?? '',
              trackTimeMillis: ((r['duration'] as int?) ?? 0) * 1000,
            );
            
            allRecommendations.add(itunesTrack);
          }
        }
      }

      // Convert to list and shuffle for variety
      final recommendationsList = allRecommendations.toList();
      recommendationsList.shuffle();
      
      return recommendationsList.take(20).toList();
    } catch (e) {
      print('[MusicRepository] getRecommendationsBasedOnRecentHistory error: $e');
      // Fallback to top songs
      return getTopSongs(limit: 20);
    }
  }

  @override
  Future<List<ItunesMeta>> searchDeezerMeta(String query) async {
    try {
      print('[MusicRepository] Deezer search started for: $query');
      final tracks = await _deezer.searchTracks(query);
      print('[MusicRepository] Deezer search returned ${tracks.length} tracks');
      return tracks.map((t) {
        final album = t['album'] as Map<String, dynamic>?;
        return ItunesMeta(
          trackName: (t['title_short'] ?? t['title']) as String?,
          artistName: t['artist']?['name'] as String?,
          artworkUrlLow: album?['cover_medium'] as String?,
          artworkUrlHigh: album?['cover_big'] as String?,
          album: album?['title'] as String?,
          trackTimeMillis: t['duration'] != null ? int.tryParse(t['duration'].toString()) != null ? int.parse(t['duration'].toString()) * 1000 : null : null,
        );
      }).toList();
    } catch (e) {
      print('[MusicRepository] searchDeezerMeta error: $e');
      return [];
    }
  }
}
