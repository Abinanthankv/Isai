import 'package:dio/dio.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class JioSaavnScraper implements MusicScraper {
  final Dio _dio;

  JioSaavnScraper(this._dio);

  @override
  String get name => 'JioSaavn';

  @override
  Future<List<ScraperResult>> search(String query) async {
    return searchStream(query).toList();
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return;

      print('[Scraper] JioSaavn searching for: "$cleanQuery"');

      // Using a valid Vercel instance that exposes properly decrypted MP4 CDN links
      final response = await _dio.get(
      //  'https://jiosaavn-api-privatecvc2.vercel.app/search/songs',
     'https://saavn.sumit.co/api/search/songs',
        queryParameters: {'query': cleanQuery},
      );

      final data = response.data;
      if (data == null) return;
      
      // Handle both {success: true, data: {results: []}} and direct {results: []}
      // Also handle {"status":"SUCCESS","data":{"results":[]}}
      final bool isVercelFormat = (data['success'] == true || data['status'] == 'SUCCESS') && data['data'] != null;
      final results = isVercelFormat 
          ? (data['data']['results'] as List<dynamic>? ?? [])
          : (data['results'] as List<dynamic>? ?? []);

      for (final item in results) {
        try {
          final title = item['name']?.toString() ?? 'Unknown';
          
          // Primary artists can be a string (Vercel) or a list (Sumit API)
          String artist = 'Unknown Artist';
          final primaryArtistsRaw = item['primaryArtists'];
          if (primaryArtistsRaw is String) {
            artist = primaryArtistsRaw;
          } else if (item['artists']?['primary'] is List) {
            final List<dynamic> paList = item['artists']['primary'];
            artist = paList.map((a) => a['name']?.toString() ?? 'Unknown').join(', ');
          }

          final albumData = item['album'];
          final String albumName = (albumData is Map) 
              ? (albumData['name']?.toString() ?? '')
              : (albumData?.toString() ?? '');

          // Find the best quality image (500x500)
          final images = item['image'] as List<dynamic>? ?? [];
          // Use 'link' first (Vercel format), then fallback to 'url'
          String? thumbnail = images.isNotEmpty ? (images.last['link'] ?? images.last['url']) : null;
          
          for (final img in images) {
            if (img['quality'] == '500x500') {
              thumbnail = img['link'] ?? img['url'];
              break;
            }
          }

          // Find the best quality download URL (320kbps)
          final downloadUrls = item['downloadUrl'] as List<dynamic>? ?? [];
          String? downloadUrl;
          String qualityStr = '160kbps';

          // Try to find 320kbps first
          for (final d in downloadUrls) {
            if (d['quality'] == '320kbps') {
              downloadUrl = d['link'] ?? d['url'];
              qualityStr = '320kbps';
              break;
            }
          }
          
          // Fallback to 160kbps or the last one
          if (downloadUrl == null) {
            for (final d in downloadUrls) {
              if (d['quality'] == '160kbps') {
                downloadUrl = d['link'] ?? d['url'];
                qualityStr = '160kbps';
                break;
              }
            }
            downloadUrl ??= downloadUrls.isNotEmpty ? (downloadUrls.last['link'] ?? downloadUrls.last['url']) : null;
          }

          if (downloadUrl == null) continue;

          final durationSecsRaw = item['duration'];
          final durationSecs = durationSecsRaw is int 
              ? durationSecsRaw 
              : int.tryParse(durationSecsRaw?.toString() ?? '0') ?? 0;
          final duration = '${(durationSecs ~/ 60)}:${(durationSecs % 60).toString().padLeft(2, '0')}';

          yield ScraperResult(
            title: title,
            artist: artist,
            url: downloadUrl,
            size: 0, 
            format: 'AAC:$qualityStr',
            source: name,
            album: albumName,
            thumbnail: thumbnail,
            linkType: 'jiosaavn',
            duration: duration,
            extras: {
              'id': item['id'],
              'year': item['year'],
            },
          );
        } catch (e) {
          print('[Scraper] JioSaavn item parse error: $e');
        }
      }
    } catch (e) {
      print('[Scraper] JioSaavn error: $e');
    }
  }
}
