import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection.dart';
import '../data/lastfm_service.dart';
import '../data/itunes_metadata_service.dart';
import '../../settings/data/lastfm_repository.dart';

/// Provider for the global trending artists on Last.fm with iTunes image enrichment.
final lastfmGlobalTopArtistsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  
  final artists = await service.getGlobalTopArtists(limit: 15);
  
  return Future.wait(artists.map((artist) async {
    final name = artist['name'] as String;
    String imageUrl = artist['image_url'] as String? ?? '';
    
    if (LastFmService.isPlaceholderImage(imageUrl)) {
      final itunesImage = await itunes.fetchArtistImage(name);
      if (itunesImage != null) imageUrl = itunesImage;
    }
    
    return {...artist, 'image_url': imageUrl};
  }));
});

/// Provider for the global trending tracks on Last.fm with iTunes image enrichment.
final lastfmGlobalTopTracksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  
  // Fetch more tracks so we have a diverse pool to filter from
  final tracks = await service.getGlobalTopTracks(limit: 45);
  
  final List<Map<String, dynamic>> diverseTracks = [];
  final Map<String, int> artistCounts = {};
  
  for (final track in tracks) {
    final artist = track['artist'] as String? ?? 'Unknown';
    final count = artistCounts[artist] ?? 0;
    if (count < 2) {
      diverseTracks.add(track);
      artistCounts[artist] = count + 1;
    }
    if (diverseTracks.length >= 15) {
      break;
    }
  }
  
  return Future.wait(diverseTracks.map((track) async {
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
