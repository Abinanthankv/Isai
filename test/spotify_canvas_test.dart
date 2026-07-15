import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../lib/features/music/data/scrapers/spotify_canvas_resolver.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  },
));

// Known popular tracks that likely have Canvas videos
final _tracks = [
  _Track('SZA', 'Kill Bill', '3OHfY25tqY28d16oZczHc8'),
  _Track('Taylor Swift', 'Anti-Hero', '1b6V01Yi9uGGhImCQHRMtf'),
  _Track('The Weeknd', 'Blinding Lights', '0VjIjW4GlUZAMYd2vXMi3b'),
  _Track('Olivia Rodrigo', 'vampire', '3k79jB4aGmMDUQzEf46Oxn'),
  _Track('Dua Lipa', 'Houdini', '2HYFX63wP3otK3J3cZGLqj'),
];

// Tracks unlikely to have Canvas (classical, obscure)
final _noCanvasTracks = [
  _Track('Ludwig van Beethoven', 'Symphony No. 5', ''),
  _Track('nonexistent', 'zzzzzzzz____invalid', ''),
];

void main() async {
  print('═══════════════════════════════════════════════════════');
  print('  Spotify Canvas Resolver Test Suite');
  print('═══════════════════════════════════════════════════════');

  await _testCurrentResolver();
  await _testPaxsenixApi();
  await _testDirectCanvasDownloader();
  await _testCanvasDownloaderSearch();

  print('\n═══════════════════════════════════════════════════════');
  print('  All tests completed.');
  print('═══════════════════════════════════════════════════════');
}

Future<void> _testCurrentResolver() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  TEST 1: Current SpotifyCanvasResolver (full pipeline)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final resolver = SpotifyCanvasResolver();

  for (final t in _tracks) {
    print('\n  --- ${t.artist} - ${t.track} ---');
    final t0 = DateTime.now();
    final url = await resolver.resolveCanvas(t.artist, t.track);
    final ms = DateTime.now().difference(t0).inMilliseconds;

    if (url != null) {
      print('  ✅ Canvas URL found (${ms}ms)');
      print('     ${url.length > 100 ? '${url.substring(0, 100)}...' : url}');
      await _verifyUrlWorks(url);
    } else {
      print('  ❌ No canvas found (${ms}ms)');
    }
  }

  // Test individual step latency
  print('\n  --- Step-by-step breakdown (SZA - Kill Bill) ---');
  await _testSteps(resolver, 'SZA', 'Kill Bill');
}

Future<void> _testSteps(SpotifyCanvasResolver resolver, String artist, String track) async {
  var t0 = DateTime.now();
  final isrc = await resolver.getIsrcFromUnison(artist, track);
  var ms = DateTime.now().difference(t0).inMilliseconds;
  print('  ISRC (Unison):     ${isrc ?? "❌"} (${ms}ms)');

  if (isrc == null) {
    t0 = DateTime.now();
    final isrc2 = await resolver.getIsrcFromMusicBrainz(artist, track);
    ms = DateTime.now().difference(t0).inMilliseconds;
    print('  ISRC (MusicBrainz): ${isrc2 ?? "❌"} (${ms}ms)');
  }

  if (isrc != null) {
    t0 = DateTime.now();
    final spotifyUrl = await resolver.getSpotifyUrl(isrc);
    ms = DateTime.now().difference(t0).inMilliseconds;
    print('  Spotify URL:        ${spotifyUrl ?? "❌"} (${ms}ms)');

    if (spotifyUrl != null) {
      t0 = DateTime.now();
      final canvas = await resolver.getCanvasVideo(spotifyUrl);
      ms = DateTime.now().difference(t0).inMilliseconds;
      print('  Canvas URL:         ${canvas != null ? "✅ (${ms}ms)" : "❌ (${ms}ms)"}');
    }
  }
}

Future<void> _testPaxsenixApi() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  TEST 2: Paxsenix0 Public API');
  print('  URL: https://api.paxsenix.biz.id/api/canvas');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  for (final t in _tracks) {
    if (t.id.isEmpty) continue;
    print('\n  --- ${t.artist} - ${t.track} (${t.id}) ---');
    final t0 = DateTime.now();
    try {
      final resp = await _dio.get(
        'https://api.paxsenix.biz.id/api/canvas',
        queryParameters: {'trackId': t.id},
      );
      final ms = DateTime.now().difference(t0).inMilliseconds;

      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data['data'] as Map?;
        final canvases = data?['canvasesList'] as List?;
        if (canvases != null && canvases.isNotEmpty) {
          final canvasUrl = canvases[0]['canvasUrl']?.toString();
          if (canvasUrl != null && canvasUrl.isNotEmpty) {
            print('  ✅ Canvas URL found (${ms}ms)');
            print('     ${canvasUrl.length > 100 ? '${canvasUrl.substring(0, 100)}...' : canvasUrl}');
            await _verifyUrlWorks(canvasUrl);
          } else {
            print('  ⚠️  Response has canvasesList but no canvasUrl (${ms}ms)');
          }
        } else {
          print('  ❌ No canvases in response (${ms}ms)');
          print('     Response: ${jsonEncode(resp.data).substring(0, 200)}');
        }
      } else {
        print('  ❌ HTTP ${resp.statusCode} (${ms}ms)');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }
}

Future<void> _testDirectCanvasDownloader() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  TEST 3: Direct CanvasDownloader.com (skip ISRC)');
  print('  URL: https://www.canvasdownloader.com/canvas?link=SPOTIFY_URL');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  for (final t in _tracks) {
    if (t.id.isEmpty) continue;
    final spotifyUrl = 'https://open.spotify.com/track/${t.id}';
    print('\n  --- ${t.artist} - ${t.track} ---');

    final t0 = DateTime.now();
    try {
      final resp = await _dio.get(
        'https://www.canvasdownloader.com/canvas',
        queryParameters: {'link': spotifyUrl},
      );
      final ms = DateTime.now().difference(t0).inMilliseconds;

      if (resp.statusCode == 200 && resp.data != null) {
        final html = resp.data.toString();
        // Try multiple regex patterns
        final patterns = [
          RegExp(r'source\s+src="([^"]+)"'),
          RegExp(r'<source\s+src="([^"]+)"'),
          RegExp(r'<video[^>]*>\s*<source\s+src="([^"]+)"'),
          RegExp(r'https?://canvaz\.scdn\.co\S+'),
        ];
        String? match;
        for (final p in patterns) {
          final m = p.firstMatch(html);
          if (m != null) {
            match = m.group(1) ?? m.group(0);
            break;
          }
        }

        if (match != null) {
          print('  ✅ Canvas URL found (${ms}ms)');
          print('     ${match.length > 100 ? '${match.substring(0, 100)}...' : match}');
          await _verifyUrlWorks(match.startsWith('http') ? match : 'https://$match');
        } else {
          print('  ❌ No canvas URL in HTML (${ms}ms)');
          // Show a snippet of HTML for debugging
          final snippet = html.length > 500 ? html.substring(0, 500) : html;
          print('     HTML snippet: ${snippet.replaceAll(RegExp(r'\s+'), ' ').trim()}');
        }
      } else {
        print('  ❌ HTTP ${resp.statusCode} (${ms}ms)');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }
}

Future<void> _testCanvasDownloaderSearch() async {
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  TEST 4: CanvasDownloader.com Search (artist page)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  for (final artist in ['Taylor Swift', 'The Weeknd']) {
    print('\n  --- Searching: $artist ---');
    final t0 = DateTime.now();
    try {
      final resp = await _dio.get(
        'https://www.canvasdownloader.com/search',
        queryParameters: {'q': artist},
      );
      final ms = DateTime.now().difference(t0).inMilliseconds;

      if (resp.statusCode == 200) {
        final html = resp.data.toString();
        // Look for track links
        final trackMatches = RegExp(r'/track/([a-zA-Z0-9]+)').allMatches(html);
        final uniqueIds = trackMatches.map((m) => m.group(1)!).toSet().toList();
        print('  ✅ Page loaded (${ms}ms), found ${uniqueIds.length} track IDs');
        for (final id in uniqueIds.take(5)) {
          print('     - https://open.spotify.com/track/$id');
        }
      } else {
        print('  ❌ HTTP ${resp.statusCode} (${ms}ms)');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
  }
}

Future<void> _verifyUrlWorks(String url) async {
  try {
    final t0 = DateTime.now();
    final req = await _dio.get(url, options: Options(
      responseType: ResponseType.stream,
      followRedirects: false,
    ));
    final ms = DateTime.now().difference(t0).inMilliseconds;
    final contentType = req.headers.value('content-type') ?? 'unknown';
    final contentLen = req.headers.value('content-length') ?? '?';
    print('     Status: ${req.statusCode}, Type: $contentType, Size: ${contentLen}B (${ms}ms)');
  } catch (e) {
    print('     ⚠️  Verify error: $e');
  }
}

class _Track {
  final String artist;
  final String track;
  final String id;
  const _Track(this.artist, this.track, this.id);
}
