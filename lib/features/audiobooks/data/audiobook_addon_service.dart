import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import '../../settings/data/torbox_settings_repository.dart';
import '../../music/data/plugins/plugin_manager.dart';
import '../../music/data/music_models.dart';
import 'audiobook_models.dart';

/// Service for communicating with the Stremio audiobook addon API via PluginManager.
/// 
/// This service is entirely independent from the music plugin system.
/// It handles searching, catalog browsing, and stream resolution for audiobooks.
@lazySingleton
class AudiobookAddonService {
  final PluginManager _pluginManager;
  final TorBoxSettingsRepository _settings;
  
  // The audiobook addon ID as installed in Eclipse Addons
  static const String _addonId = 'com.eclipse.universal.eyJub19w.audiobook';

  AudiobookAddonService(this._pluginManager, this._settings);

  /// Fetch the addon manifest to get available catalogs and resources.
  Future<Map<String, dynamic>> getManifest() async {
    try {
      final addon = _pluginManager.eclipseAddons.firstWhere((a) => a.id == _addonId);
      // Eclipse addon manifest is typically loaded during installation
      return {
        'id': addon.id,
        'name': addon.name,
        'version': addon.version,
        'description': addon.description,
        'icon': addon.icon,
      };
    } catch (e) {
      print('[AudiobookAddon] Error getting manifest: $e');
      return {};
    }
  }

  /// Search for audiobooks by query string.
  /// 
  /// Returns a list of [AudiobookResult]s matching the search query.
  Future<List<AudiobookResult>> searchBooks(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final results = await _pluginManager.searchEclipse(_addonId, query);
      return results.map((r) => AudiobookResult(
        id: r.extras?['trackId'] as String? ?? r.url,
        title: r.title,
        author: r.artist,
        artworkUrl: r.thumbnail,
        description: r.album,
      )).toList();
    } catch (e) {
      print('[AudiobookAddon] Search error for "$query": $e');
      return [];
    }
  }

  /// Get a catalog page of audiobooks.
  /// 
  /// [catalogId] is the Stremio catalog ID (e.g. 'librivox-audiobooks').
  /// [skip] is the offset for pagination.
  Future<List<AudiobookResult>> getCatalog({
    String catalogId = 'librivox-audiobooks',
    int skip = 0,
  }) async {
    try {
      // In Eclipse Addon protocol, we search/browse via search endpoint 
      // or custom catalog endpoints if available. Here we search for empty query 
      // or default catalog query to populate the browse section.
      final results = await _pluginManager.searchEclipse(_addonId, 'librivox');
      return results.map((r) => AudiobookResult(
        id: r.extras?['trackId'] as String? ?? r.url,
        title: r.title,
        author: r.artist,
        artworkUrl: r.thumbnail,
        description: r.album,
      )).toList();
    } catch (e) {
      print('[AudiobookAddon] Catalog fetch error: $e');
      return [];
    }
  }

  /// Get the detailed metadata for a specific audiobook by its ID.
  Future<AudiobookResult?> getBookDetails(String bookId) async {
    try {
      // We can query the addon search again or use search cache if needed.
      // For now, search for the book ID or title.
      final results = await _pluginManager.searchEclipse(_addonId, bookId);
      if (results.isEmpty) return null;
      final r = results.first;
      return AudiobookResult(
        id: r.extras?['trackId'] as String? ?? r.url,
        title: r.title,
        author: r.artist,
        artworkUrl: r.thumbnail,
        description: r.album,
      );
    } catch (e) {
      print('[AudiobookAddon] Book details error for "$bookId": $e');
      return null;
    }
  }

  /// Get available streams (chapters) for an audiobook.
  /// 
  /// Returns a list of [AudiobookChapter]s with stream URLs.
  Future<List<AudiobookChapter>> getBookChapters(String bookId) async {
    try {
      if (bookId.startsWith('ia_book_')) {
        final iaIdentifier = bookId.replaceFirst('ia_book_', '');
        final response = await _pluginManager.dio.get<Map<String, dynamic>>(
          'https://archive.org/metadata/$iaIdentifier',
        );
        final data = response.data;
        if (data != null && data['files'] != null) {
          final filesList = data['files'] as List<dynamic>;
          final List<AudiobookChapter> chapters = [];
          int index = 0;
          for (final f in filesList) {
            if (f is Map<String, dynamic>) {
              final format = f['format'] as String? ?? '';
              if (format == 'VBR MP3' || format == 'MP3') {
                final name = f['name'] as String? ?? '';
                final title = f['title'] as String? ?? 'Chapter ${index + 1}';
                final streamUrl = 'https://archive.org/download/$iaIdentifier/$name';
                
                chapters.add(AudiobookChapter(
                  id: '${bookId}_ch_$index',
                  title: title,
                  chapterNumber: index + 1,
                  streamUrl: streamUrl,
                  source: 'Internet Archive',
                ));
                index++;
              }
            }
          }
          if (chapters.isNotEmpty) return chapters;
        }
      }

      if (bookId.startsWith('torrent:')) {
        final parts = bookId.split(':');
        final hash = parts[1];
        final magnet = parts.length > 2 ? Uri.decodeComponent(parts[2]) : '';
        final token = _settings.apiKey ?? '';
        
        try {
          // 1. Get mylist to see if torrent exists
          final response = await _pluginManager.dio.get<Map<String, dynamic>>(
            'https://api.torbox.app/v1/api/torrents/mylist',
            queryParameters: {'bypass': 'true'},
            options: Options(headers: {
              'Authorization': 'Bearer $token'
            }),
          );
          
          final data = response.data;
          dynamic match;
          if (data != null && data['data'] != null) {
            final list = data['data'] as List<dynamic>;
            match = list.firstWhere(
              (item) => item['hash']?.toString().toLowerCase() == hash.toLowerCase(),
              orElse: () => null,
            );
          }
          
          if (match != null) {
            final files = match['files'] as List<dynamic>? ?? [];
            final List<AudiobookChapter> chapters = [];
            int idx = 0;
            for (final f in files) {
              final name = f['name'] as String? ?? '';
              final isAudio = ['.mp3', '.flac', '.aac', '.m4a', '.m4b', '.ogg', '.opus', '.wav']
                  .any((ext) => name.toLowerCase().endsWith(ext));
              if (isAudio) {
                final fileId = f['id'] as int? ?? 0;
                final torrentId = match['id'] as int? ?? 0;
                final size = f['size'] as int? ?? 0;
                chapters.add(AudiobookChapter(
                  id: 'torrent_file:$torrentId:$fileId:$size',
                  title: name.split('/').last,
                  chapterNumber: idx + 1,
                  streamUrl: 'https://lazy.torbox.internal/$torrentId/$fileId',
                  source: 'TorBox Torrent',
                ));
                idx++;
              }
            }
            if (chapters.isNotEmpty) return chapters;
          }
        } catch (e) {
          print('[AudiobookAddon] TorBox catalog fetch/add error for torrent: $e');
        }
      }

      // Fallback: Resolve the stream directly for the bookId.
      final streamUrl = await _pluginManager.resolveEclipseStream(_addonId, bookId);
      if (streamUrl == null) return [];
      
      return [
        AudiobookChapter(
          id: bookId,
          title: 'Full Audiobook',
          chapterNumber: 1,
          streamUrl: streamUrl,
          source: 'Eclipse Addon',
        )
      ];
    } catch (e) {
      print('[AudiobookAddon] Chapters fetch error for "$bookId": $e');
      return [];
    }
  }

  /// Resolve a direct stream URL for a specific chapter.
  /// 
  /// If the chapter already has a direct [streamUrl], returns it directly.
  /// Otherwise, attempts to resolve via the addon's stream endpoint.
  Future<String?> resolveChapterStream(AudiobookChapter chapter) async {
    if (chapter.streamUrl != null && chapter.streamUrl!.startsWith('http')) {
      return chapter.streamUrl;
    }
    return _pluginManager.resolveEclipseStream(_addonId, chapter.id);
  }
}
