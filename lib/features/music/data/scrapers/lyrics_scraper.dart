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

class UnisonScraper implements LyricsScraper {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://unison.boidu.dev',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  Future<LyricsData?> getLyrics(String track, String artist, {String? album, int? durationMs}) async {
    final cleanTrack = _cleanName(track);
    final cleanArtist = _cleanName(artist);
    final durationSeconds = durationMs != null ? (durationMs / 1000).round() : null;

    try {
      final response = await _dio.get(
        '/lyrics',
        queryParameters: {
          'song': cleanTrack,
          'artist': cleanArtist,
          if (album != null) 'album': album,
          if (durationSeconds != null) 'duration': durationSeconds,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final res = response.data as Map<String, dynamic>;
        if (res['success'] == true && res['data'] != null) {
          final data = res['data'] as Map<String, dynamic>;
          final format = data['format'] as String? ?? 'plain';
          final lyricsText = data['lyrics'] as String? ?? '';
          final syncType = data['syncType'] as String? ?? 'plain';

          if (lyricsText.isEmpty) return null;

          if (format == 'ttml' || syncType == 'richsync') {
            final lines = <LyricLine>[];
            final pRegExp = RegExp(r'<p\s+[^>]*begin="([^"]+)"[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true);
            final spanRegExp = RegExp(r'<span\s+[^>]*begin="([^"]+)"\s+end="([^"]+)"[^>]*>(.*?)</span>', caseSensitive: false, dotAll: true);
            
            for (final match in pRegExp.allMatches(lyricsText)) {
              final ts = match.group(1)!;
              final content = match.group(2)!;
              final cleanText = content
                  .replaceAll(RegExp(r'<[^>]*>'), '')
                  .replaceAll('&amp;', '&')
                  .replaceAll('&#39;', "'")
                  .replaceAll('&quot;', '"')
                  .trim();
              
              final words = <LyricWord>[];
              for (final spanMatch in spanRegExp.allMatches(content)) {
                try {
                  final wordStart = _parseTtmlTimestamp(spanMatch.group(1)!);
                  final wordEnd = _parseTtmlTimestamp(spanMatch.group(2)!);
                  final wordText = spanMatch.group(3)!
                      .replaceAll(RegExp(r'<[^>]*>'), '')
                      .replaceAll('&amp;', '&')
                      .replaceAll('&#39;', "'")
                      .replaceAll('&quot;', '"')
                      .trim();
                  words.add(LyricWord(start: wordStart, end: wordEnd, text: wordText));
                } catch (e) {
                  // Ignore single span parsing error
                }
              }
              
              try {
                final duration = _parseTtmlTimestamp(ts);
                lines.add(LyricLine(timestamp: duration, text: cleanText, words: words));
              } catch (e) {
                print('[UnisonScraper] Timestamp parse error: $e');
              }
            }

            if (lines.isNotEmpty) {
              return LyricsData(
                syncedLines: lines,
                plainLyrics: lines.map((l) => l.text).join('\n'),
                source: 'Unison (Synced)',
              );
            }
          } else if (format == 'lrc' || syncType == 'linesync') {
            return LyricsData.fromLrc(lyricsText, source: 'Unison (Synced)');
          }

          // Fallback to plain
          return LyricsData(
            plainLyrics: lyricsText,
            source: 'Unison (Plain)',
          );
        }
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          print('[UnisonScraper] Lyrics not found (404)');
        } else {
          print('[UnisonScraper] Network Error: ${e.message}');
        }
      } else {
        print('[UnisonScraper] Error: $e');
      }
    }
    return null;
  }

  Duration _parseTtmlTimestamp(String ts) {
    final parts = ts.split(':');
    if (parts.length == 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secondsParts = parts[2].split('.');
      final seconds = int.parse(secondsParts[0]);
      final ms = secondsParts.length > 1 ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) : 0;
      return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: ms);
    } else if (parts.length == 2) {
      final minutes = int.parse(parts[0]);
      final secondsParts = parts[1].split('.');
      final seconds = int.parse(secondsParts[0]);
      final ms = secondsParts.length > 1 ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) : 0;
      return Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
    } else {
      final secondsParts = ts.split('.');
      final seconds = int.parse(secondsParts[0]);
      final ms = secondsParts.length > 1 ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) : 0;
      return Duration(seconds: seconds, milliseconds: ms);
    }
  }

  String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .split('feat.')[0]
        .split('ft.')[0]
        .trim();
  }
}

