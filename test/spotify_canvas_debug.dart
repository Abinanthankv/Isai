import 'dart:io';
import 'package:dio/dio.dart';
import '../lib/features/music/data/scrapers/spotify_canvas_resolver.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  },
));

void main() async {
  final resolver = SpotifyCanvasResolver();
  final artist = 'SZA';
  final track = 'Kill Bill';

  // Step 1: ISRC from MusicBrainz
  var t0 = DateTime.now();
  final isrc = await resolver.getIsrcFromMusicBrainz(artist, track);
  print('ISRC: $isrc (${DateTime.now().difference(t0).inMilliseconds}ms)');

  // Step 2: Spotify URL from ISRC
  if (isrc != null) {
    t0 = DateTime.now();
    final spotifyUrl = await resolver.getSpotifyUrl(isrc);
    print('Spotify URL: $spotifyUrl (${DateTime.now().difference(t0).inMilliseconds}ms)');
    
    // Step 3: Canvas via canvasdownloader (with URL)
    if (spotifyUrl != null) {
      t0 = DateTime.now();
      final canvas = await resolver.getCanvasVideo(spotifyUrl);
      print('Canvas via canvasdownloader: $canvas (${DateTime.now().difference(t0).inMilliseconds}ms)');
    }
  }

  // Alternative: direct canvasdownloader with known track ID
  print('\n--- Direct canvasdownloader with known track ID ---');
  t0 = DateTime.now();
  final encoded = Uri.encodeComponent('https://open.spotify.com/track/3OHfY25tqY28d16oZczHc8');
  final resp = await _dio.get('https://www.canvasdownloader.com/canvas?link=$encoded');
  final html = resp.data.toString();
  final match = RegExp(r'source\s+src="([^"]+)"').firstMatch(html);
  print('Canvas URL: ${match?.group(1)} (${DateTime.now().difference(t0).inMilliseconds}ms)');

  // Test: search for track on Spotify (to get track ID from name)
  print('\n--- Spotify search for track ID ---');
  t0 = DateTime.now();
  try {
    final searchResp = await _dio.get(
      'https://api.spotify.com/v1/search',
      queryParameters: {
        'q': '$artist $track',
        'type': 'track',
        'limit': '1',
      },
    );
    print('Spotify API search: ${searchResp.statusCode} (${DateTime.now().difference(t0).inMilliseconds}ms)');
    print('Response: ${searchResp.data.toString().substring(0, 500)}');
  } catch (e) {
    print('Spotify API search failed (expected - needs auth): $e');
  }

  // Bonus: try the SpCanvas TOTP approach for reference
  print('\n--- Checking if canvasdownloader.com has an API ---');
  t0 = DateTime.now();
  try {
    final resp2 = await _dio.get('https://www.canvasdownloader.com/api/canvas', queryParameters: {
      'url': 'https://open.spotify.com/track/3OHfY25tqY28d16oZczHc8',
    });
    print('CanvasDownloader API: ${resp2.statusCode}');
    print('Response: ${resp2.data.toString().substring(0, 200)}');
  } catch (e) {
    print('CanvasDownloader API: Failed - $e');
  }
}
