import '../music_models.dart';

abstract class MusicScraper {
  String get name;
  Future<List<ScraperResult>> search(String query);
  Stream<ScraperResult> searchStream(String query);
}
