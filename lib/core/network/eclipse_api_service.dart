import 'package:dio/dio.dart';

class EclipseAuthResponse {
  final String token;
  final String userId;
  final String email;
  final String? username;
  final String? avatarUrl;

  EclipseAuthResponse({
    required this.token,
    required this.userId,
    required this.email,
    this.username,
    this.avatarUrl,
  });
}

class EclipsePlaylist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final int trackCount;
  final String createdAt;
  final String? ownerDisplayName;
  final List<EclipsePlaylistTrack> tracks;

  EclipsePlaylist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.trackCount = 0,
    this.createdAt = '',
    this.ownerDisplayName,
    this.tracks = const [],
  });

  factory EclipsePlaylist.fromJson(Map<String, dynamic> json) {
    return EclipsePlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      coverUrl: json['coverUrl'] as String?,
      trackCount: json['trackCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
      ownerDisplayName: json['ownerDisplayName'] as String?,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((e) => EclipsePlaylistTrack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class EclipsePlaylistTrack {
  final String? id;
  final String trackTitle;
  final String? artistName;
  final String? albumName;
  final String? artworkUrl;
  final String? filename;
  final int? fileId;

  EclipsePlaylistTrack({
    this.id,
    required this.trackTitle,
    this.artistName,
    this.albumName,
    this.artworkUrl,
    this.filename,
    this.fileId,
  });

  factory EclipsePlaylistTrack.fromJson(Map<String, dynamic> json) {
    return EclipsePlaylistTrack(
      id: json['id'] as String?,
      trackTitle: json['trackTitle'] as String? ?? '',
      artistName: json['artistName'] as String?,
      albumName: json['albumName'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      filename: json['filename'] as String?,
      fileId: json['fileId'] as int?,
    );
  }
}

class EclipseApiService {
  static const String baseUrl = 'https://api.eclipsemusic.app/api';
  final Dio _dio;

  EclipseApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'Isai-Eclipse/1.0',
          },
        ));

  Future<EclipseAuthResponse?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/mobile/login',
        data: {'email': email, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true || data['token'] == null) return null;

      final user = data['user'] as Map<String, dynamic>?;
      return EclipseAuthResponse(
        token: data['token'] as String,
        userId: user?['id'] as String? ?? '',
        email: user?['email'] as String? ?? email,
        username: user?['name'] as String?,
        avatarUrl: user?['image'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  Future<EclipseAuthResponse?> verifyToken(String token) async {
    try {
      final response = await _dio.get(
        '/auth/mobile/verify',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true || data['token'] == null) return null;

      final user = data['user'] as Map<String, dynamic>?;
      return EclipseAuthResponse(
        token: data['token'] as String,
        userId: user?['id'] as String? ?? '',
        email: user?['email'] as String? ?? '',
        username: user?['name'] as String?,
        avatarUrl: user?['image'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<EclipsePlaylist>> getPlaylists(String token, String userId) async {
    try {
      final response = await _dio.get(
        '/addons/$userId/music/playlists',
        queryParameters: {'includeTracks': 'true'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final playlists = data['playlists'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];
        if (playlists.isNotEmpty || data.containsKey('playlists') || data.containsKey('data')) {
          return playlists
              .map((e) => EclipsePlaylist.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      if (data is List) {
        return data
            .map((e) => EclipsePlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      print('Eclipse API: unexpected response format: ${response.statusCode} ${response.data}');
      return [];
    } catch (e) {
      print('Eclipse API getPlaylists error: $e');
      return [];
    }
  }

  Future<String?> createPlaylist(String token, String userId, String name, {String? description, String? coverUrl}) async {
    try {
      final response = await _dio.post(
        '/addons/$userId/music/playlists',
        data: {
          'name': name,
          if (description != null) 'description': description,
          if (coverUrl != null) 'coverUrl': coverUrl,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>?;
      return data?['id'] as String? ?? data?['playlistId'] as String?;
    } catch (e) {
      print('Eclipse API createPlaylist error: $e');
      return null;
    }
  }

  Future<String?> createPlaylistWithTracks(String token, String userId, String name, {String? coverUrl, required List<Map<String, dynamic>> tracks}) async {
    try {
      final response = await _dio.post(
        '/addons/$userId/music/playlists',
        data: {
          'name': name,
          if (coverUrl != null) 'coverUrl': coverUrl,
          'tracks': tracks,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>?;
      return data?['id'] as String? ?? data?['playlistId'] as String?;
    } catch (e) {
      print('Eclipse API createPlaylistWithTracks error: $e');
      return null;
    }
  }

  Future<bool> updatePlaylist(String token, String userId, String playlistId, {String? name, String? description, String? coverUrl}) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (coverUrl != null) body['coverUrl'] = coverUrl;
      final response = await _dio.put(
        '/addons/$userId/music/playlists/$playlistId',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
    } catch (e) {
      print('Eclipse API updatePlaylist error: $e');
      return false;
    }
  }

  Future<bool> deletePlaylist(String token, String userId, String playlistId) async {
    try {
      final response = await _dio.delete(
        '/addons/$userId/music/playlists/$playlistId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
    } catch (e) {
      print('Eclipse API deletePlaylist error: $e');
      return false;
    }
  }

  Future<bool> addTracksToPlaylist(String token, String userId, String playlistId, List<Map<String, dynamic>> tracks) async {
    try {
      final response = await _dio.post(
        '/addons/$userId/music/playlists/$playlistId/tracks',
        data: {'tracks': tracks},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
    } catch (e) {
      print('Eclipse API addTracksToPlaylist error: $e');
      return false;
    }
  }

  Future<bool> removeTracksFromPlaylist(String token, String userId, String playlistId, List<String> trackIds) async {
    try {
      final response = await _dio.delete(
        '/addons/$userId/music/playlists/$playlistId/tracks',
        data: {'trackIds': trackIds},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
    } catch (e) {
      print('Eclipse API removeTracksFromPlaylist error: $e');
      return false;
    }
  }

  Future<bool> logPlay(String token, Map<String, dynamic> playData) async {
    try {
      final response = await _dio.post(
        '/music/plays',
        data: playData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
    } catch (e) {
      print('Eclipse API logPlay error: $e');
      return false;
    }
  }
}
