import '../lib/features/music/data/scrapers/spotify_canvas_resolver.dart';

void main() async {
  print('═══ New SpotifyCanvasResolver test ═══\n');

  final resolver = SpotifyCanvasResolver();

  final tests = [
    ('SZA', 'Kill Bill'),
    ('Taylor Swift', 'Anti-Hero'),
  ];

  for (final (artist, track) in tests) {
    print('--- $artist - $track ---');
    final t0 = DateTime.now();
    try {
      final url = await resolver.resolveCanvas(artist, track);
      final ms = DateTime.now().difference(t0).inMilliseconds;
      if (url != null) {
        print('  ✅ Canvas found (${ms}ms)');
        print('  $url');
      } else {
        print('  ❌ No canvas (${ms}ms)');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
    print('');
  }
}
