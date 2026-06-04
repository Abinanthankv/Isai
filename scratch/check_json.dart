import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('scratch/spotify_data.json');
  final content = await file.readAsString();
  final data = jsonDecode(content);
  final trackList = data['props']['pageProps']['state']['data']['entity']['trackList'] as List<dynamic>;
  print('trackList length in file: ${trackList.length}');
  for (var i = 0; i < trackList.length; i++) {
    print('$i: ${trackList[i]['title']}');
  }
}
