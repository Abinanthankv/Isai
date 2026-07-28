// Download Flow Test — focused on YouTube Music (public, has full download impl)
//
// Tests the complete download pipeline:
//   checkAvailability -> searchTracks/getTrack -> download -> audio URL
//
// Uses REAL fetch() for YouTube API + proper mocks for fallback APIs.
//
// Usage:
//   /home/abinanthan/flutter/flutter/bin/dart test/download_flow_test.dart

import 'dart:convert';
import 'dart:io';

const _tmpDir = '/tmp/download_flow_test';

const _ytMusicUrl =
    'https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/extensions/ytmusic-spotiflac.sflx';

void main(List<String> args) async {
  await Directory(_tmpDir).create(recursive: true);

  print('\n==============================================================');
  print('  YouTube Music - Download Flow Test');
  print('==============================================================\n');

  // 1. Download extension
  print('Downloading extension...');
  final bytes = await _fetchBytes(_ytMusicUrl);
  final zipPath = '$_tmpDir/ytmusic.sflx';
  await File(zipPath).writeAsBytes(bytes);
  print('  Size: ${bytes.length} bytes');

  // 2. Extract manifest
  final manifestJson = await _zipCat(zipPath, 'manifest.json');
  if (manifestJson != null) {
    final manifest = jsonDecode(manifestJson);
    print('  Name: ${manifest['displayName']}');
    print('  Type: ${(manifest['type'] as List).join(', ')}');
  }

  // 3. Extract index.js
  final indexJs = await _zipCat(zipPath, 'index.js');
  if (indexJs == null || indexJs.isEmpty) {
    print('ERROR: index.js not found');
    exit(1);
  }
  print('  Code: ${indexJs.length} chars\n');

  // 4. Build JS test and run
  print('Running JS test...');
  final script = buildTestScript(indexJs);
  final scriptPath = '$_tmpDir/ytmusic_test.js';
  await File(scriptPath).writeAsString(script);

  final result = await Process.run('node', [scriptPath], runInShell: true);

  if (result.exitCode == 0) {
    final output = result.stdout.toString().trim();
    try {
      final steps = jsonDecode(output) as List;
      for (final s in steps) {
        final step = s['step'] ?? '';
        final status = s['status'] ?? '';
        final icon = status == 'ok'
            ? 'OK'
            : (status == 'skip' ? '--' : 'FAIL');
        final info = s['available'] != null
            ? 'available=${s['available']}'
            : s['track_id'] != null
                ? 'track=${s['track_id']}'
                : s['count'] != null
                    ? '(${s['count']})'
                    : s['file_path'] != null
                        ? 'path=${s['file_path']}'
                        : s['url'] != null
                            ? 'url=${s['url']}'
                            : s['error'] != null
                                ? s['error']
                                : s['error_type'] != null
                                    ? s['error_type']
                                    : '';
        print('  $step: $icon $info');
      }
    } catch (e) {
      print('  Output: $output');
    }
  } else {
    print('  Exit: ${result.exitCode}');
    print('  STDERR: ${result.stderr}');
  }

  // 6. Integration plan
  print('\n==============================================================');
  print('  INTEGRATION: What to change in the app');
  print('==============================================================\n');

  print('''
  The existing PluginManager._createRuntime() needs these additions:

  1. REGISTER SPOTIFLAC SHIM

    In _createRuntime(), before evaluating extension code, register:
      - log        (debug/info/warn/error)
      - utils      (appUserAgent, sha256, md5, hmacSHA1, etc.)
      - http       (get/post -- synchronous via sendMessage bridge)
      - registerExtension global function
      - globalThis.search and globalThis.getStream adapters
      - session object (for ZARZ-HMAC-V1 providers)

  2. FILES TO MODIFY

    lib/features/music/data/plugins/plugin_manager.dart
      - _createRuntime(): add the SpotiFLAC runtime shim
      - search(): add registerExtension adapter fallback
      - resolveStream(): add registerExtension adapter fallback

    lib/features/music/data/scrapers/js_plugin_scraper.dart
      - handle lazy://plugin/ URL scheme

  3. SESSION PROVIDERS

    Deezer, Qobuz, Tidal, Amazon need signed session.
    The provider JS handles HMAC internally via signedFetch().
    Dart needs HTTP transport + token storage.

    Flow: bootstrap -> challenge -> exchange -> signedFetch

  4. PUBLIC PROVIDERS (no session needed)

    YouTube Music: uses REAL fetch() to YouTube InnerTube API.
                  NO API KEY required. Tests here use real API.
    SoundCloud:   uses http.get to api-v2.soundcloud.com
    Pandora:      uses http.get/post (needs proper mocks)

''');

  await Directory(_tmpDir).delete(recursive: true);
  print('Done.');
}

String buildTestScript(String indexJs) {
  final shim = _shim();
  final testCode = _testCode();
  return '$shim\n$indexJs\n$testCode';
}

String _shim() {
  // Split into parts to avoid Dart string parsing issues
  return r'''
// SpotiFLAC Runtime Shim
var log = { debug:function(){}, info:function(){}, warn:function(){}, error:function(){} };
var crypto = require("crypto");
var utils = {
  appUserAgent: function() { return "DebridVault/1.0"; },
  appVersion: function() { return "1.0"; },
  randomUserAgent: function() { return "Mozilla/5.0 (Linux; Android 14)"; },
  sha256: function(d) { return crypto.createHash("sha256").update(String(d)).digest("hex"); },
  md5: function(d) { return crypto.createHash("md5").update(String(d)).digest("hex"); },
  hmacSHA1: function(d,k){return crypto.createHmac("sha1",String(k)).update(String(d)).digest("base64");},
  base64Decode: function(d) { return Buffer.from(String(d),"base64").toString("utf8"); },
  decryptBlockCipher: function(d) { return d; },
  isDownloadCancelled: function() { return false; },
  sleep: function() {}
};

// HTTP shim for non-YouTube APIs
var httpCalls = [];
var http = {
  get: function(url, h) {
    httpCalls.push({ method: "GET", url: url });
    if (url.indexOf("api.deezer.com") >= 0) {
      return { statusCode: 200, body: JSON.stringify({ data: [{ id: "fJ9rUzIMcZQ", title: "Bohemian Rhapsody", artist: { name: "Queen" } }] }) };
    }
    return { statusCode: 200, body: JSON.stringify({}) };
  },
  post: function(url, b, h) {
    httpCalls.push({ method: "POST", url: url });
    return { statusCode: 200, body: JSON.stringify({}) };
  }
};

// registerExtension bridge
var _ext = null;
globalThis.registerExtension = function(ext) { _ext = ext; };

// Adapter: globalThis.search -> _ext.searchTracks
globalThis.search = async function(q) {
  if (!_ext || !_ext.searchTracks) return JSON.stringify([]);
  try {
    var r = await _ext.searchTracks(q, {limit: 3});
    return JSON.stringify(r.map(function(x) { return {
      title: x.name || x.title || "",
      artist: typeof x.artist === "string" ? x.artist : (x.artists ? (Array.isArray(x.artists) ? x.artists.join(", ") : x.artists) : ""),
      url: "lazy://plugin/" + encodeURIComponent(x.id),
      trackId: x.id, isLazy: true, size: 0, format: "flac",
      source: "YouTubeMusic"
    }; }));
  } catch(e) { return JSON.stringify([]); }
};

// Adapter: globalThis.getStream -> _ext.download
globalThis.getStream = async function(id) {
  if (!_ext || !_ext.download) return null;
  try {
    var rawId = String(id).replace(/^[a-z]+:/, "");
    var r = await _ext.download({
      type: "track", id: rawId, name: "", artists: "", album_name: ""
    }, {}, function(){});
    if (r && r.success && r.file_path) return r.file_path;
    return null;
  } catch(e) { return null; }
};
''';
}

String _testCode() {
  return r'''
// Test Runner
(async function() {
  var r = [];

  r.push({ step: "INIT", status: _ext ? "ok" : "fail" });

  // A. searchTracks
  try {
    var results = await _ext.searchTracks("Bohemian Rhapsody Queen", {limit:3});
    r.push({ step: "A.searchTracks", status: "ok", count: results.length });
    if (results.length > 0) {
      var first = results[0];
      r.push({ step: "A.track[0]", status: "ok",
        id: String(first.id || "").substring(0, 25),
        title: (first.title || first.name || "").substring(0, 40),
        artist: (first.artist || "").substring(0, 25)
      });
    }
  } catch(e) { r.push({ step: "A.searchTracks", status: "error", error: (e.message||"").substring(0,80) }); }

  // B. checkAvailability with spotify_id (bypasses search)
  try {
    var avail = await _ext.checkAvailability(null, "Test", "", { spotify_id: "fJ9rUzIMcZQ" });
    r.push({ step: "B.checkAvail(byID)", status: "ok",
      available: String(avail ? avail.available : "null"),
      track_id: avail ? (avail.track_id || "") : "N/A"
    });
  } catch(e) { r.push({ step: "B.checkAvail(byID)", status: "error", error: (e.message||"").substring(0,80) }); }

  // C. checkAvailability by artist+track search (uses REAL YouTube API)
  try {
    var avail2 = await _ext.checkAvailability(null, "Bohemian Rhapsody", "Queen", {});
    r.push({ step: "C.checkAvail(search)", status: "ok",
      available: String(avail2 ? avail2.available : "null"),
      track_id: avail2 ? (avail2.track_id || "") : "N/A",
      reason: avail2 ? (avail2.reason || "") : ""
    });
  } catch(e) { r.push({ step: "C.checkAvail(search)", status: "error", error: (e.message||"").substring(0,80) }); }

  // D. download (tries InnerTube -> Cobalt -> yt1d)
  try {
    var dl = await _ext.download(
      { type: "track", id: "fJ9rUzIMcZQ", name: "Bohemian Rhapsody", artists: "Queen", album_name: "A Night At The Opera" },
      {}, function(){}
    );
    if (dl) {
      r.push({ step: "D.download", status: dl.success ? "ok" : "fail",
        success: String(dl.success),
        file_path: (dl.file_path || "").substring(0, 80),
        error_type: (dl.error_type || ""),
        error: (dl.error || "").substring(0, 80)
      });
    } else {
      r.push({ step: "D.download", status: "null_result" });
    }
  } catch(e) { r.push({ step: "D.download", status: "error", error: (e.message||"").substring(0,100) }); }

  // E. adapter: globalThis.search
  try {
    var searchResult = await globalThis.search("Bohemian Rhapsody Queen");
    var parsed = JSON.parse(searchResult);
    r.push({ step: "E.adapter.search", status: "ok", count: parsed.length });
  } catch(e) { r.push({ step: "E.adapter.search", status: "error", error: (e.message||"").substring(0,80) }); }

  // F. adapter: globalThis.getStream
  try {
    var streamUrl = await globalThis.getStream("fJ9rUzIMcZQ");
    r.push({ step: "F.adapter.getStream", status: streamUrl ? "ok" : "fail", url: (streamUrl || "null").substring(0,80) });
  } catch(e) { r.push({ step: "F.adapter.getStream", status: "error", error: (e.message||"").substring(0,80) }); }

  r.push({ step: "httpCalls", count: httpCalls.length });

  console.log(JSON.stringify(r));
})();
''';
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
