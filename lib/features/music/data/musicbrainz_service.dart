import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class MusicBrainzService {
  final Dio _dio;
  static const _baseUrl = 'https://musicbrainz.org/ws/2';

  MusicBrainzService(this._dio);

  Future<Map<String, dynamic>?> getArtistInfo(String artistName) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/artist',
        queryParameters: {
          'query': 'artist:$artistName',
          'fmt': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          },
        ),
      );

      final artists = response.data['artists'] as List<dynamic>?;
      if (artists == null || artists.isEmpty) return null;

      // Find best match
      final artist = artists.firstWhere(
        (a) => (a['name'] as String).toLowerCase() == artistName.toLowerCase(),
        orElse: () => artists.first,
      );

      final mbid = artist['id'] as String;
      
      // Get detailed info with relations
      final detailResponse = await _dio.get(
        '$_baseUrl/artist/$mbid',
        queryParameters: {
          'inc': 'url-rels+tags+area-rels+artist-rels',
          'fmt': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( abinanthan@gmail.com )',
          },
        ),
      );

      final data = detailResponse.data as Map<String, dynamic>;
      
      // Try to find Wikipedia and Wikidata links
      String? wikipediaTitle;
      String? wikidataId;
      
      final relations = data['relations'] as List<dynamic>?;
      if (relations != null) {
        for (final rel in relations) {
          if (rel['target-type'] == 'url') {
            final url = rel['url']?['resource'] as String? ?? '';
            if (rel['type'] == 'wikipedia' && url.contains('wikipedia.org/wiki/')) {
              wikipediaTitle = Uri.decodeComponent(url.split('/').last);
            } else if (rel['type'] == 'wikidata' && url.contains('wikidata.org/wiki/')) {
              wikidataId = url.split('/').last;
            }
          }
        }
      }

      // Fetch Wikipedia biography if available
      if (wikipediaTitle != null) {
        try {
          final wikiResponse = await _dio.get(
            'https://en.wikipedia.org/w/api.php',
            queryParameters: {
              'action': 'query',
              'prop': 'extracts',
              'exintro': '1',
              'explaintext': '1',
              'titles': wikipediaTitle,
              'format': 'json',
              'redirects': '1',
            },
          );
          final pages = wikiResponse.data['query']?['pages'] as Map<String, dynamic>?;
          if (pages != null && pages.isNotEmpty) {
            final page = pages.values.first;
            data['biography'] = page['extract'];
          }
        } catch (e) {
          print('[MusicBrainz] Wikipedia fetch error: $e');
        }
      }

      // Fetch Wikidata image if available
      if (wikidataId != null) {
        try {
          final wikidataResponse = await _dio.get(
            'https://www.wikidata.org/w/api.php',
            queryParameters: {
              'action': 'wbgetentities',
              'ids': wikidataId,
              'props': 'claims',
              'format': 'json',
            },
          );
          final entities = wikidataResponse.data['entities'] as Map<String, dynamic>?;
          if (entities != null && entities[wikidataId] != null) {
            final claims = entities[wikidataId]['claims'] as Map<String, dynamic>?;
            final imageClaim = claims?['P18'] as List<dynamic>?;
            if (imageClaim != null && imageClaim.isNotEmpty) {
              final imageName = imageClaim.first['mainsnak']?['datavalue']?['value'] as String?;
              if (imageName != null) {
                // Convert to Wikimedia Commons URL
                final encodedName = Uri.encodeComponent(imageName.replaceAll(' ', '_'));
                data['wikidata_image'] = 'https://commons.wikimedia.org/wiki/Special:FilePath/$encodedName?width=1000';
              }
            }
          }
        } catch (e) {
          print('[MusicBrainz] Wikidata fetch error: $e');
        }
      }

      return data;
    } catch (e) {
      print('[MusicBrainz] Error: $e');
      return null;
    }
  }
}
