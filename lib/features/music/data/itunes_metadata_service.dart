import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

class ItunesMeta {
  final String? trackName;
  final String? artistName;
  final String? artworkUrlLow;
  final String? artworkUrlHigh;
  final String? album;
  final String? genre;
  final int? releaseYear;
  final int? trackTimeMillis;
  final String? previewUrl;
  final String? id;
  final Map<String, dynamic>? extras;

  const ItunesMeta({
    this.trackName,
    this.artistName,
    this.artworkUrlLow,
    this.artworkUrlHigh,
    this.album,
    this.genre,
    this.releaseYear,
    this.trackTimeMillis,
    this.previewUrl,
    this.id,
    this.extras,
  });
}

@lazySingleton
class ItunesMetadataService {
  final Dio _dio;

  // In-memory cache: "title|artist" → metadata (null means already tried, no result)
  final Map<String, ItunesMeta?> _cache = {};

  static const _itunesBase = 'https://itunes.apple.com';

  ItunesMetadataService(this._dio);

  Future<ItunesMeta?> fetchMeta(String title, String artist) async {
    final cacheKey = '${title.toLowerCase()}|${artist.toLowerCase()}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    print('[ItunesService] Fetching: "$title" by "$artist"');
    try {
      final term = artist.isNotEmpty ? '$title $artist' : title;
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': term,
          'entity': 'song',
          'limit': 1,
          'media': 'music',
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final dynamic data = response.data;
      Map<String, dynamic> json;
      
      if (data is Map<String, dynamic>) {
        json = data;
      } else if (data is String) {
        try {
          json = jsonDecode(data) as Map<String, dynamic>;
        } catch (e) {
          print('[ItunesService] Failed to decode JSON string: $e');
          _cache[cacheKey] = null;
          return null;
        }
      } else {
        print('[ItunesService] Unexpected response type: ${data.runtimeType}');
        _cache[cacheKey] = null;
        return null;
      }

      final results = (json['results'] as List<dynamic>?) ?? [];
      print('[ItunesService] Results for "$title": ${results.length}');
      if (results.isEmpty) {
        _cache[cacheKey] = null;
        return null;
      }

      final meta = _parseResult(results.first as Map<String, dynamic>);
      _cache[cacheKey] = meta;
      return meta;
    } catch (e) {
      print('[ItunesService] Error fetching "$title": $e');

      // Do NOT cache null if it's a transient error like rate limit (429) or forbidden (403)
      bool isTransient = false;
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code == 429 || code == 403) {
          isTransient = true;
        }
      }

      if (!isTransient) {
        _cache[cacheKey] = null;
      }
      return null;
    }
  }

  Future<ItunesMeta?> lookupById(int trackId) async {
    final cacheKey = 'lookup_$trackId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final response = await _dio.get(
        '$_itunesBase/lookup',
        queryParameters: {
          'id': trackId,
          'entity': 'song',
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final data = response.data;
      Map<String, dynamic> json;
      if (data is Map<String, dynamic>) {
        json = data;
      } else if (data is String) {
        json = jsonDecode(data) as Map<String, dynamic>;
      } else {
        _cache[cacheKey] = null;
        return null;
      }

      final results = (json['results'] as List<dynamic>?) ?? [];
      if (results.isEmpty) {
        _cache[cacheKey] = null;
        return null;
      }

      final meta = _parseResult(results.first as Map<String, dynamic>);
      _cache[cacheKey] = meta;
      return meta;
    } catch (e) {
      print('[ItunesService] Lookup error for id=$trackId: $e');
      _cache[cacheKey] = null;
      return null;
    }
  }

  Future<List<ItunesMeta>> searchMeta(String term) async {
    final cleanedTerm = term.replaceAll('"', '').replaceAll("'", '');
    print('[ItunesService] Searching: "$cleanedTerm"');
    try {
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': cleanedTerm,
          'entity': 'song',
          'limit': 20,
          'media': 'music',
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      final dynamic data = response.data;
      Map<String, dynamic> json;
      if (data is Map<String, dynamic>) {
        json = data;
      } else if (data is String) {
        json = jsonDecode(data) as Map<String, dynamic>;
      } else {
        return [];
      }

      final results = (json['results'] as List<dynamic>?) ?? [];
      return results.map((r) => _parseResult(r as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[ItunesService] Search error for "$term": $e');
      return [];
    }
  }

  ItunesMeta _parseResult(Map<String, dynamic> r) {
    // Artwork resolution adjustment
    final rawArtwork = r['artworkUrl100'] as String? ?? '';
    String? lowRes;
    String? highRes;
    
    if (rawArtwork.isNotEmpty) {
      lowRes = rawArtwork.replaceAll(RegExp(r'\d+x\d+'), '600x600');
      highRes = rawArtwork.replaceAll(RegExp(r'\d+x\d+'), '1000x1000');
    }

    // Parse year from releaseDate string like "1969-09-26T00:00:00Z"
    final releaseDateStr = r['releaseDate'] as String? ?? '';
    final releaseYear = releaseDateStr.length >= 4
        ? int.tryParse(releaseDateStr.substring(0, 4))
        : null;

    final meta = ItunesMeta(
      trackName: r['trackName'] as String?,
      artistName: r['artistName'] as String?,
      artworkUrlLow: lowRes,
      artworkUrlHigh: highRes,
      album: r['collectionName'] as String?,
      genre: r['primaryGenreName'] as String?,
      releaseYear: releaseYear,
      trackTimeMillis: (r['trackTimeMillis'] as num?)?.toInt(),
      previewUrl: r['previewUrl'] as String?,
      id: r['trackId']?.toString(),
    );

    print('[ItunesService] Parsed result: "${meta.trackName}" by "${meta.artistName}"');
    if (meta.artworkUrlHigh != null) {
      print('[ItunesService] Artwork HI: ${meta.artworkUrlHigh}');
    }

    return meta;
  }

  Future<String?> fetchArtistImage(String artistName, {bool highRes = true, String? artistViewUrl}) async {
    final cacheKey = 'artist_img|${highRes ? 'hi' : 'lo'}|${artistName.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      final meta = _cache[cacheKey];
      return meta?.artworkUrlHigh;
    }

    try {
      String? viewUrl = artistViewUrl;

      if (viewUrl == null || viewUrl.isEmpty) {
        // 1. Search for musicArtist directly (most accurate)
        final artistSearchResponse = await _dio.get(
          '$_itunesBase/search',
          queryParameters: {
            'term': artistName,
            'entity': 'musicArtist',
            'limit': 1,
          },
        );

        final dynamic artistSearchData = artistSearchResponse.data;
        Map<String, dynamic> artistSearchJson;
        if (artistSearchData is Map<String, dynamic>) {
          artistSearchJson = artistSearchData;
        } else if (artistSearchData is String) {
          artistSearchJson = jsonDecode(artistSearchData) as Map<String, dynamic>;
        } else {
          artistSearchJson = {};
        }

        final artistResults = (artistSearchJson['results'] as List<dynamic>?) ?? [];
        if (artistResults.isNotEmpty) {
          // Verify name match to avoid "wrong artist" issue
          for (final r in artistResults) {
            final name = r['artistName'] as String? ?? '';
            if (name.toLowerCase() == artistName.toLowerCase()) {
              viewUrl = r['artistLinkUrl'] as String? ?? r['artistViewUrl'] as String?;
              break;
            }
          }
          // Default to first result if no exact match but only if it's reasonably similar
          if (viewUrl == null) {
            final first = artistResults.first as Map<String, dynamic>;
            final firstName = first['artistName'] as String? ?? '';
            if (firstName.toLowerCase().contains(artistName.toLowerCase()) || 
                artistName.toLowerCase().contains(firstName.toLowerCase())) {
              viewUrl = first['artistLinkUrl'] as String? ?? first['artistViewUrl'] as String?;
            }
          }
        }
      }

      if (viewUrl == null || viewUrl.isEmpty) {
        // 2. Fallback to album search to get artistViewUrl
        final searchResponse = await _dio.get(
          '$_itunesBase/search',
          queryParameters: {
            'term': artistName,
            'entity': 'album',
            'limit': 5, // Check multiple to find correct artist
          },
        );

        final dynamic searchData = searchResponse.data;
        Map<String, dynamic> searchJson;

        if (searchData is Map<String, dynamic>) {
          searchJson = searchData;
        } else if (searchData is String) {
          searchJson = jsonDecode(searchData) as Map<String, dynamic>;
        } else {
          return null;
        }

        final results = (searchJson['results'] as List<dynamic>?) ?? [];
        if (results.isNotEmpty) {
          for (final r in results) {
            final name = r['artistName'] as String? ?? '';
            if (name.toLowerCase() == artistName.toLowerCase()) {
              viewUrl = r['artistViewUrl'] as String?;
              break;
            }
          }
        }
      }

      if (viewUrl == null || viewUrl.isEmpty) {
        // Fallback to standard song artwork logic if no artistViewUrl
        return _fetchFallbackArtistImage(artistName, cacheKey, highRes: highRes);
      }

      // 2. Fetch artist page HTML
      final htmlResponse = await _dio.get(
        viewUrl!,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      final html = htmlResponse.data as String;

      // 3. Extract og:image using regex
      final ogImageMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html);
      final ogImageUrl = ogImageMatch?.group(1);

      if (ogImageUrl != null && ogImageUrl.isNotEmpty) {
        // 4. Convert to requested resolution
        // Apple Music URLs can be tricky. We try to replace the resolution part.
        final targetRes = highRes ? '1024x1024bb.jpg' : '320x320bb.jpg';
        
        // Match things like /1200x630cw.png or /100x100bb.jpg
        final processedUrl = ogImageUrl.replaceAll(RegExp(r'/\d+x\d+[^/]+\.(jpg|png|jpeg)$'), '/$targetRes');
            
        print('[ItunesService] Scraped ${highRes ? 'HI' : 'LO'} artist image: $processedUrl');
        _cache[cacheKey] = ItunesMeta(artworkUrlHigh: processedUrl);
        return processedUrl;
      }
    } catch (e) {
      print('[ItunesService] Error scraping artist image: $e');
    }

    // Fallback to previous logic if scraping fails
    return _fetchFallbackArtistImage(artistName, cacheKey);
  }

  Future<String?> _fetchFallbackArtistImage(String artistName, String cacheKey, {bool highRes = true}) async {
    try {
      final response = await _dio.get(
        '$_itunesBase/search',
        queryParameters: {
          'term': artistName,
          'entity': 'album',
          'limit': 5,
          'media': 'music',
        },
      );

      final dynamic data = response.data;
      Map<String, dynamic> json;
      if (data is Map<String, dynamic>) {
        json = data;
      } else if (data is String) {
        json = jsonDecode(data) as Map<String, dynamic>;
      } else {
        return null;
      }

      final results = (json['results'] as List<dynamic>?) ?? [];
      if (results.isEmpty) return null;

      for (final r in results) {
        final name = r['artistName'] as String? ?? '';
        if (name.toLowerCase() == artistName.toLowerCase()) {
          final rawArtwork = r['artworkUrl100'] as String? ?? '';
          if (rawArtwork.isNotEmpty) {
            final resolution = highRes ? '1024x1024' : '320x320';
            final resultUrl = rawArtwork.replaceAll('100x100bb', '${resolution}bb').replaceAll('100x100', resolution);
            _cache[cacheKey] = ItunesMeta(artworkUrlHigh: resultUrl);
            return resultUrl;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Clears the in-memory cache (call on app restart if needed).
  void clearCache() => _cache.clear();
}
