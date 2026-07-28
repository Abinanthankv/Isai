class TrackMeta {
  final String? trackName;
  final String? artistName;
  final String? album;
  final String? genre;
  final int? releaseYear;
  final int? trackTimeMillis;
  final String? artworkUrlLow;
  final String? artworkUrlHigh;
  final String? previewUrl;
  final String? id;

  final String? isrc;
  final String? label;
  final String? copyright;
  final String? composer;
  final int? trackNumber;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final String? albumType;
  final String? albumArtist;
  final String? artistId;
  final String? albumId;
  final int? bpm;
  final double? gain;
  final bool? isExplicit;
  final String? provider;

  const TrackMeta({
    this.trackName,
    this.artistName,
    this.album,
    this.genre,
    this.releaseYear,
    this.trackTimeMillis,
    this.artworkUrlLow,
    this.artworkUrlHigh,
    this.previewUrl,
    this.id,
    this.isrc,
    this.label,
    this.copyright,
    this.composer,
    this.trackNumber,
    this.totalTracks,
    this.discNumber,
    this.totalDiscs,
    this.albumType,
    this.albumArtist,
    this.artistId,
    this.albumId,
    this.bpm,
    this.gain,
    this.isExplicit,
    this.provider,
  });
}

abstract class MetadataProvider {
  String get id;
  String get displayName;
  String get description;
  String get iconAsset;

  Future<TrackMeta?> enrich(String title, String artist, {String? isrc});
  Future<TrackMeta?> enrichByIsrc(String isrc);
}
