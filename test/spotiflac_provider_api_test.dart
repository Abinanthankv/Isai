// SpotiFLAC Provider API Test — All providers, metadata + download flow
//
// Tests every provider from the registry against a unified JS bridge:
//   1. Download .sflx
//   2. Shim the runtime (log, utils, http, session)
//   3. Call searchTracks → getTrack → checkAvailability → download
//   4. Report what works and what doesn't for each provider
//
// Usage:
//   /home/abinanthan/flutter/flutter/bin/dart run test/spotiflac_provider_api_test.dart [query]

import 'dart:convert';
import 'dart:io';

const _registryUrl =
    'https://raw.githubusercontent.com/spotiflacapp/spotiflac-extension/main/registry.json';
const _tmpDir = '/tmp/spotiflac_api_test_all';

const _providers = {
  'spotify-web': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/spotify-web.sflx',
  'amzn': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/amzn.sflx',
  'apple-music': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/apple-music.sflx',
  'soundcloud': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/soundcloud.spotiflac-ext',
  'ytmusic-spotiflac': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/ytmusic-spotiflac.sflx',
  'deezer': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/deezer.sflx',
  'pandora': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/pandora.spotiflac-ext',
  'qobuz-web': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/qobuz-web.sflx',
  'tidal-web': 'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/tidal-web.sflx',
};

final _manifestTypes = <String, String>{};
final _exports = <String, List<String>>{};

// ── Unified JS bridge for ALL SpotiFLAC extensions ──
// Covers every runtime object referenced across all 9 providers.
String _universalBridge(String providerId) => '''
// ── SpotiFLAC Runtime Shim (universal, covers all providers) ──

// Logging
var log = {
  debug: function() {}, info: function() {}, warn: function() {}, error: function() {}
};

// Crypto (Node.js)
var crypto = require("crypto");

// Utilities — matches every utils.* call across all providers
var utils = {
  appUserAgent:       function() { return "SpotiFLAC-Mobile/4.7.0"; },
  appVersion:         function() { return "4.7.0"; },
  randomUserAgent:    function() { return "Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36"; },
  sha256:             function(d) { return crypto.createHash("sha256").update(String(d)).digest("hex"); },
  md5:                function(d) { return crypto.createHash("md5").update(String(d)).digest("hex"); },
  hmacSHA1:           function(d, k) { return crypto.createHmac("sha1", String(k)).update(String(d)).digest("base64"); },
  base64Decode:       function(d) { return Buffer.from(String(d), "base64").toString("utf8"); },
  decryptBlockCipher: function(d) { return d; },
  isDownloadCancelled: function() { return false; },
  sleep:              function(ms) { /* no-op */ }
};

// HTTP — synchronous (as SpotiFLAC runtime provides)
function httpGet(url, headers) {
  try {
    if (url.indexOf("api.deezer.com") >= 0 && url.indexOf("/search") >= 0) {
      return JSON.parse('{"statusCode":200,"body":"{\\\\"data\\\\":[{\\\\"id\\\\":3135556,\\\\"title\\\\":\\\\"Bohemian Rhapsody\\\\",\\\\"duration\\\\":354,\\\\"explicit_lyrics\\\\":false,\\\\"artist\\\\":{\\\\"id\\\\":403,\\\\"name\\\\":\\\\"Queen\\\\"},\\\\"album\\\\":{\\\\"id\\\\":302127,\\\\"title\\\\":\\\\"A Night At The Opera\\\\"}}],\\\\"total\\\\":1}"}');
    }
    if (url.indexOf("api.deezer.com") >= 0 && url.indexOf("/track/") >= 0) {
      var id = url.split("/track/")[1].split("?")[0].split("/")[0];
      return JSON.parse('{"statusCode":200,"body":"{\\\\"id\\\\":3135556,\\\\"title\\\\":\\\\"Bohemian Rhapsody\\\\",\\\\"duration\\\\":354,\\\\"isrc\\\\":\\\\"GBUM71029604\\\\",\\\\"explicit_lyrics\\\\":false,\\\\"artist\\\\":{\\\\"id\\\\":403,\\\\"name\\\\":\\\\"Queen\\\\"},\\\\"album\\\\":{\\\\"id\\\\":302127,\\\\"title\\\\":\\\\"A Night At The Opera\\\\"},\\\\"label\\\\":\\\\"EMI\\\\",\\\\"genre\\\\":{\\\\"name\\\\":\\\\"Rock\\\\"},\\\\"release_date\\\\":\\\\"1975-10-31\\\\"}"}');
    }
    if (url.indexOf("api.zarz.moe") >= 0 || url.indexOf("zarz.moe") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ status: "ok", data: [] }) };
    }
    if (url.indexOf("deezer") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ data: [{ id: 3135556, title: "Bohemian Rhapsody", artist: { name: "Queen" }, album: { title: "A Night At The Opera" } }] }) };
    }
    if (url.indexOf("amazon") >= 0 || url.indexOf("a2z.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ result: [{ id: "B0TEST", title: "Bohemian Rhapsody", primaryArtist: { name: "Queen" } }] }) };
    }
    if (url.indexOf("apple.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ data: [{ id: "900000001", attributes: { name: "Bohemian Rhapsody", artistName: "Queen", albumName: "A Night At The Opera" } }] }) };
    }
    if (url.indexOf("soundcloud.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify([{ id: 12345, title: "Bohemian Rhapsody", user: { username: "Queen" }, permalink_url: "https://soundcloud.com/queen/bohemian" }]) };
    }
    if (url.indexOf("youtube.com") >= 0 || url.indexOf("yt1d.io") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ items: [{ id: "fJ9rUzIMcZQ", snippet: { title: "Bohemian Rhapsody", channelTitle: "Queen" } }] }) };
    }
    if (url.indexOf("pandora.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ items: [{ id: "TRACK123", title: "Bohemian Rhapsody", artist: "Queen" }] }) };
    }
    if (url.indexOf("qobuz.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ tracks: { items: [{ id: 123456, title: "Bohemian Rhapsody", performer: { name: "Queen" } }] } }) };
    }
    if (url.indexOf("tidal.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ data: [{ id: "12345678", title: "Bohemian Rhapsody", artists: [{ name: "Queen" }] }] }) };
    }
    if (url.indexOf("spotify.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ tracks: { items: [{ id: "6rqhFgbbKwnb9MLmUQDhG6", name: "Bohemian Rhapsody", artists: [{ name: "Queen" }] }] } }) };
    }
    if (url.indexOf("song.link") >= 0 || url.indexOf("songstats") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ linksByPlatform: {} }) };
    }
    return { statusCode: 200, body: "{}" };
  } catch(e) { return { statusCode: 500, body: "{}", error: e.message }; }
}
var http = {
  get: httpGet,
  post: function(url, body, headers) {
    try {
      if (url.indexOf("zarz.moe") >= 0) return { statusCode: 200, body: JSON.stringify({ status: "ok" }) };
      if (url.indexOf("spotify.com") >= 0) return { statusCode: 200, body: JSON.stringify({ access_token: "mock", expiresIn: 3600 }) };
      if (url.indexOf("music.apple.com") >= 0) return { statusCode: 200, body: JSON.stringify({ data: [{ id: "900000001" }] }) };
      return { statusCode: 200, body: "{}" };
    } catch(e) { return { statusCode: 500, body: "{}", error: e.message }; }
  }
};

// Session (needed by providers with signedSession)
var session = {
  appVersion: "4.7.0",
  baseURL: "https://api.zarz.moe/v2",
  sessionId: "mock-session-id",
  deviceId: "mock-device-id",
  musicTerritory: "US",
  displayLanguage: "en",
  csrfToken: "mock-csrf",
  csrfRnd: "mock-rnd",
  csrfTs: Date.now(),
  initialized: true,
  completeGrant: function() { return { success: true, token: "mock" }; },
  signedFetch: function(method, path, body) {
    return { statusCode: 200, body: JSON.stringify({ status: "ok", data: {} }) };
  }
};
var completeGrant = function() { return session.completeGrant(); };

// registerExtension bridge
var _ext = null;
globalThis.registerExtension = function(ext) { _ext = ext; };
''';

// ── Test script template (provider-agnostic) ──
String _testScript(String providerId, String query) => '''
(async function() {
  var indent = "  ";
  var ok = "\\u2713";
  var fail = "\\u2717";
  var r = [];

  if (!_ext) { console.log(JSON.stringify({ error: "registerExtension not called" })); return; }

  // A. Search tracks
  try {
    if (typeof _ext.searchTracks !== "function") {
      r.push({ step: "A.searchTracks", status: "skip", reason: "not implemented" });
    } else {
      var results = await _ext.searchTracks(${jsonEncode(query)}, { limit: 3 });
      r.push({ step: "A.searchTracks", status: "ok", count: results.length });
      if (results.length > 0) {
        var first = results[0];
        r.push({ step: "A.searchTracks[0]", id: String(first.id || "").substring(0, 30), title: (first.title || first.name || "").substring(0, 40), artist: (first.artist || (first.artists ? (Array.isArray(first.artists) ? first.artists.join(",") : first.artists) : "")).substring(0, 30), album: (first.album_name || "").substring(0, 30) });
      }
    }
  } catch(e) { r.push({ step: "A.searchTracks", status: "error", error: (e.message || e).substring(0, 80) }); }

  // B. Get track
  try {
    if (typeof _ext.getTrack !== "function") {
      r.push({ step: "B.getTrack", status: "skip", reason: "not implemented" });
    } else {
      var trackId = arguments && arguments[0] ? arguments[0] : null;
      if (!trackId && r.length > 1 && r[1].id) trackId = r[1].id;
      if (trackId) {
        var detail = await _ext.getTrack(trackId);
        r.push({ step: "B.getTrack", status: detail ? "ok" : "null", fields: detail ? Object.keys(detail).join(",").substring(0, 80) : "null" });
      } else {
        r.push({ step: "B.getTrack", status: "skip", reason: "no trackId from search" });
      }
    }
  } catch(e) { r.push({ step: "B.getTrack", status: "error", error: (e.message || e).substring(0, 80) }); }

  // C. Check availability
  try {
    if (typeof _ext.checkAvailability !== "function") {
      r.push({ step: "C.checkAvailability", status: "skip", reason: "not implemented" });
    } else {
      var avail = await _ext.checkAvailability("test-id");
      r.push({ step: "C.checkAvailability", status: "ok", available: avail ? avail.available : "null" });
    }
  } catch(e) { r.push({ step: "C.checkAvailability", status: "error", error: (e.message || e).substring(0, 80) }); }

  // D. Download
  try {
    if (typeof _ext.download !== "function") {
      r.push({ step: "D.download", status: "skip", reason: "not implemented" });
    } else {
      var dl = await _ext.download({ type: "track", id: "3135556", name: "Bohemian Rhapsody", artists: "Queen", album_name: "A Night At The Opera" }, {}, function(){});
      r.push({ step: "D.download", status: dl && dl.success ? "ok" : "fail", success: dl ? dl.success : "N/A", error_type: dl ? (dl.error_type || dl.error || "") : "N/A" });
    }
  } catch(e) { r.push({ step: "D.download", status: "error", error: (e.message || e).substring(0, 80) }); }

  // E. handleUrl
  try {
    if (typeof _ext.handleUrl !== "function") {
      r.push({ step: "E.handleUrl", status: "skip", reason: "not implemented" });
    } else {
      var hu = await _ext.handleUrl("https://example.com/track/123");
      r.push({ step: "E.handleUrl", status: hu ? "ok" : "null", type: hu ? hu.type : "N/A" });
    }
  } catch(e) { r.push({ step: "E.handleUrl", status: "error", error: (e.message || e).substring(0, 80) }); }

  // F. getAlbum / getArtist / getPlaylist (sanity check)
  for (var pair of [["F.getAlbum", "getAlbum"], ["G.getArtist", "getArtist"], ["H.getPlaylist", "getPlaylist"]]) {
    try {
      if (typeof _ext[pair[1]] !== "function") {
        r.push({ step: pair[0], status: "skip", reason: "not implemented" });
      } else {
        var res = await _ext[pair[1]]("test");
        r.push({ step: pair[0], status: res ? "ok" : "null" });
      }
    } catch(e) { r.push({ step: pair[0], status: "error", error: (e.message || e).substring(0, 60) }); }
  }

  console.log(JSON.stringify(r));
})();
''';

// ── Main ──
Future<void> main(List<String> args) async {
  final query = args.isNotEmpty ? args.join(' ') : 'Bohemian Rhapsody Queen';
  await Directory(_tmpDir).create(recursive: true);

  // Fetch registry
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  final req = await client.getUrl(Uri.parse(_registryUrl));
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  client.close();
  final registry = jsonDecode(body) as Map;
  final extList = registry['extensions'] as List;

  // Build registry lookup
  final registryInfo = <String, Map>{};
  for (final e in extList) {
    final m = e as Map;
    registryInfo[m['id'] as String] = m;
  }

  final results = <String, Map>{};

  for (final entry in _providers.entries) {
    final id = entry.key;
    final url = entry.value;
    final info = registryInfo[id] ?? {};
    final displayName = info['display_name'] as String? ?? id;

    print('\n╔══ $displayName ($id) '.padRight(68, '═'));

    try {
      // Download
      final bytes = await _fetchBytes(url);
      final zipPath = '$_tmpDir/$id.sflx';
      await File(zipPath).writeAsBytes(bytes);

      // Extract manifest
      final mJson = await _zipCat(zipPath, 'manifest.json');
      Map manifest = {};
      if (mJson != null && mJson.isNotEmpty) {
        try { manifest = jsonDecode(mJson) as Map; } catch (_) {}
      }
      String types = '';
      if (manifest['type'] is List) {
        types = (manifest['type'] as List).join(', ');
      }
      _manifestTypes[id] = types;

      // Extract index.js
      final indexJs = await _zipCat(zipPath, 'index.js');
      if (indexJs == null || indexJs.isEmpty) {
        print('  ⚠  index.js not found');
        results[id] = {'error': 'index.js not found'};
        continue;
      }

      // Combine: bridge + extension
      final combined = '${_universalBridge(id)}\n$indexJs\n${_testScript(id, query)}';

      // Write and execute
      final scriptPath = '$_tmpDir/${id}_test.js';
      await File(scriptPath).writeAsString(combined);

      final proc = await Process.run('node', [scriptPath], runInShell: true);
      final stdout = proc.stdout.toString().trim();
      final stderr = proc.stderr.toString().trim();
      final exitCode = proc.exitCode;

      // Parse JSON result
      if (exitCode == 0 && stdout.isNotEmpty) {
        try {
          final steps = jsonDecode(stdout) as List;
          results[id] = {'steps': steps};

          // Pretty-print
          for (final s in steps) {
            final step = s['step'] as String? ?? '';
            final status = s['status'] as String? ?? '';
            final icon = status == 'ok' ? '✓' : (status == 'skip' ? '–' : '✗');
            if (step.startsWith('A.searchTracks[0]')) {
              print('  ${step}: id=${s['id']}, title=${s['title']}, artist=${s['artist']}');
            } else if (step.startsWith('D.download') && status == 'fail') {
              print('  ${step}: ${icon} success=${s['success']}, error=${s['error_type']}');
            } else if (step.startsWith('E.')) {
              print('  ${step}: ${icon} type=${s['type'] ?? status}');
            } else {
              final extra = s['count'] != null ? ' (${s['count']} results)' :
                            s['available'] != null ? ' available=${s['available']}' :
                            s['fields'] != null ? ' fields=${s['fields']}' :
                            s['reason'] != null ? ' [${s['reason']}]' :
                            s['error'] != null ? ' (${s['error']})' :
                            s['error_type'] != null ? ' (${s['error_type']})' : '';
              print('  ${step}: ${icon}${extra}');
            }
          }
        } catch (e) {
          results[id] = {'raw': stdout.substring(0, 200)};
          print('  stdout: $stdout');
        }
      } else {
        results[id] = {'exit': exitCode, 'stderr': stderr.substring(0, 200)};
        print('  exit: $exitCode');
        if (stderr.isNotEmpty) print('  stderr: ${stderr.substring(0, 150)}');
      }

      // Cleanup
      await File(zipPath).delete();
      await File(scriptPath).delete();
    } catch (e) {
      results[id] = {'error': e.toString()};
      print('  ⚠  $e');
    }
  }

  // ── Summary table ──
  print('\n\n╔══════════════════════════════════════════════════════════════════════╗');
  print('║                      ALL PROVIDERS — SUMMARY                         ║');
  print('╚══════════════════════════════════════════════════════════════════════╝');

  final header = 'Provider'.padRight(22) + 'Type'.padRight(32) + 'Search  Track  ChkAv  Dload  Url  Album  Artist  Playlist';
  print('\n  $header');
  print('  ${''.padRight(90, '─')}');

  for (final entry in _providers.entries) {
    final id = entry.key;
    final info = registryInfo[id] ?? {};
    final name = (info['display_name'] as String? ?? id).padRight(22);
    final type = (_manifestTypes[id] ?? info['category'] ?? '').padRight(30);
    final r = results[id];
    final line = StringBuffer('  $name$type');

    if (r == null) {
      print('${line} — no result');
      continue;
    }

    final steps = r['steps'] as List?;
    if (steps == null) {
      print('${line} error: ${(r['error'] ?? r['exit'] ?? '?').toString().substring(0, 30)}');
      continue;
    }

    for (final prefix in ['A.searchTracks', 'B.getTrack', 'C.checkAvailability',
                           'D.download', 'E.handleUrl', 'F.getAlbum',
                           'G.getArtist', 'H.getPlaylist']) {
      final step = steps.cast<Map<String, dynamic>>().where(
        (s) => (s['step'] as String?)?.startsWith(prefix) == true).firstOrNull;
      if (step == null) {
        line.write(' ?  ');
      } else {
        final status = step['status'] as String? ?? '';
        if (status == 'ok') line.write(' ✓  ');
        else if (status == 'skip') line.write(' –  ');
        else line.write(' ✗  ');
      }
    }
    print(line);
  }

  // Cleanup dir
  await Directory(_tmpDir).delete(recursive: true);
  print('\nDone.');
}

Future<List<int>> _fetchBytes(String url) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 20);
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
  final result = await Process.run('unzip', ['-p', zipPath, fileName], runInShell: true);
  if (result.exitCode != 0) return null;
  return (result.stdout as String).trim();
}
