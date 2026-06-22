import 'dart:convert';
import 'package:dio/dio.dart';

Future<void> main() async {
  print('==================================================');
  print('TESTING MULTI-PROVIDER TORRENT SCRAPING FOR AUDIOBOOKS');
  print('==================================================\n');

  final dio = Dio();
  
  // Set up search terms simulating an audiobook search
  const String bookTitle = 'The Hobbit';
  const String bookAuthor = 'Tolkien';
  
  // Add "audiobook" search modifier
  final String query = '$bookTitle $bookAuthor audiobook';
  final String refinedQuery = query.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), ' ');

  print('Search Query: "$refinedQuery"');
  print('Running concurrent index searches against: Apibay, BitSearch, and Knaben(RuTracker)...');
  print('--------------------------------------------------\n');

  // 1. Apibay Search
  Future<List<Map<String, dynamic>>> testApibay() async {
    try {
      final res = await dio.get('https://apibay.org/q.php', queryParameters: {'q': refinedQuery, 'cat': '0'});
      if (res.data is List) {
        return (res.data as List).take(3).map((item) => {
          'name': item['name'],
          'seeders': item['seeders'],
          'size': item['size'],
          'info_hash': item['info_hash'],
          'source': 'Apibay'
        }).toList();
      }
    } catch (e) {
      print('Apibay error: $e');
    }
    return [];
  }

  // 2. BitSearch Search
  Future<List<Map<String, dynamic>>> testBitSearch() async {
    try {
      final res = await dio.get(
        'https://bitsearch.to/api/v1/search',
        queryParameters: {'q': refinedQuery, 'category': 'audio', 'sort': 'seeders'},
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
      );
      if (res.data != null && res.data['success'] == true) {
        final List results = res.data['results'] ?? [];
        return results.take(3).map((item) => {
          'name': item['name'],
          'seeders': item['seeders'],
          'size': item['size'],
          'info_hash': item['info_hash'],
          'source': 'BitSearch'
        }).toList();
      }
    } catch (e) {
      print('BitSearch error: $e');
    }
    return [];
  }

  // 3. Knaben (RuTracker Proxy) Search
  Future<List<Map<String, dynamic>>> testKnaben() async {
    try {
      final res = await dio.get(
        'https://knaben.org/search/${Uri.encodeComponent(refinedQuery)}',
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
      );
      final html = res.data.toString();
      final results = <Map<String, dynamic>>[];
      final rowRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
      
      int count = 0;
      for (final match in rowRegex.allMatches(html)) {
        if (count >= 3) break;
        final rowHtml = match.group(1) ?? '';
        final magnetLinkRegex = RegExp(r'<a[^>]+href="(magnet:\?xt=[^"]+)"[^>]*>(.*?)</a>', dotAll: true, caseSensitive: false);
        final magnetLinkMatch = magnetLinkRegex.firstMatch(rowHtml);
        if (magnetLinkMatch == null) continue;
        
        final magnetLink = magnetLinkMatch.group(1) ?? '';
        final titleAttrRegex = RegExp(r'title="([^"]+)"', caseSensitive: false);
        final titleAttrMatch = titleAttrRegex.firstMatch(magnetLinkMatch.group(0)!);
        
        var name = titleAttrMatch?.group(1)?.trim() ?? '';
        if (name.isEmpty) {
          name = magnetLinkMatch.group(2)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? 'Unknown Knaben Result';
        }
        
        final tdRegex = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
        final tds = tdRegex.allMatches(rowHtml).map((m) => m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '').toList();
        
        int seeders = 0;
        String sizeStr = '0';
        if (tds.length >= 6) {
          sizeStr = tds[2];
          seeders = int.tryParse(tds[4]) ?? 0;
        }

        results.add({
          'name': name,
          'seeders': seeders,
          'size': sizeStr,
          'magnet': magnetLink,
          'source': 'Knaben'
        });
        count++;
      }
      return results;
    } catch (e) {
      print('Knaben error: $e');
    }
    return [];
  }

  // Execute concurrently
  final allSearches = await Future.wait([testApibay(), testBitSearch(), testKnaben()]);
  final apibayList = allSearches[0];
  final bitsearchList = allSearches[1];
  final knabenList = allSearches[2];

  print('=== APIBAY RESULTS ===');
  if (apibayList.isEmpty) print('No results.');
  for (var r in apibayList) {
    print('Title: ${r['name']}');
    print('Seeders: ${r['seeders']} | Size: ${r['size']} bytes\n');
  }

  print('=== BITSEARCH RESULTS ===');
  if (bitsearchList.isEmpty) print('No results.');
  for (var r in bitsearchList) {
    print('Title: ${r['name']}');
    print('Seeders: ${r['seeders']} | Size: ${r['size']} bytes\n');
  }

  print('=== KNABEN RESULTS ===');
  if (knabenList.isEmpty) print('No results.');
  for (var r in knabenList) {
    print('Title: ${r['name']}');
    print('Seeders: ${r['seeders']} | Size: ${r['size']}\n');
  }
}
