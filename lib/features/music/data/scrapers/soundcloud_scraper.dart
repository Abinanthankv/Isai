import 'dart:async';
import 'package:dio/dio.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class SoundcloudScraper implements MusicScraper {
  final Dio _dio;
  
  // Dynamic client_id extracted from SoundCloud web client
  static const String _clientId = 'iuspDvaXDbD3AnFwLWK56Fk69q56xsKu';
  static const String _apiBase = 'https://api-v2.soundcloud.com';

  SoundcloudScraper(this._dio);

  @override
  String get name => 'SoundCloud';

  @override
  Future<List<ScraperResult>> search(String query) async {
    return searchStream(query).toList();
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return;

      print('[Scraper] SoundCloud searching for: "$cleanQuery"');

      final response = await _dio.get(
        '$_apiBase/search',
        queryParameters: {
          'q': cleanQuery,
          'client_id': _clientId,
          'limit': 15,
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      final collection = response.data['collection'] as List<dynamic>? ?? [];

      for (final item in collection) {
        if (item['kind'] != 'track') continue;

        try {
          final id = item['id'];
          final title = item['title']?.toString() ?? 'Unknown';
          final artist = item['user']?['username']?.toString() ?? 'Unknown Artist';
          
          // Image processing
          String? thumbnail = item['artwork_url'] ?? item['user']?['avatar_url'];
          // SoundCloud artwork is usually 100x100 (large), we want 500x500 (t500x500)
          if (thumbnail != null) {
            thumbnail = thumbnail.replaceAll('-large.', '-t500x500.');
          }

          final durationMs = (item['duration'] as num?)?.toInt() ?? 0;
          final duration = '${(durationMs ~/ 60000)}:${((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0')}';

          yield ScraperResult(
            title: title,
            artist: artist,
            url: id.toString(), // track_id for resolution
            size: 0,
            format: 'SoundCloud',
            source: name,
            thumbnail: thumbnail,
            linkType: 'soundcloud',
            duration: duration,
            extras: {
              'track_id': id,
              'full_duration_ms': durationMs,
              'permalink': item['permalink_url'],
              'track_authorization': item['track_authorization'],
            },
          );
        } catch (e) {
          print('[Scraper] SoundCloud item parse error: $e');
        }
      }
    } catch (e) {
      print('[Scraper] SoundCloud search error: $e');
    }
  }

  /// Resolves the final playable CDN URL for a SoundCloud track.
  Future<String?> resolveStreamUrl(String trackId, {String? trackAuthorization}) async {
    try {
      print('[Scraper] SoundCloud resolving stream for track ID: $trackId (auth: ${trackAuthorization != null})');
      
      // 1. Get track details to find transcodings
      // Note: We use the track_authorization token if available to avoid 404s on restricted tracks
      final trackResponse = await _dio.get(
        '$_apiBase/tracks/$trackId',
        queryParameters: {
          'client_id': _clientId,
          if (trackAuthorization != null) 'track_authorization': trackAuthorization,
        },
      );

      final transcodings = trackResponse.data['media']?['transcodings'] as List<dynamic>? ?? [];
      if (transcodings.isEmpty) return null;

      // 2. Find a progressive transcoding (easiest to play in many players)
      // Fallback to the first transcoding if no progressive found
      final transcoding = transcodings.firstWhere(
        (t) => t['format']?['protocol'] == 'progressive',
        orElse: () => transcodings.first,
      );

      final streamUrl = transcoding['url'];
      if (streamUrl == null) return null;

      // 3. Get the actual stream URL (CDN link)
      final mediaResponse = await _dio.get(
        streamUrl,
        queryParameters: {'client_id': _clientId},
      );

      final finalUrl = mediaResponse.data['url'] as String?;
      print('[Scraper] SoundCloud resolved URL: ${finalUrl?.split('?').first}');
      return finalUrl;
    } catch (e) {
      print('[Scraper] SoundCloud resolution error: $e');
      return null;
    }
  }
}
