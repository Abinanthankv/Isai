// Deezer ARL → Stream URL Probe
//
// Validates the full private gw-light pipeline against a real Deezer ARL cookie
// BEFORE any production code is touched:
//   1. deezer.getUserData      → api_token (checkForm), sid (SESSION), license_token
//   2. song.getListData        → TRACK_TOKEN + MD5_ORIGIN for a track id
//   3. media.deezer.com/v1/get_url → CDN stream URL (Blowfish-encrypted)
//   4. Head-fetch the CDN URL  → headers + encryption presence check
//
// Usage:
//   export DEEZER_ARL='<your arl cookie value>'
//   /home/abinanthan/flutter/flutter/bin/dart run test/deezer_arl_probe_test.dart [trackId] [--quality=mp3_320|flac]
//
// Defaults: trackId=3135556, quality=all (MP3_128 + MP3_320 + FLAC).
//
// NOTE: Full-track private-API streaming is against Deezer's ToS. Use only with
// your own account. This probes your own ARL only.

// ── OPTIONAL: hardcode your ARL here (easiest for quick runs). ──
// Leave empty to fall back to the DEEZER_ARL environment variable instead.


import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
const String kHardcodedArl = '5dc64f5e6801c359a86b38a0f82332f51563f02185ddc97f118632f8791f720833720c47b76f5d0f1150ddf459e0ebb9ee18707b19fdb5a34ff43cb06bdc607295fb23736167b1161ae9770cf96e36fb8e4209f718eca102346a9f535f46354b';
const _gwUrl = 'https://www.deezer.com/ajax/gw-light.php';
const _mediaUrl = 'https://media.deezer.com/v1/get_url';
const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, '
    'like Gecko) Chrome/125.0.0.0 Safari/537.36';
const _defaultTrackId = '3135556';

bool kDebug = true;

void _dump(String label, Map<String, Object?> res) {
  if (!kDebug) return;
  final body = (res['body'] as String?) ?? '';
  print('\n    ┌── [DEBUG DATA: $label] (HTTP ${res['status']})');
  if (res['sid'] != null) {
    print('    │ Extracted sid from Set-Cookie: ${res['sid']}');
  }
  print('    │ Response Body:');
  for (final line in body.split('\n')) {
    print('    │ $line');
  }
  print('    └──────────────────────────────────────────────────\n');
}

final _client = HttpClient()
  ..connectionTimeout = const Duration(seconds: 20);

Future<void> main(List<String> args) async {
  final arl = _findArl(args);
  if (arl == null || arl.isEmpty) {
    print('No ARL found. Set the DEEZER_ARL environment variable, e.g.:');
    print('  export DEEZER_ARL=\'<your arl cookie value>\'');
    print('Or pass it directly: dart run test/deezer_arl_probe_test.dart --arl=...');
    exit(2);
  }

  final trackId = _findTrackId(args);
  final qualities = _findQualities(args);
  kDebug = true;

  print('\n╔══ DEEZER ARL PROBE '.padRight(64, '═'));
  print('  trackId:  $trackId');
  print('  quality:  ${qualities.join(', ')}');
  print('  arl:      ${arl.length}-char cookie '
      '(${arl.length >= 100 ? 'looks complete' : 'TOO SHORT — should be ~192 chars'})');

  // ── Step 1: Auth ──
  final sid = await _stepPing(arl);
  final auth = await _stepGetUserData(arl, sid);
  if (auth == null) {
    print('\n  ABORT: authentication failed.');
    _client.close(force: true);
    exit(1);
  }

  // ── Step 2: Track token ──
  final track = await _stepGetListData(auth, trackId);
  if (track == null) {
    print('\n  ABORT: could not fetch track token.');
    _client.close(force: true);
    exit(1);
  }

  // ── Step 3: Stream URLs ──
  final urls = <String, String?>{};
  for (final fmt in qualities) {
    urls[fmt] = await _stepGetUrl(auth, track, fmt);
  }

  // ── Step 4: Verify CDN ──
  final verify = <String, Map<String, Object>>{};
  for (final fmt in qualities) {
    final url = urls[fmt];
    if (url == null || url.isEmpty) {
      verify[fmt] = {'url': ''};
      continue;
    }
    verify[fmt] = await _stepVerifyCdn(url, fmt);
  }

  // ── Summary ──
  print('\n\n╔══════════════════════════════════════════════════════════════════════╗');
  print('║                        DEEZER ARL — SUMMARY                            ║');
  print('╚══════════════════════════════════════════════════════════════════════╝');
  for (final fmt in qualities) {
    final u = urls[fmt];
    if (u == null || u.isEmpty) {
      print('  $fmt  ✗  no stream URL (account/format unavailable)');
      continue;
    }
    final v = verify[fmt] ?? {};
    final status = (v['status'] ?? '?').toString();
    final enc = (v['encrypted'] ?? '?').toString();
    print('  $fmt  ✓  ${v['mime'] ?? '?'}  ${v['bytes'] ?? '?'} bytes  '
        'encrypted=$enc  http=$status');
    print('       URL: $u');
  }

  if (track['key'] != null) {
    print('\n  Reference (needed for Blowfish decryption later):');
    print('    SNG_ID:     ${track['id']}');
    print('    MD5_ORIGIN: ${track['md5']}');
    print('    BF key     = md5(MD5_ORIGIN + SNG_ID) = ${track['key']}');
  }

  _client.close(force: true);
  print('\nDone.');
}

// ── Step 0: Ping → SESSION ──
Future<String?> _stepPing(String arl) async {
  print('\n── Step 0: deezer.ping ───────────────────────────────────────────');
  final url = '$_gwUrl?method=deezer.ping&api_version=1.0&input=3&api_token=';
  final res = await _post(url, '', 'arl=$arl');
  print('  HTTP ${res['status']}');
  _dump('ping', res);

  Map<String, dynamic> json;
  try {
    json = jsonDecode(res['body'] as String) as Map<String, dynamic>;
  } catch (e) {
    print('  ✗ could not parse ping response: '
        '${(res['body'] as String).substring(0, 120)}');
    return null;
  }

  final err = json['error'];
  if (err != null && err != false && err != 0 && (err is List ? err.isNotEmpty : true)) {
    print('  ✗ ping error: $err');
    return null;
  }

  final results = json['results'] as Map<String, dynamic>?;
  final session = results?['SESSION'] as String?;
  if (session == null || session.isEmpty) {
    print('  ✗ no SESSION from deezer.ping (continuing without sid)');
    return null;
  }
  print('  ✓ sid (SESSION): ${session.length} chars');
  return session;
}

// ── Step 1 ──
Future<Map<String, Object?>?> _stepGetUserData(String arl, String? sid) async {
  print('\n── Step 1: deezer.getUserData ────────────────────────────────────');
  final url = '$_gwUrl?method=deezer.getUserData&api_version=1.0&input=3&api_token=';
  final res = await _post(url, '', _cookie(arl, sid));
  print('  HTTP ${res['status']}');
  _dump('getUserData', res);

  Map<String, dynamic> json;
  try {
    json = jsonDecode(res['body'] as String) as Map<String, dynamic>;
  } catch (e) {
    print('  ✗ could not parse response: ${(res['body'] as String).substring(0, 120)}');
    return null;
  }

  final err = json['error'];
  if (err != null && err != false && err != 0 && (err is List ? err.isNotEmpty : true)) {
    print('  ✗ auth error: $err');
    print('  Hint: invalid/expired ARL, or you were logged out elsewhere.');
    return null;
  }

  final results = json['results'] as Map<String, dynamic>?;
  if (results == null) {
    print('  ✗ no results in response');
    return null;
  }

  final user = results['USER'] as Map<String, dynamic>? ?? {};
  final options = user['OPTIONS'] as Map<String, dynamic>? ?? {};
  final licenseToken = options['license_token'] as String?;
  final apiToken = results['checkForm'] as String?;
  final setCookieSid = res['sid'] as String?;
  final resolvedSid = (results['SESSION'] as String?) ??
      (results['SESSION_ID'] as String?) ??
      setCookieSid ??
      sid;
  final userId = results['user_id'] ?? results['USER_ID'] ?? user['USER_ID'] ?? '?';
  final name = user['NAME'] ?? user['FIRSTNAME'] ?? '?';
  final country = user['COUNTRY'] ?? options['country'] ?? '?';

  final premium = licenseToken != null && licenseToken.isNotEmpty;

  print('  ✓ logged in as $name (id=$userId, country=$country)');
  print('    premium entitlement: ${premium ? 'YES (license_token present)' : 'NO — free account (320kbps/FLAC will fail)'}');
  print('    api_token (checkForm): ${apiToken == null ? 'MISSING ✗' : apiToken.length.toString() + ' chars ✓'}');
  print('    sid (SESSION):         ${resolvedSid == null ? 'MISSING ✗' : resolvedSid.length.toString() + ' chars ✓'}');

  if (apiToken == null || licenseToken == null) {
    print('  ✗ missing required credential from getUserData');
    return null;
  }

  return {
    'arl': arl,
    'api_token': apiToken,
    'sid': resolvedSid,
    'license_token': licenseToken,
    'premium': premium,
  };
}

// ── Step 2 ──
Future<Map<String, Object?>?> _stepGetListData(
    Map<String, Object?> auth, String trackId) async {
  print('\n── Step 2: song.getListData ──────────────────────────────────────');
  final apiToken = auth['api_token']! as String;
  final sid = auth['sid'] as String?;
  final arl = auth['arl']! as String;
  final url = '$_gwUrl?method=song.getListData&api_version=1.0&input=3&api_token=$apiToken';
  final res = await _post(url, jsonEncode({'sng_ids': [trackId]}), _cookie(arl, sid));
  print('  HTTP ${res['status']}');
  _dump('song.getListData', res);
  _dump('song.getListData', res);

  Map<String, dynamic> json;
  try {
    json = jsonDecode(res['body'] as String) as Map<String, dynamic>;
  } catch (e) {
    print('  ✗ could not parse response: ${(res['body'] as String).substring(0, 160)}');
    return null;
  }

  final err = json['error'];
  if (err != null && err != false && err != 0 && (err is List ? err.isNotEmpty : true)) {
    print('  ✗ api error: $err');
    return null;
  }

  final data = (json['results'] as Map<String, dynamic>?)?['data'] as List?;
  if (data == null || data.isEmpty) {
    print('  ✗ no track data returned.');
    return null;
  }

  final t = data.first as Map<String, dynamic>;
  final trackToken = t['TRACK_TOKEN'] as String?;
  final md5Origin = (t['MD5_ORIGIN'] ?? t['MD5_AUDIO'] ?? t['MD5_SONG'] ?? t['MD5']) as String?;
  final sngId = (t['SNG_ID'] ?? trackId).toString();
  final title = t['SNG_TITLE'] ?? t['SNG_TITLE_2'] ?? '?';
  final artist = t['ART_NAME'] ?? '?';

  final digit = (md5Origin != null && md5Origin.isNotEmpty)
      ? md5.convert(utf8.encode(md5Origin + sngId))
      : null;
  final keyHex = digit == null
      ? null
      : digit.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  print('  ✓ "${title}" — $artist');
  print('    TRACK_TOKEN: ${trackToken == null ? 'MISSING ✗' : '${trackToken.length} chars ✓'}');
  print('    MD5_ORIGIN:  ${md5Origin ?? 'MISSING (keys present: ${t.keys.where((k) => k.startsWith('MD5')).join(', ')})'}');
  print('    sizes: MP3_128=${t['FILESIZE_MP3_128']} MP3_320=${t['FILESIZE_MP3_320']} FLAC=${t['FILESIZE_FLAC']}');

  if (trackToken == null) {
    print('  ✗ missing TRACK_TOKEN');
    return null;
  }

  return {
    'id': sngId,
    'md5': md5Origin ?? '',
    'track_token': trackToken,
    'key': keyHex,
  };
}

// ── Step 3 ──
Future<String?> _stepGetUrl(
    Map<String, Object?> auth, Map<String, Object?> track, String fmt) async {
  final arl = auth['arl']! as String;
  final sid = auth['sid'] as String?;
  final lic = auth['license_token']! as String;
  final token = track['track_token']! as String;

  final body = jsonEncode({
    'license_token': lic,
    'media': [
      {
        'type': 'FULL',
        'formats': [
          {'cipher': 'BF_CBC_STRIPE', 'format': fmt}
        ],
      }
    ],
    'track_tokens': [token],
  });

  final res = await _post(_mediaUrl, body, _cookie(arl, sid));
  _dump('media.get_url ($fmt)', res);

  Map<String, dynamic> json;
  try {
    json = jsonDecode(res['body'] as String) as Map<String, dynamic>;
  } catch (e) {
    print('  $fmt  ✗ get_url: unparseable response');
    return null;
  }

  final err = json['error'];
  if (err != null && err != false && err != 0 && (err is List ? err.isNotEmpty : true)) {
    print('  $fmt  ✗ get_url error: $err');
    return null;
  }

  final data = json['data'] as List?;
  if (data == null || data.isEmpty) {
    print('  $fmt  ✗ get_url: empty data (format not entitled on this account?)');
    return null;
  }

  final sources = (data.first as Map<String, dynamic>)['media'] as List?;
  if (sources == null || sources.isEmpty) {
    print('  $fmt  ✗ get_url: no media sources');
    return null;
  }

  final srcs = (sources.first as Map<String, dynamic>)['sources'] as List?;
  if (srcs == null || srcs.isEmpty) {
    print('  $fmt  ✗ get_url: empty sources');
    return null;
  }

  String? url;
  for (final s in srcs.cast<Map<String, dynamic>>()) {
    final u = s['url'] as String?;
    if (u != null && u.isNotEmpty) {
      url = u;
      break;
    }
  }

  if (url == null) {
    print('  $fmt  ✗ get_url: no URL in sources');
    return null;
  }

  print('  $fmt  ✓ stream URL obtained (${url.length} chars)');
  return url;
}

// ── Step 4 ──
Future<Map<String, Object>> _stepVerifyCdn(String url, String fmt) async {
  try {
    final req = await _client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', _ua);
    req.headers.set('Range', 'bytes=0-8191');
    final resp = await req.close();
    final bytes = await resp.fold<List<int>>([], (p, c) => p..addAll(c));

    final mime = resp.headers.contentType?.mimeType ?? '?';
    final len = resp.headers.value('content-length') ?? (resp.contentLength < 0 ? '?' : resp.contentLength.toString());

    final encrypted = _detectEncryption(bytes, fmt);

    print('  $fmt  ✓ fetched ${bytes.length} bytes  mime=$mime  content-length=$len');
    print('    first bytes: ${bytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    print('    encryption:  ${encrypted ? 'YES (Blowfish BF_CBC_STRIPE — decrypt before playback)' : 'NO (plaintext — playable directly)'}');

    return {'status': resp.statusCode, 'mime': mime, 'bytes': bytes.length, 'encrypted': encrypted};
  } catch (e) {
    print('  $fmt  ✗ CDN fetch failed: $e');
    return {'status': 'error', 'error': e.toString(), 'encrypted': true};
  }
}

bool _detectEncryption(List<int> bytes, String fmt) {
  final isFlac = fmt == 'FLAC';
  int hits = 0;
  for (int i = 0; i + 1 < bytes.length && i < 8192; i++) {
    if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) hits++;
  }
  final hasMagic = !isFlac && hits >= 4;
  final hasFlacMagic = isFlac && bytes.length >= 4 &&
      bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43;
  return !(hasMagic || hasFlacMagic);
}

// ── Helpers ──
String _cookie(String arl, String? sid) =>
    sid == null || sid.isEmpty ? 'arl=$arl' : 'sid=$sid; arl=$arl';

Future<Map<String, Object?>> _post(String url, String body, String cookie) async {
  final req = await _client.postUrl(Uri.parse(url));
  req.headers.set('User-Agent', _ua);
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Accept-Language', 'en-US,en;q=0.9');
  req.headers.set('Cookie', cookie);
  req.write(body);
  final resp = await req.close();
  final raw = await resp.transform(utf8.decoder).join();

  String? sid;
  final cookies = resp.headers['set-cookie'];
  if (cookies != null) {
    for (final c in cookies) {
      if (c.contains('sid=')) {
        final match = RegExp(r'sid=([^;]+)').firstMatch(c);
        if (match != null) {
          sid = match.group(1);
          break;
        }
      }
    }
  }

  return {'status': resp.statusCode, 'body': raw, if (sid != null) 'sid': sid};
}

String? _findArl(List<String> args) {
  for (final a in args) {
    if (a.startsWith('--arl=')) return a.substring('--arl='.length);
  }
  final env = Platform.environment['DEEZER_ARL'];
  if (env != null && env.isNotEmpty) return env;
  return kHardcodedArl.isNotEmpty ? kHardcodedArl : null;
}

String _findTrackId(List<String> args) {
  for (final a in args) {
    if (a.startsWith('--') || a.startsWith('-')) continue;
    return a;
  }
  return _defaultTrackId;
}

List<String> _findQualities(List<String> args) {
  for (final a in args) {
    if (a.startsWith('--quality=')) {
      final raw = a.substring('--quality='.length).toUpperCase().replaceAll('-', '_');
      final v = raw.startsWith('MP3_') ? raw : 'MP3_$raw';
      return [v];
    }
  }
  return const ['MP3_128', 'MP3_320', 'FLAC'];
}
