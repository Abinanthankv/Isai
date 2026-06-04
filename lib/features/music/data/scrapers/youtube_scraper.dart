import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class YouTubeScraper implements MusicScraper {
  final _yt = YoutubeExplode();
  YouTubeScraper();

  @override
  String get name => 'YouTube (Stream)';

  @override
  Future<List<ScraperResult>> search(String query) async {
    return searchStream(query).toList();
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return;
      print('[Scraper] YouTube initializing search for keyword: "$cleanQuery"');
      final videos = await _yt.search.search(cleanQuery);
      
      int count = 0;
      for (final v in videos) {
        if (count >= 5) break; // Limit to 5 results for speed
        count++;
        yield ScraperResult(
          title: v.title,
          artist: v.author,
          url: v.id.value, // videoId
          source: 'YouTube (Stream)',
          size: 0,
          format: v.duration?.toString().split('.').first ?? 'Unknown format',
          linkType: 'youtube',
          duration: v.duration?.toString().split('.').first,
          thumbnail: v.thumbnails.highResUrl,
          extras: {
            'author': v.author,
            'duration': v.duration?.inSeconds ?? 0,
          },
        );
      }
    } catch (e) {
      print('[Music] YouTube search error: $e');
    }
  }
}
