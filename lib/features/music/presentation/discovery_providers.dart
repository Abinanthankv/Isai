import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:drift/drift.dart';
import '../../../core/di/injection.dart';
import '../../../core/database/database.dart';
import '../data/deezer_service.dart';
import '../data/itunes_metadata_service.dart';
import '../data/recommendation_engine.dart';

class DiscoveryTrack {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final String? previewUrl;

  DiscoveryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    this.previewUrl,
  });
}

class DiscoveryState {
  final bool isLoading;
  final String? error;
  final List<DiscoveryTrack> tracks;
  final int currentIndex;

  DiscoveryState({
    this.isLoading = true,
    this.error,
    this.tracks = const [],
    this.currentIndex = 0,
  });

  DiscoveryState copyWith({
    bool? isLoading,
    String? error,
    List<DiscoveryTrack>? tracks,
    int? currentIndex,
  }) {
    return DiscoveryState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class DiscoveryNotifier extends Notifier<DiscoveryState> {
  final AudioPlayer previewPlayer = AudioPlayer();
  final Set<String> _processedIds = {};
  bool _isDisposed = false;
  int _fetchRound = 0;

  @override
  DiscoveryState build() {
    print('[Discovery] Notifier build() called');

    // Auto-advance when preview finishes
    final sub = previewPlayer.processingStateStream.listen((ps) {
      if (ps == ProcessingState.completed && !_isDisposed) {
        print('[Discovery] Preview completed, auto-advancing...');
        nextCard();
      }
    });

    ref.onDispose(() {
      print('[Discovery] Notifier disposed');
      _isDisposed = true;
      sub.cancel();
      try {
        previewPlayer.dispose();
      } catch (_) {}
    });
    Future.microtask(() => _init());
    return DiscoveryState();
  }

  /// Get diverse seed artists — queries DB directly so it works even if stream providers aren't ready
  Future<List<String>> _getSeedArtists() async {
    // 1. Direct DB query — most reliable, doesn't depend on provider state
    try {
      final db = getIt<AppDatabase>();
      final history = await db.getAllPlayback();
      if (history.isNotEmpty) {
        final Map<String, int> artistCounts = {};
        for (final h in history) {
          if (h.artist.isNotEmpty) {
            // Split multi-artist fields
            final artists = RecommendationEngine.splitArtists(h.artist);
            for (final artist in artists) {
              artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
            }
          }
        }
        if (artistCounts.isNotEmpty) {
          final sorted = artistCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final names = sorted.take(10).map((e) => e.key).toList();
          print('[Discovery] Got ${names.length} artists from DB history: $names');
          return names;
        }
      }
    } catch (e) {
      print('[Discovery] DB history query failed: $e');
    }

    // 2. Fallback: followed artists from DB
    try {
      final db = getIt<AppDatabase>();
      final followed = await db.getAllFollowedArtists();
      if (followed.isNotEmpty) {
        final names = followed.map((a) => a.name).toList();
        print('[Discovery] Got ${names.length} followed artists from DB');
        return names;
      }
    } catch (e) {
      print('[Discovery] DB followed artists failed: $e');
    }

    // 3. Fallback: liked tracks
    try {
      final db = getIt<AppDatabase>();
      final liked = await db.getLikedTracks();
      if (liked.isNotEmpty) {
        final names = liked
            .map((t) => t.artist ?? '')
            .where((a) => a.isNotEmpty)
            .toSet()
            .toList();
        if (names.isNotEmpty) {
          print('[Discovery] Got ${names.length} artists from liked tracks');
          return names;
        }
      }
    } catch (e) {
      print('[Discovery] Liked tracks query failed: $e');
    }

    print('[Discovery] No seed artists found from any source');
    return [];
  }

  Future<void> _init({bool isRefill = false}) async {
    try {
      if (_isDisposed) return;
      
      if (!isRefill) {
        state = state.copyWith(isLoading: true, error: null);
      }

      final deezer = getIt<DeezerService>();
      final itunes = getIt<ItunesMetadataService>();
      
      final allSeedArtists = await _getSeedArtists();
      List<DiscoveryTrack> newTracks = [];

      if (allSeedArtists.isNotEmpty) {
        // ── Diverse per-artist fetching ──
        // Pick different artists each round for variety
        final shuffled = List<String>.from(allSeedArtists)..shuffle(Random());
        // Take 3 different artists per round, cycling through the list
        final startIdx = (_fetchRound * 3) % shuffled.length;
        final selectedSeeds = <String>[];
        for (int i = 0; i < min(3, shuffled.length); i++) {
          selectedSeeds.add(shuffled[(startIdx + i) % shuffled.length]);
        }
        _fetchRound++;
        
        print('[Discovery] Round $_fetchRound seeds: $selectedSeeds');

        // Fetch from each artist independently for diversity
        for (final artistName in selectedSeeds) {
          if (_isDisposed) break;
          try {
            final artistData = await deezer.searchArtist(artistName);
            if (artistData == null) continue;
            
            final artistId = artistData['id'].toString();
            final artistDisplayName = artistData['name'] as String;

            // Get tracks from multiple sources per artist for variety
            final List<Map<String, dynamic>> artistTracks = [];

            // Source A: Artist radio (related tracks)
            final radioTracks = await deezer.getArtistRadio(artistId);
            artistTracks.addAll(radioTracks);

            // Source B: Related artists' top tracks (for discovery beyond the artist)
            final related = await deezer.getArtistRelated(artistId);
            // Pick 2 random related artists
            final relatedShuffled = List.from(related)..shuffle(Random());
            for (final rel in relatedShuffled.take(2)) {
              try {
                final relId = rel['id'].toString();
                final relTop = await deezer.getArtistTopTracks(relId, rel['name'] as String? ?? '');
                artistTracks.addAll(relTop.take(5));
              } catch (_) {}
            }

            print('[Discovery] Fetched ${artistTracks.length} tracks for "$artistDisplayName"');
            newTracks.addAll(_mapDeezerTracks(artistTracks));
          } catch (e) {
            print('[Discovery] Error fetching for "$artistName": $e');
          }
        }
      }

      // ── Fallback: iTunes direct search ──
      if (newTracks.isEmpty) {
        print('[Discovery] No Deezer results, falling back to iTunes...');
        newTracks = await _fetchFromItunes(itunes, allSeedArtists);
        print('[Discovery] iTunes fallback: ${newTracks.length} tracks');
      }

      if (_isDisposed) return;

      if (newTracks.isEmpty && !isRefill) {
        state = state.copyWith(isLoading: false, error: 'Could not load any tracks. Check your connection.');
        return;
      }

      // Shuffle for variety — mix tracks from different artists together
      newTracks.shuffle(Random());

      print('[Discovery] Total new tracks: ${newTracks.length}');

      final allTracks = [...state.tracks, ...newTracks];
      state = state.copyWith(
        isLoading: false,
        tracks: allTracks,
        error: null,
      );

      if (allTracks.isNotEmpty && !isRefill) {
        await _resolveItunesPreview(state.currentIndex, itunes);
        _playCurrentPreview();
      }

      // Pre-resolve upcoming previews in background
      _resolveUpcomingPreviews(itunes);

    } catch (e) {
      if (_isDisposed) return;
      print('[Discovery] ERROR in _init: $e');
      state = state.copyWith(isLoading: false, error: state.tracks.isEmpty ? 'Discovery Error: $e' : null);
    }
  }

  /// Map Deezer API results to DiscoveryTrack, skipping already-seen
  List<DiscoveryTrack> _mapDeezerTracks(List<Map<String, dynamic>> deezerTracks) {
    final List<DiscoveryTrack> tracks = [];
    for (final dt in deezerTracks) {
      final id = dt['id'].toString();
      if (_processedIds.contains(id)) continue;
      _processedIds.add(id);
      
      final title = dt['title'] as String? ?? dt['title_short'] as String? ?? 'Unknown';
      final artist = (dt['artist'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown Artist';
      final artworkUrl = (dt['album'] as Map<String, dynamic>?)?['cover_xl'] as String? ?? 
                         (dt['album'] as Map<String, dynamic>?)?['cover_big'] as String? ??
                         (dt['album'] as Map<String, dynamic>?)?['cover_medium'] as String? ?? '';
      final deezerPreview = dt['preview'] as String?;

      tracks.add(DiscoveryTrack(
        id: id,
        title: title,
        artist: artist,
        artworkUrl: artworkUrl,
        previewUrl: deezerPreview,
      ));
    }
    return tracks;
  }

  /// Fetch tracks directly from iTunes when Deezer is unavailable
  Future<List<DiscoveryTrack>> _fetchFromItunes(
    ItunesMetadataService itunes,
    List<String> seedArtists,
  ) async {
    final List<DiscoveryTrack> tracks = [];
    
    final queries = <String>[
      ...seedArtists.take(5).map((a) => a),
      'top hits 2025',
      'popular songs',
      'trending music',
    ];

    for (final query in queries) {
      if (_isDisposed) break;
      if (tracks.length >= 25) break;
      
      try {
        final results = await itunes.searchMeta(query);
        for (final meta in results) {
          if (meta.previewUrl == null || meta.previewUrl!.isEmpty) continue;
          
          final id = 'itunes_${meta.id ?? meta.trackName}';
          if (_processedIds.contains(id)) continue;
          _processedIds.add(id);

          tracks.add(DiscoveryTrack(
            id: id,
            title: meta.trackName ?? 'Unknown',
            artist: meta.artistName ?? 'Unknown Artist',
            artworkUrl: meta.artworkUrlHigh ?? meta.artworkUrlLow ?? '',
            previewUrl: meta.previewUrl,
          ));
        }
      } catch (e) {
        print('[Discovery] iTunes search error for "$query": $e');
      }
    }

    return tracks;
  }

  /// Resolve iTunes preview URL for a specific track index
  Future<void> _resolveItunesPreview(int index, ItunesMetadataService itunes) async {
    if (_isDisposed || index >= state.tracks.length) return;
    
    final track = state.tracks[index];
    if (track.previewUrl != null && track.previewUrl!.isNotEmpty) return;

    try {
      final meta = await itunes.fetchMeta(track.title, track.artist);
      if (_isDisposed || meta?.previewUrl == null) return;

      print('[Discovery] Resolved iTunes preview for "${track.title}": ${meta!.previewUrl}');

      final updatedTracks = List<DiscoveryTrack>.from(state.tracks);
      updatedTracks[index] = DiscoveryTrack(
        id: track.id,
        title: track.title,
        artist: track.artist,
        artworkUrl: meta.artworkUrlHigh ?? track.artworkUrl,
        previewUrl: meta.previewUrl,
      );
      state = state.copyWith(tracks: updatedTracks);
    } catch (e) {
      print('[Discovery] iTunes preview resolve error for "${track.title}": $e');
    }
  }

  /// Pre-resolve iTunes previews for the next few tracks
  Future<void> _resolveUpcomingPreviews(ItunesMetadataService itunes) async {
    final startIdx = state.currentIndex + 1;
    final endIdx = (startIdx + 5).clamp(0, state.tracks.length);
    
    for (int i = startIdx; i < endIdx; i++) {
      if (_isDisposed) return;
      await _resolveItunesPreview(i, itunes);
    }
  }

  Future<void> _playCurrentPreview() async {
    if (_isDisposed) return;
    if (state.currentIndex >= state.tracks.length) return;
    
    final track = state.tracks[state.currentIndex];
    
    // If no preview URL, try resolving from iTunes
    if (track.previewUrl == null || track.previewUrl!.isEmpty) {
      final itunes = getIt<ItunesMetadataService>();
      await _resolveItunesPreview(state.currentIndex, itunes);
      if (_isDisposed || state.currentIndex >= state.tracks.length) return;
      final updatedTrack = state.tracks[state.currentIndex];
      if (updatedTrack.previewUrl == null || updatedTrack.previewUrl!.isEmpty) {
        print('[Discovery] No preview URL for "${track.title}", skipping audio');
        return;
      }
    }
    
    try {
      final url = state.tracks[state.currentIndex].previewUrl!;
      await previewPlayer.setUrl(url);
      if (_isDisposed) return;
      await previewPlayer.play();
    } catch (e) {
      print('[Discovery] Error playing preview: $e');
    }
  }

  void nextCard() {
    if (state.currentIndex < state.tracks.length - 1) {
      previewPlayer.stop();
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      _playCurrentPreview();
      
      // Pre-resolve upcoming iTunes previews
      final itunes = getIt<ItunesMetadataService>();
      _resolveUpcomingPreviews(itunes);
      
      // Pre-fetch more if getting low
      if (state.tracks.length - state.currentIndex < 5 && !state.isLoading) {
         _init(isRefill: true);
      }
    } else {
       previewPlayer.stop();
       _init(isRefill: true);
    }
  }

  void stopPreview() {
    try {
      previewPlayer.stop();
    } catch (_) {}
  }

  void pausePreview() {
    previewPlayer.pause();
  }
  
  void resumePreview() {
    previewPlayer.play();
  }

  Future<void> likeCurrentTrack() async {
    final track = state.tracks[state.currentIndex];
    print('[Discovery] Liked: ${track.title} by ${track.artist}');
    
    try {
      final db = getIt<AppDatabase>();
      
      final playlists = await db.getAllPlaylists();
      var discoveryPlaylist = playlists.where((p) => p.name == 'Discovery Hits').firstOrNull;
      
      int playlistId;
      if (discoveryPlaylist == null) {
        playlistId = await db.createPlaylist(PlaylistsCompanion.insert(
          name: 'Discovery Hits',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      } else {
        playlistId = discoveryPlaylist.id;
      }
      
      final exists = await db.checkTrackInPlaylist(
        playlistId: playlistId,
        youtubeId: 'discovery_${track.id}',
      );
      
      if (!exists) {
        await db.addTracksToPlaylist([
          PlaylistTracksCompanion.insert(
            playlistId: playlistId,
            title: track.title,
            artist: track.artist,
            youtubeId: 'discovery_${track.id}',
            artworkUrl: Value(track.artworkUrl),
          )
        ]);
      }
    } catch (e) {
      print('[Discovery] Error saving liked track: $e');
    }
    
    nextCard();
  }
  
  void skipCurrentTrack() {
    nextCard();
  }
}

final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(() {
  return DiscoveryNotifier();
});
