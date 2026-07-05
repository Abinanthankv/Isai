import 'package:dio/dio.dart';
import 'package:isai/features/music/data/lyrics_models.dart';
import 'package:isai/features/music/data/scrapers/lyrics_scraper.dart';
import 'package:test/test.dart';

void main() {
  late LyricsOvhScraper scraper;

  setUp(() {
    scraper = LyricsOvhScraper();
  });

  group('LyricsOvhScraper', () {
    test('fetches lyrics for Cher - Believe', () async {
      final result = await scraper.getLyrics('Believe', 'Cher');
      expect(result, isNotNull);
      expect(result!.plainLyrics, isNotEmpty);
      expect(result.source, 'Lyrics.ovh');
      print('Source: ${result.source}');
      print('Lyrics (first 200 chars): ${result.plainLyrics!.substring(0, 200)}');
    });

    test('fetches lyrics for Tool - Pneuma', () async {
      final result = await scraper.getLyrics('Pneuma', 'Tool');
      expect(result, isNotNull);
      expect(result!.plainLyrics, isNotEmpty);
      print('Source: ${result.source}');
      print('Lyrics (first 200 chars): ${result.plainLyrics!.substring(0, 200)}');
    });

    test('fetches lyrics for The Beatles - Hey Jude', () async {
      final result = await scraper.getLyrics('Hey Jude', 'The Beatles');
      expect(result, isNotNull);
      expect(result!.plainLyrics, isNotEmpty);
      print('Source: ${result.source}');
      print('Lyrics (first 200 chars): ${result.plainLyrics!.substring(0, 200)}');
    });

    test('fetches lyrics for Hindi song - Tum Hi Ho', () async {
      final result = await scraper.getLyrics('Tum Hi Ho', 'Arijit Singh');
      expect(result, isNotNull);
      expect(result!.plainLyrics, isNotEmpty);
      print('Source: ${result.source}');
      print('Lyrics (first 200 chars): ${result.plainLyrics!.substring(0, 200)}');
    });

    test('returns null for non-existent song', () async {
      final result = await scraper.getLyrics('NonexistentSong12345', 'NonexistentArtist');
      expect(result, isNull);
    });

    test('handles features in track name', () async {
      final result = await scraper.getLyrics('Love the Way You Lie (feat. Rihanna)', 'Eminem');
      expect(result, isNotNull);
      expect(result!.plainLyrics, isNotEmpty);
      print('Source: ${result.source}');
      print('Lyrics (first 200 chars): ${result.plainLyrics!.substring(0, 200)}');
    });
  });
}
