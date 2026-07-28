// SpotiFLAC Provider Inspection — Download & analyze every .sflx
//
// For each provider:
//   1. Downloads the .sflx (ZIP)
//   2. Extracts manifest.json + index.js
//   3. Parses registerExtension() to list every exported function
//   4. Summarises auth, endpoints, and capabilities
//
// Usage:
//   /home/abinanthan/flutter/flutter/bin/dart run test/spotiflac_provider_inspection_test.dart

import 'dart:convert';
import 'dart:io';

const _registryUrl =
    'https://raw.githubusercontent.com/spotiflacapp/spotiflac-extension/main/registry.json';
const _tmpDir = '/tmp/spotiflac_inspect';

Future<Map<String, dynamic>> _fetchJson(String url) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse(url);
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (body.isEmpty) return {};
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<List<int>> _fetchBytes(String url) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse(url);
    final req = await client.getUrl(uri);
    final resp = await req.close();
    return await resp.fold<List<int>>([], (p, c) => p..addAll(c));
  } finally {
    client.close(force: true);
  }
}

Future<String?> _zipCat(String zipPath, String fileName) async {
  final result = await Process.run(
    'unzip',
    ['-p', zipPath, fileName],
    runInShell: true,
  );
  if (result.exitCode != 0) return null;
  return (result.stdout as String).trim();
}

List<String> _parseRegisterExtension(String js) {
  final idx = js.indexOf('registerExtension');
  if (idx < 0) return [];
  final braceStart = js.indexOf('{', idx);
  if (braceStart < 0) return [];
  int depth = 1;
  int pos = braceStart + 1;
  while (depth > 0 && pos < js.length) {
    if (js[pos] == '{') depth++;
    if (js[pos] == '}') depth--;
    pos++;
  }
  final body = js.substring(braceStart + 1, pos - 1);
  final fns = <String>{};
  for (final line in body.split(',')) {
    final trimmed = line.trim();
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx > 0) {
      final name = trimmed.substring(0, colonIdx).trim();
      if (RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(name)) {
        fns.add(name);
      }
    }
  }
  return fns.toList()..sort();
}

final _urlPattern = RegExp(r'''["'](https?://[^\s"'()]+)["']''');

Set<String> _findEndpoints(String js) {
  final urls = <String>{};
  for (final m in _urlPattern.allMatches(js)) {
    final url = m.group(1)!;
    if (url.contains('api.') || url.contains('graphql') ||
        url.contains('/v1') || url.contains('/v2') ||
        url.contains('/v3') || url.contains('.com/') ||
        url.contains('.net/') || url.contains('.io/')) {
      urls.add(url);
    }
  }
  return urls;
}

final _capTags = {
  'searchTracks': 'search',
  'getTrack': 'track',
  'getAlbum': 'album',
  'getArtist': 'artist',
  'getPlaylist': 'playlist',
  'getLyrics': 'lyrics',
  'fetchLyrics': 'lyrics',
  'download': 'download',
  'checkAvailability': 'check',
  'completeGrant': 'auth',
  'getHomeFeed': 'homefeed',
  'enrichTrack': 'enrich',
  'matchTrack': 'match',
  'validateTrackForDownload': 'validate',
  'customSearch': 'search',
  'handleUrl': 'url',
};

void main(List<String> args) async {
  await Directory(_tmpDir).create(recursive: true);

  print('\n╔══════════════════════════════════════════════════════════════════════╗');
  print('║              SpotiFLAC Provider Deep Inspection                      ║');
  print('╚══════════════════════════════════════════════════════════════════════╝\n');

  final registry = await _fetchJson(_registryUrl);
  final extensions = registry['extensions'] as List;
  final allExports = <String, List<String>>{};
  final allManifests = <String, Map<String, dynamic>>{};

  for (int i = 0; i < extensions.length; i++) {
    final e = extensions[i] as Map<String, dynamic>;
    final name = e['display_name'] as String? ?? 'Unknown';
    final id = e['id'] as String? ?? '';
    final downloadUrl = e['download_url'] as String?;

    print('╔══ [${i + 1}/${extensions.length}] $name ($id) '.padRight(70, '═'));
    print('║   Version: ${e['version']}  |  MinApp: ${e['min_app_version']}');
    print('║   Tags: ${(e['tags'] as List).join(', ')}');

    if (downloadUrl == null) {
      print('║   ⚠  No downloadable .sflx — registry entry only');
      allExports[id] = [];
      allManifests[id] = {};
      print('╚══════════════════════════════════════════════════════════════════════\n');
      continue;
    }

    try {
      final bytes = await _fetchBytes(downloadUrl);
      print('║   Size: ${bytes.length} bytes');
      final zipPath = '$_tmpDir/$id.sflx';
      await File(zipPath).writeAsBytes(bytes);

      // manifest.json
      final manifestJson = await _zipCat(zipPath, 'manifest.json');
      Map<String, dynamic> manifest = {};
      if (manifestJson != null && manifestJson.isNotEmpty) {
        try {
          manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
        } catch (_) {}
      }
      allManifests[id] = manifest;

      print('║   Type: ${(manifest['type'] as List?)?.join(', ') ?? e['category']}');
      if (manifest['description'] != null) {
        print('║   Desc: ${manifest['description']}');
      }
      final features = manifest['requiredRuntimeFeatures'] as List?;
      if (features != null && features.isNotEmpty) {
        print('║   Runtime: ${features.join(', ')}');
      }
      final ss = manifest['signedSession'] as Map?;
      if (ss != null) {
        print('║   Auth: ${ss['schemeLabel']} @ ${ss['baseUrl']}');
        final ep = ss['endpoints'] as Map?;
        if (ep != null) {
          print('║   Session endpoints:');
          for (final k in ['bootstrap', 'challenge', 'exchange', 'refresh']) {
            if (ep[k] != null) print('║      $k: ${ss['baseUrl']}${ep[k]}');
          }
        }
      } else {
        print('║   Auth: none (public)');
      }

      // index.js — parse registerExtension exports
      final indexJs = await _zipCat(zipPath, 'index.js');
      if (indexJs != null && indexJs.isNotEmpty) {
        final exports = _parseRegisterExtension(indexJs);
        allExports[id] = exports;
        print('║');
        print('║   registerExtension() exports (${exports.length}):');
        for (final fx in exports) {
          final tag = _capTags[fx];
          final label = tag != null ? ' [$tag]' : '';
          print('║     • $fx$label');
        }

        // API endpoints
        final endpoints = _findEndpoints(indexJs);
        if (endpoints.isNotEmpty) {
          print('║');
          print('║   API endpoints (${endpoints.length}):');
          for (final ep in endpoints.take(8)) {
            print('║     $ep');
          }
          if (endpoints.length > 8) {
            print('║     ... +${endpoints.length - 8} more');
          }
        }
      } else {
        allExports[id] = [];
        print('║   index.js not found');
      }

      await File(zipPath).delete();
      print('╚══════════════════════════════════════════════════════════════════════\n');
    } catch (e) {
      allExports[id] = [];
      allManifests[id] = {};
      print('║   ⚠  Error: $e');
      print('╚══════════════════════════════════════════════════════════════════════\n');
    }
  }

  // ── Summary table ──
  print('╔══════════════════════════════════════════════════════════════════════╗');
  print('║                         CAPABILITY MATRIX                           ║');
  print('╚══════════════════════════════════════════════════════════════════════╝\n');

  final cols = ['Provider', 'search', 'track', 'album', 'artist', 'playlist',
                 'lyrics', 'download', 'auth', 'check', 'enrich', 'homefeed',
                 'match', 'validate'];
  print('  ${cols[0].padRight(18)} ${cols.sublist(1).map((c) => c.padLeft(8)).join()}');
  print('  ${''.padRight(18, '─')} ${''.padRight(cols.length * 9 - 10, '─')}');

  for (final ext in extensions) {
    final e = ext as Map<String, dynamic>;
    final id = e['id'] as String? ?? '';
    final name = e['display_name'] as String? ?? id;
    final exports = allExports[id] ?? [];
    final s = StringBuffer(name.padRight(18));
    for (final col in cols.sublist(1)) {
      final key = _capTags.entries.firstWhere(
        (x) => x.value == col,
        orElse: () => MapEntry('', ''),
      ).key;
      if (key.isNotEmpty && exports.contains(key)) {
        s.write('  ✓  ');
      } else {
        final alt = _capTags.entries.where((x) => x.value == col && x.key != key);
        if (alt.isNotEmpty && alt.any((x) => exports.contains(x.key))) {
          s.write('  ✓  ');
        } else {
          s.write('     ');
        }
      }
    }
    print('  $s');
  }

  print('');
  print('  auth     = signedSession (ZARZ-HMAC-V1)');
  print('  check    = checkAvailability');
  print('  enrich   = enrichTrack');
  print('  homefeed = getHomeFeed');
  print('  match    = matchTrack');
  print('  validate = validateTrackForDownload');

  // ── Provider recommendation ──
  print('\n╔══════════════════════════════════════════════════════════════════════╗');
  print('║                         RECOMMENDATIONS                              ║');
  print('╚══════════════════════════════════════════════════════════════════════╝\n');

  print('  For metadata + lyrics:          Apple Music (only lyrics provider)');
  print('  For metadata + lossless DL:     Deezer, Qobuz, Tidal, Amazon');
  print('  For metadata + lossy DL:        SoundCloud, YouTube Music, Pandora');
  print('  For Spotify enrichment only:    Spotify Web (no download)');
  print('  For home feed/browse:           Spotify Web, Amazon, YouTube Music');
  print('');

  await Directory(_tmpDir).delete(recursive: true);
  print('Done.');
}
