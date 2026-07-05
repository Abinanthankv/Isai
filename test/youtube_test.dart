import 'dart:io';
import '../lib/features/youtube/data/youtube_video_service.dart';

final _testIds = [
  'dQw4w9WgXcQ', // Rick Astley 4K
  'uXIsTszCjZE', // nature 1080p
  'jNQXAC9IVRw', // "Me at the zoo" (first YT video)
  'dQw4w9WgXcQ', // Rick Astley again (InnerTube cache test)
];

void main() async {
  final service = YoutubeVideoService();

  // Test 1: Search
  print('=== Test 1: Search ===');
  final t0 = DateTime.now();
  final results = await service.search('Taylor Swift');
  print('Search time: ${DateTime.now().difference(t0).inMilliseconds}ms');
  print('Found ${results.length} results');
  for (final r in results.take(5)) {
    print('  - ${r.title} (${r.durationSeconds}s) by ${r.author} [${r.id}]');
  }

  // Test 2: Video info with first-byte verification
  print('\n=== Test 2: Video Info + Stream Verification ===');
  for (final id in _testIds) {
    print('\n--- Video: $id ---');
    final t0 = DateTime.now();
    final info = await service.getVideoInfo(id);
    final fetchMs = DateTime.now().difference(t0).inMilliseconds;
    print('  Fetch time: ${fetchMs}ms');

    if (info == null) {
      print('  FAILED: could not fetch');
      continue;
    }
    print('  Title: ${info.title}');
    print('  Author: ${info.author}');
    print('  Duration: ${info.durationSeconds}s');
    print('  Video streams: ${info.videoStreams.length}');
    for (final vs in info.videoStreams.take(6)) {
      final fbMs = await _firstByte(vs.url);
      print('    ${vs.qualityLabel} | ${vs.width}x${vs.height} | ${vs.bitrate ~/ 1000}kbps | ${vs.codec} | first-byte: ${fbMs}ms');
    }
    print('  Audio streams: ${info.audioStreams.length}');
    for (final a in info.audioStreams.take(4)) {
      final fbMs = await _firstByte(a.url);
      print('    ${a.bitrate ~/ 1000}kbps | ${a.codec} | ${a.contentLength ~/ 1048576}MB | first-byte: ${fbMs}ms');
    }
  }

  service.dispose();
  print('\n=== Done ===');
}

Future<int> _firstByte(String url) async {
  final t0 = DateTime.now();
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('Range', 'bytes=0-0');
    final resp = await req.close();
    await resp.drain();
    client.close();
    return DateTime.now().difference(t0).inMilliseconds;
  } catch (_) {
    return -1;
  }
}
