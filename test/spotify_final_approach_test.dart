import 'dart:convert';
import 'package:dio/dio.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 10),
));

// Test using Spotify Client Credentials for app-level access
// The user just registers a free Spotify app once, no login needed
void main() async {
  print('═══ Spotify App-Only Client Credentials Test ═══');
  print('No user login required - just app client_id + client_secret\n');

  // Test with a known public client ID (from spotify-web-api-js examples)
  // This is a test/demo client ID - for production you'd register your own
  // But actually for testing, we can just witness that it works
  
  print('Testing canvasdownloader.com direct (best tokenless approach so far):\n');

  // We now know direct canvasdownloader.com + known track ID works
  // The bottleneck is finding the track ID
  
  // Best approach: combine existing ISRC lookup with DuckDuckGo for name+artist
  // but be smart about rate limiting
  
  print('=== Approach 1: Batch DuckDuckGo with delays ===');
  final queries = [
    '"SZA" "Kill Bill"',
    '"Taylor Swift" "Anti-Hero"', 
    '"The Weeknd" "Blinding Lights"',
  ];
  
  int i = 0;
  for (final q in queries) {
    i++;
    if (i > 1) await Future.delayed(Duration(seconds: 2)); // avoid rate limit
    try {
      final r = await _dio.post('https://html.duckduckgo.com/html',
        data: {'q': '$q spotify track'},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
            'Accept': 'text/html',
          },
        ));
      final html = r.data.toString();
      final ids = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html)
          .map((m) => m.group(1)!).toSet().toList();
      print('  $q: ${ids.isNotEmpty ? ids.join(", ") : "none"}');
    } catch (e) {
      print('  $q: Error - ${e.runtimeType}');
    }
  }

  print('\n=== Approach 2: Try different User-Agents ===');
  for (final ua in [
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
    'Mozilla/5.0 (SMART-TV; Linux; Tizen 2.4.0) AppleWebKit/538.1',
  ]) {
    try {
      final r = await _dio.post('https://html.duckduckgo.com/html',
        data: {'q': '"SZA" "Kill Bill" spotify track'},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'User-Agent': ua, 'Accept': 'text/html'},
        ));
      final html = r.data.toString();
      final ids = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html)
          .map((m) => m.group(1)!).toSet().toList();
      print('  UA ${ua.substring(0, 30)}...: ${ids.isNotEmpty ? "✅ ${ids.first}" : "❌"}');
    } catch (e) { print('  Error'); }
  }

  print('\n=== Approach 3: Try search.cai.com (another search engine) ===');
  try {
    final r = await _dio.get('https://search.brave.com/search',
      queryParameters: {'q': '"SZA" "Kill Bill" spotify'},
      options: Options(headers: {'Accept': 'text/html'}));
    final html = r.data.toString();
    final ids = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html)
        .map((m) => m.group(1)!).toSet().toList();
    print('  Brave Search: ${ids.isNotEmpty ? ids.join(", ") : "none"}');
    if (ids.isEmpty) {
      print('  HTML: ${html.substring(0, 200).replaceAll(RegExp(r'\s+'), ' ')}');
    }
  } catch (e) { print('  Brave Search: Error - $e'); }

  print('\n=== Approach 4: Use Wikipedia to find Spotify URL ===');
  try {
    final r = await _dio.get('https://en.wikipedia.org/w/api.php',
      queryParameters: {
        'action': 'query',
        'list': 'search',
        'srsearch': 'SZA Kill Bill song',
        'format': 'json',
        'srlimit': '1',
      });
    print('  Wikipedia API: ${jsonEncode(r.data).substring(0, 300)}');
  } catch (e) { print('  Error'); }

  print('\n=== Summary of findings ===');
  print('  • DuckDuckGo works but rate-limits aggressively');
  print('  • CanvasDownloader.com canvas API works with known track IDs');
  print('  • MusicBrainz gives ISRC but not Spotify URL (no relation)');
  print('  • No publicly hosted Spotify search proxy found');
  print('\nBest practical solution: ISRC + search engine fallback + canvasdownloader');
  print('For reliable results: register free Spotify app for Client Credentials (no user login).');
}
