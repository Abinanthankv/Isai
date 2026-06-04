import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../music_models.dart';

@lazySingleton
class LastFmScraper {
  final Dio _dio;

  LastFmScraper(this._dio);

  static const _url = 'https://www.last.fm/charts';

  Future<List<ItunesTrack>> getTopArtists() async {
    try {
      final response = await _dio.get(
        _url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      final html = response.data as String;
      return _parseArtists(html);
    } catch (e) {
      print('[LastFmScraper] Error fetching global top artists: $e');
      return [];
    }
  }

  List<ItunesTrack> _parseArtists(String html) {
    final List<ItunesTrack> artists = [];
    
    // 1. Isolate the "Top Artists" section
    final artistSectionAnchor = 'id="top-artists"';
    final sectionIndex = html.indexOf(artistSectionAnchor);
    if (sectionIndex == -1) return artists;

    // We only care about the content after this anchor until the next major section
    final sectionHtml = html.substring(sectionIndex);
    
    // 2. Extract links within this section
    // Format: <a href="/music/Artist+Name" class="link-block-target">Artist Name</a>
    final matches = RegExp(r'<a[^>]*href="/music/([^"]+)"[^>]*class="link-block-target"[^>]*>([^<]+)</a>').allMatches(sectionHtml);

    final Set<String> seen = {};

    for (final match in matches) {
      final artistPath = match.group(1) ?? '';
      final artistName = match.group(2)?.trim() ?? '';
      
      // Filter out tracks/albums (which contain '/_/' or extra slashes)
      if (artistPath.contains('/_/') || artistPath.split('/').length > 1) {
        continue;
      }

      if (artistName.isNotEmpty && !seen.contains(artistName)) {
        seen.add(artistName);
        artists.add(ItunesTrack(
          trackId: artistName.hashCode,
          trackName: '',
          artistName: artistName,
          collectionName: '',
          artworkUrl: '', 
          artistViewUrl: '',
        ));
      }
      
      if (artists.length >= 15) break;
    }

    return artists;
  }

  Future<String?> getArtistBio(String artistName) async {
    try {
      final formattedName = Uri.encodeComponent(artistName).replaceAll('%20', '+');
      final response = await _dio.get(
        'https://www.last.fm/music/$formattedName/+wiki',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      final html = response.data as String;
      
      // Look for the wiki summary
      // Using a more flexible start tag search as Last.fm adds itemprop attributes
      final startSearch = '<div class="wiki-content"';
      final startIndex = html.indexOf(startSearch);
      if (startIndex == -1) return null;

      // Find the end of this div opening tag
      final tagEnd = html.indexOf('>', startIndex);
      if (tagEnd == -1) return null;

      final end = html.indexOf('</div>', tagEnd);
      if (end == -1) return null;

      var content = html.substring(tagEnd + 1, end);
      
      // Simple HTML tag removal (keep it basic for now)
      content = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      
      // Decode entities
      content = content.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ');

      // Extract a reasonable amount of text
      if (content.length > 500) {
        content = content.substring(0, 500).trim() + '...';
      }

      return content.isNotEmpty ? content : null;
    } catch (e) {
      print('[LastFmScraper] Error fetching bio for $artistName: $e');
      return null;
    }
  }

  Future<List<String>> getSimilarArtists(String artistName) async {
    try {
      final formattedName = Uri.encodeComponent(artistName).replaceAll('%20', '+');
      final response = await _dio.get(
        'https://www.last.fm/music/$formattedName',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      final html = response.data as String;
      final Set<String> similar = {};
      
      // Try multiple class names used by Last.fm for similar artists
      final classPatterns = [
        'artist-similar-artists-sidebar-item-name',
        'catalogue-overview-similar-artists-item-name',
        'similar-artists-item-name', // Fallback for older patterns
      ];

      for (final className in classPatterns) {
        final regex = RegExp('class="$className"[^>]*>.*?<a[^>]*>([^<]+)</a>', dotAll: true);
        final matches = regex.allMatches(html);
        for (final match in matches) {
           final name = match.group(1)?.trim() ?? '';
           if (name.isNotEmpty) similar.add(name);
        }
        if (similar.length >= 6) break;
      }

      return similar.take(8).toList();
    } catch (e) {
      print('[LastFmScraper] Error fetching similar artists for $artistName: $e');
      return [];
    }
  }
}
