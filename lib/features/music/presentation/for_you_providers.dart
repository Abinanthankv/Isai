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
  final db = getIt<AppDatabase>();
  final history = await db.getAllPlayback();
  if (history.isEmpty) return UserMusicProfile.empty;

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

  // Diversity: spread seeds by rank (top, bottom, middle) rather than top-N
  final List<String> mixSeeds;
  if (seeds.length <= 6) {
    mixSeeds = seeds.toList();
  } else {
    // Pick from top, middle, and bottom for genre diversity
    final shuffled = List<String>.from(seeds);
    final top = shuffled.take(2).toList();
    final bottom = shuffled.skip(shuffled.length - 2).toList();
    final middle = shuffled.skip(2).take(shuffled.length - 4).toList();
    middle.shuffle();
    mixSeeds = [...top, ...middle.take(2), ...bottom];
  }
  
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
    final allTrackKeys = <String>{};
    final mixTasks = mixSeeds.asMap().entries.map((entry) async {
      final index = entry.key;
      final artistName = entry.value;
      
      try {
        final tracks = await deezer.getPersonalizedPlaylist(
          seedArtists: [artistName],
          limit: 50,
        );
        
        if (tracks.isEmpty) return null;

        // Deduplicate tracks across mixes (max 2 per artist per mix, no dupes across mixes)
        var itunesTracks = _deezerTracksToItunes(tracks);
        final deduped = <ItunesTrack>[];
        final artistCount = <String, int>{};
        for (final t in itunesTracks) {
          final key = '${t.trackName}-${t.artistName}'.toLowerCase();
          if (allTrackKeys.contains(key)) continue;
          final artistKey = t.artistName!.toLowerCase();
          if ((artistCount[artistKey] ?? 0) >= 2) continue;
          allTrackKeys.add(key);
          artistCount[artistKey] = (artistCount[artistKey] ?? 0) + 1;
          deduped.add(t);
        }

        if (deduped.isEmpty) return null;

        return (
          title: 'Daily Mix ${index + 1}',
          subtitle: 'Based on $artistName',
          tracks: deduped,
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

  // Inject ~30% global chart tracks for discovery
  try {
    final chart = await deezer.fetchDiscoveryCharts(limit: 50);
    final chartTracks = _deezerTracksToItunes(chart);
    chartTracks.shuffle();
    final discoveryCount = (results.length * 0.3).round().clamp(3, 15);
    results.addAll(chartTracks.take(discoveryCount));
  } catch (e) {
    print('[ForYou] Taste mix chart injection failed: $e');
  }

  // Enforce max 2 per artist
  final artistCount = <String, int>{};
  final deduped = <ItunesTrack>[];
  for (final t in results) {
    final artistKey = (t.artistName ?? '').toLowerCase();
    if ((artistCount[artistKey] ?? 0) >= 2) continue;
    artistCount[artistKey] = (artistCount[artistKey] ?? 0) + 1;
    deduped.add(t);
  }
  deduped.shuffle();

  return deduped.take(50).toList();
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

  // Pick a mid-weight genre (avoid top 2 most-listened) for diversity
  final int genreIndex;
  if (profile.genreWeights.length >= 5) {
    // Deterministic rotation based on week number
    final week = (DateTime.now().millisecondsSinceEpoch ~/ (7 * 24 * 60 * 60 * 1000));
    genreIndex = 2 + (week % (profile.genreWeights.length - 2)).clamp(0, 5);
  } else {
    genreIndex = 0;
  }
  final selectedGenre = profile.genreWeights[genreIndex.clamp(0, profile.genreWeights.length - 1)].genre;
  final deezer = getIt<DeezerService>();

  // Find an artist in the selected genre and get their radio
  // Try to pick an artist NOT in top artists for more discovery
  String seedArtist = profile.topArtists.first;
  if (profile.topArtists.length > 1) {
    // Pick a lower-ranked artist to avoid same-artist fatigue
    seedArtist = profile.topArtists[profile.topArtists.length > 3 ? 2 : 1];
  }

  final artist = await deezer.searchArtist(seedArtist);
  if (artist == null) return (genre: selectedGenre, tracks: <ItunesTrack>[]);

  final artistId = artist['id']?.toString() ?? '';
  if (artistId.isEmpty) return (genre: selectedGenre, tracks: <ItunesTrack>[]);

  final tracks = await deezer.getArtistRadio(artistId);
  return (genre: selectedGenre, tracks: _deezerTracksToItunes(tracks));
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

/// "Outside Your Bubble" — tracks from genres the user rarely listens to.
final outsideYourBubbleProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null || profile.genreWeights.length < 3) return [];

  final deezer = getIt<DeezerService>();

  // Pick bottom 3 genres (least listened)
  final bottomGenres = profile.genreWeights
      .skip((profile.genreWeights.length / 2).floor())
      .take(3)
      .toList();

  if (bottomGenres.isEmpty) return [];

  final seenKeys = <String>{};
  final results = <ItunesTrack>[];
  final topArtistNames = profile.topArtists.map((a) => a.toLowerCase()).toSet();

  for (final gw in bottomGenres) {
    try {
      final playlists = await deezer.getGenrePlaylists(0, genreName: gw.genre);
      if (playlists.isEmpty) continue;

      // Take first playlist's tracks
      final playlistId = playlists.first['id']?.toString() ?? '';
      if (playlistId.isEmpty) continue;

      final tracks = await deezer.getPlaylistTracks(playlistId, limit: 20);
      for (final t in _deezerTracksToItunes(tracks)) {
        if (results.length >= 15) break;
        final key = '${t.trackName}-${t.artistName}'.toLowerCase();
        if (seenKeys.contains(key)) continue;
        // Filter out artists the user already listens to
        final artistKey = (t.artistName ?? '').toLowerCase();
        if (topArtistNames.contains(artistKey)) continue;
        seenKeys.add(key);
        results.add(t);
      }
    } catch (e) {
      print('[ForYou] Outside bubble error for ${gw.genre}: $e');
    }
    if (results.length >= 15) break;
  }

  return results;
});

/// "Fresh & Different" — tracks similar to liked tracks but by different artists.
final freshAndDifferentProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  if (profile == null) return [];

  final db = getIt<AppDatabase>();
  final lastfm = getIt<LastFmService>();
  final topArtistNames = profile.topArtists.map((a) => a.toLowerCase()).toSet();

  // Get liked tracks as seeds
  final liked = await db.getLikedTracks();
  if (liked.isEmpty) return [];

  // Pick up to 3 liked tracks with artists NOT in top artists (more discovery)
  liked.shuffle();
  final seeds = liked.where((t) {
    final artist = (t.artist ?? '').toLowerCase();
    return artist.isNotEmpty && !topArtistNames.contains(artist);
  }).take(3).toList();

  // Fallback: use any liked track if no discovery candidates
  final seedTracks = seeds.isNotEmpty ? seeds : liked.take(3).toList();

  final seenKeys = <String>{};
  final results = <ItunesTrack>[];

  for (final seed in seedTracks) {
    try {
      final similar = await lastfm.getSimilarTracks(
        seed.trackTitle ?? '',
        seed.artist ?? '',
        limit: 15,
      );
      for (final s in similar) {
        if (results.length >= 15) break;
        final trackName = s['name'] as String? ?? '';
        final artistName = s['artist'] as String? ?? s['artist_name'] as String? ?? '';
        if (trackName.isEmpty || artistName.isEmpty) continue;
        final key = '${trackName}_${artistName}'.toLowerCase();
        if (seenKeys.contains(key)) continue;
        // Filter out artists user already knows
        if (topArtistNames.contains(artistName.toLowerCase())) continue;
        seenKeys.add(key);
        results.add(ItunesTrack(
          trackId: trackName.hashCode,
          trackName: trackName,
          artistName: artistName,
          collectionName: '',
          artworkUrl: s['image_url'] as String? ?? '',
        ));
      }
    } catch (e) {
      print('[ForYou] Fresh & different error: $e');
    }
  }

  // Fill missing artwork via iTunes
  final itunes = getIt<ItunesMetadataService>();
  final artworkFixes = <int>{};
  for (int i = 0; i < results.length; i++) {
    if (results[i].artworkUrl.isEmpty) artworkFixes.add(i);
  }
  await Future.wait(artworkFixes.map((i) async {
    try {
      final meta = await itunes.fetchMeta(results[i].trackName, results[i].artistName);
      if (meta?.artworkUrlHigh != null || meta?.artworkUrlLow != null) {
        results[i] = results[i].copyWith(
          artworkUrl: meta!.artworkUrlHigh ?? meta.artworkUrlLow ?? '',
        );
      }
    } catch (_) {}
  }));

  return results;
});

// ─── Discovery Stats ──────────────────────────────────────────────────────────

class DiscoveryStats {
  final int thisWeekNewArtists;
  final int thisWeekNewTracks;
  final int totalNewArtists;
  final int totalNewTracks;
  final List<String> recentlyDiscoveredArtists;
  final List<int> weeklyDiscoveryCounts;
  final int peakWeekCount;

  const DiscoveryStats({
    required this.thisWeekNewArtists,
    required this.thisWeekNewTracks,
    required this.totalNewArtists,
    required this.totalNewTracks,
    required this.recentlyDiscoveredArtists,
    required this.weeklyDiscoveryCounts,
    required this.peakWeekCount,
  });
}

/// Track new artist / track discovery rate over time.
final discoveryStatsProvider = FutureProvider<DiscoveryStats>((ref) async {
  final db = getIt<AppDatabase>();
  final history = await db.getAllPlayback();
  if (history.isEmpty) {
    return const DiscoveryStats(
      thisWeekNewArtists: 0,
      thisWeekNewTracks: 0,
      totalNewArtists: 0,
      totalNewTracks: 0,
      recentlyDiscoveredArtists: [],
      weeklyDiscoveryCounts: [],
      peakWeekCount: 0,
    );
  }

  final sorted = List<DbPlaybackHistory>.from(history)
    ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

  final seenArtists = <String>{};
  final seenTrackKeys = <String>{};
  final weeklyMap = <int, int>{};
  final recentArtists = <String>[];
  final recentArtistSet = <String>{};

  final now = DateTime.now();
  final currentWeekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
  final currentWeekMs = currentWeekStart.millisecondsSinceEpoch;

  int thisWeekArtists = 0;
  int thisWeekTracks = 0;

  for (final h in sorted) {
    final artistKey = h.artist.toLowerCase();
    final trackKey = '${h.artist}|${h.trackTitle}'.toLowerCase();
    final recDate = DateTime.fromMillisecondsSinceEpoch(h.playedAt);
    final weekStart = DateTime(recDate.year, recDate.month, recDate.day - recDate.weekday + 1);
    final weekMs = weekStart.millisecondsSinceEpoch;

    final isNewArtist = !seenArtists.contains(artistKey);
    final isNewTrack = !seenTrackKeys.contains(trackKey);

    if (isNewArtist) seenArtists.add(artistKey);
    if (isNewTrack) seenTrackKeys.add(trackKey);

    if (isNewArtist || isNewTrack) {
      weeklyMap[weekMs] = (weeklyMap[weekMs] ?? 0) + 1;

      if (isNewArtist && !recentArtistSet.contains(artistKey)) {
        recentArtistSet.add(artistKey);
        recentArtists.add(h.artist);
        if (recDate.millisecondsSinceEpoch >= currentWeekMs) thisWeekArtists++;
      }
      if (isNewTrack && recDate.millisecondsSinceEpoch >= currentWeekMs) thisWeekTracks++;
    }
  }

  final sortedWeeks = weeklyMap.keys.toList()..sort();
  final last8Weeks = sortedWeeks.reversed.take(8).toList()..sort();
  final weeklyCounts = last8Weeks.map((w) => weeklyMap[w]!).toList();
  final peak = weeklyCounts.isEmpty ? 0 : weeklyCounts.reduce((a, b) => a > b ? a : b);

  return DiscoveryStats(
    thisWeekNewArtists: thisWeekArtists,
    thisWeekNewTracks: thisWeekTracks,
    totalNewArtists: seenArtists.length,
    totalNewTracks: seenTrackKeys.length,
    recentlyDiscoveredArtists: recentArtists.reversed.take(6).toList(),
    weeklyDiscoveryCounts: weeklyCounts,
    peakWeekCount: peak,
  );
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

/// Decade + genre mixes from Deezer, paired from the user's listening history.
final decadeMixesProvider = FutureProvider<List<DailyMix>>((ref) async {
  final profile = ref.watch(userMusicProfileProvider).value;
  final db = getIt<AppDatabase>();
  final deezer = getIt<DeezerService>();

  // Query DB directly — same as stats page, no stream delay
  final allHistory = await db.getAllPlayback();
  final Map<int, ({int plays, Set<String> tracks})> decades = {};
  for (final h in allHistory) {
    if (h.releaseYear == null) continue;
    final decade = (h.releaseYear! ~/ 10) * 10;
    final entry = decades.putIfAbsent(decade, () => (plays: 0, tracks: {}));
    decades[decade] = (plays: entry.plays + 1, tracks: {...entry.tracks, '${h.trackTitle}-${h.artist}'});
  }
  final sorted = decades.entries.toList()..sort((a, b) => b.value.plays.compareTo(a.value.plays));
  final topDecades = sorted.map((e) => e.key).toList();
  if (topDecades.isEmpty) return [];

  final genres = profile?.genreWeights
      .where((g) => g.genre.isNotEmpty)
      .map((g) => g.genre)
      .toList() ?? [];

  final List<({Color from, Color to, Color shadow})> decadeGradients = [
    (from: const Color(0xFF6B52A0), to: const Color(0xFF2D1B69), shadow: const Color(0xFF6B52A0)),
    (from: const Color(0xFFD4145A), to: const Color(0xFFBB0B4A), shadow: const Color(0xFFD4145A)),
    (from: const Color(0xFF11998E), to: const Color(0xFF0B6B5E), shadow: const Color(0xFF11998E)),
  ];

  final mixes = <DailyMix>[];
  final seenKeys = <String>{};
  final seenPlaylistIds = <int>{};
  for (int i = 0; i < topDecades.length; i++) {
    final decade = topDecades[i];
    final gradient = decadeGradients[i % decadeGradients.length];
    final genre = genres.isNotEmpty ? genres[i % genres.length] : '';

    final mixKey = '$decade|$genre';
    if (!seenKeys.add(mixKey)) continue;

    final query = genre.isNotEmpty ? '${decade}s $genre' : '${decade}s hits';

    List<ItunesTrack> tracks = [];
    String mixTitle = genre.isNotEmpty ? '${decade}s $genre Mix' : '${decade}s Mix';

    // Try Deezer with genre query first, then fall back to generic decade hits
    final queries = genre.isNotEmpty ? [query, '${decade}s hits'] : [query];
    for (final q in queries) {
      if (tracks.isNotEmpty) break;
      try {
        final playlists = await deezer.searchPlaylists(q);
        if (playlists.isNotEmpty) {
          final pl = playlists.firstWhere(
            (p) => !seenPlaylistIds.contains((p['id'] as num?)?.toInt()),
            orElse: () => playlists.first,
          );
          final plId = (pl['id'] as num?)?.toInt() ?? pl['title']?.toString().hashCode ?? q.hashCode;
          final rawTracks = await deezer.getPlaylistTracks(plId.toString(), limit: 20);
          for (final t in rawTracks) {
            final artist = t['artist'] as Map<String, dynamic>? ?? {};
            final album = t['album'] as Map<String, dynamic>? ?? {};
            tracks.add(ItunesTrack(
              trackId: (t['id'] as num?)?.toInt() ?? 0,
              trackName: t['title'] as String? ?? 'Unknown',
              artistName: artist['name'] as String? ?? 'Unknown Artist',
              collectionName: album['title'] as String? ?? '',
              artworkUrl: (album['cover_medium'] as String?) ?? (album['cover_big'] as String?) ?? '',
              previewUrl: t['preview'] as String?,
              trackTimeMillis: ((t['duration'] as num?)?.toInt() ?? 0) * 1000,
            ));
          }
          seenPlaylistIds.add(plId);
        }
    } catch (_) {}
  }

  if (tracks.isEmpty) {
    final library = ref.read(libraryProvider);
      for (final file in library.allAudioFiles) {
        final meta = library.metadata['${file.torrentId}-${file.id}'];
        if (meta?.releaseYear == null) continue;
        if ((meta!.releaseYear! ~/ 10) * 10 != decade) continue;
        tracks.add(ItunesTrack(
          trackId: (meta.trackName ?? file.name).hashCode,
          trackName: meta.trackName ?? file.name,
          artistName: meta.artistName ?? 'Unknown',
          collectionName: meta.album ?? '',
          artworkUrl: meta.artworkUrlHigh ?? meta.artworkUrlLow ?? '',
          trackTimeMillis: meta.trackTimeMillis,
        ));
      }
    }

    if (tracks.isEmpty) continue;

    final subtitle = genre.isNotEmpty ? '${tracks.length} tracks • $genre' : '${tracks.length} tracks';
    mixes.add((
      title: mixTitle,
      subtitle: subtitle,
      tracks: tracks,
      colors: [gradient.from, gradient.to],
    ));
  }

  return mixes;
});
