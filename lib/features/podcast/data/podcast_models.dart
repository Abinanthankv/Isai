library;

class PodcastEpisode {
  final String id;
  final String title;
  final String? description;
  final String? audioUrl;
  final int? durationSec;
  final String? pubDate;
  final String? artworkUrl;
  final String? episodeUrl;
  final String? feedUrl;
  final String? collectionName;

  const PodcastEpisode({
    required this.id,
    required this.title,
    this.description,
    this.audioUrl,
    this.durationSec,
    this.pubDate,
    this.artworkUrl,
    this.episodeUrl,
    this.feedUrl,
    this.collectionName,
  });
}

class PodcastSeries {
  final int collectionId;
  final String collectionName;
  final String artistName;
  final String? feedUrl;
  final String? artworkUrl;
  final String? primaryGenre;
  final int? trackCount;
  final String? releaseDate;
  final List<PodcastEpisode>? episodes;

  const PodcastSeries({
    required this.collectionId,
    required this.collectionName,
    required this.artistName,
    this.feedUrl,
    this.artworkUrl,
    this.primaryGenre,
    this.trackCount,
    this.releaseDate,
    this.episodes,
  });

  factory PodcastSeries.fromItunes(Map<String, dynamic> json) {
    return PodcastSeries(
      collectionId: json['collectionId'] as int? ?? 0,
      collectionName: json['collectionName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      feedUrl: json['feedUrl'] as String?,
      artworkUrl: (json['artworkUrl600'] as String?)
          ?.replaceAll('600x600', '600x600'),
      primaryGenre: json['primaryGenreName'] as String?,
      trackCount: json['trackCount'] as int?,
      releaseDate: json['releaseDate'] as String?,
    );
  }

  PodcastSeries withEpisodes(List<PodcastEpisode> episodes) {
    return PodcastSeries(
      collectionId: collectionId,
      collectionName: collectionName,
      artistName: artistName,
      feedUrl: feedUrl,
      artworkUrl: artworkUrl,
      primaryGenre: primaryGenre,
      trackCount: episodes.length,
      releaseDate: releaseDate,
      episodes: episodes,
    );
  }
}
