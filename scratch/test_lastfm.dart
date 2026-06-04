import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final apiKey = 'd5133b9001314731b3db98c648cb1dab';
  final url = 'https://ws.audioscrobbler.com/2.0/';
  
  try {
    final response = await dio.get(url, queryParameters: {
      'method': 'chart.gettopartists',
      'api_key': apiKey,
      'format': 'json',
      'limit': '5',
    });
    
    final data = response.data;
    final artists = data['artists']?['artist'] ?? [];
    for (var artist in artists) {
      print('Artist: ${artist['name']}');
      final images = artist['image'] as List?;
      if (images != null) {
        for (var img in images) {
          print('  Size ${img['size']}: ${img['#text']}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
