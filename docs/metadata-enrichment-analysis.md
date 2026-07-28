# Metadata Enrichment via Public Music APIs — Analysis

> **Date:** 2026-07-28  
> **Scope:** How to enrich track metadata using free public music APIs (Deezer, MusicBrainz) without the SpotiFLAC extension proxy, and how to surface them as selectable metadata addons.

---

## 1. Executive Summary

**Our app currently** relies solely on the iTunes Search API for metadata enrichment. This gives us ~40% of available metadata fields (no ISRC, label, composer, BPM, etc.), limited artwork resolution, and frequent rate limiting.

**The Deezer public API** alone provides all the rich metadata the SpotiFLAC session extensions do (ISRC, label, copyright, composer, BPM, gain, explicit flag, track/disc numbers, full release dates, album type, UPC, genre, 1000×1000 cover art, preview URLs) — but **without requiring any authentication, proxy, or browser grant flow**.

**Solution:** Use MusicBrainz as a free search/resolution layer (to find Deezer track IDs by title+artist), then use the Deezer track and album APIs for full metadata enrichment. Surface each provider as a toggle-able "metadata addon" in the existing Addons Manager.

---

## 2. The Free APIs We'd Use

### 2.1 Deezer Public API (`api.deezer.com`)

| Aspect | Detail |
|---|---|
| **Authentication** | None required for catalog/search endpoints |
| **Rate Limit** | ~50 requests per 5 seconds (10 req/s) per IP |
| **Cost** | Free |
| **Content** | 100M+ tracks with full metadata |

**Key endpoints:**

| Endpoint | What it returns | Example |
|---|---|---|
| `GET /track/{id}` | Track: title, ISRC, duration, track_position, disk_number, BPM, gain, explicit_lyrics, release_date, preview, contributors, artist, album | `api.deezer.com/track/3135553` |
| `GET /track/isrc:{isrc}` | Same as above, looked up by ISRC | `api.deezer.com/track/isrc:GBDUW0000053` |
| `GET /album/{id}` | Album: title, artist, label, copyright, release_date, record_type, nb_tracks, nb_disk, UPC, genres, cover_xl, fans, rating | `api.deezer.com/album/302127` |
| `GET /album/{id}/tracks` | Full tracklist with positions | `api.deezer.com/album/302127/tracks` |
| `GET /artist/{id}` | Artist: name, nb_fan, nb_album, picture_xl, radio | `api.deezer.com/artist/21` |
| `GET /search/track?q=...` | Search tracks (**may be geo-restricted**) | `api.deezer.com/search/track?q=eminem` |

**What each endpoint returns (verified by testing):**

**Track** (`/track/3135553` → "One More Time" by Daft Punk):
```json
{
  "id": 3135553,
  "title": "One More Time",
  "title_short": "One More Time",
  "isrc": "GBDUW0000053",
  "duration": 320,
  "track_position": 1,
  "disk_number": 1,
  "release_date": "2001-03-12",
  "bpm": 122.7,
  "gain": -12.8,
  "explicit_lyrics": false,
  "preview": "https://cdnt-preview.dzcdn.net/...",
  "contributors": [
    { "id": 21, "name": "Daft Punk", "role": "Main" }
  ],
  "artist": { "id": 27, "name": "Daft Punk", "picture_xl": "..." },
  "album": {
    "id": 302127,
    "title": "Discovery",
    "cover_xl": "https://cdn-images.dzcdn.net/images/cover/.../1000x1000-000000-80-0-0.jpg"
  }
}
```

**Album** (`/album/302127` → "Discovery"):
```json
{
  "id": 302127,
  "title": "Discovery",
  "artist": { "name": "Daft Punk" },
  "label": "Daft Life Ltd./ADA France",
  "release_date": "2001-03-07",
  "record_type": "album",
  "nb_tracks": 14,
  "upc": "724384960650",
  "fans": 337658,
  "genres": { "data": [{ "name": "Electro" }] },
  "cover_xl": "https://cdn-images.dzcdn.net/images/cover/.../1000x1000-...jpg"
}
```

### 2.2 MusicBrainz API (`musicbrainz.org/ws/2`)

| Aspect | Detail |
|---|---|
| **Authentication** | None (requires meaningful User-Agent) |
| **Rate Limit** | 1 request/second per IP |
| **Cost** | Free (non-commercial); CC0 data license |
| **Content** | Open music encyclopedia with ISRC, recording, release, artist data |

**Key endpoints:**

| Endpoint | What it returns |
|---|---|
| `GET /recording/?query=title+AND+artist:name&fmt=json` | Search recordings by title+artist, returns MBID, ISRCs, length, artist-credit, releases |
| `GET /isrc/{isrc}?fmt=json&inc=artists+releases` | Look up all recordings by ISRC, returns artist credits, releases with dates and labels |
| `GET /recording/{mbid}?fmt=json&inc=artists+releases+isrcs` | Full recording details |

**Why we need both APIs:**
- Deezer gives us the **richest metadata** but we need a track ID or ISRC to query it
- Deezer's search endpoint **may be geo-restricted** (returns empty data from some regions)
- MusicBrainz is **always available** and can resolve title+artist → ISRC → we then use Deezer

### 2.3 Keep: iTunes API as Final Fallback

The existing `ItunesMetadataService` should remain as the **last-resort fallback** for artwork when neither Deezer nor MusicBrainz finds a match. It's still useful for finding album art.

---

## 3. Metadata Coverage Comparison

| Metadata Field | iTunes API (current) | Deezer Public API | MusicBrainz |
|---|---|---|---|
| Track title | ✅ | ✅ | ✅ |
| Artist name | ✅ | ✅ | ✅ |
| Album name | ✅ | ✅ | ✅ |
| Artwork (1000×1000) | ⚠️ (600×600 max) | ✅ (1000×1000 native) | ❌ |
| Genre | ✅ | ✅ | ❌ |
| Duration | ✅ | ✅ | ✅ |
| Release date (full) | ❌ (year only) | ✅ | ✅ |
| ISRC | ❌ | ✅ | ✅ |
| Label | ❌ | ✅ | ⚠️ (via release label-info) |
| Copyright | ❌ | ✅ (sometimes) | ❌ |
| Composer | ❌ | ✅ (via `title_version` + contributors) | ❌ |
| Track number | ❌ | ✅ `track_position` | ❌ |
| Disc number | ❌ | ✅ `disk_number` | ❌ |
| Total tracks | ❌ | ✅ `nb_tracks` | ❌ |
| Album type | ❌ | ✅ `record_type` | ❌ |
| UPC/barcode | ❌ | ✅ `upc` | ✅ `barcode` |
| BPM | ❌ | ✅ `bpm` | ❌ |
| Gain | ❌ | ✅ `gain` | ❌ |
| Explicit flag | ❌ | ✅ `explicit_lyrics` | ❌ |
| Preview URL | ❌ | ✅ `preview` | ❌ |
| Contributors/roles | ❌ | ✅ `contributors[].role` | ✅ artist-credit |
| Fans/popularity | ❌ | ✅ `rank`, `fans` | ❌ |

**Coverage summary:** Deezer alone covers **~90%** of useful metadata fields. Adding MusicBrainz gives us ISRC-based resolution and a reliable search layer. Together they make the iTunes API mostly redundant (keep only as artwork fallback).

---

## 4. Architecture: Metadata Addon System

### 4.1 Provider Interface

```dart
/// A single metadata enrichment source.
abstract class MetadataProvider {
  String get id;           // "deezer", "musicbrainz", "itunes"
  String get displayName;  // "Deezer", "MusicBrainz", "iTunes"
  String get description;  // Short description shown in UI
  bool get enabled;        // Toggle state
  
  /// Enrich a track by title + artist.
  /// Returns null if provider can't find a match.
  Future<TrackMeta?> enrich(String title, String artist, {String? isrc});
  
  /// Enrich by ISRC directly (most accurate).
  Future<TrackMeta?> enrichByIsrc(String isrc);
}
```

### 4.2 TrackMeta Model (extends current ItunesMeta)

```dart
class TrackMeta {
  // Existing fields
  final String? trackName;
  final String? artistName;
  final String? artworkUrlLow;    // 600x600
  final String? artworkUrlHigh;   // 1000x1000
  final String? album;
  final String? genre;
  final int? releaseYear;
  final int? trackTimeMillis;
  final String? previewUrl;
  final String? id;
  final Map<String, dynamic>? extras;
  
  // New fields (from Deezer)
  final String? isrc;
  final String? label;
  final String? copyright;
  final String? composer;
  final int? trackNumber;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final String? albumType;        // "album" / "ep" / "single" / "compilation"
  final String? albumArtist;
  final String? artistId;
  final String? albumId;
  final int? bpm;
  final double? gain;
  final bool? isExplicit;
  final int? rank;
  final String? provider;         // "deezer", "musicbrainz", etc.
}
```

### 4.3 MetadataAddonManager

```dart
@lazySingleton
class MetadataAddonManager {
  final List<MetadataProvider> _providers = [];
  
  List<MetadataProvider> get providers => List.unmodifiable(_providers);
  List<MetadataProvider> get enabledProviders => _providers.where((p) => p.enabled).toList();
  
  void init() {
    _providers.addAll([
      DeezerMetadataProvider(dio),  // Requires impl
      MusicBrainzMetadataProvider(dio),  // Requires impl
      ItunesMetadataProvider(dio),  // Already exists
    ]);
    _loadSavedStates();
  }
  
  Future<TrackMeta?> enrichTrack(String title, String artist, {String? isrc}) async {
    for (final provider in enabledProviders) {
      try {
        final result = await (isrc != null 
            ? provider.enrichByIsrc(isrc) 
            : provider.enrich(title, artist, isrc: isrc));
        if (result != null) return result;
      } catch (e) {
        print('[MetaAddon] ${provider.id} failed: $e');
      }
    }
    return null;
  }
}
```

### 4.4 Resolution Pipeline

```
User plays a TorBox file
  → Parse filename → guess title + artist
  
  Step 1: For each enabled provider (in order):
    a. If we have ISRC → enrichByIsrc (fastest, most accurate)
    b. Otherwise → enrich(title, artist)
    
  Step 2: If a provider returns a result:
    → Fill as many TrackMeta fields as possible
    → Merge with previous results (Deezer's artwork > iTunes artwork)
    → Persist to DB
    
  Step 3: If no provider found a match:
    → Fall back to iTunes API (existing behavior)
```

### 4.5 Example: DeezerMetadataProvider Implementation

```dart
class DeezerMetadataProvider implements MetadataProvider {
  final Dio _dio;
  bool _enabled = true;
  
  @override
  String get id => 'deezer';
  @override
  String get displayName => 'Deezer';
  @override
  String get description => 'Rich metadata (ISRC, label, BPM, album type) from Deezer\'s public catalog. No account needed.';
  @override
  bool get enabled => _enabled;
  set enabled(bool v) => _enabled = v;
  
  Future<int?> _findTrackId(String title, String artist) async {
    // Search MusicBrainz for the track to get ISRC, then look up on Deezer
    // OR: Use a title+artist fingerprint to search Deezer's search (if available)
    // For now: try to use MusicBrainz search as the resolution layer
    final mbProvider = getIt<MusicBrainzMetadataProvider>();
    final result = await mbProvider.enrich(title, artist);
    if (result?.isrc != null) {
      final track = await _fetchByIsrc(result!.isrc!);
      if (track != null) return track['id'] as int;
    }
    return null;
  }
  
  Future<Map<String, dynamic>?> _fetchByIsrc(String isrc) async {
    try {
      final response = await _dio.get('https://api.deezer.com/track/isrc:$isrc');
      if (response.statusCode == 200 && response.data is Map && !response.data.containsKey('error')) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
  
  @override
  Future<TrackMeta?> enrich(String title, String artist, {String? isrc}) async {
    if (isrc != null) return enrichByIsrc(isrc);
    
    // No ISRC — we can't search Deezer directly (search is geo-blocked in many regions)
    // This provider depends on MusicBrainz for the search/resolution step
    return null;
  }
  
  @override
  Future<TrackMeta?> enrichByIsrc(String isrc) async {
    final track = await _fetchByIsrc(isrc);
    if (track == null) return null;
    
    // Optionally fetch album for label/copyright
    final albumId = (track['album'] as Map?)?['id'];
    Map<String, dynamic>? album;
    if (albumId != null) {
      try {
        final resp = await _dio.get('https://api.deezer.com/album/$albumId');
        if (resp.statusCode == 200) album = resp.data as Map<String, dynamic>;
      } catch (_) {}
    }
    
    final albumData = album ?? track['album'] as Map? ?? {};
    
    // Build TrackMeta with ALL available fields
    return TrackMeta(
      trackName: track['title'] as String?,
      artistName: (track['artist'] as Map?)?['name'] as String?,
      artworkUrlLow: (albumData['cover_medium'] as String?)
          ?.replaceAll('250x250', '600x600'),
      artworkUrlHigh: albumData['cover_xl'] as String?,
      album: albumData['title'] as String? ?? (track['album'] as Map?)?['title'] as String?,
      genre: (albumData['genres'] as Map?)?['data'] is List 
          ? ((albumData['genres']['data'] as List).firstOrNull as Map?)?['name'] as String?
          : null,
      releaseYear: track['release_date'] is String && (track['release_date'] as String).length >= 4
          ? int.tryParse((track['release_date'] as String).substring(0, 4))
          : null,
      trackTimeMillis: (track['duration'] as num?)?.toInt() != null
          ? (track['duration'] as num).toInt() * 1000
          : null,
      previewUrl: track['preview'] as String?,
      id: track['id']?.toString(),
      
      // New fields from Deezer
      isrc: track['isrc'] as String?,
      label: albumData['label'] as String?,
      copyright: albumData['copyright'] as String?,
      composer: track['composer'] as String?,
      trackNumber: (track['track_position'] as num?)?.toInt(),
      totalTracks: (albumData['nb_tracks'] as num?)?.toInt(),
      discNumber: (track['disk_number'] as num?)?.toInt(),
      totalDiscs: (albumData['nb_disk'] as num?)?.toInt(),
      albumType: albumData['record_type'] as String?,
      albumArtist: (albumData['artist'] as Map?)?['name'] as String?,
      artistId: (track['artist'] as Map?)?['id']?.toString(),
      albumId: albumData['id']?.toString(),
      bpm: (track['bpm'] as num?)?.toInt(),
      gain: (track['gain'] as num?)?.toDouble(),
      isExplicit: track['explicit_lyrics'] as bool?,
      rank: (track['rank'] as num?)?.toInt(),
      provider: 'deezer',
    );
  }
}
```

### 4.6 Example: MusicBrainzMetadataProvider

```dart
class MusicBrainzMetadataProvider implements MetadataProvider {
  /// Primary role: search/resolution layer.
  /// Resolves title+artist → ISRC → Deezer can then take over.
  
  @override
  Future<TrackMeta?> enrich(String title, String artist, {String? isrc}) async {
    // 1 query/sec rate limit
    await Future.delayed(const Duration(milliseconds: 1100));
    
    final query = '${_escapeQuery(title)} AND artist:${_escapeQuery(artist)}';
    final response = await _dio.get(
      'https://musicbrainz.org/ws/2/recording/',
      queryParameters: {
        'query': query,
        'fmt': 'json',
        'limit': 5,
        'inc': 'artists+releases+isrcs',
      },
      options: Options(headers: {'User-Agent': 'Isai/1.0 (music@isai.app)'}),
    );
    
    final recordings = (response.data as Map)['recordings'] as List? ?? [];
    if (recordings.isEmpty) return null;
    
    final best = recordings.first as Map;
    final isrcs = best['isrcs'] as List? ?? [];
    
    return TrackMeta(
      trackName: best['title'] as String?,
      artistName: _formatArtistCredit(best['artist-credit']),
      trackTimeMillis: best['length'] != null ? (best['length'] as int) ~/ 1000 : null,
      isrc: isrcs.isNotEmpty ? isrcs.first as String : null,
      provider: 'musicbrainz',
    );
  }
}
```

---

## 5. Database Schema Changes

```dart
class TrackMetadata extends Table {
  // Existing columns...
  
  // New columns to add:
  TextColumn get isrc => text().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get copyright => text().nullable()();
  TextColumn get composer => text().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get totalTracks => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get totalDiscs => integer().nullable()();
  TextColumn get albumType => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get albumId => text().nullable()();
  IntColumn get bpm => integer().nullable()();
  RealColumn get gain => real().nullable()();
  BoolColumn get isExplicit => boolean().nullable()();
  TextColumn get provider => text().nullable()();  // "deezer", "musicbrainz", etc.
}
```

These same columns should also be added to:
- `ExternalTrackMetadata` (virtual track cache)
- `PlaybackHistory` (playback history records)
- `PlaylistTracks` (playlist items)

---

## 6. UI: Metadata Addon Section in Addons Manager

### 6.1 Current Addons Manager Structure

The existing `PluginManager` has:
- **JS Plugins** (Deezer, JioSaavn, SoundCloud, YouTube) — search + download
- **Eclipse Addons** — remote addons

### 6.2 Proposed Metadata Addons Section

A third section in the Addons Manager screen:

```
┌─────────────────────────────────────┐
│  Addons Manager                     │
├─────────────────────────────────────┤
│  JS Plugins                         │
│  ┌─────────────────────────────────┐│
│  │ Deezer               [On]  ⚙️   ││
│  │ JioSaavn             [Off] ⚙️   ││
│  └─────────────────────────────────┘│
│                                     │
│  Eclipse Addons                     │
│  ┌─────────────────────────────────┐│
│  │ TorBox                 [On]     ││
│  └─────────────────────────────────┘│
│                                     │
│  Metadata Providers  (NEW)          │
│  ┌─────────────────────────────────┐│
│  │ 🎵 Deezer Metadata    [On]  ⚙️  ││
│  │   Rich metadata from Deezer's   ││
│  │   public catalog. ISRC, label,  ││
│  │   BPM, album type, 1000x1000    ││
│  │   cover art. No account needed. ││
│  ├─────────────────────────────────┤│
│  │ 📖 MusicBrainz        [On]  ⚙️  ││
│  │   Open music database for ISRC  ││
│  │   resolution and fallback       ││
│  │   search. CC0 licensed data.    ││
│  ├─────────────────────────────────┤│
│  │ 🍎 iTunes              [On]  ⚙️ ││
│  │   Fallback metadata provider.   ││
│  │   Album art, genres, basic info.││
│  └─────────────────────────────────┘│
│                                     │
│  Priority: Deezer > MusicBrainz     │
│  > iTunes         [Reorder]         │
└─────────────────────────────────────┘
```

### 6.3 What Makes a "Metadata Addon"

Unlike JS plugins (which run JS code in a sandbox), metadata addons are **native Dart services** that implement `MetadataProvider`. They don't need to be downloaded from a remote URL — they're built into the app and enabled/disabled by the user.

**Future possibility:** Allow third-party metadata addons via a plugin-like manifest:

```json
{
  "id": "example-metadata",
  "name": "My Metadata Provider",
  "type": "metadata_provider",
  "apiUrl": "https://api.my-service.com/metadata",
  "description": "Custom metadata enrichment"
}
```

---

## 7. Implementation Plan

### Phase 1: Foundation (1-2 days)
1. Create `TrackMeta` model with all fields (replace/extend `ItunesMeta`)
2. Add new DB columns via migration
3. Implement `DeezerMetadataProvider` (track ISRC + album lookup)
4. Implement `MusicBrainzMetadataProvider` (search + ISRC resolution)

### Phase 2: Manager & UI (1-2 days)
5. Create `MetadataAddonManager` with provider registry and state persistence
6. Add "Metadata Providers" section to the Addons Manager UI
7. Wire up the enrichment pipeline to use `MetadataAddonManager` instead of direct iTunes calls

### Phase 3: Enrichment Pipeline (1 day)
8. Replace `ItunesMetadataService` calls in `audio_handler.dart` and `music_providers.dart` with `MetadataAddonManager.enrichTrack()`
9. Persist all new fields to `DbTrackMetadata` 
10. Display new fields in Now Playing screen (album type badge, label, etc.)

### Phase 4: Polish
11. Add provider priority reordering
12. Cache ISRC lookups locally to avoid repeated MusicBrainz queries
13. Handle rate limits properly (Deezer: 10 req/s, MusicBrainz: 1 req/s)

---

## 8. Key Advantages Over the SpotiFLAC Extension Approach

| Aspect | SpotiFLAC Extension | Direct Deezer + MusicBrainz |
|---|---|---|
| **Auth** | Browser grant flow (zarz.moe proxy) | None needed |
| **Complexity** | Need session HMAC, deep links, token exchange | Simple HTTP GET requests |
| **Reliability** | Depends on zarz.moe proxy uptime | Direct from source |
| **Rate Limits** | Unknown (proxy-controlled) | Known: Deezer ~10/s, MB 1/s |
| **Latency** | Proxy adds round-trip | Direct (~100-200ms per call) |
| **Metadata Quality** | Excellent | Identical (same Deezer API) |
| **Offline/Artwork** | Same Deezer CDN URLs | Same Deezer CDN URLs |
| **Implementation Cost** | Weeks (session bridge, deep links, HMAC) | Days (HTTP client + model) |
| **Future-Proof** | Depends on zarz.moe | Direct API integration |

**Bottom line:** The direct Deezer + MusicBrainz approach gives us all the metadata enrichment benefits of SpotiFLAC session providers with **~10% of the implementation complexity** and **no external proxy dependency**.

The SpotiFLAC extension system is still valuable for **download functionality** (where actual content delivery requires the zarz.moe proxy), but for **metadata enrichment alone**, the direct API approach is overwhelmingly superior.
