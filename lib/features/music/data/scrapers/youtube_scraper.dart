import 'dart:async';
import '../../../youtube/data/youtube_video_service.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class YouTubeScraper implements MusicScraper {
  final YoutubeVideoService _service = YoutubeVideoService();

  @override
  String get name => 'YouTube';

  @override
  Future<List<ScraperResult>> search(String query) async {
    final results = <ScraperResult>[];
    await for (final r in searchStream(query)) {
      results.add(r);
    }
    return results;
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return;
      print('[Scraper] YouTube searching via InnerTube: "$cleanQuery"');

      final videos = await _service.search('$cleanQuery official audio');
      if (videos.isEmpty) return;

      for (final v in videos.take(5)) {
        yield ScraperResult(
          title: v.title,
          artist: v.author,
          url: v.id,
          source: 'YouTube',
          size: 0,
          format: 'Audio',
          linkType: 'youtube',
          duration: Duration(seconds: v.durationSeconds).toString().split('.').first,
          thumbnail: v.thumbnailUrl,
          extras: {
            'author': v.author,
            'duration': v.durationSeconds,
          },
        );
      }
    } catch (e) {
      print('[Scraper] YouTube search error: $e');
    }
  }
}
