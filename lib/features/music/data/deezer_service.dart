import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class DeezerService {
  final Dio _dio;
  static const _baseUrl = 'https://api.deezer.com';

  DeezerService(this._dio);

  /// 0. Discovery Charts (Top 100) with optional personalization
  Future<List<Map<String, dynamic>>> fetchDiscoveryCharts({List<String>? seedArtists, int limit = 100}) async {
    try {
      if (seedArtists != null && seedArtists.isNotEmpty) {
        print('[DeezerService] Fetching personalized discovery for: $seedArtists');
        return await getPersonalizedPlaylist(seedArtists: seedArtists, limit: limit);
      }

      print('[DeezerService] Fetching global discovery charts');
      final response = await _dio.get('$_baseUrl/chart/0/tracks', queryParameters: {'limit': limit});
      final data = response.data;
      final results = (data is String ? jsonDecode(data) : data)['data'] ?? [];
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      print('[DeezerService] fetchDiscoveryCharts error: $e');
      return [];
    }
  }

  /// 1. Search for artist to get their unique ID
  Future<Map<String, dynamic>?> searchArtist(String artistName) async {
    try {
      // First try a simple query which is often more reliable for top results
      final response = await _dio.get(
        '$_baseUrl/search/artist',
        queryParameters: {'q': artistName, 'limit': 5},
      );
      final data = response.data;
      final List<dynamic> results = (data is String ? jsonDecode(data) : data)['data'] ?? [];
      
      if (results.isEmpty) return null;

      // Check if we have an exact name match in top 5
      for (final a in results) {
        if ((a['name'] as String).toLowerCase() == artistName.toLowerCase()) {
          print('[DeezerService] Found exact artist match for "$artistName": ${a['name']} (ID: ${a['id']})');
          return a as Map<String, dynamic>;
        }
      }

      // If no exact match found yet, try a strict query as fallback
      final strictResponse = await _dio.get(
        '$_baseUrl/search/artist',
        queryParameters: {'q': 'artist:"$artistName"'},
      );
      final strictData = strictResponse.data;
      final List<dynamic> strictResults = (strictData is String ? jsonDecode(strictData) : strictData)['data'] ?? [];
      
      if (strictResults.isNotEmpty) {
        final match = strictResults.first;
        // Verify it's actually the right name
        if ((match['name'] as String).toLowerCase() == artistName.toLowerCase()) {
          print('[DeezerService] Found strict artist match for "$artistName": ${match['name']} (ID: ${match['id']})');
          return match as Map<String, dynamic>;
        }
      }

      // Final fallback: just use the very first result from simple search
      final fallback = results.first;
      print('[DeezerService] Using fallback artist match for "$artistName": ${fallback['name']} (ID: ${fallback['id']})');
      return fallback as Map<String, dynamic>;
    } catch (e) {
      print('[DeezerService] searchArtist error for "$artistName": $e');
      return null;
    }
  }

  /// 1.5 Search for Tracks
  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/search/track',
        queryParameters: {'q': query},
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );
      final data = response.data;
      final List<dynamic> results = (data is String ? jsonDecode(data) : data)['data'] ?? [];
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      print('[DeezerService] searchTracks error: $e');
      return [];
    }
  }

  /// 1b. Get Full Artist Object (with stats like nb_fan, nb_album)
  Future<Map<String, dynamic>?> getArtistDetails(String artistId) async {
    try {
      final response = await _dio.get('$_baseUrl/artist/$artistId');
      final data = response.data;
      return Map<String, dynamic>.from(data is String ? jsonDecode(data) : data);
    } catch (e) {
      print('[DeezerService] getArtistDetails error: $e');
      return null;
    }
  }

  /// 2. Get Artist Playlists
  Future<List<Map<String, dynamic>>> getArtistPlaylists(String artistId) async {
    try {
      final response = await _dio.get('$_baseUrl/artist/$artistId/playlists');
      final data = response.data;
      return List<Map<String, dynamic>>.from((data is String ? jsonDecode(data) : data)['data'] ?? []);
    } catch (e) {
      print('[DeezerService] getArtistPlaylists error: $e');
      return [];
    }
  }

  /// 3. Get Artist Top Tracks (Using radio/search fallback if /top is empty)
  Future<List<Map<String, dynamic>>> getArtistTopTracks(String artistId, String artistName) async {
    try {
      // 1. Try direct /top first
      final directResponse = await _dio.get('$_baseUrl/artist/$artistId/top');
      final directData = directResponse.data;
      final directList = List<Map<String, dynamic>>.from((directData is String ? jsonDecode(directData) : directData)['data'] ?? []);
      
      if (directList.isNotEmpty) {
        print('[DeezerService] Found ${directList.length} tracks via /top for $artistName');
        return directList;
      }

      // 2. Fallback: try artist radio (often has data when /top is restricted)
      print('[DeezerService] /top empty for $artistName, trying /radio fallback');
      final radioResponse = await _dio.get('$_baseUrl/artist/$artistId/radio');
      final radioData = radioResponse.data;
      final radioList = List<Map<String, dynamic>>.from((radioData is String ? jsonDecode(radioData) : radioData)['data'] ?? []);
      
      if (radioList.isNotEmpty) {
        print('[DeezerService] Found ${radioList.length} tracks via /radio for $artistName');
        return radioList;
      }

      // 3. Final Fallback: search for artist tracks
      print('[DeezerService] /radio empty for $artistName, trying search fallback');
      final searchResponse = await _dio.get(
        '$_baseUrl/search', 
        queryParameters: {'q': 'artist:"$artistName"', 'order': 'RANKING'},
      );
      final searchData = searchResponse.data;
      final searchList = List<Map<String, dynamic>>.from((searchData is String ? jsonDecode(searchData) : searchData)['data'] ?? []);
      
      print('[DeezerService] Found ${searchList.length} tracks via search for $artistName');
      return searchList;
    } catch (e) {
      print('[DeezerService] getArtistTopTracks error: $e');
      return [];
    }
  }

  /// 4. Get Full Discography (Using search fallback if /albums is empty)
  Future<List<Map<String, dynamic>>> getArtistAlbums(String artistId, String artistName) async {
    try {
      // Try direct first
      final directResponse = await _dio.get('$_baseUrl/artist/$artistId/albums');
      final directData = directResponse.data;
      final directList = List<Map<String, dynamic>>.from((directData is String ? jsonDecode(directData) : directData)['data'] ?? []);

      if (directList.isNotEmpty) return directList;

      // Fallback: search for albums
      final searchResponse = await _dio.get(
        '$_baseUrl/search/album',
        queryParameters: {'q': artistName},
      );
      final searchData = searchResponse.data;
      return List<Map<String, dynamic>>.from((searchData is String ? jsonDecode(searchData) : searchData)['data'] ?? []);
    } catch (e) {
      print('[DeezerService] getArtistAlbums error: $e');
      return [];
    }
  }

  /// 5. Get Related Artists
  Future<List<Map<String, dynamic>>> getArtistRelated(String artistId) async {
    try {
      final response = await _dio.get('$_baseUrl/artist/$artistId/related');
      final data = response.data;
      return List<Map<String, dynamic>>.from((data is String ? jsonDecode(data) : data)['data'] ?? []);
    } catch (e) {
      print('[DeezerService] getArtistRelated error: $e');
      return [];
    }
  }

  /// 6. Get Artist Radio
  Future<List<Map<String, dynamic>>> getArtistRadio(String artistId) async {
    try {
      final response = await _dio.get('$_baseUrl/artist/$artistId/radio');
      final data = response.data;
      return List<Map<String, dynamic>>.from((data is String ? jsonDecode(data) : data)['data'] ?? []);
    } catch (e) {
      print('[DeezerService] getArtistRadio error: $e');
      return [];
    }
  }

  /// 6b. Search for Playlists
  Future<List<Map<String, dynamic>>> searchPlaylists(String query, {int index = 0}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/search/playlist',
        queryParameters: {
          'q': query,
          'index': index.toString(),
        },
      );
      final data = response.data;
      return List<Map<String, dynamic>>.from((data is String ? jsonDecode(data) : data)['data'] ?? []);
    } catch (e) {
      print('[DeezerService] searchPlaylists error: $e');
      return [];
    }
  }

  /// 7. Get Playlist Tracks
  Future<List<Map<String, dynamic>>> getPlaylistTracks(String playlistId, {int index = 0, int limit = 50}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/playlist/$playlistId/tracks',
        queryParameters: {
          'index': index.toString(),
          'limit': limit.toString(),
        },
      );
      final data = response.data;
      return List<Map<String, dynamic>>.from((data is String ? jsonDecode(data) : data)['data'] ?? []);
    } catch (e) {
      print('[DeezerService] getPlaylistTracks error: $e');
      return [];
    }
  }

  /// 8. Get Genres
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      final response = await _dio.get('$_baseUrl/genre');
      final data = response.data;
      final List<dynamic> results = (data is String ? jsonDecode(data) : data)['data'] ?? [];
      
      // Filter out 'All' genre (id: 0) and ensured we have a picture
      return results
          .where((g) => g['id'] != 0 && g['picture_medium'] != null)
          .map((g) => Map<String, dynamic>.from(g))
          .toList();
    } catch (e) {
      print('[DeezerService] getGenres error: $e');
      return [];
    }
  }

  /// 9. Get Genre Playlists
  Future<List<Map<String, dynamic>>> getGenrePlaylists(int genreId, {String? genreName}) async {
    try {
      // Direct endpoint is often broken or restricted, so we use search by genre name which is very reliable
      if (genreName != null && genreName.isNotEmpty) {
        // 1. Try strict genre search
        final response = await _dio.get(
          '$_baseUrl/search/playlist',
          queryParameters: {'q': 'genre:"$genreName"', 'order': 'RANKING'},
        );
        final data = response.data;
        List<dynamic> results = (data is String ? jsonDecode(data) : data)['data'] ?? [];
        
        // 2. If strict results are low, try broader search (e.g. "Tamil Hits" or "Tamil")
        if (results.length < 10) {
          final broadQuery = '$genreName Hits';
          final broadResponse = await _dio.get(
            '$_baseUrl/search/playlist',
            queryParameters: {'q': broadQuery, 'order': 'RANKING'},
          );
          final broadData = broadResponse.data;
          final List<dynamic> broadResults = (broadData is String ? jsonDecode(broadData) : broadData)['data'] ?? [];
          
          if (broadResults.length > results.length) {
            results = broadResults;
          }
          
          // 3. Final fallback to just the name if still very low
          if (results.length < 5) {
             final nameResponse = await _dio.get(
              '$_baseUrl/search/playlist',
              queryParameters: {'q': genreName, 'order': 'RANKING'},
            );
            final nameData = nameResponse.data;
            final List<dynamic> nameResults = (nameData is String ? jsonDecode(nameData) : nameData)['data'] ?? [];
            if (nameResults.length > results.length) {
              results = nameResults;
            }
          }
        }
        
        if (results.isNotEmpty) return List<Map<String, dynamic>>.from(results);
      }

      // Final fallback (legacy)
      final response = await _dio.get('$_baseUrl/genre/$genreId/playlists');
      final data = response.data;
      return List<Map<String, dynamic>>.from((data is String ? jsonDecode(data) : data)['data'] ?? []);
    } catch (e) {
      print('[DeezerService] getGenrePlaylists error: $e');
      return [];
    }
  }

  /// 9.5 Search for New Releases (Robust fallback for iTunes RSS)
  Future<List<Map<String, dynamic>>> searchNewReleases({int limit = 30}) async {
    try {
      // Use search for all tracks ordered by release date
      // We use a wildcard/generic term and sort by release date
      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'q': 'top', // Generic query
          'order': 'RELEASEDATE_DESC',
          'limit': limit.toString(),
        },
      );
      final data = response.data;
      final List<dynamic> results = (data is String ? jsonDecode(data) : data)['data'] ?? [];
      
      print('[DeezerService] Fetched ${results.length} new releases via search');
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      print('[DeezerService] searchNewReleases error: $e');
      return [];
    }
  }

  /// 10. Create personalized playlist based on listening history (Discover Weekly style)
  /// Uses artist relationships from Deezer to find similar music
  Future<List<Map<String, dynamic>>> getPersonalizedPlaylist({
    required List<String> seedArtists,
    int limit = 30,
  }) async {
    try {
      if (seedArtists.isEmpty) return [];

      final results = <Map<String, dynamic>>[];
      final processedTracks = <int>{};

      print('[DeezerService] Starting robust personalized mix for seeds: $seedArtists');

      // 1. Fetch seed artist details in parallel
      final seedDetailsTasks = seedArtists.take(3).map((name) => searchArtist(name)).toList();
      final seedArtistResponse = await Future.wait(seedDetailsTasks);
      final validSeeds = seedArtistResponse.whereType<Map<String, dynamic>>().toList();

      if (validSeeds.isEmpty) {
        print('[DeezerService] No valid seed artists found on Deezer');
        return [];
      }

      // 2. For each seed, fetch both radio AND related artists in parallel
      final List<Future<void>> secondaryTasks = [];

      for (final artist in validSeeds) {
        final artistId = artist['id'];
        final artistName = artist['name'];
        
        // Task: Get radio tracks for seed (much more robust than /top)
        secondaryTasks.add((() async {
          try {
            final response = await _dio.get('$_baseUrl/artist/$artistId/radio');
            final data = response.data;
            final List<dynamic> tracks = (data is String ? jsonDecode(data) : data)['data'] ?? [];
            
            // If radio is empty, try search fallback
            if (tracks.isEmpty) {
              print('[DeezerService] Radio empty for $artistName, trying search fallback');
              final sResponse = await _dio.get('$_baseUrl/search', queryParameters: {'q': 'artist:"$artistName"'});
              final sData = sResponse.data;
              tracks.addAll((sData is String ? jsonDecode(sData) : sData)['data'] ?? []);
            }

            int addedCount = 0;
            for (final t in tracks) {
              final id = t['id'] as int;
              if (!processedTracks.contains(id)) {
                processedTracks.add(id);
                results.add(Map<String, dynamic>.from(t));
                addedCount++;
              }
            }
            print('[DeezerService] Added $addedCount tracks for seed $artistName');
          } catch (e) {
            print('[DeezerService] Error fetching tracks for seed $artistName: $e');
          }
        })());

        // Task: Get related artists and their radio tracks
        secondaryTasks.add((() async {
          try {
            final relatedResponse = await _dio.get('$_baseUrl/artist/$artistId/related');
            final relatedData = relatedResponse.data;
            final List<dynamic> related = (relatedData is String ? jsonDecode(relatedData) : relatedData)['data'] ?? [];
            
            print('[DeezerService] Found ${related.length} related artists for $artistName');

            // Limit to top 5 related artists
            final List<Future<void>> relatedTracksTasks = related.take(5).map((r) async {
              final rId = r['id'];
              final rName = r['name'];
              try {
                // For related artists, we can use /top or /radio. Let's try /top then /radio.
                final tracksResponse = await _dio.get('$_baseUrl/artist/$rId/top');
                final tracksData = tracksResponse.data;
                var rTracks = (tracksData is String ? jsonDecode(tracksData) : tracksData)['data'] ?? [];
                
                if (rTracks.isEmpty) {
                   final rRadioResponse = await _dio.get('$_baseUrl/artist/$rId/radio');
                   rTracks = (rRadioResponse.data is String ? jsonDecode(rRadioResponse.data) : rRadioResponse.data)['data'] ?? [];
                }

                int rAdded = 0;
                for (final t in rTracks) {
                  final id = t['id'] as int;
                  if (!processedTracks.contains(id)) {
                    processedTracks.add(id);
                    results.add(Map<String, dynamic>.from(t));
                    rAdded++;
                  }
                }
              } catch (_) {}
            }).toList();
            
            await Future.wait(relatedTracksTasks);
          } catch (e) {
            print('[DeezerService] Error fetching related artists for seed $artistId: $e');
          }
        })());
      }

      await Future.wait(secondaryTasks);

      // Convert to list and shuffle for variety
      results.shuffle();
      
      print('[DeezerService] Final robust personalized mix size: ${results.length} tracks');
      return results.take(limit).toList();
    } catch (e) {
      print('[DeezerService] getPersonalizedPlaylist critical error: $e');
      return [];
    }
  }

  /// 11. Get recommendations based on a specific track
  /// Uses Deezer's related artists to find similar music
  Future<List<Map<String, dynamic>>> getRecommendationsForTrack({
    required String trackTitle,
    required String artistName,
    int limit = 20,
  }) async {
    try {
      // First, search for the track to get artist ID
      final searchResponse = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {'q': '$trackTitle $artistName', 'limit': 1},
      );
      final searchData = searchResponse.data;
      final List<dynamic> results = (searchData is String ? jsonDecode(searchData) : searchData)['data'] ?? [];
      
      if (results.isEmpty) {
        // Fallback: just search for artist
        final artistSearchResponse = await _dio.get(
          '$_baseUrl/search/artist',
          queryParameters: {'q': artistName, 'limit': 1},
        );
        final artistSearchData = artistSearchResponse.data;
        final List<dynamic> artistResults = (artistSearchData is String ? jsonDecode(artistSearchData) : artistSearchData)['data'] ?? [];
        
        if (artistResults.isNotEmpty) {
          final artist = artistResults.first as Map<String, dynamic>;
          return await _getTracksFromRelatedArtists(artist['id'], limit);
        }
        return [];
      }

      final track = results.first as Map<String, dynamic>;
      final artist = track['artist'] as Map<String, dynamic>;
      
      return await _getTracksFromRelatedArtists(artist['id'], limit);
    } catch (e) {
      print('[DeezerService] getRecommendationsForTrack error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getTracksFromRelatedArtists(int artistId, int limit) async {
    try {
      final relatedResponse = await _dio.get('$_baseUrl/artist/$artistId/related');
      final relatedData = relatedResponse.data;
      final List<dynamic> related = (relatedData is String ? jsonDecode(relatedData) : relatedData)['data'] ?? [];

      final Set<Map<String, dynamic>> tracks = {};
      
      // Get top tracks from related artists
      for (final relatedArtist in related.take(8)) {
        try {
          final tracksResponse = await _dio.get('$_baseUrl/artist/${relatedArtist['id']}/top');
          final tracksData = tracksResponse.data;
          final List<dynamic> topTracks = (tracksData is String ? jsonDecode(tracksData) : tracksData)['data'] ?? [];
          topTracks.forEach((t) => tracks.add(Map<String, dynamic>.from(t)));
        } catch (e) {
          print('[DeezerService] Error fetching tracks from related artist: $e');
        }
      }

      final trackList = tracks.toList();
      trackList.shuffle();
      
      return trackList.take(limit).toList();
    } catch (e) {
      print('[DeezerService] _getTracksFromRelatedArtists error: $e');
      return [];
    }
  }

  /// 13. Get "Because you listened to X" recommendations
  Future<List<Map<String, dynamic>>> getBecauseYouListenedTo({
    required String artistName,
    int limit = 20,
  }) async {
    try {
      // Search for the artist
      final searchResponse = await _dio.get(
        '$_baseUrl/search/artist',
        queryParameters: {'q': artistName, 'limit': 2},
      );
      final searchData = searchResponse.data;
      final List<dynamic> results = (searchData is String ? jsonDecode(searchData) : searchData)['data'] ?? [];
      
      if (results.isEmpty) return [];

      final artist = results.first as Map<String, dynamic>;
      final artistId = artist['id'] as int;

      // Get artist radio (mix of artist and related artists)
      final radioResponse = await _dio.get('$_baseUrl/artist/$artistId/radio');
      final radioData = radioResponse.data;
      final List<dynamic> radioTracks = (radioData is String ? jsonDecode(radioData) : radioData)['data'] ?? [];

      if (radioTracks.isNotEmpty) {
        return radioTracks.take(limit).map((t) => Map<String, dynamic>.from(t)).toList();
      }

      // Fallback: get related artists and their top tracks
      return await _getTracksFromRelatedArtists(artistId, limit);
    } catch (e) {
      print('[DeezerService] getBecauseYouListenedTo error: $e');
      return [];
    }
  }

  /// Helper for synchronized access (Dart is single-threaded, so this is just a pass-through)
  void synchronized(dynamic lock, Function action) {
    action();
  }
}
