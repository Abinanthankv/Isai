import 'dart:convert';
import 'package:dio/dio.dart';
import '../lib/features/music/data/scrapers/spotify_canvas_resolver.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 10),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  },
));

void main() async {
  print('═══ Full pipeline: ISRC → DuckDuckGo → CanvasDownloader ═══');

  final resolver = SpotifyCanvasResolver();
  final testCases = [
    ('SZA', 'Kill Bill'),
    ('Taylor Swift', 'Anti-Hero'),
    ('The Weeknd', 'Blinding Lights'),
    ('Dua Lipa', 'Houdini'),
    ('Eminem', 'Mockingbird'),
  ];

  for (final (artist, track) in testCases) {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('  $artist - $track');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Step 1: Get ISRC from MusicBrainz
    var t0 = DateTime.now();
    var isrc = await resolver.getIsrcFromMusicBrainz(artist, track);
    if (isrc == null) {
      isrc = await resolver.getIsrcFromUnison(artist, track);
    }
    print('  ISRC: ${isrc ?? "❌ not found"} (${DateTime.now().difference(t0).inMilliseconds}ms)');

    if (isrc == null) {
      print('  ❌ Cannot proceed without ISRC');
      continue;
    }

    // Step 2: Search DuckDuckGo for "ISRC spotify"
    t0 = DateTime.now();
    final query = Uri.encodeComponent('"$isrc" spotify');
    try {
      final r = await _dio.post('https://html.duckduckgo.com/html',
        data: {'q': '"$isrc" spotify'},
        options: Options(contentType: Headers.formUrlEncodedContentType));
      
      final html = r.data.toString();
      final trackIds = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html)
          .map((m) => m.group(1)!).toSet().toList();
      final ddgMs = DateTime.now().difference(t0).inMilliseconds;

      if (trackIds.isEmpty) {
        print('  ❌ DuckDuckGo found no Spotify URLs (${ddgMs}ms)');
        continue;
      }
      print('  DuckDuckGo: found ${trackIds.length} track IDs (${ddgMs}ms)');

      // Step 3: Try canvasdownloader for each found ID
      for (final id in trackIds) {
        final spotifyUrl = 'https://open.spotify.com/track/$id';
        final encoded = Uri.encodeComponent(spotifyUrl);
        
        t0 = DateTime.now();
        try {
          final cResp = await _dio.get('https://www.canvasdownloader.com/canvas?link=$encoded');
          final html2 = cResp.data.toString();
          final canvasMatch = RegExp(r'source\s+src="([^"]+)"').firstMatch(html2);
          final canvasMs = DateTime.now().difference(t0).inMilliseconds;

          if (canvasMatch != null) {
            print('  ✅ Canvas found! track/$id (${canvasMs}ms)');
            print('     ${canvasMatch.group(1)}');
            break; // Found a canvas for this track
          } else if (html2.contains('Canvas not found')) {
            print('  ⚠️  track/$id: no canvas (${canvasMs}ms)');
          } else {
            print('  ⚠️  track/$id: unexpected response (${canvasMs}ms)');
          }
        } catch (e) {
          print('  ⚠️  track/$id: error - $e');
        }
      }
    } catch (e) {
      print('  ❌ DuckDuckGo error: $e');
    }
  }
}
