import 'package:dio/dio.dart';

class SpotifyCanvasResolver {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    },
  ));

  String _cleanString(String s) {
    return s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }

  Future<String?> getIsrcFromUnison(String artist, String track) async {
    try {
      final query = Uri.encodeComponent('$artist $track');
      final response = await _dio.get('https://unison.boidu.dev/lyrics/search?q=$query');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final cleanT = _cleanString(track);
          final cleanA = _cleanString(artist);
          for (final item in data['data']) {
            final itemSong = _cleanString(item['song'] ?? '');
            final itemArtist = _cleanString(item['artist'] ?? '');
            if ((cleanT.contains(itemSong) || itemSong.contains(cleanT)) &&
                (cleanA.contains(itemArtist) || itemArtist.contains(cleanA))) {
              final isrc = item['isrc'];
              if (isrc != null && isrc.toString().isNotEmpty) {
                return isrc.toString();
              }
            }
          }
        }
      }
    } catch (e) {
      print('[SpotifyCanvasResolver] Unison Error: $e');
    }
    return null;
  }

  Future<String?> getIsrcFromMusicBrainz(String artist, String track) async {
    try {
      final query = Uri.encodeComponent('recording:"$track" AND artist:"$artist"');
      final response = await _dio.get(
        'https://musicbrainz.org/ws/2/recording?query=$query&fmt=json',
        options: Options(headers: {
          'User-Agent': 'DebridVaultCanvas/1.0.0 (abinanthan)'
        }),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final recordings = data['recordings'] as List?;
        if (recordings != null) {
          final cleanT = _cleanString(track);
          for (final rec in recordings) {
            final recTitle = _cleanString(rec['title'] ?? '');
            if (cleanT.contains(recTitle) || recTitle.contains(cleanT)) {
              final isrcs = rec['isrcs'] as List?;
              if (isrcs != null && isrcs.isNotEmpty) {
                return isrcs[0].toString();
              }
            }
          }
        }
      }
    } catch (e) {
      print('[SpotifyCanvasResolver] MusicBrainz Search Error: $e');
    }
    return null;
  }

  Future<String?> getSpotifyUrl(String isrc) async {
    try {
      final response = await _dio.get(
        'https://musicbrainz.org/ws/2/isrc/$isrc?inc=url-rels&fmt=json',
        options: Options(headers: {
          'User-Agent': 'DebridVaultCanvas/1.0.0 (abinanthan)'
        }),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final recordings = data['recordings'] as List?;
        if (recordings != null) {
          for (final rec in recordings) {
            final relations = rec['relations'] as List?;
            if (relations != null) {
              for (final rel in relations) {
                final targetUrl = rel['url']?['resource']?.toString() ?? '';
                if (targetUrl.contains('open.spotify.com/track/')) {
                  return targetUrl;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('[SpotifyCanvasResolver] MusicBrainz ISRC Error: $e');
    }
    return null;
  }

  Future<String?> getCanvasVideo(String spotifyUrl) async {
    try {
      final queryUrl = Uri.encodeComponent(spotifyUrl);
      final response = await _dio.get('https://www.canvasdownloader.com/canvas?link=$queryUrl');
      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        final match = RegExp(r'source\s+src="([^"]+)"').firstMatch(html);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      print('[SpotifyCanvasResolver] CanvasDownloader Error: $e');
    }
    return null;
  }

  Future<String?> resolveCanvas(String artist, String track) async {
    String? isrc = await getIsrcFromUnison(artist, track);
    if (isrc == null || isrc.isEmpty) {
      isrc = await getIsrcFromMusicBrainz(artist, track);
    }
    if (isrc == null || isrc.isEmpty) {
      return null;
    }
    final spotifyUrl = await getSpotifyUrl(isrc);
    if (spotifyUrl == null || spotifyUrl.isEmpty) {
      return null;
    }
    return await getCanvasVideo(spotifyUrl);
  }
}
