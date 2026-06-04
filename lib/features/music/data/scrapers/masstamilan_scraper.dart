import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import '../music_models.dart';
import 'music_scraper.dart';

class MasstamilanScraper implements MusicScraper {
  final Dio _dio;
  final Dio _freshDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  ));

  MasstamilanScraper(this._dio);

  @override
  String get name => 'MassTamilan (320kbps)';

  @override
  Future<List<ScraperResult>> search(String query) async {
    return searchStream(query).toList();
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    try {
      final rawQuery = query.trim();
      if (rawQuery.isEmpty) return;

      final headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };
      
      const baseUrl = 'https://www.masstamilan.dev';

      // 1. Direct URL handling
      bool isUrl = rawQuery.startsWith('http') && rawQuery.contains('masstamilan');
      if (isUrl) {
         print('[Scraper] MassTamilan detected direct album URL: $rawQuery');
         final albumLinkMock = parser.parseFragment('<a href="$rawQuery"></a>').querySelector('a')!;
         final subResults = await _scrapeAlbum(albumLinkMock, baseUrl, '', headers);
         for (final r in subResults) {
           yield r;
         }
         return;
      }

      // 2. Normal keyword search
      final cleanQuery = query.replaceAll(RegExp(r'[&()"\\[\]]'), ' ')
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim();
      
      if (cleanQuery.isEmpty) return;
      
      final words = cleanQuery.split(' ');
      String searchKeyword = cleanQuery;
      if (words.length > 6) {
        searchKeyword = words.take(6).join(' ');
      }

      print('[Scraper] MassTamilan initializing search for keyword: "$searchKeyword"');
      
      final searchUrl = '$baseUrl/search?keyword=${Uri.encodeComponent(searchKeyword)}';
      
      print('[Scraper] MassTamilan search URL: $searchUrl');

      final response = await _freshDio.get(
        searchUrl, 
        options: Options(
          headers: headers,
          validateStatus: (status) => true,
        ),
      );
      
      if (response.statusCode != 200) {
        print('[Scraper] MassTamilan search failed: ${response.statusCode}');
        return;
      }
      
      final document = parser.parse(response.data);
      // More generic selector to find album links (anything pointing to -songs)
      final albumLinksRaw = document.querySelectorAll('a[href*="-songs"]');
      
      // Filter out duplicates and ensure we pick links with titles (likely albums)
      final uniqueAlbums = <String, dynamic>{};
      for (final link in albumLinksRaw) {
        final href = link.attributes['href'];
        if (href != null && !uniqueAlbums.containsKey(href)) {
          uniqueAlbums[href] = link;
        }
      }

      final albumList = uniqueAlbums.values.take(3).toList();
      print('[Scraper] MassTamilan found ${albumList.length} unique albums');
      
      if (albumList.isEmpty) {
        print('[Scraper] MassTamilan: No albums found in search results');
      }

      // Fetch all album pages concurrently
      final controller = StreamController<ScraperResult>();
      int pending = albumList.length;
      if (pending == 0) controller.close();

      for (final albumLink in albumList) {
        _scrapeAlbum(albumLink, baseUrl, cleanQuery, headers).then((subResults) {
          print('[Scraper] MassTamilan yielded ${subResults.length} songs from album: ${albumLink.attributes["href"]}');
          for (final r in subResults) {
            controller.add(r);
          }
        }).catchError((e) {
          print('[Scraper] MassTamilan album fetch error: $e');
        }).whenComplete(() {
          pending--;
          if (pending == 0) controller.close();
        });
      }

      yield* controller.stream;
    } catch (e) {
      print('[Scraper] MassTamilan search error: $e');
    }
  }

  Future<List<ScraperResult>> _scrapeAlbum(dynamic albumLink, String baseUrl, String cleanQuery, Map<String, String> headers) async {
    final results = <ScraperResult>[];
    final albumUrlSuffix = albumLink.attributes['href'];
    if (albumUrlSuffix == null) return results;
    
    final albumUrl = albumUrlSuffix.startsWith('http') 
        ? albumUrlSuffix 
        : '$baseUrl$albumUrlSuffix';
        
    String albumTitle = albumLink.attributes['title']?.replaceAll(' tamil songs download', '') ?? 
                       albumLink.querySelector('h2')?.text.trim() ?? 'Unknown Album';

    print('[Scraper] MassTamilan scraping album page: $albumUrl');

    final albumResponse = await _freshDio.get(
      albumUrl, 
      options: Options(
        headers: headers,
        validateStatus: (status) => true,
      ),
    );
    
    if (albumResponse.statusCode != 200) return results;
    
    final albumDoc = parser.parse(albumResponse.data);
    
    // If we couldn't get the title from the link (e.g. direct URL), try to get it from the page
    if (albumTitle == 'Unknown Album') {
      final h1 = albumDoc.querySelector('h1.page-title')?.text.trim() ?? 
                 albumDoc.querySelector('h1')?.text.trim() ?? 'Unknown Album';
      albumTitle = h1.replaceAll(' Tamil Songs', '').replaceAll(' Songs Download', '');
    }

    // Try to get thumbnail image from the album page (MassTamilan uses figure.ib img)
    final thumbnailImg = albumDoc.querySelector('figure.ib img') ?? 
                         albumDoc.querySelector('.info-wrapper img') ?? 
                         albumDoc.querySelector('img[alt*="poster"]') ??
                         albumDoc.querySelector('img[title*="Poster"]');
    final String? thumbnail = thumbnailImg?.attributes['src'] != null 
        ? (thumbnailImg!.attributes['src']!.startsWith('http') ? thumbnailImg.attributes['src'] : '$baseUrl${thumbnailImg.attributes['src']}')
        : null;

    final rows = albumDoc.querySelectorAll('#tl tr[itemprop="itemListElement"]');
    
    print('[Scraper] MassTamilan found ${rows.length} rows in #tl table');
    
    for (final row in rows) {
      String? songName = row.querySelector('span[itemprop="name"]')?.text.trim();
      
      // Secondary check for song name in dlink title if first one fails
      final dlinks = row.querySelectorAll('a.dlink');
      final dlink320 = dlinks.where((a) => a.attributes['href']?.contains('d320_cdn') ?? false).firstOrNull ??
                       dlinks.where((a) => a.attributes['href']?.contains('320') ?? false).firstOrNull;

      if (songName == null && dlink320 != null) {
        final titleAttr = dlink320.attributes['title'] ?? '';
        if (titleAttr.contains('Download ')) {
          songName = titleAttr.replaceAll('Download ', '').replaceAll(' 320kbps', '').trim();
        }
      }

      if (songName == null) continue;

      final songLower = songName.toLowerCase();
      final albumLower = albumTitle.toLowerCase();
      final queryWords = cleanQuery.toLowerCase().split(' ')
          .where((w) => w.length > 2)
          .toList();
      
      bool albumMatch = queryWords.isEmpty || queryWords.any((w) => albumLower.contains(w));
      bool keywordMatch = queryWords.isEmpty || queryWords.any((w) => songLower.contains(w));
      
      if (!keywordMatch && !albumMatch) continue;

      final singers = row.querySelector('span[itemprop="byArtist"]')?.text.trim();
      final href = dlink320?.attributes['href'];
      
      if (href != null) {
        results.add(ScraperResult(
          title: songName,
          artist: singers ?? 'Unknown Artist',
          url: href.startsWith('http') ? href : '$baseUrl$href',
          size: 0,
          format: 'MP3 (320kbps)',
          source: name,
          album: albumTitle,
          thumbnail: thumbnail,
        ));
      }
    }
    return results;
  }
}
