class YoutubeStreamInfo {
  final String url;
  final String qualityLabel;
  final int width;
  final int height;
  final int bitrate;
  final int contentLength;
  final String mimeType;
  final String container;
  final String codec;
  final bool isAudio;
  final bool isVideo;
  final dynamic rawStreamInfo;

  YoutubeStreamInfo({
    required this.url,
    required this.qualityLabel,
    required this.width,
    required this.height,
    required this.bitrate,
    required this.contentLength,
    required this.mimeType,
    required this.container,
    required this.codec,
    this.isAudio = false,
    this.isVideo = false,
    this.rawStreamInfo,
  });
}

class YoutubeVideoInfo {
  final String id;
  final String title;
  final String author;
  final String channelId;
  final int durationSeconds;
  final String description;
  final String? thumbnailUrl;
  final List<YoutubeStreamInfo> videoStreams;
  final List<YoutubeStreamInfo> audioStreams;
  final String? clientUserAgent;

  YoutubeVideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.channelId,
    required this.durationSeconds,
    required this.description,
    this.thumbnailUrl,
    this.videoStreams = const [],
    this.audioStreams = const [],
    this.clientUserAgent,
  });
}

class YoutubeSearchResult {
  final String id;
  final String title;
  final String author;
  final String channelId;
  final int durationSeconds;
  final String? thumbnailUrl;
  final String? description;
  String? audioUrl;

  YoutubeSearchResult({
    required this.id,
    required this.title,
    required this.author,
    required this.channelId,
    required this.durationSeconds,
    this.thumbnailUrl,
    this.description,
    this.audioUrl,
  });
}
