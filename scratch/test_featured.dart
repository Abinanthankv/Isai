import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  print('Fetching featured playlists...');
  final dio = Dio();
  dio.options.headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
  };
  
  try {
    final response = await dio.get('https://www.jiosaavn.com/featured-playlists/english');
    final html = response.data as String;
    
    final lines = html.split('\n');
    String? jsonLine;
    for (var line in lines) {
      if (line.contains('window.__INITIAL_DATA__')) {
        jsonLine = line;
        break;
      }
    }
    
    if (jsonLine == null) {
      print('Could not find window.__INITIAL_DATA__');
      return;
    }
    
    final startIndex = jsonLine.indexOf('window.__INITIAL_DATA__');
    final equalIndex = jsonLine.indexOf('=', startIndex);
    if (equalIndex == -1) {
      print('Could not find = after window.__INITIAL_DATA__');
      return;
    }
    
    var jsonStr = jsonLine.substring(equalIndex + 1).trim();
    if (jsonStr.endsWith(';')) {
      jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
    }
    
    print('Cleaned JSON string length: ${jsonStr.length}');
    
    jsonStr = jsonStr.replaceAll(RegExp(r':\s*undefined'), ': null');
    jsonStr = jsonStr.replaceAll(RegExp(r'new Date\([^)]+\)'), 'null');
    
    try {
      final data = jsonDecode(jsonStr);
      final browseList = data['browse']?['browse_list'] as List<dynamic>? ?? [];
      print('Found ${browseList.length} items in browse list.');
      for (var item in browseList) {
        print('Item: ${item['title']?['text']} | ID: ${item['id']}');
      }
    } catch (e) {
      print('JSON Decode error: $e');
    }
  } catch (e) {
    print('Dio error: $e');
  }
}
