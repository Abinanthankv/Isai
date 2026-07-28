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

      final artist = artists.firstWhere(
        (a) => (a['name'] as String).toLowerCase() == artistName.toLowerCase(),
        orElse: () => artists.first,
      );

      final mbid = artist['id'] as String;
      
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

  Future<List<Map<String, String>>> getArtistAlbums(String artistName) async {
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
      if (artists == null || artists.isEmpty) return [];
      final artist = artists.firstWhere(
        (a) => (a['name'] as String).toLowerCase() == artistName.toLowerCase(),
        orElse: () => artists.first,
      );
      final mbid = artist['id'] as String;

      final rgResponse = await _dio.get(
        '$_baseUrl/release-group',
        queryParameters: {
          'artist': mbid,
          'type': 'album',
          'limit': '25',
          'fmt': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          },
        ),
      );
      final groups = rgResponse.data['release-groups'] as List<dynamic>? ?? [];
      final albums = await Future.wait(groups.map((g) async {
        final rgid = g['id'] as String? ?? '';
        final coverUrl = await _getCoverArtUrl(rgid);
        return {
          'id': rgid,
          'title': g['title'] as String? ?? '',
          'releaseDate': g['first-release-date'] as String? ?? '',
          'coverUrl': coverUrl,
        };
      }));
      return albums;
    } catch (e) {
      print('[MusicBrainz] getArtistAlbums error: $e');
      return [];
    }
  }

  Future<String> _getCoverArtUrl(String releaseGroupId) async {
    try {
      final coverResponse = await _dio.get(
        'https://coverartarchive.org/release-group/$releaseGroupId/front',
        options: Options(
          followRedirects: false,
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          },
        ),
      );
      if (coverResponse.statusCode == 307 || coverResponse.statusCode == 302) {
        return coverResponse.headers.value('location') ?? '';
      }
      return 'https://coverartarchive.org/release-group/$releaseGroupId/front';
    } catch (e) {
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> getAlbumTracks(String artistName, String albumTitle) async {
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
      if (artists == null || artists.isEmpty) return [];
      final artist = artists.firstWhere(
        (a) => (a['name'] as String).toLowerCase() == artistName.toLowerCase(),
        orElse: () => artists.first,
      );
      final artistMbid = artist['id'] as String;

      final rgResponse = await _dio.get(
        '$_baseUrl/release-group',
        queryParameters: {
          'artist': artistMbid,
          'query': 'releasegroup:$albumTitle',
          'limit': '5',
          'fmt': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          },
        ),
      );
      final rgs = rgResponse.data['release-groups'] as List<dynamic>? ?? [];
      Map<String, dynamic>? matched;
      for (final rg in rgs) {
        if ((rg['title'] as String).toLowerCase() == albumTitle.toLowerCase()) {
          matched = rg as Map<String, dynamic>;
          break;
        }
      }
      if (matched == null && rgs.isNotEmpty) matched = rgs.first as Map<String, dynamic>;
      if (matched == null) return [];

      final releaseResp = await _dio.get(
        '$_baseUrl/release',
        queryParameters: {
          'release-group': matched['id'],
          'limit': '1',
          'fmt': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          },
        ),
      );
      final releases = releaseResp.data['releases'] as List<dynamic>? ?? [];
      if (releases.isEmpty) return [];

      final releaseId = releases.first['id'] as String;
      final detailResp = await _dio.get(
        '$_baseUrl/release/$releaseId',
        queryParameters: {
          'inc': 'recordings',
          'fmt': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          },
        ),
      );
      final tracks = <Map<String, dynamic>>[];
      final media = detailResp.data['media'] as List<dynamic>? ?? [];
      for (final m in media) {
        final trackList = m['tracks'] as List<dynamic>? ?? [];
        for (final t in trackList) {
          final rec = t['recording'] as Map<String, dynamic>? ?? {};
          tracks.add({
            'position': t['position'],
            'title': rec['title'] ?? t['title'] ?? '',
            'length': rec['length'] ?? t['length'] ?? 0,
          });
        }
      }
      return tracks;
    } catch (e) {
      print('[MusicBrainz] getAlbumTracks error: $e');
      return [];
    }
  }

  Future<List<String>> lookupIsrc(String title, String artist) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/recording',
        queryParameters: {
          'query': 'recording:$title AND artist:$artist',
          'fmt': 'json',
          'limit': '5',
        },
        options: Options(
          headers: {
            'User-Agent': 'DebridVault/1.0.0 ( dummy@gmail.com )',
          },
        ),
      );
      final recordings = response.data['recordings'] as List<dynamic>?;
      if (recordings == null || recordings.isEmpty) return [];

      final isrcs = <String>{};
      for (final rec in recordings) {
        final isrcList = rec['isrcs'] as List<dynamic>?;
        if (isrcList != null) {
          for (final isrc in isrcList) {
            if (isrc is String) isrcs.add(isrc);
          }
        }
      }
      return isrcs.toList();
    } catch (e) {
      print('[MusicBrainz] ISRC lookup error: $e');
      return [];
    }
  }
}
