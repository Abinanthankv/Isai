import 'package:dio/dio.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class InternetArchiveScraper implements MusicScraper {
  final Dio _dio;

  InternetArchiveScraper(this._dio);

  @override
  String get name => 'Internet Archive';

  @override
  Future<List<ScraperResult>> search(String query) async {
    return searchStream(query).toList();
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return;
      
      final response = await _dio.get(
        'https://archive.org/advancedsearch.php',
        queryParameters: {
          'q': 'title:($cleanQuery) AND format:(flac) AND mediatype:(audio)',
          'fl[]': ['identifier', 'title', 'creator'],
          'output': 'json',
          'rows': 5,
        },
      );

      final data = response.data;
      if (data == null || data['response'] == null) return;
      
      final docs = data['response']['docs'] as List<dynamic>? ?? [];

      final futures = docs.map((doc) async {
        final identifier = doc['identifier'];
        final title = doc['title']?.toString() ?? 'Unknown';
        final dynamic creatorRaw = doc['creator'];
        final String creator = (creatorRaw is List) 
            ? creatorRaw.join(', ') 
            : (creatorRaw?.toString() ?? 'Unknown Artist');

        try {
          final metaResponse = await _dio.get('https://archive.org/metadata/$identifier');
          final files = metaResponse.data['files'] as List<dynamic>? ?? [];
          
          final results = <ScraperResult>[];
          for (final file in files) {
            final fileName = file['name'] as String;
            final format = file['format'] as String;
            
            if (format.toLowerCase().contains('flac') && !fileName.contains('_vbr.mp3')) {
              final fileNameLower = fileName.toLowerCase();
              final queryWords = cleanQuery.toLowerCase().split(' ')
                  .where((w) => w.length > 2)
                  .toList();
              
              bool keywordMatch = queryWords.isEmpty || queryWords.any((w) => fileNameLower.contains(w));
              if (!keywordMatch) continue;

              results.add(ScraperResult(
                title: fileName.replaceAll('.flac', '').replaceAll('_', ' '),
                artist: creator,
                url: 'https://archive.org/download/$identifier/$fileName',
                size: int.tryParse(file['size']?.toString() ?? '0') ?? 0,
                format: 'FLAC',
                source: name,
                album: title,
                thumbnail: 'https://archive.org/services/img/$identifier',
              ));
            }
          }
          return results;
        } catch (e) {
          print('[Scraper] Archive metadata error for $identifier: $e');
          return <ScraperResult>[];
        }
      }).toList();

      final resultsList = await Future.wait(futures);
      for (final subResults in resultsList) {
        for (final res in subResults) {
          yield res;
        }
      }
    } catch (e) {
      print('[Scraper] Internet Archive error: $e');
    }
  }
}
