import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/di/injection.dart';
import '../data/recommendation_engine.dart';
import '../data/deezer_service.dart';
import '../data/lastfm_service.dart';
import '../data/music_models.dart';
import '../data/music_repository.dart';
import '../data/itunes_metadata_service.dart';
import 'stats_providers.dart';
import 'music_providers.dart';

// ─── User Music Profile ─────────────────────────────────────────────────────

final _recommendationEngine = const RecommendationEngine();

/// Full user music profile built from playback history.
final userMusicProfileProvider = FutureProvider<UserMusicProfile>((ref) async {
  final history = ref.watch(allPlaybackProvider).value ?? [];
  if (history.isEmpty) return UserMusicProfile.empty;

  final db = getIt<AppDatabase>();
  final metadata = await db.getAllMetadata();
  final followedArtists = await db.getAllFollowedArtists();

  return _recommendationEngine.buildProfile(
    history: history,
    metadata: metadata,
    followedArtists: followedArtists,
  );
});

/// Listening personality derived from profile.
final listeningPersonalityProvider = Provider<({String name, String description, PersonalityType type})>((ref) {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null) {
    return (name: 'Getting Started', description: 'Play more music to discover your personality.', type: PersonalityType.eclectic);
  }
  return (name: profile.personalityName, description: profile.personalityDescription, type: profile.personalityType);
});

/// Genre weights for the bar chart visualization.
final topicWeightsProvider = Provider<List<GenreWeight>>((ref) {
  return ref.watch(userMusicProfileProvider).value?.genreWeights ?? [];
});

/// Temporal patterns for time-of-day cards.
final temporalPatternsForYouProvider = Provider<List<TemporalPattern>>((ref) {
  return ref.watch(userMusicProfileProvider).value?.temporalPatterns ?? [];
});

/// Artist affinity list for the insights page.
final artistAffinityListProvider = Provider<List<ArtistAffinity>>((ref) {
  return ref.watch(userMusicProfileProvider).value?.artistAffinities ?? [];
});

// ─── For You Recommendation Providers ────────────────────────────────────────

/// Model for a segmented Daily Mix.
typedef DailyMix = ({String title, String subtitle, List<ItunesTrack> tracks, List<Color> colors});

/// Personalized daily mix collection from top artists.
final forYouMixProvider = FutureProvider<List<DailyMix>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  final db = getIt<AppDatabase>();
  final repo = getIt<MusicRepository>();
  final deezer = getIt<DeezerService>();

  List<String> seeds = profile?.topArtists ?? [];
  
  // Fallbacks for seeds...
  if (seeds.isEmpty) {
    final followed = await db.getAllFollowedArtists();
    seeds = followed.map((a) => a.name).toList();
  }
  if (seeds.isEmpty) {
    final liked = await db.getLikedTracks();
    seeds = liked.map((t) => t.artist ?? '').where((a) => a.isNotEmpty).toSet().toList();
  }

  // If still no seeds, return empty (UI will show global fallback in screen)
  if (seeds.isEmpty) return [];

  // Limit to 6 mixes maximum
  final mixSeeds = seeds.take(6).toList();
  
  // Define gradients for variety
  final gradients = [
    [const Color(0xFF00c6ff), const Color(0xFF0072ff)], // Blue
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)], // Purple
    [const Color(0xFF11998e), const Color(0xFF38ef7d)], // Green
    [const Color(0xFFf12711), const Color(0xFFf5af19)], // Orange
    [const Color(0xFFee0979), const Color(0xFFff6a00)], // Pink
    [const Color(0xFF3a1c71), const Color(0xFFd76d77)], // Sunset
  ];

  try {
    // Generate all mixes in parallel
    final mixTasks = mixSeeds.asMap().entries.map((entry) async {
      final index = entry.key;
      final artistName = entry.value;
      
      try {
        final tracks = await deezer.getPersonalizedPlaylist(
          seedArtists: [artistName],
          limit: 50,
        );
        
        if (tracks.isEmpty) return null;

        return (
          title: 'Daily Mix ${index + 1}',
          subtitle: 'Based on $artistName',
          tracks: _deezerTracksToItunes(tracks),
          colors: gradients[index % gradients.length],
        );
      } catch (e) {
        print('[ForYou] Failed to generate mix for $artistName: $e');
        return null;
      }
    }).toList();

    final results = await Future.wait(mixTasks);
    final validMixes = results.whereType<DailyMix>().toList();

    // Fallback if all failed
    if (validMixes.isEmpty) {
      final topSongs = await repo.getTopSongs(limit: 50);
      return [(
        title: 'Daily Mix',
        subtitle: 'Popular global tracks',
        tracks: topSongs,
        colors: gradients[0],
      )];
    }

    return validMixes;
  } catch (e) {
    print('[ForYou] Multi-mix generation failed: $e');
    return [];
  }
});

/// Personalized "Taste Mix" based on most played artists and genre.
final personalizedTasteMixProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  final db = getIt<AppDatabase>();
  final repo = getIt<MusicRepository>();
  final deezer = getIt<DeezerService>();
  
  List<String> seedArtists = profile?.topArtists ?? [];
  
  // Fallback 1: Followed Artists
  if (seedArtists.isEmpty) {
    final followed = await db.getAllFollowedArtists();
    seedArtists = followed.map((a) => a.name).toList();
  }

  // Fallback 2: Global Trending
  if (seedArtists.isEmpty) {
    return await repo.getTopSongs(limit: 20);
  }

  // Use a mix of top artists and top genre as seeds
  final topGenre = profile?.genreWeights.isNotEmpty == true ? profile!.genreWeights.first.genre : '';
  
  // Fetch tracks based on artists
  final tracks = await deezer.getPersonalizedPlaylist(
    seedArtists: seedArtists.take(3).toList(),
    limit: 50,
  );

  var results = _deezerTracksToItunes(tracks);
  
  if (results.length > 50) {
    results = results.take(50).toList();
  } else if (results.length < 15) {
    // If not enough tracks, add some from the top artist radio
    final artistRes = await deezer.searchArtist(seedArtists.first);
    if (artistRes != null) {
      final radioTracks = await deezer.getArtistRadio(artistRes['id'].toString());
      final additional = _deezerTracksToItunes(radioTracks);
      results.addAll(additional.take(50 - results.length));
    }
  }

  return results.take(50).toList();
});

/// "Because you listened to [Artist]" — returns multiple sections.
class BecauseSection {
  final String artistName;
  final List<ItunesTrack> tracks;

  const BecauseSection({required this.artistName, required this.tracks});
}

final becauseYouListenedProvider = FutureProvider<List<BecauseSection>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null || profile.topArtists.isEmpty) return [];

  final deezer = getIt<DeezerService>();
  final sections = <BecauseSection>[];

  // Pick top 3 artists for "because you listened to" sections
  for (final artist in profile.topArtists.take(3)) {
    try {
      final tracks = await deezer.getBecauseYouListenedTo(
        artistName: artist,
        limit: 10,
      );
      if (tracks.isNotEmpty) {
        sections.add(BecauseSection(
          artistName: artist,
          tracks: _deezerTracksToItunes(tracks),
        ));
      }
    } catch (e) {
      print('[ForYou] Error getting "because" for $artist: $e');
    }
  }

  return sections;
});

/// Similar artists from Last.fm.
final similarArtistsForYouProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null || profile.topArtists.isEmpty) return [];

  final lastfm = getIt<LastFmService>();
  final itunes = getIt<ItunesMetadataService>();
  final Set<String> allSimilar = {};
  final List<Map<String, dynamic>> rawResults = [];

  for (final artist in profile.topArtists.take(2)) {
    try {
      final similar = await lastfm.getSimilarArtists(artist, limit: 8);
      for (final s in similar) {
        final name = s['name'] as String;
        if (!allSimilar.contains(name.toLowerCase()) &&
            !profile.topArtists.any((a) => a.toLowerCase() == name.toLowerCase())) {
          allSimilar.add(name.toLowerCase());
          rawResults.add(s);
        }
      }
    } catch (e) {
      print('[ForYou] Error getting similar artists: $e');
    }
  }

  final truncatedResults = rawResults.take(10).toList();

  // Enrich images with iTunes fallback in parallel
  return Future.wait(truncatedResults.map((artist) async {
    final name = artist['name'] as String;
    String imageUrl = artist['image_url'] as String? ?? '';
    
    // Detect missing or placeholder images
    if (imageUrl.isEmpty || imageUrl.contains('2a96cbd8b46e442fc41c2b86b821562f')) {
      final itunesImage = await itunes.fetchArtistImage(name);
      if (itunesImage != null) imageUrl = itunesImage;
    }
    
    return {...artist, 'image_url': imageUrl};
  }));
});

/// Genre radio — tracks from top genre.
final genreRadioProvider = FutureProvider<({String genre, List<ItunesTrack> tracks})>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null || profile.genreWeights.isEmpty || profile.topArtists.isEmpty) {
    return (genre: '', tracks: <ItunesTrack>[]);
  }

  final topGenre = profile.genreWeights.first.genre;
  final deezer = getIt<DeezerService>();

  // Find an artist in the top genre and get their radio
  final artist = await deezer.searchArtist(profile.topArtists.first);
  if (artist == null) return (genre: topGenre, tracks: <ItunesTrack>[]);

  final artistId = artist['id']?.toString() ?? '';
  if (artistId.isEmpty) return (genre: topGenre, tracks: <ItunesTrack>[]);

  final tracks = await deezer.getArtistRadio(artistId);
  return (genre: topGenre, tracks: _deezerTracksToItunes(tracks));
});

/// Time-based mix — contextual recommendations.
final timeBasedMixProvider = FutureProvider<({String label, List<ItunesTrack> tracks})>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null || profile.topArtists.isEmpty) {
    return (label: '', tracks: <ItunesTrack>[]);
  }

  final currentSlot = RecommendationEngine.getCurrentTimeSlot();
  final slotLabel = RecommendationEngine.getTimeSlotLabel(currentSlot);

  // Find what genre/artist the user typically listens to at this time
  final pattern = profile.temporalPatterns.firstWhere(
    (p) => p.slot == currentSlot,
    orElse: () => profile.temporalPatterns.first,
  );

  String seed = profile.topArtists.first;
  if (pattern.topGenres.isNotEmpty) {
    // Use genre + top artist as query seed
    seed = '${pattern.topGenres.first.genre} ${profile.topArtists.first}';
  }

  final repo = getIt<MusicRepository>();
  final tracks = await repo.searchItunes(seed);

  return (label: slotLabel, tracks: tracks.take(15).toList());
});

/// New releases from top artists.
final newReleasesForYouProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null || profile.topArtists.isEmpty) return [];

  final repo = getIt<MusicRepository>();
  final Set<String> seenTracks = {};
  final List<ItunesTrack> results = [];

  for (final artist in profile.topArtists.take(3)) {
    try {
      // Search for recent songs by this artist
      final tracks = await repo.searchItunes('$artist new');
      for (final t in tracks) {
        final key = '${t.trackName}-${t.artistName}'.toLowerCase();
        if (!seenTracks.contains(key)) {
          seenTracks.add(key);
          results.add(t);
        }
      }
    } catch (e) {
      print('[ForYou] Error getting new releases for $artist: $e');
    }
  }

  if (results.isEmpty) {
    print('[ForYou] No artist-specific new releases, falling back to global');
    return await repo.getNewReleases(limit: 15);
  }

  return results.take(15).toList();
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Convert Deezer track maps to ItunesTrack objects for consistent UI.
List<ItunesTrack> _deezerTracksToItunes(List<Map<String, dynamic>> deezerTracks) {
  return deezerTracks.map((t) {
    final artist = t['artist'] as Map<String, dynamic>? ?? {};
    final album = t['album'] as Map<String, dynamic>? ?? {};

    // Get artwork: album cover or artist picture
    String artworkUrl = '';
    if (album['cover_big'] != null) {
      artworkUrl = album['cover_big'] as String;
    } else if (album['cover_medium'] != null) {
      artworkUrl = album['cover_medium'] as String;
    } else if (artist['picture_big'] != null) {
      artworkUrl = artist['picture_big'] as String;
    }

    return ItunesTrack(
      trackId: (t['id'] as num?)?.toInt() ?? 0,
      trackName: t['title'] as String? ?? t['name'] as String? ?? 'Unknown',
      artistName: artist['name'] as String? ?? t['artist_name'] as String? ?? 'Unknown Artist',
      collectionName: album['title'] as String? ?? '',
      artworkUrl: artworkUrl,
      previewUrl: t['preview'] as String?,
      trackTimeMillis: ((t['duration'] as num?)?.toInt() ?? 0) * 1000,
    );
  }).where((t) => t.trackName != 'Unknown').toList();
}
