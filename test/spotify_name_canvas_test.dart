import 'dart:convert';
import 'package:dio/dio.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 10),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  },
));

void main() async {
  print('═══ Name search → canvasdownloader pipeline ═══');

  final testCases = [
    ('SZA', 'Kill Bill', '3OHfY25tqY28d16oZczHc8'),
    ('Taylor Swift', 'Anti-Hero', '1b6V01Yi9uGGhImCQHRMtf'),
    ('The Weeknd', 'Blinding Lights', '0VjIjW4GlUZAMYd2vXMi3b'),
    ('Dua Lipa', 'Houdini', '2HYFX63wP3otK3J3cZGLqj'),
    ('Eminem', 'Mockingbird', '5CjA1gQ6eNIAN2UhnG7RAs'),
  ];

  for (final (artist, track, expectedId) in testCases) {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('  $artist - $track');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Search DuckDuckGo by name
    final t0 = DateTime.now();
    try {
      final r = await _dio.post('https://html.duckduckgo.com/html',
        data: {'q': '"$artist" "$track" spotify'},
        options: Options(contentType: Headers.formUrlEncodedContentType));
      
      final html = r.data.toString();
      final trackIds = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html)
          .map((m) => m.group(1)!).toSet().toList();
      final ms = DateTime.now().difference(t0).inMilliseconds;

      print('  DuckDuckGo: ${trackIds.length} IDs (${ms}ms)');
      
      var found = false;
      for (final id in trackIds) {
        final match = id == expectedId ? '✅' : '';
        
        // Try canvasdownloader
        final encoded = Uri.encodeComponent('https://open.spotify.com/track/$id');
        try {
          final cResp = await _dio.get('https://www.canvasdownloader.com/canvas?link=$encoded');
          final html2 = cResp.data.toString();
          final canvasMatch = RegExp(r'source\s+src="([^"]+)"').firstMatch(html2);

          if (canvasMatch != null) {
            print('  ✅ Canvas: track/$id $match');
            print('     ${canvasMatch.group(1)}');
            found = true;
            break;
          } else {
            print('  ⚠️  No canvas: track/$id $match');
          }
        } catch (e) {
          print('  ⚠️  Error: track/$id - $e');
        }
      }
      
      if (!found) {
        print('  ❌ No canvas found for any returned track ID');
      }
    } catch (e) {
      print('  ❌ DuckDuckGo error: $e');
    }
  }
}
