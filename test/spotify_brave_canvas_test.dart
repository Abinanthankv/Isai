import 'dart:convert';
import 'package:dio/dio.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 10),
  headers: {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  },
));

void main() async {
  print('═══ Brave Search → CanvasDownloader pipeline ═══\n');

  final testCases = [
    ('SZA', 'Kill Bill', '3OHfY25tqY28d16oZczHc8'),
    ('Taylor Swift', 'Anti-Hero', '1b6V01Yi9uGGhImCQHRMtf'),
    ('The Weeknd', 'Blinding Lights', '0VjIjW4GlUZAMYd2vXMi3b'),
    ('Dua Lipa', 'Houdini', '2HYFX63wP3otK3J3cZGLqj'),
    ('Eminem', 'Mockingbird', '5CjA1gQ6eNIAN2UhnG7RAs'),
    ('Olivia Rodrigo', 'vampire', '3k79jB4aGmMDUQzEf46Oxn'),
    ('Billie Eilish', 'bad guy', '2Fxmhks0bxGSBdJ92vM42m'),
    ('Kendrick Lamar', 'Not Like Us', '3kJth6Ws1I9G76qKOcMUTx'),
  ];

  int success = 0;
  int total = 0;

  for (final (artist, track, expectedId) in testCases) {
    total++;
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('  $artist - $track');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Step 1: Brave Search
    var t0 = DateTime.now();
    try {
      final r = await _dio.get('https://search.brave.com/search',
        queryParameters: {'q': '"$artist" "$track" spotify'});
      final html = r.data.toString();
      final trackIds = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html)
          .map((m) => m.group(1)!).toSet().toList();
      final searchMs = DateTime.now().difference(t0).inMilliseconds;
      
      final hasExpected = trackIds.contains(expectedId);
      print('  Brave: ${trackIds.length} IDs, got expected? $hasExpected (${searchMs}ms)');
      if (!hasExpected) {
        print('    Returned: ${trackIds.take(3).join(", ")}...');
        print('    Expected: $expectedId');
      }

      // Step 2: Try canvasdownloader for each ID
      var canvasFound = false;
      for (final id in trackIds) {
        final encoded = Uri.encodeComponent('https://open.spotify.com/track/$id');
        try {
          t0 = DateTime.now();
          final cResp = await _dio.get('https://www.canvasdownloader.com/canvas?link=$encoded');
          final html2 = cResp.data.toString();
          final canvasMatch = RegExp(r'source\s+src="([^"]+)"').firstMatch(html2);
          final canvasMs = DateTime.now().difference(t0).inMilliseconds;

          if (canvasMatch != null) {
            print('  ✅ Canvas: track/$id (${canvasMs}ms)');
            print('     ${canvasMatch.group(1)}');
            canvasFound = true;
            if (id == expectedId) success++;
            break;
          }
        } catch (_) {}
      }

      if (!canvasFound) {
        print('  ❌ No canvas found');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }

  print('\n════════════════════════════════════════════');
  print('  Results: $success/$total canvases found');
  print('════════════════════════════════════════════');
}
