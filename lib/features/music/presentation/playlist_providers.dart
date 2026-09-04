import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isai/main.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../core/database/database.dart';
import '../../../core/di/injection.dart';
import '../data/music_models.dart';
import '../data/itunes_metadata_service.dart';
import '../data/eclipse_sync_service.dart';
import 'eclipse_playlist_provider.dart';
import 'music_providers.dart';

class PlaylistWithCount {
  final DbPlaylist playlist;
  final int count;
  PlaylistWithCount(this.playlist, this.count);
}

final playlistProvider = NotifierProvider<PlaylistNotifier, AsyncValue<List<PlaylistWithCount>>>(() {
  return PlaylistNotifier();
});

class PlaylistNotifier extends Notifier<AsyncValue<List<PlaylistWithCount>>> {
  late final AppDatabase _db;
  late final EclipseSyncService _eclipseSync;
  late final _yt = YoutubeExplode();

  @override
  AsyncValue<List<PlaylistWithCount>> build() {
    _db = getIt<AppDatabase>();
    _eclipseSync = EclipseSyncService(_db);
    ref.onDispose(() => _yt.close());
    _init();
    return const AsyncValue.loading();
  }

  void _init() {
    // Listen to both playlists and tracks table changes
    _db.watchAllPlaylists().listen((_) => _refreshState());
    _db.watchAllPlaylistTracks().listen((_) => _refreshState());
  }

  Future<void> _refreshState() async {
    try {
      final playlists = await _db.getAllPlaylists();
      final counts = await _db.getPlaylistSongCounts();
      state = AsyncValue.data(
        playlists.map((p) => PlaylistWithCount(p, counts[p.id] ?? 0)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importYoutubePlaylist(String url) async {
    final previousState = state;
    try {
      state = const AsyncValue.loading();

      final uri = Uri.tryParse(url);
      String? playlistId = uri?.queryParameters['list'];
      if (playlistId == null) {
        final match = RegExp(r'[?&]list=([^&]+)').firstMatch(url);
        playlistId = match?.group(1);
      }

      String playlistTitle = 'YouTube Playlist';
      String? playlistArtwork;
      final List<Map<String, dynamic>> parsedTracks = [];
      String? continuation;

      final dio = Dio();
      dio.options.headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://music.youtube.com/',
        'Origin': 'https://music.youtube.com',
      };

      bool usedMusicApi = false;

      // 1. Try YouTube Music InnerTube browse API (supports full pagination past 200 songs)
      if (playlistId != null && playlistId.isNotEmpty) {
        final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
        print('[YoutubeImport] Fetching YouTube Music browse for $browseId...');
        try {
          final response = await dio.post(
            'https://music.youtube.com/youtubei/v1/browse?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc',
            data: {
              'context': {
                'client': {
                  'clientName': 'WEB_REMIX',
                  'clientVersion': '1.20250331.01.00',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
              'browseId': browseId,
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data as Map<String, dynamic>;
            try {
              final mfTitle = data['microformat']?['microformatDataRenderer']?['title'] as String?;
              if (mfTitle != null && mfTitle.isNotEmpty) {
                playlistTitle = mfTitle;
              }
              final mfThumbs = data['microformat']?['microformatDataRenderer']?['thumbnail']?['thumbnails'] as List?;
              if (mfThumbs != null && mfThumbs.isNotEmpty) {
                playlistArtwork = mfThumbs.last['url'];
              }

              final header = data['header']?['musicDetailHeaderRenderer'] ?? data['header']?['playlistHeaderRenderer'] ?? data['header']?['musicHeaderRenderer'];
              if (header != null) {
                if ((playlistTitle == 'YouTube Playlist' || playlistTitle.isEmpty) && header['title']?['runs'] != null && (header['title']['runs'] as List).isNotEmpty) {
                  playlistTitle = header['title']['runs'][0]['text'] ?? playlistTitle;
                }
                if (playlistArtwork == null) {
                  final thumbs = header['thumbnail']?['croppedSquareThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
                  if (thumbs != null && thumbs.isNotEmpty) {
                    playlistArtwork = thumbs.last['url'];
                  }
                }
              }
              if ((playlistTitle == 'YouTube Playlist' || playlistTitle.isEmpty) && data['metadata']?['playlistMetadataRenderer']?['title'] != null) {
                playlistTitle = data['metadata']['playlistMetadataRenderer']['title'];
              }
            } catch (_) {}


            _findTracksInJson(data, parsedTracks);
            continuation = _findContinuationToken(data);
            usedMusicApi = parsedTracks.isNotEmpty;
            print('[YoutubeImport] Music API initial load: ${parsedTracks.length} tracks, title: "$playlistTitle", hasContinuation: ${continuation != null}');
          }
        } catch (e) {
          print('[YoutubeImport] YouTube Music API browse error: $e');
        }
      }

      // 2. Fallback to HTML scraping if Music API didn't return tracks
      if (!usedMusicApi) {
        print('[YoutubeImport] Falling back to YouTube web HTML scraping...');
        final cleanUrl = url.replaceAll('music.youtube.com', 'www.youtube.com');
        final webDio = Dio();
        webDio.options.headers = {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        };

        final response = await webDio.get(cleanUrl);
        final html = response.data as String;

        final pattern = RegExp(r'ytInitialData\s*=\s*(\{.*?\});');
        final match = pattern.firstMatch(html);
        if (match == null) {
          throw Exception("Failed to extract YouTube playlist data");
        }

        final data = jsonDecode(match.group(1)!);

        if (data['metadata'] != null && data['metadata']['playlistMetadataRenderer'] != null) {
          playlistTitle = data['metadata']['playlistMetadataRenderer']['title'] ?? playlistTitle;
        }

        try {
          final header = data['header']?['playlistHeaderRenderer'];
          if (header != null && header['heroImage'] != null) {
            final img = header['heroImage']['contentPreviewImageViewModel']?['image'];
            if (img != null && img['sources'] != null && (img['sources'] as List).isNotEmpty) {
              playlistArtwork = img['sources'].last['url'];
            }
          }
        } catch (_) {}

        _findTracksInJson(data, parsedTracks);
        continuation = _findContinuationToken(data);
        print('[YoutubeImport] Web HTML initial load: ${parsedTracks.length} tracks');
      }

      // 3. Fetch all remaining pages via continuation tokens
      int pageCount = 0;
      final seenTokens = <String>{};
      while (continuation != null && seenTokens.add(continuation)) {
        pageCount++;
        print('[YoutubeImport] Fetching continuation page $pageCount (token len: ${continuation.length})...');
        final pageData = await _fetchYoutubeContinuationPage(continuation, useMusicApi: usedMusicApi);
        if (pageData == null) {
          print('[YoutubeImport] Continuation page $pageCount returned null');
          break;
        }
        final before = parsedTracks.length;
        _findTracksInJson(pageData, parsedTracks);
        final added = parsedTracks.length - before;
        print('[YoutubeImport] Page $pageCount: added $added tracks (total: ${parsedTracks.length})');
        try {
          continuation = _findContinuationToken(pageData);
        } catch (e) {
          print('[YoutubeImport] Error finding continuation: $e');
          break;
        }
        if (continuation == null) {
          print('[YoutubeImport] No more continuation tokens (reached end of playlist)');
        }
      }
      print('[YoutubeImport] Successfully imported ${parsedTracks.length} tracks across ${pageCount + 1} pages for "$playlistTitle"');

      if (playlistArtwork == null && parsedTracks.isNotEmpty) {
        playlistArtwork = parsedTracks.first['artworkUrl'];
      }

      final dbPlaylistId = await _db.createPlaylist(PlaylistsCompanion.insert(
        name: playlistTitle,
        artworkUrl: Value(playlistArtwork),
        sourceUrl: Value(url),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      final List<PlaylistTracksCompanion> tracks = [];
      for (final t in parsedTracks) {
        final ytId = t['youtubeId'] as String? ?? '';
        String? artwork = t['artworkUrl'] as String?;
        if ((artwork == null || artwork.isEmpty) && ytId.isNotEmpty) {
          artwork = 'https://i.ytimg.com/vi/$ytId/hqdefault.jpg';
        }
        tracks.add(PlaylistTracksCompanion.insert(
          playlistId: dbPlaylistId,
          title: t['title'] ?? 'Unknown Track',
          artist: t['artist'] ?? 'Unknown Artist',
          youtubeId: ytId,
          duration: const Value(null),
          artworkUrl: Value(artwork),
        ));
      }

      if (tracks.isNotEmpty) {
        await _db.addTracksToPlaylist(tracks);
      }

      _enrichPlaylistInBackground(dbPlaylistId, preserveArtwork: true);
    } catch (e, st) {
      print('[YoutubeImport] ERROR: $e\n$st');
      state = previousState;
      rethrow;
    }
  }

  static String? _findContinuationToken(dynamic data) {
    if (data is! Map) return null;
    try {
      final contContents = data['continuationContents'] as Map?;
      if (contContents != null) {
        for (final entry in contContents.values) {
          if (entry is Map && entry['contents'] is List) {
            for (final item in (entry['contents'] as List).reversed) {
              if (item is Map && item['continuationItemRenderer'] is Map) {
                final token = item['continuationItemRenderer']
                    ?['continuationEndpoint']?['continuationCommand']?['token'] as String?;
                if (token != null && token.isNotEmpty) return token;
              }
              if (item is Map && item['continuationItemViewModel'] is Map) {
                final token = item['continuationItemViewModel']
                    ?['continuationCommand']?['innertubeCommand']
                    ?['continuationCommand']?['token'] as String?;
                if (token != null && token.isNotEmpty) return token;
              }
            }
          }
        }
      }
    } catch (_) {}
    return _findContinuationRecursive(data);
  }

  static String? _findContinuationRecursive(dynamic node) {
    if (node is Map) {
      if (node.containsKey('continuationItemRenderer')) {
        try {
          final token = node['continuationItemRenderer']
              ?['continuationEndpoint']?['continuationCommand']?['token'] as String?;
          if (token != null && token.isNotEmpty) return token;
        } catch (_) {}
      }
      if (node.containsKey('continuationItemViewModel')) {
        try {
          final token = node['continuationItemViewModel']
              ?['continuationCommand']?['innertubeCommand']
              ?['continuationCommand']?['token'] as String?;
          if (token != null && token.isNotEmpty) return token;
        } catch (_) {}
      }
      for (final val in node.values) {
        final result = _findContinuationRecursive(val);
        if (result != null) return result;
      }
    } else if (node is List) {
      for (final val in node) {
        final result = _findContinuationRecursive(val);
        if (result != null) return result;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchYoutubeContinuationPage(String token, {bool useMusicApi = true}) async {
    final dio = Dio();
    final clientName = useMusicApi ? 'WEB_REMIX' : 'WEB';
    final clientVersion = useMusicApi ? '1.20250331.01.00' : '2.20250331.10.00';
    final endpoint = useMusicApi
        ? 'https://music.youtube.com/youtubei/v1/browse?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc'
        : 'https://www.youtube.com/youtubei/v1/browse?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc';

    dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Content-Type': 'application/json',
      if (useMusicApi) 'Referer': 'https://music.youtube.com/',
      if (useMusicApi) 'Origin': 'https://music.youtube.com',
    };
    try {
      final response = await dio.post(
        endpoint,
        data: {
          'context': {
            'client': {
              'clientName': clientName,
              'clientVersion': clientVersion,
              'hl': 'en',
              'gl': 'US',
            },
          },
          'continuation': Uri.decodeComponent(token),
        },
      );
      if (response.statusCode != 200 || response.data == null) {
        print('[YoutubeImport] Continuation API returned ${response.statusCode}');
        return null;
      }
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('[YoutubeImport] Continuation API error: $e');
      return null;
    }
  }

  void _findTracksInJson(dynamic node, List<Map<String, dynamic>> results) {
    if (node is Map) {
      if (node.containsKey('musicResponsiveListItemRenderer')) {
        final item = node['musicResponsiveListItemRenderer'];
        final playlistItemData = item['playlistItemData'];
        
        String? videoId = playlistItemData?['videoId'];
        if (videoId == null || videoId.isEmpty) {
          videoId = item['doubleTapCommand']?['watchEndpoint']?['videoId'];
        }
        if (videoId == null || videoId.isEmpty) {
          try {
            final flex0 = item['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer'];
            videoId = flex0?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'];
          } catch (_) {}
        }

        if (videoId != null && videoId.isNotEmpty) {
          String title = 'Unknown Title';
          try {
            final flex0 = item['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer'];
            title = flex0?['text']?['runs']?[0]?['text'] ?? 'Unknown Title';
          } catch (_) {}

          String artist = 'Unknown Artist';
          try {
            final flex1 = item['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer'];
            final runs = flex1?['text']?['runs'] as List?;
            if (runs != null && runs.isNotEmpty) {
              artist = runs[0]['text'] ?? 'Unknown Artist';
            }
          } catch (_) {}

          String thumb = '';
          try {
            final thumbs = item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
            if (thumbs != null && thumbs.isNotEmpty) {
              thumb = thumbs.last['url'] ?? '';
            }
          } catch (_) {}

          results.add({
            'title': title,
            'artist': artist,
            'youtubeId': videoId,
            'artworkUrl': thumb,
          });
        }
      } else if (node.containsKey('lockupViewModel')) {
        final item = node['lockupViewModel'];
        final videoId = item['contentId'];
        if (videoId != null && videoId.isNotEmpty) {
          final metadata = item['metadata']?['lockupMetadataViewModel'];
          String title = 'Unknown Title';
          if (metadata != null && metadata['title'] != null) {
            title = metadata['title']['content'] ?? 'Unknown Title';
          }
          
          String artist = 'Unknown Artist';
          if (metadata != null && metadata['metadata'] != null) {
            final contentMeta = metadata['metadata']['contentMetadataViewModel'];
            if (contentMeta != null && contentMeta['metadataRows'] != null && (contentMeta['metadataRows'] as List).isNotEmpty) {
              final firstRow = contentMeta['metadataRows'][0];
              if (firstRow['metadataParts'] != null && (firstRow['metadataParts'] as List).isNotEmpty) {
                final firstPart = firstRow['metadataParts'][0];
                if (firstPart['text'] != null) {
                  artist = firstPart['text']['content'] ?? 'Unknown Artist';
                }
              }
            }
          }
          
          String thumb = '';
          if (item['contentImage'] != null && item['contentImage']['thumbnailViewModel'] != null) {
            final thumbModel = item['contentImage']['thumbnailViewModel'];
            if (thumbModel['image'] != null && thumbModel['image']['sources'] != null) {
              final sources = thumbModel['image']['sources'] as List;
              if (sources.isNotEmpty) {
                thumb = sources.last['url'] ?? '';
              }
            }
          }
          
          results.add({
            'title': title,
            'artist': artist,
            'youtubeId': videoId,
            'artworkUrl': thumb,
          });
        }
      } else if (node.containsKey('playlistVideoRenderer')) {
        final item = node['playlistVideoRenderer'];
        final videoId = item['videoId'];
        if (videoId != null && videoId.isNotEmpty) {
          String title = 'Unknown Title';
          if (item['title'] != null) {
            if (item['title']['runs'] != null && (item['title']['runs'] as List).isNotEmpty) {
              title = item['title']['runs'][0]['text'] ?? 'Unknown Title';
            } else {
              title = item['title']['simpleText'] ?? 'Unknown Title';
            }
          }
          
          String artist = 'Unknown Artist';
          if (item['shortBylineText'] != null && item['shortBylineText']['runs'] != null && (item['shortBylineText']['runs'] as List).isNotEmpty) {
            artist = item['shortBylineText']['runs'][0]['text'] ?? 'Unknown Artist';
          }
          
          String thumb = '';
          if (item['thumbnail'] != null && item['thumbnail']['thumbnails'] != null) {
            final sources = item['thumbnail']['thumbnails'] as List;
            if (sources.isNotEmpty) {
              thumb = sources.last['url'] ?? '';
            }
          }
          
          results.add({
            'title': title,
            'artist': artist,
            'youtubeId': videoId,
            'artworkUrl': thumb,
          });
        }
      }
      for (final val in node.values) {
        _findTracksInJson(val, results);
      }
    } else if (node is List) {
      for (final val in node) {
        _findTracksInJson(val, results);
      }
    }
  }


  Future<void> importSpotifyPlaylist(String url) async {
    final previousState = state;
    try {
      state = const AsyncValue.loading();
      print('[SpotifyImport] Starting import for URL: $url');

      final regExp = RegExp(r'playlist/([a-zA-Z0-9]+)');
      final match = regExp.firstMatch(url);
      if (match == null) {
        throw Exception('Invalid Spotify playlist URL');
      }
      final playlistIdStr = match.group(1)!;
      print('[SpotifyImport] Extracted playlist ID: $playlistIdStr');

      final dio = Dio();
      if (dio.httpClientAdapter is IOHttpClientAdapter) {
        (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = io.HttpClient();
          client.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36';
          return client;
        };
      }
      dio.options.headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
      };

      final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistIdStr';
      print('[SpotifyImport] Requesting embed URL: $embedUrl');
      final response = await dio.get(embedUrl);
      final html = response.data as String;
      print('[SpotifyImport] Embed page response status: ${response.statusCode}, HTML length: ${html.length}');
      
      final pattern = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', dotAll: true);
      final nextDataMatch = pattern.firstMatch(html);
      if (nextDataMatch == null) {
        throw Exception('Failed to extract playlist data from Spotify page (NEXT_DATA script not found)');
      }

      final data = jsonDecode(nextDataMatch.group(1)!);
      final props = data['props'] as Map<String, dynamic>?;
      final pageProps = props?['pageProps'] as Map<String, dynamic>?;
      final stateData = pageProps?['state'] as Map<String, dynamic>?;
      final entityData = stateData?['data'] as Map<String, dynamic>?;
      final entity = entityData?['entity'] as Map<String, dynamic>?;
      if (entity == null) {
        throw Exception('This Spotify playlist could not be read. Please make sure the playlist is set to Public.');
      }

      final playlistName = entity['name'] as String? ?? 'Spotify Playlist';
      final sources = entity['coverArt']?['sources'] as List<dynamic>?;
      final artworkUrl = (sources != null && sources.isNotEmpty) ? sources.first['url'] as String? : null;
      print('[SpotifyImport] Playlist Name: $playlistName, Artwork: $artworkUrl');

      final dbPlaylistId = await _db.createPlaylist(PlaylistsCompanion.insert(
        name: playlistName,
        artworkUrl: Value(artworkUrl),
        sourceUrl: Value(url),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      final List<PlaylistTracksCompanion> tracksToInsert = [];
      final trackList = entity['trackList'] as List<dynamic>? ?? [];
      print('[SpotifyImport] Found ${trackList.length} tracks in trackList');

      for (var i = 0; i < trackList.length; i++) {
        final item = trackList[i];
        final title = item['title'] as String? ?? 'Unknown Track';
        final subtitle = item['subtitle'] as String? ?? 'Unknown Artist';
        final firstArtist = subtitle.split(',').first.trim();
        final durationMs = item['duration'] as int?;
        final durationSec = durationMs != null ? durationMs ~/ 1000 : null;

        print('[SpotifyImport] Track $i: "$title" by "$firstArtist" ($durationSec s)');

        tracksToInsert.add(PlaylistTracksCompanion.insert(
          playlistId: dbPlaylistId,
          title: title,
          artist: firstArtist,
          youtubeId: '', 
          duration: Value(durationSec),
          artworkUrl: Value(artworkUrl),
        ));
      }

      if (tracksToInsert.isNotEmpty) {
        await _db.addTracksToPlaylist(tracksToInsert);
        print('[SpotifyImport] Successfully inserted ${tracksToInsert.length} tracks to DB');
        _enrichPlaylistInBackground(dbPlaylistId, preserveTitleArtist: true);
      } else {
        print('[SpotifyImport] WARNING: No tracks to insert');
      }
    } catch (e, st) {
      print('[SpotifyImport] ERROR: $e');
      print(st);
      state = previousState;
      rethrow;
    }
  }



  Future<void> _enrichPlaylistInBackground(int playlistId, {bool preserveTitleArtist = false, bool preserveArtwork = false}) async {
    print('[PlaylistNotifier] Starting background enrichment for playlist: $playlistId');
    final tracks = await _db.getPlaylistTracks(playlistId);
    final itunes = getIt<ItunesMetadataService>();

    for (final track in tracks) {
      try {
        // Clean title for better matching (YouTube titles are often messy)
        final cleanTitle = track.title
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .replaceAll(RegExp(r'\(.*?\)'), '')
            .replaceAll(RegExp(r'ft\..*'), '')
            .replaceAll(RegExp(r'feat\..*'), '')
            .trim();
        
        final results = await itunes.searchMeta('$cleanTitle ${track.artist}');
        if (results.isNotEmpty) {
          final best = results.first;
          final hasExistingArtwork = track.artworkUrl != null && track.artworkUrl!.isNotEmpty;
          final artworkToUse = (preserveArtwork && hasExistingArtwork)
              ? track.artworkUrl
              : (best.artworkUrlHigh ?? best.artworkUrlLow ?? track.artworkUrl);

          await _db.updatePlaylistTrack(PlaylistTracksCompanion(
            id: Value(track.id),
            title: preserveTitleArtist ? Value(track.title) : Value(best.trackName ?? track.title),
            artist: preserveTitleArtist ? Value(track.artist) : Value(best.artistName ?? track.artist),
            artworkUrl: Value(artworkToUse),
            album: Value(best.album),
            genre: Value(best.genre),
          ));
        }
      } catch (e) {
        print('[PlaylistNotifier] Enrichment failed for track ${track.id}: $e');
      }
    }
    print('[PlaylistNotifier] Background enrichment completed for playlist: $playlistId');
  }

  Future<void> enrichPlaylistTrack(int trackId, ItunesMeta meta) async {
    await _db.updatePlaylistTrack(PlaylistTracksCompanion(
      id: Value(trackId),
      title: Value(meta.trackName ?? ''),
      artist: Value(meta.artistName ?? ''),
      artworkUrl: Value(meta.artworkUrlHigh ?? meta.artworkUrlLow),
      album: Value(meta.album),
      genre: Value(meta.genre),
    ));

    // Refresh AudioHandler if this track is currently playing (pass metadata directly)
    await audioHandler.customAction('refresh_metadata', {
      'torrentId': -1,
      'fileId': -trackId,
      '_meta_title': meta.trackName,
      '_meta_artist': meta.artistName,
      '_meta_album': meta.album,
      '_meta_genre': meta.genre,
      '_meta_releaseYear': meta.releaseYear,
      '_meta_trackTimeMillis': meta.trackTimeMillis,
      '_meta_artworkHigh': meta.artworkUrlHigh,
      '_meta_artworkLow': meta.artworkUrlLow,
    });
  }

  Future<void> updatePlaylistTrackSource(int trackId, String youtubeId) async {
    await _db.updatePlaylistTrack(PlaylistTracksCompanion(
      id: Value(trackId),
      youtubeId: Value(youtubeId),
    ));
  }

  Future<void> deletePlaylistTrack(int id) async {
    final track = await _db.getPlaylistTrackById(id);
    await _db.deletePlaylistTrack(id);
    if (track == null) return;
    final playlist = await _db.getPlaylistById(track.playlistId);
    if (playlist?.eclipseId == null) return;
    final settings = ref.read(settingsProvider);
    if (!settings.eclipseIsValid) return;

    if (track.eclipseTrackId != null) {
      _eclipseSync.removeTrackFromEclipsePlaylist(
        token: settings.eclipseToken,
        userId: settings.eclipseUserId!,
        eclipsePlaylistId: playlist!.eclipseId!,
        eclipseTrackId: track.eclipseTrackId!,
      );
    } else {
      _eclipseSync.removeTrackFromEclipsePlaylistByMetadata(
        token: settings.eclipseToken,
        userId: settings.eclipseUserId!,
        eclipsePlaylistId: playlist!.eclipseId!,
        title: track.title,
        artist: track.artist,
      );
    }
  }

  Future<void> deletePlaylist(int id) async {
    final playlist = await _db.getPlaylistById(id);
    await _db.deletePlaylist(id);
    if (playlist?.eclipseId != null) {
      final settings = ref.read(settingsProvider);
      if (settings.eclipseIsValid) {
        _eclipseSync.deletePlaylistOnEclipse(
          token: settings.eclipseToken,
          userId: settings.eclipseUserId!,
          eclipsePlaylistId: playlist!.eclipseId!,
        );
      }
    }
  }

  Future<int> createPlaylist(String name) async {
    final id = await _db.createPlaylist(PlaylistsCompanion.insert(
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    final settings = ref.read(settingsProvider);
    if (settings.eclipseIsValid && settings.eclipseToken.isNotEmpty && settings.eclipseUserId != null) {
      await _eclipseSync.createPlaylistOnEclipse(
        token: settings.eclipseToken,
        userId: settings.eclipseUserId!,
        localPlaylistId: id,
        name: name,
      );
    }
    return id;
  }

  Future<void> _syncTrackToEclipse(int playlistId, String title, String artist, {String? album, String? artworkUrl}) async {
    final playlist = await _db.getPlaylistById(playlistId);
    if (playlist?.eclipseId == null) return;
    final settings = ref.read(settingsProvider);
    if (!settings.eclipseIsValid) return;
    await _eclipseSync.addTrackToEclipsePlaylist(
      token: settings.eclipseToken,
      userId: settings.eclipseUserId!,
      eclipsePlaylistId: playlist!.eclipseId!,
      title: title,
      artist: artist,
      album: album,
      artworkUrl: artworkUrl,
    );
  }

  Future<void> importEclipsePlaylists() async {
    final settings = ref.read(settingsProvider);
    if (!settings.eclipseIsValid || settings.eclipseToken.isEmpty || settings.eclipseUserId == null) return;
    await _eclipseSync.importEclipsePlaylists(
      token: settings.eclipseToken,
      userId: settings.eclipseUserId!,
    );
  }

  Future<void> refresh() async {
    await importEclipsePlaylists();
    await _refreshState();
  }

  Future<int> syncLocalPlaylistsToEclipse() async {
    final settings = ref.read(settingsProvider);
    if (!settings.eclipseIsValid || settings.eclipseToken.isEmpty || settings.eclipseUserId == null) return 0;
    return _eclipseSync.syncLocalPlaylistsToEclipse(
      token: settings.eclipseToken,
      userId: settings.eclipseUserId!,
    );
  }

  Future<bool> addTrackToPlaylist(int playlistId, ItunesTrack track) async {
    final exists = await _db.checkTrackInPlaylist(
      playlistId: playlistId,
      youtubeId: track.trackId.toString(),
    );
    if (exists) return false;

    await _db.addSingleTrackToPlaylist(
      PlaylistTracksCompanion.insert(
        playlistId: playlistId,
        title: track.trackName,
        artist: track.artistName,
        album: Value(track.collectionName),
        youtubeId: track.trackId.toString(),
        artworkUrl: Value(track.artworkUrl),
      )
    );
    _syncTrackToEclipse(
      playlistId,
      track.trackName,
      track.artistName,
      album: track.collectionName.isNotEmpty ? track.collectionName : null,
      artworkUrl: track.artworkUrl.isNotEmpty ? track.artworkUrl : null,
    );
    return true;
  }

  Future<bool> addFileToPlaylist(int playlistId, TorBoxFile file, ItunesMeta meta) async {
    final exists = await _db.checkTrackInPlaylist(
      playlistId: playlistId,
      torrentId: file.torrentId,
      fileId: file.id,
    );
    if (exists) return false;

    await _db.addSingleTrackToPlaylist(
      PlaylistTracksCompanion.insert(
        playlistId: playlistId,
        title: meta.trackName ?? file.name,
        artist: meta.artistName ?? 'Unknown Artist',
        album: Value(meta.album),
        youtubeId: '',
        torrentId: Value(file.torrentId),
        fileId: Value(file.id),
        artworkUrl: Value(meta.artworkUrlHigh ?? meta.artworkUrlLow),
      )
    );
    _syncTrackToEclipse(
      playlistId,
      meta.trackName ?? file.name,
      meta.artistName ?? 'Unknown Artist',
      album: meta.album,
      artworkUrl: meta.artworkUrlHigh ?? meta.artworkUrlLow,
    );
    return true;
  }

  Future<String> exportPlaylistToJson(int playlistId) async {
    final playlist = (await _db.getAllPlaylists()).firstWhere((p) => p.id == playlistId);
    final tracks = await _db.getPlaylistTracks(playlistId);

    final data = {
      'version': 1,
      'name': playlist.name,
      'artworkUrl': playlist.artworkUrl,
      'sourceUrl': playlist.sourceUrl,
      'tracks': tracks.map((t) => {
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'youtubeId': t.youtubeId,
        'duration': t.duration,
        'artworkUrl': t.artworkUrl,
        'genre': t.genre,
        'torrentId': t.torrentId,
        'fileId': t.fileId,
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> importPlaylistFromJson(String jsonContent) async {
    final Map<String, dynamic> data = jsonDecode(jsonContent);
    final name = data['name'] as String? ?? 'Imported Playlist';
    final artworkUrl = data['artworkUrl'] as String?;
    final sourceUrl = data['sourceUrl'] as String?;
    final rawTracks = data['tracks'] as List<dynamic>? ?? [];

    final playlistId = await _db.createPlaylist(PlaylistsCompanion.insert(
      name: name,
      artworkUrl: Value(artworkUrl),
      sourceUrl: Value(sourceUrl),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    final List<PlaylistTracksCompanion> tracks = [];
    for (final rt in rawTracks) {
      if (rt is Map<String, dynamic>) {
        tracks.add(PlaylistTracksCompanion.insert(
          playlistId: playlistId,
          title: rt['title'] as String? ?? 'Unknown Track',
          artist: rt['artist'] as String? ?? 'Unknown Artist',
          album: Value(rt['album'] as String?),
          youtubeId: rt['youtubeId'] as String? ?? '',
          duration: Value(rt['duration'] as int?),
          artworkUrl: Value(rt['artworkUrl'] as String?),
          genre: Value(rt['genre'] as String?),
          torrentId: Value(rt['torrentId'] as int?),
          fileId: Value(rt['fileId'] as int?),
        ));
      }
    }

    if (tracks.isNotEmpty) {
      await _db.addTracksToPlaylist(tracks);
    }
  }

  Future<void> importItunesTracksPlaylist(String name, String? artworkUrl, List<ItunesTrack> tracks, {String? sourceUrl}) async {
    final playlistId = await _db.createPlaylist(PlaylistsCompanion.insert(
      name: name,
      artworkUrl: Value(artworkUrl),
      sourceUrl: Value(sourceUrl),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    final List<PlaylistTracksCompanion> tracksToInsert = [];
    for (final track in tracks) {
      tracksToInsert.add(PlaylistTracksCompanion.insert(
        playlistId: playlistId,
        title: track.trackName,
        artist: track.artistName,
        album: Value(track.collectionName),
        youtubeId: track.trackId.toString(),
        artworkUrl: Value(track.artworkUrl),
      ));
    }

    if (tracksToInsert.isNotEmpty) {
      await _db.addTracksToPlaylist(tracksToInsert);
    }

    final settings = ref.read(settingsProvider);
    if (settings.eclipseIsValid && settings.eclipseToken.isNotEmpty && settings.eclipseUserId != null) {
      final eclipseTracks = tracks.map((t) => {
        'title': t.trackName,
        'artist': t.artistName,
        if (t.collectionName.isNotEmpty) 'album': t.collectionName,
        if (t.artworkUrl.isNotEmpty) 'coverUrl': t.artworkUrl,
      }).toList();
      await _eclipseSync.createPlaylistOnEclipseWithTracks(
        token: settings.eclipseToken,
        userId: settings.eclipseUserId!,
        localPlaylistId: playlistId,
        name: name,
        artworkUrl: artworkUrl,
        tracks: eclipseTracks,
      );
      ref.invalidate(eclipsePlaylistsProvider);
    }
  }

  Future<String> exportAllPlaylistsToJson() async {
    final allPlaylists = await _db.getAllPlaylists();
    final List<Map<String, dynamic>> playlistsData = [];

    for (final playlist in allPlaylists) {
      final tracks = await _db.getPlaylistTracks(playlist.id);
      playlistsData.add({
        'name': playlist.name,
        'artworkUrl': playlist.artworkUrl,
        'sourceUrl': playlist.sourceUrl,
        'tracks': tracks.map((t) => {
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'youtubeId': t.youtubeId,
          'duration': t.duration,
          'artworkUrl': t.artworkUrl,
          'genre': t.genre,
          'torrentId': t.torrentId,
          'fileId': t.fileId,
        }).toList(),
      });
    }

    final backup = {
      'version': 1,
      'type': 'all_playlists_backup',
      'playlists': playlistsData,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<int> importAllPlaylistsFromJson(String jsonContent) async {
    final Map<String, dynamic> backup = jsonDecode(jsonContent);
    if (backup['type'] != 'all_playlists_backup') {
      await importPlaylistFromJson(jsonContent);
      return 1;
    }

    final rawPlaylists = backup['playlists'] as List<dynamic>? ?? [];
    int count = 0;

    for (final rawPlaylist in rawPlaylists) {
      if (rawPlaylist is Map<String, dynamic>) {
        final name = rawPlaylist['name'] as String? ?? 'Imported Playlist';
        final artworkUrl = rawPlaylist['artworkUrl'] as String?;
        final sourceUrl = rawPlaylist['sourceUrl'] as String?;
        final rawTracks = rawPlaylist['tracks'] as List<dynamic>? ?? [];

        final playlistId = await _db.createPlaylist(PlaylistsCompanion.insert(
          name: name,
          artworkUrl: Value(artworkUrl),
          sourceUrl: Value(sourceUrl),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));

        final List<PlaylistTracksCompanion> tracks = [];
        for (final rt in rawTracks) {
          if (rt is Map<String, dynamic>) {
            tracks.add(PlaylistTracksCompanion.insert(
              playlistId: playlistId,
              title: rt['title'] as String? ?? 'Unknown Track',
              artist: rt['artist'] as String? ?? 'Unknown Artist',
              album: Value(rt['album'] as String?),
              youtubeId: rt['youtubeId'] as String? ?? '',
              duration: Value(rt['duration'] as int?),
              artworkUrl: Value(rt['artworkUrl'] as String?),
              genre: Value(rt['genre'] as String?),
              torrentId: Value(rt['torrentId'] as int?),
              fileId: Value(rt['fileId'] as int?),
            ));
          }
        }

        if (tracks.isNotEmpty) {
          await _db.addTracksToPlaylist(tracks);
        }
        count++;
      }
    }
    return count;
  }
}

final playlistTracksProvider = StreamProvider.family<List<DbPlaylistTrack>, int>((ref, playlistId) {
  return getIt<AppDatabase>().watchPlaylistTracks(playlistId);
});
