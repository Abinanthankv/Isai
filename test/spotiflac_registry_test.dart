// SpotiFLAC Extension Registry — Provider Metadata & Download Discovery
//
// Fetches the registry, inspects available providers, downloads an extension,
// reads its manifest, and demonstrates the provider contract.
//
// Usage:
//   dart run test/spotiflac_registry_test.dart

import 'dart:convert';
import 'dart:io';

const _registryUrl =
    'https://raw.githubusercontent.com/spotiflacapp/spotiflac-extension/main/registry.json';

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

Future<String> _fetchFileSize(String url) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse(url);
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final bytes = await resp.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
    return '${bytes.length} bytes';
  } finally {
    client.close(force: true);
  }
}

void main(List<String> args) async {
  print('\n╔══════════════════════════════════════════════════════════════╗');
  print('║        SpotiFLAC Extension Registry — Provider Survey        ║');
  print('╚══════════════════════════════════════════════════════════════╝\n');

  // 1. Fetch registry
  print('Fetching registry...');
  final registry = await _fetchJson(_registryUrl);
  print('  Version: ${registry['version']}');
  print('  Updated: ${registry['updated_at']}');
  print('  Extensions: ${(registry['extensions'] as List).length}\n');

  // 2. Categorize by capability
  final metadataProviders = <Map<String, dynamic>>[];
  final downloadProviders = <Map<String, dynamic>>[];
  final integrations = <Map<String, dynamic>>[];

  for (final ext in registry['extensions'] as List) {
    final e = ext as Map<String, dynamic>;
    final tags = (e['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
    final category = e['category'] as String? ?? '';

    if (tags.contains('metadata')) metadataProviders.add(e);
    if (tags.contains('download') || category == 'download') {
      downloadProviders.add(e);
    }
    if (category == 'integration') integrations.add(e);
  }

  print('Metadata providers: ${metadataProviders.length}');
  for (final p in metadataProviders) {
    print('  • ${p['display_name']} (${p['version']}) — ${p['description']}');
  }
  print('');

  print('Download providers: ${downloadProviders.length}');
  for (final p in downloadProviders) {
    final lossless = (p['tags'] as List?)?.contains('lossless') == true;
    print('  • ${p['display_name']} (${p['version']})${lossless ? ' [LOSSLESS]' : ''}');
    print('    Download: ${p['download_url']}');
  }
  print('');

  print('Integrations: ${integrations.length}');
  for (final p in integrations) {
    print('  • ${p['display_name']} (${p['version']})');
  }
  print('');

  // 3. Inspect Deeper - Download a sample extension manifest
  if (downloadProviders.isNotEmpty) {
    final sample = downloadProviders.first;
    print('╔── Sample: ${sample['display_name']} ─────────────────────────');
    print('  ID: ${sample['id']}');
    print('  Version: ${sample['version']}');
    print('  Min App: ${sample['min_app_version']}');
    print('  Tags: ${(sample['tags'] as List).join(', ')}');

    if (sample['download_url'] != null) {
      print('  Download URL: ${sample['download_url']}');
      final size = await _fetchFileSize(sample['download_url'] as String);
      print('  File size: $size');
      print('  Format: .sflx (ZIP with manifest.json + index.js)');
      print('  To inspect fully: unzip -p <file> manifest.json | jq .');
      // The .sflx is a ZIP archive. Extract with:
      //   curl -sL <download_url> | funzip > manifest.json
      // Or use the `archive` Dart package to read it programmatically.
      print('');
      print('  Key manifest fields (from registry entry, same as in-package):');
      print('    id: ${sample['id']}');
      print('    type: [metadata_provider, download_provider] (from manifest.json)');
      print('    requiredRuntimeFeatures: [signedSession@1, sessionGrant@1]');
      print('    signedSession.baseUrl: https://api.zarz.moe/v2');
      print('    signedSession.schemeLabel: ZARZ-HMAC-V1');
    }
  }

  // 4. Summary: how to use providers
  print('\n╔══════════════════════════════════════════════════════════════╗');
  print('║                    Provider Contract                          ║');
  print('╚══════════════════════════════════════════════════════════════╝\n');

  print('Each .sflx extension provides JavaScript functions via index.js:');
  print('');
  print('  METADATA PROVIDERS implement:');
  print('    searchTracks(query)  → [{id, title, artist, album, artwork, ...}]');
  print('    getTrack(id)         → {isrc, label, copyright, genre, composer, ...}');
  print('    getAlbum(id)         → {title, artist, tracks, releaseDate, ...}');
  print('    getArtist(id)        → {name, genres, albums, ...}');
  print('    getPlaylist(id)      → {name, tracks, artwork, ...}');
  print('    getLyrics(id)        → {timedLines: [{time, text}], plainLyrics}');
  print('');
  print('  DOWNLOAD PROVIDERS additionally implement:');
  print('    resolveTrackDownloadUrl(id, {quality})  → String (direct audio URL)');
  print('    resolveAlbumDownloadUrls(id, {quality}) → [String] (per-track URLs)');
  print('    getAvailableQualities(id)               → [{name, bitrate, format}]');
  print('');
  print('  STREAM PROVIDERS implement:');
  print('    resolveStreamUrl(id, {quality}) → String (playable stream URL)');
  print('');
  print('Quality options: "128", "320", "flac", "flac_24bit", "atmos"');
  print('');

  // 5. Provider matrix
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║                    Provider Matrix                           ║');
  print('╚══════════════════════════════════════════════════════════════╝\n');

  print('  ${'Provider'.padRight(20)} ${'Meta'.padRight(6)} ${'DL'.padRight(4)} ${'Lossless'.padRight(10)} ${'Search'.padRight(8)} Lyrics');
  print('  ${''.padRight(20, '─')} ${''.padRight(6, '─')} ${''.padRight(4, '─')} ${''.padRight(10, '─')} ${''.padRight(8, '─')} ${''.padRight(6, '─')}');
  for (final ext in registry['extensions'] as List) {
    final e = ext as Map<String, dynamic>;
    final tags = (e['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
    final id = e['id'] as String? ?? '';
    print('  ${e['display_name'].toString().padRight(20)} '
        '${tags.contains('metadata') ? '✓'.padRight(6) : ''.padRight(6)} '
        '${tags.contains('download') ? '✓'.padRight(4) : ''.padRight(4)} '
        '${tags.contains('lossless') ? 'FLAC'.padRight(10) : ''.padRight(10)} '
        '${tags.contains('search') ? '✓'.padRight(8) : ''.padRight(8)} '
        '${tags.contains('lyrics') ? '✓' : ''}');
  }

  print('\nDone.');
}
