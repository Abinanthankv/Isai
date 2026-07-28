import 'package:injectable/injectable.dart';
import '../itunes_metadata_service.dart';
import 'metadata_provider.dart';

@injectable
class AppleMusicMetadataProvider implements MetadataProvider {
  final ItunesMetadataService _itunes;

  AppleMusicMetadataProvider(this._itunes);

  @override
  String get id => 'apple_music';

  @override
  String get displayName => 'Apple Music';

  @override
  String get description =>
      'Album art, genres, track info from the iTunes Store catalog. Enabled by default.';

  @override
  String get iconAsset => 'apple_music';

  @override
  Future<TrackMeta?> enrich(String title, String artist,
      {String? isrc}) async {
    final result = await _itunes.fetchMeta(title, artist);
    if (result == null) return null;

    return TrackMeta(
      trackName: result.trackName,
      artistName: result.artistName,
      album: result.album,
      genre: result.genre,
      releaseYear: result.releaseYear,
      trackTimeMillis: result.trackTimeMillis,
      artworkUrlLow: result.artworkUrlLow,
      artworkUrlHigh: result.artworkUrlHigh,
      previewUrl: result.previewUrl,
      id: result.id,
      provider: 'apple_music',
    );
  }

  @override
  Future<TrackMeta?> enrichByIsrc(String isrc) async {
    return null;
  }
}
