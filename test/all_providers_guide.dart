// SpotiFLAC All-Provider Integration Guide
//
// Run: /home/abinanthan/flutter/flutter/bin/dart run test/all_providers_guide.dart
//
// Documents every provider's capabilities, runtime needs,
// and how to bridge SpotiFLAC extensions into the app.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  p('=' * 76);
  p('  SPOTIFLAC EXTENSION INTEGRATION GUIDE');
  p('  How to use .sflx providers in Debrid Vault');
  p('=' * 76);

  // ── PART 1 ──
  p('');
  p('-' * 76);
  p('  PART 1: PROVIDER CAPABILITIES');
  p('-' * 76);

  p('');
  p('  Provider             Metadata   Download   Lossless   Auth       Lyrics');
  p('  -------------------- ---------- ---------- ---------- ---------- ------');
  p('  Spotify Web          full       no         no         public     no');
  p('  Amazon Music         basic      yes        FLAC       session    no');
  p('  Apple Music          rich       no         no         public     yes');
  p('  SoundCloud           basic      yes        no         public     no');
  p('  YouTube Music        basic      yes        no         public     no');
  p('  Deezer               rich       yes        FLAC       session    no');
  p('  Pandora              basic      yes        no         public     no');
  p('  Qobuz                rich       yes        FLAC       session    no');
  p('  Tidal                rich       yes        FLAC       session    no');
  p('');
  p('  Auth keys:');
  p('    public  = no auth required');
  p('    session = needs ZARZ-HMAC-V1 signed session (api.zarz.moe/v2)');
  p('');

  // ── PART 2 ──
  p('-' * 76);
  p('  PART 2: RUNTIME CONTRACT');
  p('-' * 76);

  p('');
  p('  Every .sflx extension expects these globals in the JS runtime:');
  p('');
  p('    log       -- { debug(), info(), warn(), error() }');
  p('    utils     -- { appUserAgent(), randomUserAgent(), sha256(),');
  p('                   md5(), hmacSHA1(), base64Decode(),');
  p('                   decryptBlockCipher(), isDownloadCancelled(),');
  p('                   sleep() }');
  p('    http      -- { get(url, headers), post(url, body, headers) }');
  p('                  returns { statusCode, body } SYNCHRONOUSLY');
  p('    session   -- { signedFetch(method, path, body?),');
  p('                   completeGrant(), appVersion, deviceId ... }');
  p('                  (only for session-auth providers)');
  p('    registerExtension({ searchTracks, getTrack, download ... })');
  p('');

  // ── PART 3 ──
  p('-' * 76);
  p('  PART 3: BRIDGE ARCHITECTURE');
  p('-' * 76);

  p('');
  p('  Existing plugin system expects:');
  p('    globalThis.search(query)    -> array of results');
  p('    globalThis.getStream(id)    -> URL string');
  p('');
  p('  SpotiFLAC extensions use:');
  p('    registerExtension({');
  p('      searchTracks, getTrack, download, ...');
  p('    })');
  p('');
  p('  Approach A: Adapter Bridge (MVP)');
  p('');
  p('    1. Register registerExtension() in the runtime first');
  p('       -> captures the extension object as _ext');
  p('    2. Register globalThis.search that delegates to');
  p('       _ext.searchTracks, normalizes result format');
  p('    3. Register globalThis.getStream that delegates to');
  p('       _ext.download (with session bootstrap for auth providers)');
  p('');
  p('  Flow:');
  p('    ext code -> registerExtension({...})');
  p('                         |');
  p('                   _ext captured');
  p('                         |');
p('    search(query) -> _ext.searchTracks(query) -> ScraperResult[]');
  p('    getStream(id) -> session.signedFetch() -> _ext.download()');
  p('');
  p('  Approach B: Native registerExtension (ideal)');
  p('    Modify PluginManager to support registerExtension natively.');
  p('    Store extension object in Dart-side state, expose methods');
  p('    as Dart functions. Keep runtime alive across calls.');
  p('');

  // ── PART 4 ──
  p('-' * 76);
  p('  PART 4: SIGNED SESSION AUTH FLOW');
  p('-' * 76);

  p('');
  p('  Lossless providers (Amazon, Deezer, Qobuz, Tidal) use');
  p('  ZARZ-HMAC-V1 signed session protocol:');
  p('');
  p('    1. Bootstrap');
  p('       GET https://api.zarz.moe/v2/bootstrap');
  p('       <- { sessionId, deviceId, serverTime }');
  p('');
  p('    2. Challenge');
  p('       GET https://api.zarz.moe/v2/challenge');
  p('       Headers: X-Zarz-* HMAC-signed');
  p('       <- { challenge, salt }');
  p('');
  p('    3. Exchange (user may need CAPTCHA)');
  p('       POST https://api.zarz.moe/v2/session/exchange');
  p('       Body: { challenge, appVersion, platform }');
  p('       <- { accessToken, refreshToken, expiresIn }');
  p('');
  p('    4. All API calls use session.signedFetch()');
  p('       which HMAC-signs every request.');
  p('');
  p('  Dart only needs to:');
  p('    - Call session.completeGrant() after user challenge');
  p('    - Store session tokens for reuse');
  p('    - Provide the http bridge that signedFetch delegates to');
  p('');

  // ── PART 5 ──
  p('-' * 76);
  p('  PART 5: INTEGRATION PLAN');
  p('-' * 76);

  p('');
  p('  PHASE 1: Runtime Shim (in PluginManager._createRuntime)');
  p('');
  p('  Add to the existing JS runtime setup:');
  p('');
  p('    // Register SpotiFLAC runtime globals');
  p('    runtime.evaluate(');
  p(q('      var log = { info:function(){}, warn:function(){},'));
  p(q('                  error:function(){}, debug:function(){} };'));
  p(q('      var utils = { appUserAgent: function() { return "DV/1.0"; } };'));
  p(q('      var http = {'));
  p(q('        get: function(u,h) { return bridge("httpGet",u,h); },'));
  p(q('        post: function(u,b,h) { return bridge("httpPost",u,b,h); }'));
  p(q('      };'));
  p(q('      globalThis.registerExtension = function(ext) {'));
  p(q('        bridge("registerExt", JSON.stringify(ext));'));
  p(q('      };'));
  p('    );');
  p('');
  p('  Then in the sendMessage handler:');
  p('    registerExt -> store extension functions in Dart');
  p('    httpGet     -> Dio.get(url, headers)');
  p('    httpPost    -> Dio.post(url, body, headers)');
  p('');

  p('  PHASE 2: Provider Selection Strategy');
  p('');
  p('  Service          Metadata          Download');
  p('  ---------------- ----------------- ------------------');
  p('  Spotify links    Spotify Web       Deezer (lossless)');
  p('  Deezer links     Deezer            Deezer');
  p('  Qobuz links      Qobuz             Qobuz');
  p('  Tidal links      Tidal             Tidal');
  p('  Apple Music lnks Apple (+lyrics)   Deezer (fallback)');
  p('  YouTube links    YouTube Music     YouTube Music');
  p('  SoundCloud lnks  SoundCloud        SoundCloud');
  p('  Amazon links     Amazon            Amazon');
  p('  Pandora links    Pandora           Pandora');
  p('  Unknown/fallback Deezer (best)     Deezer (lossless)');
  p('');

  p('  PHASE 3: Enrichment Pipeline');
  p('');
  p('  When user searches "Bohemian Rhapsody Queen":');
  p('');
  p('    1. Try Spotify Web searchTracks(query)');
  p('       -> get ISRC from result');
  p('    2. Enrich with getTrack(id) from any provider');
  p('       -> get ISRC, label, genre, composer, artwork');
  p('    3. Try download providers in priority order:');
  p('       a. checkAvailability(id)');
  p('       b. download(descriptor, { quality })');
  p('       c. Fallback to next provider');
  p('    4. For lyrics: Apple Music fetchLyrics(trackId)');
  p('');

  p('  PHASE 4: Caching & Offline');
  p('');
  p('    - Cache session tokens (refreshToken) for reuse');
  p('    - Cache search results (TTL: 1 hour)');
  p('    - Cache track metadata (TTL: 24 hours)');
  p('    - Download queue with progress callback');
  p('');

  // ── PART 6 ──
  p('-' * 76);
  p('  PART 6: TEST RESULTS');
  p('-' * 76);

  p('');
  p('  From running test/spotiflac_provider_api_test.dart:');
  p('');
  p('  Provider       Search  Track  CheckAv  Download  Notes');
  p('  -------------- ------- ------ -------- --------- ---------------------');
  p('  Deezer         OK(1)   OK     OK       needsAuth getTrack: id, name,');
  p('                                                   artists, album, isrc,');
  p('                                                   label, genre,');
  p('                                                   release_date, bpm');
  p('  SoundCloud     OK(0)   -      OK       needsAuth mock shape mismatch');
  p('  Tidal          OK(0)   -      OK       needsAuth mock shape mismatch');
  p('  Qobuz          ERR     -      OK       needsAuth needs real Qobuz API');
  p('  Spotify Web    ERR     -      -        -        needs sp_t cookie');
  p('  Apple Music    ERR     -      OK       -        needs dev token');
  p('  Amazon         -       -      OK       needsAuth uses customSearch');
  p('  YouTube Music  -       -      OK       needsAuth uses customSearch');
  p('  Pandora        -       -      OK       needsAuth has no searchTracks');
  p('');
  p('  Download needs signedSession: Amazon, Deezer, Qobuz, Tidal');
  p('  Download is public: SoundCloud, YouTube Music, Pandora');
  p('  OK(0) = function exists but mock data shape mismatched');
  p('  ERR   = function threw (needs real API response shape)');
  p('  -     = function not implemented by this provider');
  p('  needsAuth = needs ZARZ-HMAC-V1 session bootstrap');
  p('');

  p('-' * 76);
  p('  KEY FILES CREATED');
  p('-' * 76);

  p('');
  p('  test/spotiflac_registry_test.dart');
  p('    -> Surveys all providers from the registry');
  p('    -> Provider matrix with capabilities');
  p('');
  p('  test/spotiflac_provider_inspection_test.dart');
  p('    -> Downloads and inspects every .sflx');
  p('    -> Shows manifest + registerExtension exports');
  p('');
  p('  test/spotiflac_provider_api_test.dart');
  p('    -> Tests all 9 providers through a JS bridge');
  p('    -> searchTracks -> getTrack -> checkAvailability -> download');
  p('    -> Run: dart run test/spotiflac_provider_api_test.dart [query]');
  p('');
  p('  test/all_providers_guide.dart');
  p('    -> This integration guide (runnable)');
  p('    -> Run: dart run test/all_providers_guide.dart');
  p('');

  p('-' * 76);
  p('  Registry: https://raw.githubusercontent.com/spotiflacapp/');
  p('            spotiflac-extension/main/registry.json');
  p('');
  p('  Each .sflx = ZIP (manifest.json + index.js)');
  p('  index.js calls registerExtension({...}) at module init.');
  p('-' * 76);
}

void p(String s) => print(s);
String q(String s) => "      $s";
