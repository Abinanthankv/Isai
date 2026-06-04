import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection.dart';
import '../data/lastfm_service.dart';
import '../data/itunes_metadata_service.dart';
import '../../settings/data/lastfm_repository.dart';

/// The mode for the Statistics screen.
enum StatsViewMode { 
  local, 
  lastfm 
}

/// Provider for the current stats view mode using modern Notifier pattern.
class StatsViewModeNotifier extends Notifier<StatsViewMode> {
  @override
  StatsViewMode build() => StatsViewMode.local;
  
  void setMode(StatsViewMode mode) {
    state = mode;
  }
}

final statsViewModeProvider = NotifierProvider<StatsViewModeNotifier, StatsViewMode>(
  StatsViewModeNotifier.new,
);

/// Provider for Last.fm user profile summary.
final lastfmUserProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return null;
  
  final service = getIt<LastFmService>();
  return service.getUserInfo(username);
});

/// Provider for Last.fm Top Artists (Overall) with enrichment.
final lastfmTopArtistsOverallProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return [];
  
  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  
  final artists = await service.getUserTopArtists(username, period: 'overall', limit: 10);
  
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

/// Provider for Last.fm Top Tracks (Overall) with enrichment.
final lastfmTopTracksOverallProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return [];
  
  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  
  final tracks = await service.getUserTopTracks(username, period: 'overall', limit: 10);
  
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

/// Provider for Last.fm Top Albums (Overall) with enrichment.
final lastfmTopAlbumsOverallProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = getIt<LastfmRepository>();
  final username = repository.username;
  if (username == null || username.isEmpty) return [];
  
  final service = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  
  final albums = await service.getUserTopAlbums(username, period: 'overall', limit: 10);
  
  return Future.wait(albums.map((album) async {
    final title = album['name'] as String;
    final artist = album['artist'] as String;
    String imageUrl = album['image_url'] as String? ?? '';
    
    if (LastFmService.isPlaceholderImage(imageUrl)) {
      // Use meta search for album image too
      final itunesMeta = await itunes.fetchMeta(title, artist);
      if (itunesMeta?.artworkUrlHigh != null) imageUrl = itunesMeta!.artworkUrlHigh!;
    }
    
    return {...album, 'image_url': imageUrl};
  }));
});
