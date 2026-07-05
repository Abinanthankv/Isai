import 'dart:io';
import 'dart:math';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../lib/features/youtube/data/youtube_video_service.dart';
import '../lib/features/youtube/data/youtube_models.dart';

final _rng = Random();

void main() async {
  final service = YoutubeVideoService();

  final queries = [
    'Rick Astley Never Gonna Give You Up',
    '4K nature footage relaxing music',
    'Flutter tutorial 2025',
    'lofi hip hop radio beats to relax study',
    'python programming full course',
  ];

  print('=== YouTube End-to-End Timing Benchmark ===\n');
  print('Query\t\t\t\tSearch\tManifest\tFirstByte\tTotal');
  print(''.padRight(120, '-'));

  for (final query in queries) {
    final totalStart = DateTime.now();

    // Step 1: Search
    final t0 = DateTime.now();
    final results = await service.search(query);
    final searchMs = DateTime.now().difference(t0).inMilliseconds;

    if (results.isEmpty) {
      print('${pad(query, 40)}\t${searchMs}ms\t-\t-\t-');
      continue;
    }

    // Pick a video with reasonable duration
    final candidates = results.where((r) => r.durationSeconds >= 30 && r.durationSeconds < 600).toList();
    if (candidates.isEmpty) {
      print('${pad(query, 40)}\t${searchMs}ms\t-\t-\t-');
      continue;
    }
    final pick = candidates[_rng.nextInt(candidates.length)];

    // Step 2: Get video info (manifest)
    final t1 = DateTime.now();
    final info = await service.getVideoInfo(pick.id);
    final manifestMs = DateTime.now().difference(t1).inMilliseconds;

    if (info == null || info.videoStreams.isEmpty) {
      print('${pad(query, 40)}\t${searchMs}ms\t${manifestMs}ms\t-\t-');
      continue;
    }

    // Step 3: First byte of best video stream
    final streamUrl = info.videoStreams.first.url;
    final t2 = DateTime.now();
    int firstByteMs = 0;
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(streamUrl));
      req.headers.set('Range', 'bytes=0-0');
      final resp = await req.close();
      firstByteMs = DateTime.now().difference(t2).inMilliseconds;
      await resp.drain();
      client.close();
    } catch (_) {
      firstByteMs = -1;
    }

    final totalMs = DateTime.now().difference(totalStart).inMilliseconds;

    print('${pad(pick.title.length > 38 ? '${pick.title.substring(0, 35)}...' : pick.title, 40)}\t'
        '${searchMs}ms\t${manifestMs}ms\t${firstByteMs}ms\t${totalMs}ms');
  }

  // Direct 4K + audio stream first byte
  print('\n--- Direct Stream First-Byte Tests ---');
  for (final entry in [
    const ('dQw4w9WgXcQ', 'Rick Astley 4K'),
    const ('jNQXAC9IVRw', 'Me at the zoo (oldest)'),
    const ('uXIsTszCjZE', 'Anime Studio 1080p'),
  ]) {
    final t0 = DateTime.now();
    final info = await service.getVideoInfo(entry.$1);
    final manifestMs = DateTime.now().difference(t0).inMilliseconds;
    print('${pad('${entry.$2} manifest', 35)}\t${manifestMs}ms\t\t');

    if (info == null) continue;

    // First byte of best video stream
    if (info.videoStreams.isNotEmpty) {
      final t1 = DateTime.now();
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(info.videoStreams.first.url));
        req.headers.set('Range', 'bytes=0-0');
        final resp = await req.close();
        final ms = DateTime.now().difference(t1).inMilliseconds;
        print('${pad('  best video (${info.videoStreams.first.qualityLabel}) first byte', 35)}\t\t${ms}ms');
        await resp.drain();
        client.close();
      } catch (_) {}
    }
    // First byte of best audio stream
    if (info.audioStreams.isNotEmpty) {
      final t1 = DateTime.now();
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(info.audioStreams.first.url));
        req.headers.set('Range', 'bytes=0-0');
        final resp = await req.close();
        final ms = DateTime.now().difference(t1).inMilliseconds;
        print('${pad('  best audio (${info.audioStreams.first.bitrate ~/ 1000}kbps) first byte', 35)}\t\t${ms}ms');
        await resp.drain();
        client.close();
      } catch (_) {}
    }

    // Show available qualities
    for (final vs in info.videoStreams.take(4)) {
      print('  ${vs.qualityLabel} | ${vs.width}x${vs.height} | ${vs.bitrate ~/ 1000}kbps | ${vs.codec}');
    }
  }

  service.dispose();
  print('\n=== Done ===');
}

String pad(String s, int n) {
  if (s.length >= n) return s;
  return s + ' ' * (n - s.length);
}
