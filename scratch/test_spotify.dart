import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io' as io;

void main() async {
  final dio = Dio();
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = io.HttpClient();
    client.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36';
    return client;
  };

  try {
    final response = await dio.get('https://open.spotify.com/embed/playlist/01n6KeLDgJsGy0VYgEFccH');
    print('Status: ${response.statusCode}');
  } catch (e) {
    print('Error: $e');
  }
}
