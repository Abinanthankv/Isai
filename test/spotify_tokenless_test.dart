import 'dart:convert';
import 'package:dio/dio.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  },
));

final _tracks = [
  ('SZA', 'Kill Bill', '3OHfY25tqY28d16oZczHc8'),
  ('Taylor Swift', 'Anti-Hero', '1b6V01Yi9uGGhImCQHRMtf'),
  ('The Weeknd', 'Blinding Lights', '0VjIjW4GlUZAMYd2vXMi3b'),
  ('Dua Lipa', 'Houdini', '2HYFX63wP3otK3J3cZGLqj'),
  ('Eminem', 'Mockingbird', '5CjA1gQ6eNIAN2UhnG7RAs'),
];

void main() async {
  print('═══════════════════════════════════════════════════════');
  print('  Tokenless Spotify Track ID resolution');
  print('═══════════════════════════════════════════════════════');

  await _testSpotifySearch();
  await _testDuckDuckGo();
  await _testGoogleSearch();
  await _testCanvasDownloaderSearchPage();
}

Future<void> _testSpotifySearch() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  Method 1: open.spotify.com/search');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  for (final (artist, track, expected) in _tracks) {
    print('\n  --- $artist - $track ---');
    final t0 = DateTime.now();
    try {
      final q = Uri.encodeComponent('$artist $track');
      final resp = await _dio.get('https://open.spotify.com/search/$q',
        options: Options(followRedirects: true));
      final ms = DateTime.now().difference(t0).inMilliseconds;
      
      if (resp.statusCode == 200) {
        final html = resp.data.toString();
        
        // Look for track links in the format /track/22charId
        final trackMatches = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html);
        final ids = trackMatches.map((m) => m.group(1)!).toSet().toList();
        
        if (ids.isNotEmpty) {
          final found = ids.first;
          final match = found == expected ? '✅' : '⚠️';
          print('  $match Found: $found (expected: $expected) (${ms}ms)');
          if (ids.length > 1) {
            print('     All IDs: $ids');
          }
        } else {
          print('  ❌ No track IDs found (${ms}ms)');
          print('     HTML snippet: ${html.substring(0, 300).replaceAll(RegExp(r'\s+'), ' ')}');
        }
      } else {
        print('  ❌ HTTP ${resp.statusCode} (${ms}ms)');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }
}

Future<void> _testDuckDuckGo() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  Method 2: DuckDuckGo !sp shortcut');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  for (final (artist, track, expected) in _tracks) {
    print('\n  --- $artist - $track ---');
    final t0 = DateTime.now();
    try {
      final q = Uri.encodeComponent('site:open.spotify.com/track "$artist" "$track"');
      final resp = await _dio.get(
        'https://html.duckduckgo.com/html/',
        data: {'q': q},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
        ),
      );
      final ms = DateTime.now().difference(t0).inMilliseconds;

      if (resp.statusCode == 200) {
        final html = resp.data.toString();
        final trackMatches = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html);
        final ids = trackMatches.map((m) => m.group(1)!).toSet().toList();
        
        if (ids.isNotEmpty) {
          final found = ids.first;
          final match = found == expected ? '✅' : '⚠️';
          print('  $match Found: $found (expected: $expected) (${ms}ms)');
        } else {
          print('  ❌ No track IDs found (${ms}ms)');
        }
      } else {
        print('  ❌ HTTP ${resp.statusCode} (${ms}ms)');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }
}

Future<void> _testGoogleSearch() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  Method 3: Google search scraping');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  for (final (artist, track, expected) in _tracks.take(2)) {
    print('\n  --- $artist - $track ---');
    final t0 = DateTime.now();
    try {
      final q = Uri.encodeComponent('"$artist" "$track" spotify');
      final resp = await _dio.get(
        'https://www.google.com/search?q=$q&hl=en',
        options: Options(followRedirects: true),
      );
      final ms = DateTime.now().difference(t0).inMilliseconds;

      if (resp.statusCode == 200) {
        final html = resp.data.toString();
        final trackMatches = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html);
        final ids = trackMatches.map((m) => m.group(1)!).toSet().toList();
        
        if (ids.isNotEmpty) {
          final found = ids.first;
          final match = found == expected ? '✅' : '⚠️';
          print('  $match Found: $found (expected: $expected) (${ms}ms)');
        } else {
          print('  ❌ No track IDs found (${ms}ms)');
        }
      } else {
        print('  ❌ HTTP ${resp.statusCode} (${ms}ms)');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }
}

Future<void> _testCanvasDownloaderSearchPage() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  Method 4: CanvasDownloader internal search API');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  // Try various endpoints
  final endpoints = [
    '/api/search?q=SZA',
    '/api/tracks?q=SZA',
    '/search/SZA',
    '/search?artist=SZA',
    '/artists/SZA',
  ];

  for (final ep in endpoints) {
    try {
      final resp = await _dio.get('https://www.canvasdownloader.com$ep');
      print('  $ep -> ${resp.statusCode}');
      if (resp.statusCode == 200 && resp.data.toString().length > 100) {
        print('    Body: ${resp.data.toString().substring(0, 200).replaceAll(RegExp(r'\s+'), ' ')}');
      }
    } catch (e) {
      print('  $ep -> Error: ${e.runtimeType}');
    }
  }

  // Also try the artist pages that the homepage mentions
  print('\n  --- Try artist pages ---');
  for (final artist in ['taylor-swift', 'the-weeknd', 'sza']) {
    final t0 = DateTime.now();
    try {
      final resp = await _dio.get('https://www.canvasdownloader.com/artist/$artist');
      print('  /artist/$artist -> ${resp.statusCode} (${DateTime.now().difference(t0).inMilliseconds}ms)');
      if (resp.statusCode == 200) {
        final html = resp.data.toString();
        final trackMatches = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html);
        final ids = trackMatches.map((m) => m.group(1)!).toSet().toList();
        print('    Tracks found: ${ids.take(10).join(', ')}');
      }
    } catch (e) {
      print('  /artist/$artist -> Error: $e');
    }
  }
}
