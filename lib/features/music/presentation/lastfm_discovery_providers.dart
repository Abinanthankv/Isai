import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection.dart';
import '../data/lastfm_service.dart';
import '../data/itunes_metadata_service.dart';
import '../data/music_models.dart';
import '../../settings/data/lastfm_repository.dart';

/// Provider for the global trending artists on Last.fm with lazy image enrichment.
/// Shows raw data immediately, then fills in iTunes artwork in the background.
final lastfmGlobalTopArtistsProvider = NotifierProvider<LastfmArtistsNotifier, AsyncValue<List<Map<String, dynamic>>>>(LastfmArtistsNotifier.new);

class LastfmArtistsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    _load();
    return const AsyncLoading();
  }

  Future<void> _load() async {
    try {
      final service = getIt<LastFmService>();
      final itunes = getIt<ItunesMetadataService>();
      final rawArtists = await service.getGlobalTopArtists(limit: 15);

      // Emit raw data immediately — UI shows with placeholders
      state = AsyncData(List.from(rawArtists));

      // Background enrichment: replace placeholder images with iTunes artwork (parallel)
      final enriched = await Future.wait(rawArtists.map((artist) async {
        final name = artist['name'] as String;
        String imageUrl = artist['image_url'] as String? ?? '';
        if (LastFmService.isPlaceholderImage(imageUrl)) {
          final img = await itunes.fetchArtistImage(name);
          if (img != null) imageUrl = img.replaceAll(RegExp(r'\d+x\d+'), '100x100');
        }
        return {...artist, 'image_url': imageUrl};
      }));

      state = AsyncData(enriched);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Provider for the global trending tracks on Last.fm with lazy image enrichment.
/// Shows raw data immediately, then fills in iTunes artwork in the background.
final lastfmGlobalTopTracksProvider = NotifierProvider<LastfmTracksNotifier, AsyncValue<List<Map<String, dynamic>>>>(LastfmTracksNotifier.new);

class LastfmTracksNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    _load();
    return const AsyncLoading();
  }

  Future<void> _load() async {
    try {
      final service = getIt<LastFmService>();
      final itunes = getIt<ItunesMetadataService>();

      // Fetch more tracks so we have a diverse pool to filter from
      final rawTracks = await service.getGlobalTopTracks(limit: 45);

      final List<Map<String, dynamic>> diverseTracks = [];
      final Map<String, int> artistCounts = {};

      for (final track in rawTracks) {
        final artist = track['artist'] as String? ?? 'Unknown';
        final count = artistCounts[artist] ?? 0;
        if (count < 2) {
          diverseTracks.add(Map.from(track));
          artistCounts[artist] = count + 1;
        }
        if (diverseTracks.length >= 15) {
          break;
        }
      }

      // Emit raw data immediately — UI shows with placeholders
      state = AsyncData(List.from(diverseTracks));

      // Background enrichment: replace placeholder images with iTunes artwork (parallel)
      final enriched = await Future.wait(diverseTracks.map((track) async {
        final name = track['name'] as String;
        final artist = track['artist'] as String;
        String imageUrl = track['image_url'] as String? ?? '';
        if (LastFmService.isPlaceholderImage(imageUrl)) {
          final meta = await itunes.fetchMeta(name, artist);
          if (meta?.artworkUrlHigh != null) imageUrl = meta!.artworkUrlHigh!.replaceAll(RegExp(r'\d+x\d+'), '200x200');
        }
        return {...track, 'image_url': imageUrl};
      }));

      state = AsyncData(enriched);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Provider for the user's personal top artists from Last.fm with enrichment.
final lastfmUserTopArtistsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return [];
  
  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  
  final artists = await service.getUserTopArtists(username, period: '1month', limit: 10);
  
  return Future.wait(artists.map((artist) async {
    final name = artist['name'] as String;
    String imageUrl = artist['image_url'] as String? ?? '';
    
    if (imageUrl.isEmpty || imageUrl.contains('2a96cbd8b46e442fc41c2b86b821562f')) {
      final itunesImage = await itunes.fetchArtistImage(name);
      if (itunesImage != null) imageUrl = itunesImage;
    }
    
    return {...artist, 'image_url': imageUrl};
  }));
});

/// Provider for the user's recent scrobbles (cross-device history) from Last.fm with enrichment.
final lastfmUserRecentTracksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return [];
  
  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  
  final tracks = await service.getUserRecentTracks(username, limit: 12);
  
  return Future.wait(tracks.map((track) async {
    final name = track['name'] as String;
    final artist = track['artist'] as String;
    String imageUrl = track['image_url'] as String? ?? '';
    
    if (LastFmService.isPlaceholderImage(imageUrl)) {
      final itunesMeta = await itunes.fetchMeta(name, artist);
      if (itunesMeta?.artworkUrlHigh != null) imageUrl = itunesMeta!.artworkUrlHigh!;
    }
    
    return {...track, 'image_url': imageUrl};
  }));
});

/// Provider for Last.fm Recommended station playlists (one per page).
final lastfmRecommendedProvider = FutureProvider<List<({String title, String subtitle, List<ItunesTrack> tracks, List<Color> colors})>>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return [];

  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();

  const gradients = [
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    [Color(0xFF00c6ff), Color(0xFF0072ff)],
    [Color(0xFF11998e), Color(0xFF38ef7d)],
    [Color(0xFFf12711), Color(0xFFf5af19)],
  ];

  final results = await Future.wait([1, 2, 3].map((page) async {
    final tracks = await service.fetchStationPlaylist(username, 'recommended', page: page);
    if (tracks.isEmpty) return null;

    final itunesTracks = await Future.wait(tracks.asMap().entries.map((entry) async {
      final idx = entry.key;
      final track = entry.value;
      final name = track['name'] as String;
      final artist = track['artist'] as String;
      String imageUrl = track['image_url'] as String? ?? '';

      if (imageUrl.isEmpty) {
        final itunesMeta = await itunes.fetchMeta(name, artist);
        if (itunesMeta?.artworkUrlHigh != null) imageUrl = itunesMeta!.artworkUrlHigh!;
      }

      return ItunesTrack(
        trackId: idx,
        trackName: name,
        artistName: artist,
        collectionName: name,
        artworkUrl: imageUrl,
        trackTimeMillis: (track['duration'] as int? ?? 0) * 1000,
      );
    }));

    if (itunesTracks.isEmpty) return null;

    return (
      title: 'Recommended Vol. $page',
      subtitle: '${itunesTracks.length} songs',
      tracks: itunesTracks,
      colors: gradients[(page - 1) % gradients.length],
    );
  }));

  final List<({String title, String subtitle, List<ItunesTrack> tracks, List<Color> colors})> playlists = [];
  for (final r in results) {
    if (r != null) playlists.add(r);
  }
  return playlists;
});

/// Provider for Last.fm Mix station playlists (one per page).
final lastfmMixProvider = FutureProvider<List<({String title, String subtitle, List<ItunesTrack> tracks, List<Color> colors})>>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return [];

  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();

  const gradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF4facfe), Color(0xFF00f2fe)],
    [Color(0xFF43e97b), Color(0xFF38f9d7)],
  ];

  final results = await Future.wait([1, 2, 3].map((page) async {
    final tracks = await service.fetchStationPlaylist(username, 'mix', page: page);
    if (tracks.isEmpty) return null;

    final itunesTracks = await Future.wait(tracks.asMap().entries.map((entry) async {
      final idx = entry.key;
      final track = entry.value;
      final name = track['name'] as String;
      final artist = track['artist'] as String;
      String imageUrl = track['image_url'] as String? ?? '';

      if (imageUrl.isEmpty) {
        final itunesMeta = await itunes.fetchMeta(name, artist);
        if (itunesMeta?.artworkUrlHigh != null) imageUrl = itunesMeta!.artworkUrlHigh!;
      }

      return ItunesTrack(
        trackId: idx,
        trackName: name,
        artistName: artist,
        collectionName: name,
        artworkUrl: imageUrl,
        trackTimeMillis: (track['duration'] as int? ?? 0) * 1000,
      );
    }));

    if (itunesTracks.isEmpty) return null;

    return (
      title: 'Mix Vol. $page',
      subtitle: '${itunesTracks.length} songs',
      tracks: itunesTracks,
      colors: gradients[(page - 1) % gradients.length],
    );
  }));

  final List<({String title, String subtitle, List<ItunesTrack> tracks, List<Color> colors})> playlists = [];
  for (final r in results) {
    if (r != null) playlists.add(r);
  }
  return playlists;
});
