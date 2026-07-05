import 'package:dio/dio.dart';
import '../lyrics_models.dart';

abstract class LyricsScraper {
  Future<LyricsData?> getLyrics(String track, String artist, {String? album, int? durationMs});
}

class LrclibScraper implements LyricsScraper {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://lrclib.net',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  Future<LyricsData?> getLyrics(String track, String artist, {String? album, int? durationMs}) async {
    final cleanTrack = _cleanName(track);
    final cleanArtist = _cleanName(artist);

    try {
      final queryParams = {
        'track_name': cleanTrack,
        'artist_name': cleanArtist,
        if (album != null) 'album_name': album,
        if (durationMs != null) 'duration': (durationMs / 1000).round(),
      };

      // 1. Try exact match first
      final response = await _dio.get('/api/get', queryParameters: queryParams);

      if (response.statusCode == 200 && response.data != null) {
        return _parseResponse(response.data);
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Not found with exact match, try search fallback
        return _searchFallback(cleanTrack, cleanArtist, durationMs);
      }
      print('[LrclibScraper] Get Error: $e');
    }
    return null;
  }

  Future<LyricsData?> _searchFallback(String track, String artist, int? durationMs) async {
    try {
      final response = await _dio.get('/api/search', queryParameters: {
        'q': '$artist $track',
      });

      if (response.statusCode == 200 && response.data != null) {
        final List results = response.data;
        if (results.isEmpty) return null;

        // Try to find a good match in search results
        // 1. Same artist + same track (case insensitive)
        // 2. Nearest duration
        Map<String, dynamic>? bestMatch;
        
        for (final res in results) {
          final resTrack = (res['trackName'] as String).toLowerCase();
          final resArtist = (res['artistName'] as String).toLowerCase();
          
          if (resTrack.contains(track.toLowerCase()) || track.toLowerCase().contains(resTrack)) {
            bestMatch = res;
            break;
          }
        }
        
        bestMatch ??= results.first;
        return _parseResponse(bestMatch);
      }
    } catch (e) {
        print('[LrclibScraper] Search Fallback Error: $e');
    }
    return null;
  }

  LyricsData? _parseResponse(dynamic data) {
    if (data == null) return null;
    final map = data as Map<String, dynamic>;
    final syncedLrc = map['syncedLyrics'] as String?;
    final plainLyrics = map['plainLyrics'] as String?;

    if (syncedLrc != null && syncedLrc.isNotEmpty) {
      return LyricsData.fromLrc(syncedLrc, source: 'LRCLIB (Synced)');
    } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
      return LyricsData(
        plainLyrics: plainLyrics,
        source: 'LRCLIB (Plain)',
      );
    }
    return null;
  }

  String _cleanName(String name) {
    // Remove (Official Video), [HQ], (Taylor's Version), etc.
    return name
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '') // remove everything in () or []
        .split('feat.')[0] // remove features
        .split('ft.')[0]
        .trim();
  }
}

class LyricsOvhScraper implements LyricsScraper {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.lyrics.ovh',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  Future<LyricsData?> getLyrics(String track, String artist, {String? album, int? durationMs}) async {
    final cleanTrack = _cleanName(track);
    final cleanArtist = _cleanName(artist);

    if (cleanTrack.isEmpty || cleanArtist.isEmpty) return null;

    try {
      final response = await _dio.get('/v1/$cleanArtist/$cleanTrack');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final lyrics = data['lyrics'] as String?;
        if (lyrics != null && lyrics.isNotEmpty && !lyrics.startsWith('{')){
          return LyricsData(
            plainLyrics: lyrics,
            source: 'Lyrics.ovh',
          );
        }
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      print('[LyricsOvhScraper] Error: $e');
    }
    return null;
  }

  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .split('feat.')[0]
        .split('ft.')[0]
        .trim();
  }
}

