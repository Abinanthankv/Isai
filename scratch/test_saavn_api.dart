import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final response = await dio.get('https://saavn.sumit.co/api/search/songs?query=drake');
  final data = response.data;
  final results = data['data']['results'] as List;
  if (results.isNotEmpty) {
    final first = results.first;
    print('Keys: ${first.keys.toList()}');
    print('name: ${first['name']}');
    print('artists: ${first['artists']}');
    print('primaryArtists: ${first['primaryArtists']}');
    print('singers: ${first['singers']}');
  } else {
    print('No results');
  }
}
