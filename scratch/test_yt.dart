import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final url = 'https://music.youtube.com/playlist?list=PLLf2Fgj9xEccOln_bJ8dbeMYBhaiwT3rO';
  try {
    print('Fetching playlist metadata...');
    final playlist = await yt.playlists.get(url);
    print('Playlist Title: ${playlist.title}');
    print('Playlist ID: ${playlist.id}');
    
    print('Fetching videos...');
    int count = 0;
    await for (final video in yt.playlists.getVideos(playlist.id)) {
      count++;
      print('$count: ${video.title} by ${video.author}');
    }
    print('Total videos fetched: $count');
  } catch (e, st) {
    print('Error: $e');
    print(st);
  } finally {
    yt.close();
  }
}
