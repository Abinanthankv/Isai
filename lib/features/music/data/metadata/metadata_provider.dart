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

  TrackMeta copyWith({
    String? trackName,
    String? artistName,
    String? album,
    String? genre,
    int? releaseYear,
    int? trackTimeMillis,
    String? artworkUrlLow,
    String? artworkUrlHigh,
    String? previewUrl,
    String? id,
    String? isrc,
    String? label,
    String? copyright,
    String? composer,
    int? trackNumber,
    int? totalTracks,
    int? discNumber,
    int? totalDiscs,
    String? albumType,
    String? albumArtist,
    String? artistId,
    String? albumId,
    int? bpm,
    double? gain,
    bool? isExplicit,
    String? provider,
  }) =>
      TrackMeta(
        trackName: trackName ?? this.trackName,
        artistName: artistName ?? this.artistName,
        album: album ?? this.album,
        genre: genre ?? this.genre,
        releaseYear: releaseYear ?? this.releaseYear,
        trackTimeMillis: trackTimeMillis ?? this.trackTimeMillis,
        artworkUrlLow: artworkUrlLow ?? this.artworkUrlLow,
        artworkUrlHigh: artworkUrlHigh ?? this.artworkUrlHigh,
        previewUrl: previewUrl ?? this.previewUrl,
        id: id ?? this.id,
        isrc: isrc ?? this.isrc,
        label: label ?? this.label,
        copyright: copyright ?? this.copyright,
        composer: composer ?? this.composer,
        trackNumber: trackNumber ?? this.trackNumber,
        totalTracks: totalTracks ?? this.totalTracks,
        discNumber: discNumber ?? this.discNumber,
        totalDiscs: totalDiscs ?? this.totalDiscs,
        albumType: albumType ?? this.albumType,
        albumArtist: albumArtist ?? this.albumArtist,
        artistId: artistId ?? this.artistId,
        albumId: albumId ?? this.albumId,
        bpm: bpm ?? this.bpm,
        gain: gain ?? this.gain,
        isExplicit: isExplicit ?? this.isExplicit,
        provider: provider ?? this.provider,
      );
}

abstract class MetadataProvider {
  String get id;
  String get displayName;
  String get description;
  String get iconAsset;

  Future<TrackMeta?> enrich(String title, String artist, {String? isrc});
  Future<TrackMeta?> enrichByIsrc(String isrc);
}
