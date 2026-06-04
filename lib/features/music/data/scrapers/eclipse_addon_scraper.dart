import 'dart:async';
import '../plugins/eclipse_addon.dart';
import '../plugins/plugin_manager.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class EclipseAddonScraper implements MusicScraper {
  final EclipseAddon addon;
  final PluginManager _manager;

  EclipseAddonScraper(this.addon, this._manager);

  @override
  String get name => addon.name;

  @override
  Future<List<ScraperResult>> search(String query) async {
    if (!addon.enabled) return [];
    return _manager.searchEclipse(addon.id, query);
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    if (!addon.enabled) return;
    try {
      final results = await search(query);
      for (final r in results) {
        yield r;
      }
    } catch (e) {
      print('[EclipseAddonScraper] Error in searchStream for ${addon.name}: $e');
    }
  }
}
