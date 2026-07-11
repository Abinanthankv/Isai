import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../lyrics_models.dart';

abstract class LyricsScraper {
  Future<LyricsData?> getLyrics(String track, String artist, {String? album, int? durationMs});
}

class LrclibScraper implements LyricsScraper {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://lrclib.net',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
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
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
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

class KpoeScraper implements LyricsScraper {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const _kpoeServers = [
    'https://lyricsplus.binimum.org',
    'https://lyricsplus-seven.vercel.app',
    'https://lyricsplus.prjktla.workers.dev',
    'https://lyrics-plus-backend.vercel.app',
  ];

  @override
  Future<LyricsData?> getLyrics(String track, String artist, {String? album, int? durationMs}) async {
    if (track.isEmpty || artist.isEmpty) return null;

    // Try original name first, fall back to cleaned
    final attempts = [
      NameVariant(track, artist),
      NameVariant(_cleanName(track), _cleanName(artist)),
    ];

    for (final attempt in attempts) {
      // Try BiniLyrics cache proxy first
      try {
        final params = <String, dynamic>{
          'track': attempt.track,
          'artist': attempt.artist,
          if (album != null) 'album': album,
          if (durationMs != null && durationMs > 0) 'duration': (durationMs / 1000).round().toString(),
        };
        final response = await _dio.get('https://lyrics-api.binimum.org/', queryParameters: params);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data['results'] is List && (data['results'] as List).isNotEmpty) {
            final result = (data['results'] as List)[0] as Map<String, dynamic>;
            if (result['lyricsUrl'] != null) {
              final ttmlResponse = await _dio.get(result['lyricsUrl'].toString());
              if (ttmlResponse.statusCode == 200 && ttmlResponse.data != null) {
                final parsed = _parseTTML(ttmlResponse.data.toString());
                if (parsed != null) return parsed;
              }
            }
          }
        }
      } catch (_) {}

      // Fallback to KPoe mirrors
      for (final base in _kpoeServers) {
        try {
          final params = <String, String>{
            'title': attempt.track,
            'artist': attempt.artist,
            if (durationMs != null && durationMs > 0) 'duration': (durationMs / 1000).round().toString(),
            if (album != null) 'album': album,
          };
          final uri = Uri.parse('$base/v2/lyrics/get').replace(queryParameters: params);
          final response = await _dio.getUri(uri);
          if (response.statusCode == 200 && response.data != null) {
            final parsed = _parseKPoeResponse(response.data);
            if (parsed != null) return parsed;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  LyricsData? _parseTTML(String ttml) {
    try {
      final document = XmlDocument.parse(ttml);
      final lines = <LyricLine>[];
      final plainLines = <String>[];

      final pNodes = document.findAllElements('p');
      for (final p in pNodes) {
        final beginMs = _timeToMs(p.getAttribute('begin'));
        final endMs = _timeToMs(p.getAttribute('end'));
        if (beginMs == null) continue;

        final spans = p.findElements('span');
        final words = <LyricWord>[];
        final textParts = <String>[];

        if (spans.isNotEmpty) {
          for (final span in spans) {
            if (span.getAttribute('ttm:role') == 'x-bg') continue;
            if (span.parent is XmlElement &&
                (span.parent as XmlElement).getAttribute('ttm:role') == 'x-bg') continue;

            final wordBegin = _timeToMs(span.getAttribute('begin')) ?? beginMs;
            final wordEnd = _timeToMs(span.getAttribute('end')) ?? (endMs ?? beginMs + 5000);
            final wordText = span.innerText.trim();
            if (wordText.isEmpty) continue;

            textParts.add(wordText);
            words.add(LyricWord(
              start: Duration(milliseconds: wordBegin),
              end: Duration(milliseconds: wordEnd),
              text: wordText,
            ));
          }
        } else {
          final text = p.innerText.trim();
          if (text.isEmpty) continue;
          textParts.add(text);
          words.add(LyricWord(
            start: Duration(milliseconds: beginMs),
            end: Duration(milliseconds: endMs ?? beginMs + 5000),
            text: text,
          ));
        }

        final lineText = textParts.join(' ');
        lines.add(LyricLine(
          timestamp: Duration(milliseconds: beginMs),
          text: lineText,
          words: words,
        ));
        plainLines.add(lineText);
      }

      if (lines.isEmpty) return null;
      lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return LyricsData(
        syncedLines: lines,
        plainLyrics: plainLines.join('\n'),
        source: 'KPoe (Apple Music)',
      );
    } catch (_) {
      return null;
    }
  }

  LyricsData? _parseKPoeResponse(dynamic payload) {
    if (payload == null) return null;

    List<dynamic>? rawLyrics;
    String? source;
    String? sourceFromMetadata;

    if (payload is Map<String, dynamic>) {
      sourceFromMetadata = payload['metadata']?['source'] as String? ??
                           payload['metadata']?['provider'] as String?;

      if (payload['lyrics'] is List) {
        rawLyrics = payload['lyrics'] as List;
        source = sourceFromMetadata;
      } else if (payload['data'] is Map) {
        final data = payload['data'] as Map;
        source = data['metadata']?['source'] as String? ??
                 data['metadata']?['provider'] as String? ??
                 sourceFromMetadata;
        if (data['lyrics'] is List) {
          rawLyrics = data['lyrics'] as List;
        }
      } else if (payload['data'] is List) {
        rawLyrics = payload['data'] as List;
        source = sourceFromMetadata;
      }
    }

    if (rawLyrics == null || rawLyrics.isEmpty) return null;

    final lines = <LyricLine>[];
    final plainLines = <String>[];

    for (final entry in rawLyrics) {
      if (entry == null || entry is! Map) continue;

      final lineStart = _toMs(entry['time']) ?? 0;
      final lineDuration = _toMs(entry['duration']);
      final explicitEnd = _toMs(entry['endTime']);
      final lineEnd = explicitEnd ?? (lineStart + (lineDuration ?? 0));
      final lineText = entry['text'] as String? ?? '';

      List<dynamic>? syllabus;
      if (entry['syllabus'] is List) {
        syllabus = entry['syllabus'] as List;
      } else if (entry['words'] is List) {
        syllabus = entry['words'] as List;
      }

      final words = <LyricWord>[];

      if (syllabus != null && syllabus.isNotEmpty) {
        final currentWord = <Map<String, dynamic>>[];

        for (final syl in syllabus) {
          if (syl == null) continue;
          currentWord.add(syl as Map<String, dynamic>);

          if (syl['part'] != true) {
            final wordText = currentWord.map((s) => s['text'] as String? ?? '').join();
            final wordStart = _toMs(currentWord.first['time']) ?? lineStart;
            final lastSylEnd = _toMs(currentWord.last['time']) ?? 0;
            final lastDuration = _toMs(currentWord.last['duration']) ?? 0;
            final wordEnd = lastSylEnd + lastDuration;

            words.add(LyricWord(
              start: Duration(milliseconds: wordStart),
              end: Duration(milliseconds: wordEnd > 0 ? wordEnd : wordStart + 500),
              text: wordText,
            ));
            currentWord.clear();
          }
        }

        if (currentWord.isNotEmpty) {
          final wordText = currentWord.map((s) => s['text'] as String? ?? '').join();
          final wordStart = _toMs(currentWord.first['time']) ?? lineStart;
          words.add(LyricWord(
            start: Duration(milliseconds: wordStart),
            end: Duration(milliseconds: lineEnd > 0 ? lineEnd : wordStart + 500),
            text: wordText,
          ));
        }
      }

      if (lineText.isEmpty && words.isEmpty) continue;

      lines.add(LyricLine(
        timestamp: Duration(milliseconds: lineStart),
        text: lineText,
        words: words,
      ));
      if (lineText.isNotEmpty) plainLines.add(lineText);
    }

    if (lines.isEmpty) return null;
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sourceLabel = source != null ? 'KPoe ($source)' : 'KPoe';
    return LyricsData(
      syncedLines: lines,
      plainLyrics: plainLines.join('\n'),
      source: sourceLabel,
    );
  }

  static int? _toMs(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return _parseTimeStringMs(value);
    return null;
  }

  static int? _timeToMs(String? value) {
    if (value == null) return null;
    return _parseTimeStringMs(value);
  }

  static int? _parseTimeStringMs(String value) {
    // Try m:ss.SSS or mm:ss.SSS format
    final colonParts = value.split(':');
    if (colonParts.length == 2) {
      final minutes = int.tryParse(colonParts[0]);
      final seconds = double.tryParse(colonParts[1]);
      if (minutes != null && seconds != null) {
        return (minutes * 60 * 1000 + (seconds * 1000).round());
      }
    } else if (colonParts.length == 3) {
      final hours = int.tryParse(colonParts[0]);
      final minutes = int.tryParse(colonParts[1]);
      final seconds = double.tryParse(colonParts[2]);
      if (hours != null && minutes != null && seconds != null) {
        return (hours * 3600 * 1000 + minutes * 60 * 1000 + (seconds * 1000).round());
      }
    }
    // Try plain numeric string (seconds as float or int)
    final number = double.tryParse(value);
    if (number != null) return (number * 1000).round();
    return null;
  }

  static String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .split('feat.')[0]
        .split('ft.')[0]
        .trim();
  }
}

class NameVariant {
  final String track;
  final String artist;
  const NameVariant(this.track, this.artist);
}

