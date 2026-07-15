import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:crypto/crypto.dart';
import 'package:audio_service/audio_service.dart';

/// Last.fm API service for recommendation data.
/// Uses the free JSON API (api_key required, no auth).
@lazySingleton
class LastFmService {
  final Dio _dio;
  static const _baseUrl = 'https://ws.audioscrobbler.com/2.0/';
  
  // Last.fm API Credentials
  // IMPORTANT: Replace with your own from https://www.last.fm/api/account/create
  static const _apiKey = '3368667cd97107b3b2cd72d21267c2cb';
  static const _apiSecret = 'd5133b9001314731b3db98c648cb1dab'; 

  static String get apiKey => _apiKey;

  LastFmService(this._dio);

  // ─── Authentication & Scrobbling ──────────────────────────────────────────

  /// Fetches a request token for the web-based auth flow.
  Future<String?> fetchToken() async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'auth.getToken',
        'api_key': _apiKey,
        'format': 'json',
      });
      return response.data['token'];
    } catch (e) {
      print('[LastFmService] fetchToken error: $e');
      return null;
    }
  }

  /// Exchanges an approved token for a Session Key.
  Future<({String key, String name})?> getSession(String token) async {
    try {
      final params = {
        'method': 'auth.getSession',
        'api_key': _apiKey,
        'token': token,
      };
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final response = await _dio.get(_baseUrl, queryParameters: params);
      final session = response.data['session'];
      if (session != null) {
        return (key: session['key'] as String, name: session['name'] as String);
      }
    } catch (e) {
      print('[LastFmService] getSession error: $e');
    }
    return null;
  }

  /// Updates the "Now Playing" status.
  Future<void> updateNowPlaying(MediaItem item, String sessionKey) async {
    try {
      final params = {
        'method': 'track.updateNowPlaying',
        'api_key': _apiKey,
        'sk': sessionKey,
        'track': item.title,
        'artist': item.artist ?? 'Unknown',
        if (item.album != null) 'album': item.album!,
      };
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      await _dio.post(_baseUrl, queryParameters: params);
      print('[LastFmService] Now playing updated: ${item.title}');
    } catch (e) {
      print('[LastFmService] updateNowPlaying error: $e');
    }
  }

  /// Formally scrobbles a track.
  Future<void> scrobble(MediaItem item, String sessionKey) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor().toString();
      final params = {
        'method': 'track.scrobble',
        'api_key': _apiKey,
        'sk': sessionKey,
        'timestamp[0]': timestamp,
        'track[0]': item.title,
        'artist[0]': item.artist ?? 'Unknown',
        if (item.album != null) 'album[0]': item.album!,
      };
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      await _dio.post(_baseUrl, queryParameters: params);
      print('[LastFmService] Scrobbled: ${item.title}');
    } catch (e) {
      print('[LastFmService] scrobble error: $e');
    }
  }

  String _generateSignature(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    final stringToSign = sortedKeys.map((k) => '$k${params[k]}').join() + _apiSecret;
    return md5.convert(utf8.encode(stringToSign)).toString();
  }

  // ─── Data Discovery ───────────────────────────────────────────────────────

  /// Get similar artists to the given artist name.
  Future<List<Map<String, dynamic>>> getSimilarArtists(String artistName, {int limit = 15}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'artist.getsimilar',
        'artist': artistName,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> artists = data['similarartists']?['artist'] ?? [];
      return artists.map(_parseArtist).where((a) => (a['name'] as String).isNotEmpty).toList();
    } catch (e) {
      print('[LastFmService] getSimilarArtists error: $e');
      return [];
    }
  }

  /// Get similar tracks to the given track.
  Future<List<Map<String, dynamic>>> getSimilarTracks(String trackName, String artistName, {int limit = 20}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'track.getsimilar',
        'track': trackName,
        'artist': artistName,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> tracks = data['similartracks']?['track'] ?? [];
      return tracks.map(_parseTrack).where((t) => (t['name'] as String).isNotEmpty).toList();
    } catch (e) {
      print('[LastFmService] getSimilarTracks error: $e');
      return [];
    }
  }

  /// Get top tracks for an artist.
  Future<List<Map<String, dynamic>>> getArtistTopTracks(String artistName, {int limit = 10}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'artist.gettoptracks',
        'artist': artistName,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> tracks = data['toptracks']?['track'] ?? [];
      return tracks.map(_parseTrack).where((t) => (t['name'] as String).isNotEmpty).toList();
    } catch (e) {
      print('[LastFmService] getArtistTopTracks error: $e');
      return [];
    }
  }

  /// Get top tags (genres) for an artist.
  Future<List<String>> getArtistTopTags(String artistName, {int limit = 5}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'artist.gettoptags',
        'artist': artistName,
        'api_key': _apiKey,
        'format': 'json',
      });

      final data = response.data;
      final List<dynamic> tags = data['toptags']?['tag'] ?? [];

      return tags
          .take(limit)
          .map((t) => t['name'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (e) {
      print('[LastFmService] getArtistTopTags error: $e');
      return [];
    }
  }

  // ─── Personalized Discovery ────────────────────────────────────────────────

  /// Get a user's top artists.
  /// period: overall | 7day | 1month | 3month | 6month | 12month
  Future<List<Map<String, dynamic>>> getUserTopArtists(String username, {String period = '7day', int limit = 10}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'user.gettopartists',
        'user': username,
        'period': period,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> artists = data['topartists']?['artist'] ?? [];
      return artists.map(_parseArtist).toList();
    } catch (e) {
      print('[LastFmService] getUserTopArtists error: $e');
      return [];
    }
  }

  /// Get a user's top tracks.
  Future<List<Map<String, dynamic>>> getUserTopTracks(String username, {String period = '7day', int limit = 10}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'user.gettoptracks',
        'user': username,
        'period': period,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> tracks = data['toptracks']?['track'] ?? [];
      return tracks.map(_parseTrack).toList();
    } catch (e) {
      print('[LastFmService] getUserTopTracks error: $e');
      return [];
    }
  }

  /// Get a user's recent scrobbles.
  Future<List<Map<String, dynamic>>> getUserRecentTracks(String username, {int limit = 20}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'user.getrecenttracks',
        'user': username,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> tracks = data['recenttracks']?['track'] ?? [];
      return tracks.map(_parseTrack).toList();
    } catch (e) {
      print('[LastFmService] getUserRecentTracks error: $e');
      return [];
    }
  }
  /// Get the user's loved tracks.
  Future<Map<String, dynamic>> getLovedTracks(String username, {int page = 1, int limit = 50}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'user.getlovedtracks',
        'user': username,
        'api_key': _apiKey,
        'format': 'json',
        'page': page.toString(),
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> tracks = data['lovedtracks']?['track'] ?? [];
      final attr = data['lovedtracks']?['@attr'] ?? {};
      
      return {
        'tracks': tracks.map(_parseTrack).toList(),
        'totalPages': int.tryParse(attr['totalPages']?.toString() ?? '1') ?? 1,
        'total': int.tryParse(attr['total']?.toString() ?? '0') ?? 0,
      };
    } catch (e) {
      print('[LastFmService] getLovedTracks error: $e');
      return {'tracks': [], 'totalPages': 0, 'total': 0};
    }
  }

  /// Love a track.
  Future<bool> loveTrack(String track, String artist, String sessionKey) async {
    try {
      final params = {
        'method': 'track.love',
        'track': track,
        'artist': artist,
        'api_key': _apiKey,
        'sk': sessionKey,
      };
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      await _dio.post(_baseUrl, queryParameters: params);
      return true;
    } catch (e) {
      print('[LastFmService] loveTrack error: $e');
      return false;
    }
  }

  /// Unlove a track.
  Future<bool> unloveTrack(String track, String artist, String sessionKey) async {
    try {
      final params = {
        'method': 'track.unlove',
        'track': track,
        'artist': artist,
        'api_key': _apiKey,
        'sk': sessionKey,
      };
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      await _dio.post(_baseUrl, queryParameters: params);
      return true;
    } catch (e) {
      print('[LastFmService] unloveTrack error: $e');
      return false;
    }
  }

  /// Get the user's overall listening statistics.
  Future<Map<String, dynamic>?> getUserInfo(String username) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'user.getinfo',
        'user': username,
        'api_key': _apiKey,
        'format': 'json',
      });

      final user = response.data['user'];
      if (user == null) return null;

      final registration = user['registered']?['unixtime'];
      final regTime = registration != null ? (int.tryParse(registration.toString()) ?? 0) : 0;

      return {
        'name': user['name'] ?? '',
        'realname': user['realname'] ?? '',
        'url': user['url'] ?? '',
        'scrobbles': int.tryParse(user['playcount']?.toString() ?? '0') ?? 0,
        'artists': int.tryParse(user['artist_count']?.toString() ?? '0') ?? 0,
        'registered': regTime,
        'image_url': _parseArtist(user)['image_url'], // Reuses same image logic
      };
    } catch (e) {
      print('[LastFmService] getUserInfo error: $e');
      return null;
    }
  }

  /// Get the user's top albums.
  Future<List<Map<String, dynamic>>> getUserTopAlbums(String username, {String period = 'overall', int limit = 10}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'user.gettopalbums',
        'user': username,
        'period': period,
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> albums = data['topalbums']?['album'] ?? [];
      return albums.map(_parseAlbum).toList();
    } catch (e) {
      print('[LastFmService] getUserTopAlbums error: $e');
      return [];
    }
  }

  // ─── Global discovery ──────────────────────────────────────────────────────

  /// Get global trending artists.
  Future<List<Map<String, dynamic>>> getGlobalTopArtists({int limit = 10}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'chart.gettopartists',
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> artists = data['artists']?['artist'] ?? [];
      return artists.map(_parseArtist).toList();
    } catch (e) {
      print('[LastFmService] getGlobalTopArtists error: $e');
      return [];
    }
  }

  /// Get global trending tracks.
  Future<List<Map<String, dynamic>>> getGlobalTopTracks({int limit = 10}) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'method': 'chart.gettoptracks',
        'api_key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
      });

      final data = response.data;
      final List<dynamic> tracks = data['tracks']?['track'] ?? [];
      return tracks.map(_parseTrack).toList();
    } catch (e) {
      print('[LastFmService] getGlobalTopTracks error: $e');
      return [];
    }
  }

  // ─── Station API (internal Last.fm player API) ─────────────────────────────

  /// Fetch tracks from a Last.fm station page (recommended, mix, etc.).
  /// Uses the internal player API at www.last.fm (not the web service API).
  Future<List<Map<String, dynamic>>> fetchStationPlaylist(String username, String stationType, {int page = 1}) async {
    try {
      final url = 'https://www.last.fm/player/station/user/$username/$stationType';
      final response = await _dio.get(url, queryParameters: {
        'page': page.toString(),
        'ajax': '1',
      });

      final data = response.data;
      final List<dynamic> playlist = data['playlist'] ?? [];

      return playlist.map((item) {
        final artists = item['artists'] as List<dynamic>? ?? [];
        final artistName = artists.isNotEmpty ? (artists[0]['_name'] as String? ?? 'Unknown') : 'Unknown';

        String? youtubeId;
        final playlinks = item['_playlinks'] as List<dynamic>? ?? [];
        for (final link in playlinks) {
          if (link['affiliate'] == 'youtube') {
            youtubeId = link['id'] as String?;
            break;
          }
        }

        final images = item['images'] as List<dynamic>? ?? [];
        String? imageUrl;
        if (images.isNotEmpty) {
          for (final img in images.reversed) {
            final sizes = img['sizes'] as Map<String, dynamic>? ?? {};
            final sizeKeys = ['extralarge', 'large', 'medium', 'small'];
            for (final key in sizeKeys) {
              final val = sizes[key] as String?;
              if (val != null && val.isNotEmpty) {
                imageUrl = val;
                break;
              }
            }
            if (imageUrl != null && imageUrl.isNotEmpty) break;
          }
        }

        return {
          'name': item['_name'] as String? ?? 'Unknown Track',
          'artist': artistName,
          'duration': item['duration'] as int? ?? 0,
          'image_url': imageUrl ?? '',
          'youtube_id': youtubeId ?? '',
        };
      }).toList();
    } catch (e) {
      print('[LastFmService] fetchStationPlaylist($stationType) error: $e');
      return [];
    }
  }

  // ─── Parsing Helpers ──────────────────────────────────────────────────────

  Map<String, dynamic> _parseArtist(dynamic a) {
    if (a == null) return {};
    final images = a['image'] as List<dynamic>? ?? [];
    String imageUrl = '';
    // Last.fm image sizes: small, medium, large, extralarge, mega
    for (final img in images.reversed) {
      imageUrl = img['#text'] ?? '';
      if (imageUrl.isNotEmpty) break;
    }
    return {
      'name': a['name'] ?? '',
      'image_url': imageUrl,
      'url': a['url'] ?? '',
      'playcount': int.tryParse(a['playcount']?.toString() ?? '0') ?? 0,
      'listeners': int.tryParse(a['listeners']?.toString() ?? '0') ?? 0,
    };
  }

  /// Helper to detect Last.fm placeholder images.
  static bool isPlaceholderImage(String? url) {
    if (url == null || url.isEmpty) return true;
    final u = url.toLowerCase();
    return u.contains('2a96cbd8b46e442fc41c2b86b821562f') || 
           u.contains('lastfm_noimage') ||
           u.contains('default_artist_card');
  }

  Map<String, dynamic> _parseTrack(dynamic t) {
    if (t == null) return {};
    final artist = t['artist'];
    final artistName = artist is String ? artist : (artist?['name'] ?? '');
    
    final images = t['image'] as List<dynamic>? ?? [];
    String imageUrl = '';
    for (final img in images.reversed) {
      imageUrl = img['#text'] ?? '';
      if (imageUrl.isNotEmpty) break;
    }

    return {
      'name': t['name'] ?? '',
      'artist': artistName,
      'album': t['album']?['#text'] ?? '',
      'image_url': imageUrl,
      'url': t['url'] ?? '',
      'playcount': int.tryParse(t['playcount']?.toString() ?? '0') ?? 0,
      'listeners': int.tryParse(t['listeners']?.toString() ?? '0') ?? 0,
      'date': t['date']?['#text'], // For recent tracks
    };
  }

  Map<String, dynamic> _parseAlbum(dynamic a) {
    if (a == null) return {};
    final images = a['image'] as List<dynamic>? ?? [];
    String imageUrl = '';
    for (final img in images.reversed) {
      imageUrl = img['#text'] ?? '';
      if (imageUrl.isNotEmpty) break;
    }

    return {
      'name': a['name'] ?? '',
      'artist': a['artist']?['name'] ?? '',
      'image_url': imageUrl,
      'url': a['url'] ?? '',
      'playcount': int.tryParse(a['playcount']?.toString() ?? '0') ?? 0,
    };
  }
}
