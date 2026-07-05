import 'dart:io';
import '../lib/features/youtube/data/youtube_video_service.dart';

void main() async {
  final service = YoutubeVideoService();

  final queries = [
    'Taylor Swift Anti-Hero official video',
    'Taylor Swift Cruel Summer',
    'Taylor Swift Shake It Off',
    'Taylor Swift Blank Space',
    'Taylor Swift Love Story',
    'Taylor Swift Fortnight',
  ];

  print('=== Taylor Swift - Search to Audio Playback Timing ===\n');
  print('${pad("Query/Pick", 50)}\tSearch\tManifest\tAudio1stB\tTotal');
  print(''.padRight(130, '-'));

  for (final query in queries) {
    final totalStart = DateTime.now();

    final t0 = DateTime.now();
    final results = await service.search(query);
    final searchMs = DateTime.now().difference(t0).inMilliseconds;

    if (results.isEmpty) {
      print('${pad(query, 48)}\t${searchMs}ms\t-\t-\t-');
      continue;
    }

    final pick = results.first;

    final t1 = DateTime.now();
    final info = await service.getVideoInfo(pick.id);
    final manifestMs = DateTime.now().difference(t1).inMilliseconds;

    if (info == null) {
      print('${pad(pick.title, 48)}\t${searchMs}ms\t${manifestMs}ms\t-\t-');
      continue;
    }

    int audioFirstByte = -1;
    if (info.audioStreams.isNotEmpty) {
      final t2 = DateTime.now();
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(info.audioStreams.first.url));
        req.headers.set('Range', 'bytes=0-0');
        final resp = await req.close();
        audioFirstByte = DateTime.now().difference(t2).inMilliseconds;
        await resp.drain();
        client.close();
      } catch (_) {}
    }

    final totalMs = DateTime.now().difference(totalStart).inMilliseconds;

    final label = pick.title.length > 46 ? '${pick.title.substring(0, 43)}...' : pick.title;
    print('${pad(label, 48)}\t'
        '${searchMs}ms\t${manifestMs}ms\t'
        '${audioFirstByte >= 0 ? "${audioFirstByte}ms" : "-"}\t'
        '${totalMs}ms');

    // Show what audio streams we got
    if (info.audioStreams.isNotEmpty) {
      final a = info.audioStreams.first;
      print('${pad("  audio: ${a.bitrate ~/ 1000}kbps | ${a.codec}", 48)}');
    }
    if (info.videoStreams.isNotEmpty) {
      final best = info.videoStreams.first;
      print('${pad("  best video: ${best.qualityLabel} | ${best.bitrate ~/ 1000}kbps", 48)}');
    }
  }

  service.dispose();
  print('\n=== Done ===');
}

String pad(String s, int n) {
  if (s.length >= n) return s;
  return s + ' ' * (n - s.length);
}
