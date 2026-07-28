import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'metadata_provider.dart';

@injectable
class DeezerMetadataProvider implements MetadataProvider {
  final Dio _dio;
  static const _baseUrl = 'https://api.deezer.com';

  DeezerMetadataProvider(this._dio);

  @override
  String get id => 'deezer';

  @override
  String get displayName => 'Deezer';

  @override
  String get description =>
      'ISRC, label, BPM, album type, 1000×1000 cover art. No account needed.';

  @override
  String get iconAsset => 'deezer';

  Future<Map<String, dynamic>?> _fetchTrackByIsrc(String isrc) async {
    try {
      final response = await _dio.get('$_baseUrl/track/isrc:$isrc',
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
            },
          ));
      if (response.statusCode == 200 &&
          response.data is Map &&
          !(response.data as Map).containsKey('error')) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchAlbum(String albumId) async {
    try {
      final response = await _dio.get('$_baseUrl/album/$albumId',
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
            },
          ));
      if (response.statusCode == 200 &&
          response.data is Map &&
          !(response.data as Map).containsKey('error')) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  String? _extractGenre(Map<String, dynamic> albumData) {
    final genres = albumData['genres'];
    if (genres is Map && genres['data'] is List) {
      final list = genres['data'] as List;
      if (list.isNotEmpty && list.first is Map) {
        return (list.first as Map)['name'] as String?;
      }
    }
    return null;
  }

  TrackMeta? _trackToMeta(Map<String, dynamic> track,
      {Map<String, dynamic>? album}) {
    final albumData =
        album ?? (track['album'] as Map<String, dynamic>?) ?? {};

    String? releaseDateStr;
    if (track['release_date'] is String) {
      releaseDateStr = track['release_date'] as String;
    } else if (albumData['release_date'] is String) {
      releaseDateStr = albumData['release_date'] as String;
    }

    int? releaseYear;
    if (releaseDateStr != null && releaseDateStr.length >= 4) {
      releaseYear = int.tryParse(releaseDateStr.substring(0, 4));
    }

    final duration = (track['duration'] as num?)?.toInt();
    final coverMedium = albumData['cover_medium'] as String?;
    final coverXl = albumData['cover_xl'] as String?;

    return TrackMeta(
      trackName: track['title'] as String?,
      artistName:
          (track['artist'] as Map<String, dynamic>?)?['name'] as String?,
      album: albumData['title'] as String?,
      genre: _extractGenre(albumData),
      releaseYear: releaseYear,
      trackTimeMillis: duration != null ? duration * 1000 : null,
      artworkUrlLow: coverMedium?.replaceAll('250x250', '600x600'),
      artworkUrlHigh: coverXl,
      previewUrl: track['preview'] as String?,
      id: track['id']?.toString(),
      isrc: track['isrc'] as String?,
      label: albumData['label'] as String?,
      copyright: albumData['copyright'] as String?,
      composer: track['composer'] as String?,
      trackNumber: (track['track_position'] as num?)?.toInt(),
      totalTracks: (albumData['nb_tracks'] as num?)?.toInt(),
      discNumber: (track['disk_number'] as num?)?.toInt(),
      totalDiscs: (albumData['nb_disk'] as num?)?.toInt(),
      albumType: albumData['record_type'] as String?,
      albumArtist:
          (albumData['artist'] as Map<String, dynamic>?)?['name'] as String?,
      artistId:
          (track['artist'] as Map<String, dynamic>?)?['id']?.toString(),
      albumId: albumData['id']?.toString(),
      bpm: (track['bpm'] as num?)?.toInt(),
      gain: (track['gain'] as num?)?.toDouble(),
      isExplicit: track['explicit_lyrics'] as bool?,
      provider: 'deezer',
    );
  }

  @override
  Future<TrackMeta?> enrich(String title, String artist,
      {String? isrc}) async {
    if (isrc != null) return enrichByIsrc(isrc);
    return null;
  }

  @override
  Future<TrackMeta?> enrichByIsrc(String isrc) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final track = await _fetchTrackByIsrc(isrc);
    if (track == null) return null;

    final albumId = (track['album'] as Map<String, dynamic>?)?['id'];
    Map<String, dynamic>? album;
    if (albumId != null) {
      album = await _fetchAlbum(albumId.toString());
    }

    return _trackToMeta(track, album: album);
  }
}
