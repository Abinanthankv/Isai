import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
  };

  try {
    print('Fetching featured playlists...');
    final response = await dio.get('https://www.jiosaavn.com/featured-playlists/english');
    final html = response.data as String;

    String? jsonStr;
    final lines = html.split('\n');
    for (var line in lines) {
      if (line.contains('window.__INITIAL_DATA__')) {
        final startIndex = line.indexOf('window.__INITIAL_DATA__');
        final equalIndex = line.indexOf('=', startIndex);
        if (equalIndex != -1) {
          var str = line.substring(equalIndex + 1).trim();
          if (str.endsWith(';')) {
            str = str.substring(0, str.length - 1).trim();
          }
          jsonStr = str;
        }
        break;
      }
    }

    if (jsonStr == null) {
      print('Could not find __INITIAL_DATA__');
      return;
    }

    jsonStr = jsonStr.replaceAll(RegExp(r':\s*undefined'), ': null');
    jsonStr = jsonStr.replaceAll(RegExp(r'new Date\([^)]+\)'), 'null');

    final data = jsonDecode(jsonStr);
    final browseList = data['browse']?['browse_list'] as List<dynamic>? ?? [];
    if (browseList.isEmpty) {
      print('No featured playlists found.');
      return;
    }

    final firstPlaylistUrl = browseList.first['perma_url']?.toString();
    if (firstPlaylistUrl == null) {
      print('First playlist perma_url is null.');
      return;
    }

    print('Fetching playlist details for: $firstPlaylistUrl');
    final playlistResponse = await dio.get(firstPlaylistUrl);
    final playlistHtml = playlistResponse.data as String;

    String? playlistJsonStr;
    for (var line in playlistHtml.split('\n')) {
      if (line.contains('window.__INITIAL_DATA__')) {
        final startIndex = line.indexOf('window.__INITIAL_DATA__');
        final equalIndex = line.indexOf('=', startIndex);
        if (equalIndex != -1) {
          var str = line.substring(equalIndex + 1).trim();
          if (str.endsWith(';')) {
            str = str.substring(0, str.length - 1).trim();
          }
          playlistJsonStr = str;
        }
        break;
      }
    }

    if (playlistJsonStr == null) {
      print('Could not find playlist __INITIAL_DATA__');
      return;
    }

    playlistJsonStr = playlistJsonStr.replaceAll(RegExp(r':\s*undefined'), ': null');
    playlistJsonStr = playlistJsonStr.replaceAll(RegExp(r'new Date\([^)]+\)'), 'null');

    final playlistData = jsonDecode(playlistJsonStr);
    final playlist = playlistData['playlist']?['playlist'] as Map<String, dynamic>?;
    if (playlist == null) {
      print('Playlist map not found.');
      return;
    }

    final list = playlist['list'] as List<dynamic>? ?? [];
    print('Total songs in playlist: ${list.length}');
    
    if (list.isNotEmpty) {
      for (var i = 0; i < (list.length > 3 ? 3 : list.length); i++) {
        final item = list[i];
        print('\n--- Song #${i + 1} ---');
        print('Title: ${item['title']?['text']}');
        print('Raw artists list: ${jsonEncode(item['artists'])}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
