import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class TidalSquidScraper implements MusicScraper {
  final Dio _dio;

  TidalSquidScraper(this._dio);

  @override
  String get name => 'Tidal (via SquidWTF)';

  @override
  Future<List<ScraperResult>> search(String query) async {
    return searchStream(query).toList();
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return;
      print('[Scraper] Tidal initializing search for query: "$cleanQuery"');
      
      final searchResponse = await _dio.get(
        'https://triton.squid.wtf/search/',
        queryParameters: {'s': cleanQuery},
        options: Options(headers: {
          'x-client': 'BiniLossless/v3.4',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        }),
      );

      final dynamic responseData = searchResponse.data;
      Map<String, dynamic> parsedData = {};
      
      if (responseData is Map) {
        parsedData = responseData as Map<String, dynamic>;
      } else if (responseData is String) {
        try {
          parsedData = jsonDecode(responseData);
        } catch (_) {}
      }

      final items = parsedData['data']?['items'] as List<dynamic>? ?? [];
      print('[Scraper] Tidal found ${items.length} tracks for "$cleanQuery"');

      if (items.isEmpty) return;

      // Resolve all tracks concurrently for speed
      final controller = StreamController<ScraperResult>();
      int pending = items.length;

      for (final track in items) {
        _resolveTrack(track).then((result) {
          if (result != null) controller.add(result);
        }).catchError((e) {
          // Silently skip failed tracks
        }).whenComplete(() {
          pending--;
          if (pending == 0) controller.close();
        });
      }

      yield* controller.stream;
    } catch (e) {
      print('[Scraper] Tidal Squid error: $e');
    }
  }

  Future<ScraperResult?> _resolveTrack(dynamic track) async {
    final id = track['id'];
    final title = track['title'] ?? 'Unknown';
    final artist = (track['artists'] as List<dynamic>?)?.isNotEmpty == true 
        ? track['artists'][0]['name'] 
        : (track['artist']?['name'] ?? 'Unknown Artist');
    final album = track['album']?['title'] ?? 'Unknown Album';
    
    String? thumbnail;
    final coverUuid = track['album']?['cover'];
    if (coverUuid is String) {
      thumbnail = 'https://resources.tidal.com/images/${coverUuid.replaceAll('-', '/')}/640x640.jpg';
    }

    final trackResponse = await _dio.get(
      'https://triton.squid.wtf/track/',
      queryParameters: {
        'id': id,
        'quality': 'HI_RES_LOSSLESS',
      },
      options: Options(
        headers: {
          'x-client': 'BiniLossless/v3.4',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
        validateStatus: (s) => true,
      ),
    );
    
    if (trackResponse.statusCode != 200) return null;
    
    dynamic parsedTrackData = trackResponse.data;
    if (parsedTrackData is String) {
      try { parsedTrackData = jsonDecode(parsedTrackData); } catch (_) {}
    }
    
    String? manifestBase64;
    if (parsedTrackData is Map && parsedTrackData['data'] is Map) {
      manifestBase64 = parsedTrackData['data']['manifest'];
    }
    
    if (manifestBase64 == null) return null;

    final manifestJson = utf8.decode(base64.decode(manifestBase64));
    if (manifestJson.trim().startsWith('<')) return null;

    final manifest = jsonDecode(manifestJson);
    final url = manifest['urls']?[0];
    
    if (url == null) return null;

    return ScraperResult(
      title: title,
      artist: artist,
      url: url,
      size: 0,
      format: 'FLAC (Hi-Res)',
      source: name,
      album: album,
      thumbnail: thumbnail,
    );
  }
}

