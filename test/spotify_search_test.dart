import 'dart:convert';
import 'package:dio/dio.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: Duration(seconds: 15),
  receiveTimeout: Duration(seconds: 15),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  },
));

void main() async {
  print('═══ Search engine approaches for Spotify track IDs ═══');

  // Test 1: DuckDuckGo HTML search
  print('\n--- DuckDuckGo HTML search ---');
  for (final q in ['"SZA" "Kill Bill" spotify track', '"Taylor Swift" "Anti-Hero" spotify']) {
    print('\n  Query: $q');
    try {
      final r = await _dio.post('https://html.duckduckgo.com/html',
        data: {'q': q},
        options: Options(contentType: Headers.formUrlEncodedContentType));
      final html = r.data.toString();
      final ids = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html).map((m) => m.group(1)!).toSet().toList();
      print('  Status: ${r.statusCode}, Track IDs: ${ids.isNotEmpty ? ids.join(", ") : "none"}');
    } catch (e) { print('  Error: $e'); }
  }

  // Test 2: Use DuckDuckGo lite version  
  print('\n--- DuckDuckGo lite ---');
  for (final q in ['"SZA" "Kill Bill" spotify', '"Taylor Swift" "Anti-Hero" spotify']) {
    try {
      final r = await _dio.get('https://lite.duckduckgo.com/lite/', queryParameters: {'q': q});
      final html = r.data.toString();
      final ids = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html).map((m) => m.group(1)!).toSet().toList();
      print('  $q: ${ids.isNotEmpty ? ids.join(", ") : "none"} (${r.statusCode})');
    } catch (e) { print('  $q: Error - $e'); }
  }

  // Test 3: Bing search (no API key needed for basic scraping)
  print('\n--- Bing search ---');
  for (final q in ['"SZA" "Kill Bill" spotify track']) {
    try {
      final r = await _dio.get('https://www.bing.com/search', queryParameters: {'q': q});
      final html = r.data.toString();
      final ids = RegExp(r'/track/([a-zA-Z0-9]{22})').allMatches(html).map((m) => m.group(1)!).toSet().toList();
      print('  $q: ${ids.isNotEmpty ? ids.join(", ") : "none"} (${r.statusCode})');
      if (ids.isEmpty) {
        // Show first 300 chars of HTML
        print('  HTML: ${html.substring(0, 300).replaceAll(RegExp(r'\s+'), ' ')}');
      }
    } catch (e) { print('  $q: Error - $e'); }
  }

  // Test 4: Try to use the Spotify Config endpoint
  // The web player exposes some config
  print('\n--- Spotify Web API (no auth) ---');
  try {
    final r = await _dio.get('https://open.spotify.com/get_access_token');
    print('get_access_token: ${r.statusCode} - ${r.data.toString().substring(0, 200)}');
  } catch (e) { print('get_access_token: Error - $e'); }

  // Test 5: Use spotify.com's server-side rendered track page
  // Maybe we can search via a known pattern
  print('\n--- Known Spotify track page HTML check ---');
  try {
    final r = await _dio.get('https://open.spotify.com/track/3OHfY25tqY28d16oZczHc8');
    print('Track page: ${r.statusCode}, length: ${r.data.toString().length}');
    final html = r.data.toString();
    // Check for JSON-LD or server-side data
    for (final p in [
      RegExp(r'<script[^>]+type="application/ld\+json"[^>]*>(.+?)</script>', dotAll: true),
      RegExp(r'<script[^>]+id="__NEXT_DATA__"[^>]*>(.+?)</script>', dotAll: true),
    ]) {
      for (final m in p.allMatches(html)) {
        print('  Found data: ${m.group(1)!.substring(0, m.group(1)!.length.clamp(0, 300))}');
      }
    }
  } catch (e) { print('Error: $e'); }

  // Test 6: Try the Spotify web player's search suggestions endpoint (undocumented)
  print('\n--- Spotify search suggestions ---');
  try {
    final r = await _dio.get('https://open.spotify.com/search/track/headers',
      queryParameters: {'q': 'SZA Kill Bill'},
      options: Options(headers: {'Accept': 'application/json'}));
    print('Search suggestions: ${r.statusCode} - ${r.data.toString().substring(0, 200)}');
  } catch (e) { print('Search suggestions: Error - $e'); }
}
