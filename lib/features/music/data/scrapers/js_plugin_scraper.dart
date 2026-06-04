import 'dart:async';
import '../plugins/js_plugin.dart';
import '../plugins/plugin_manager.dart';
import '../music_models.dart';
import 'music_scraper.dart';

class JsPluginScraper implements MusicScraper {
  final JsPlugin plugin;
  final PluginManager _manager;

  JsPluginScraper(this.plugin, this._manager);

  @override
  String get name => plugin.name;

  @override
  Future<List<ScraperResult>> search(String query) async {
    if (!plugin.enabled) return [];
    return _manager.search(plugin.id, query);
  }

  @override
  Stream<ScraperResult> searchStream(String query) async* {
    if (!plugin.enabled) return;
    try {
      final results = await search(query);
      for (final r in results) {
        yield r;
      }
    } catch (e) {
      print('[JsPluginScraper] Error in searchStream for ${plugin.name}: $e');
    }
  }
}
