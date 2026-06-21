import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  final dio = Dio();
  dio.options.headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  final originalUrl = 'https://music.youtube.com/playlist?list=PLLf2Fgj9xEccOln_bJ8dbeMYBhaiwT3rO';
  final url = originalUrl.replaceAll('music.youtube.com', 'www.youtube.com');
  
  print('Original URL: $originalUrl');
  print('Requesting URL: $url');
  
  try {
    final response = await dio.get(url);
    final html = response.data as String;
    
    final pattern = RegExp(r'var ytInitialData\s*=\s*(\{.*?\});\s*</script>');
    final match = pattern.firstMatch(html);
    if (match == null) {
      print('ytInitialData not found');
      return;
    }

    final data = jsonDecode(match.group(1)!);
    
    String playlistTitle = 'YouTube Playlist';
    if (data['metadata'] != null && data['metadata']['playlistMetadataRenderer'] != null) {
      playlistTitle = data['metadata']['playlistMetadataRenderer']['title'] ?? 'YouTube Playlist';
    }
    
    final List<Map<String, dynamic>> results = [];
    _findLockups(data, results);
    
    print('Successfully parsed Playlist: "$playlistTitle"');
    print('Found ${results.length} tracks.');
  } catch (e) {
    print('Error: $e');
  }
}

void _findLockups(dynamic node, List<Map<String, dynamic>> results) {
  if (node is Map) {
    if (node.containsKey('lockupViewModel')) {
      results.add(Map<String, dynamic>.from(node['lockupViewModel']));
    }
    for (final val in node.values) {
      _findLockups(val, results);
    }
  } else if (node is List) {
    for (final val in node) {
      _findLockups(val, results);
    }
  }
}
