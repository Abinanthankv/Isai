import 'dart:convert';
import 'package:dio/dio.dart';

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  },
));

void main() async {
  print('═══ CanvasDownloader API exploration ═══');

  // Test 1: Search for tracks by artist+name
  print('\n--- Search: SZA Kill Bill ---');
  final r1 = await _dio.get('https://www.canvasdownloader.com/api/search', queryParameters: {'q': 'SZA Kill Bill'});
  print('Status: ${r1.statusCode}');
  print(jsonEncode(r1.data));

  print('\n--- Search: Taylor Swift Anti-Hero ---');
  final r2 = await _dio.get('https://www.canvasdownloader.com/api/search', queryParameters: {'q': 'Taylor Swift Anti-Hero'});
  print('Status: ${r2.statusCode}');
  print(jsonEncode(r2.data));

  // Test 2: Get artist slug from search
  print('\n--- Get artist slug for SZA ---');
  final artistSearch = await _dio.get('https://www.canvasdownloader.com/api/search', queryParameters: {'q': 'SZA'});
  final data = artistSearch.data as Map;
  if (data['artists'] != null) {
    for (final a in data['artists'] as List) {
      final slug = a['slug'];
      print('  Artist: ${a['name']}, slug: $slug');
      
      // Try to get tracks for this artist
      if (slug != null) {
        print('\n--- Artist tracks: ${a['name']} ($slug) ---');
        try {
          final tracks = await _dio.get('https://www.canvasdownloader.com/api/artist/$slug/tracks');
          print('Status: ${tracks.statusCode}');
            print(jsonEncode(tracks.data));
        } catch (e) {
          print('Artist tracks failed: $e');
        }

        // Try other endpoints
        for (final ep in ['/api/artist/$slug', '/api/artist/$slug/canvases', '/api/artist?slug=$slug']) {
          try {
            final r = await _dio.get('https://www.canvasdownloader.com$ep');
            final s = jsonEncode(r.data);
            print('  $ep -> ${r.statusCode}: ${s.substring(0, s.length.clamp(0, 300))}');
          } catch (e) {
            print('  $ep -> Error');
          }
        }
      }
    }
  }

  // Test 3: Try to search tracks by track name (not artist)
  print('\n--- Search track directly: Anti-Hero ---');
  final r3 = await _dio.get('https://www.canvasdownloader.com/api/search', queryParameters: {'q': 'Anti-Hero Taylor'});
  print('Status: ${r3.statusCode}');
  print(jsonEncode(r3.data));

  // Test 4: What about just passing track+artist directly?
  // Maybe the site has a JS-rendered page that loads data from /api
  print('\n--- Page source for track page ---');
  final r4 = await _dio.get('https://www.canvasdownloader.com/track/3OHfY25tqY28d16oZczHc8');
  if (r4.statusCode == 200) {
    final html = r4.data.toString();
    // Look for any embedded JSON data
    final jsonMatches = RegExp(r'<script[^>]*>window\.__INITIAL_STATE__\s*=\s*({.+?})<').allMatches(html);
    for (final m in jsonMatches) {
      final s = m.group(1)!;
      print('  Found __INITIAL_STATE__: ${s.substring(0, s.length.clamp(0, 500))}');
    }
    // Look for any JSON-LD
    final jsonldMatches = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>({.+?})<').allMatches(html);
    for (final m in jsonldMatches) {
      final ld = m.group(1)!;
      print('  Found JSON-LD: ${ld.substring(0, ld.length.clamp(0, 500))}');
    }
  }
}
