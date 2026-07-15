import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, SnackBarBehavior, Text;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show YoutubeExplode;
import 'package:drift/drift.dart' show Value;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../database/database.dart';
import '../di/injection.dart';
import '../../features/music/data/itunes_metadata_service.dart';
import '../../main.dart';

class ShareHandlerService {
  static StreamSubscription? _intentDataStreamSubscription;
  static final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static void init() {
    // For sharing or opening when app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
    }, onError: (err) {
      print("[ShareHandler] Error receiving share: $err");
    });

    // For sharing or opening when app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleSharedText(value.first.path);
        });
      }
    }).catchError((err) {
      print("[ShareHandler] Error receiving initial share: $err");
    });
  }

  static void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  static Future<void> _handleSharedText(String text) async {
    print("[ShareHandler] Received shared text: $text");
    
    // Extract URL if shared text contains text around URL
    final urlRegex = RegExp(r'(https?://[^\s]+)');
    final match = urlRegex.firstMatch(text);
    if (match == null) return;
    
    final url = match.group(0)!;
    print("[ShareHandler] Extracted URL: $url");

    try {
      if (url.contains("spotify.com/playlist/")) {
        await _processSpotifyPlaylist(url);
      } else if (url.contains("spotify.com/track/")) {
        await _processSpotifyTrack(url);
      } else if ((url.contains("youtube.com/") || url.contains("youtu.be/")) && url.contains("list=")) {
        await _processYoutubePlaylist(url);
      } else if (url.contains("youtube.com/") || url.contains("youtu.be/")) {
        await _processYoutubeTrack(url);
      } else {
        print("[ShareHandler] Unsupported shared URL: $url");
      }
    } catch (e) {
      print("[ShareHandler] Error processing shared URL: $e");
      _showStatus("Error importing: $e");
    }
  }

  static void _showStatus(String message) {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<void> _processSpotifyPlaylist(String url) async {
    print("[ShareHandler] Processing Spotify Playlist: $url");
    _showStatus("Importing Spotify playlist...");

    final regExp = RegExp(r'playlist/([a-zA-Z0-9]+)');
    final match = regExp.firstMatch(url);
    if (match == null) {
      throw Exception("Invalid Spotify playlist URL");
    }
    final playlistIdStr = match.group(1)!;

    final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistIdStr';
    final response = await _dio.get(embedUrl);
    final html = response.data as String;

    final pattern = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', dotAll: true);
    final nextDataMatch = pattern.firstMatch(html);
    if (nextDataMatch == null) {
      throw Exception("Failed to extract playlist data from Spotify page");
    }

    final data = jsonDecode(nextDataMatch.group(1)!);
    final props = data['props'] as Map<String, dynamic>?;
    final pageProps = props?['pageProps'] as Map<String, dynamic>?;
    final stateData = pageProps?['state'] as Map<String, dynamic>?;
    final entityData = stateData?['data'] as Map<String, dynamic>?;
    final entity = entityData?['entity'] as Map<String, dynamic>?;
    if (entity == null) {
      throw Exception("This Spotify playlist could not be read. Please make sure the playlist is set to Public.");
    }

    final playlistName = entity['name'] as String? ?? 'Spotify Playlist';
    final sources = entity['coverArt']?['sources'] as List<dynamic>?;
    final artworkUrl = (sources != null && sources.isNotEmpty) ? sources.first['url'] as String? : null;

    final db = getIt<AppDatabase>();
    final dbPlaylistId = await db.createPlaylist(PlaylistsCompanion.insert(
      name: playlistName,
      artworkUrl: Value(artworkUrl),
      sourceUrl: Value(url),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    final List<PlaylistTracksCompanion> tracksToInsert = [];
    final trackList = entity['trackList'] as List<dynamic>? ?? [];

    for (var i = 0; i < trackList.length; i++) {
      final item = trackList[i];
      final title = item['title'] as String? ?? 'Unknown Track';
      final subtitle = item['subtitle'] as String? ?? 'Unknown Artist';
      final firstArtist = subtitle.split(',').first.trim();
      final durationMs = item['duration'] as int?;
      final durationSec = durationMs != null ? durationMs ~/ 1000 : null;

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
      await db.addTracksToPlaylist(tracksToInsert);
      _showStatus("Imported '$playlistName' (${tracksToInsert.length} tracks)");
      _enrichPlaylistInBackground(dbPlaylistId, preserveTitleArtist: true);
    } else {
      _showStatus("Imported empty playlist '$playlistName'");
    }
  }

  static Future<void> _processYoutubePlaylist(String url) async {
    print("[ShareHandler] Processing YouTube Playlist: $url");
    _showStatus("Importing YouTube playlist...");

    try {
      final cleanUrl = url.replaceAll('music.youtube.com', 'www.youtube.com');
      final response = await _dio.get(
        cleanUrl,
        options: Options(headers: {
          'Accept-Language': 'en-US,en;q=0.9',
        }),
      );
      final html = response.data as String;
      
      final pattern = RegExp(r'var ytInitialData\s*=\s*(\{.*?\});\s*</script>');
      final match = pattern.firstMatch(html);
      if (match == null) {
        throw Exception("Failed to extract YouTube playlist data");
      }
      
      final data = jsonDecode(match.group(1)!);
      
      String playlistTitle = 'YouTube Playlist';
      if (data['metadata'] != null && data['metadata']['playlistMetadataRenderer'] != null) {
        playlistTitle = data['metadata']['playlistMetadataRenderer']['title'] ?? 'YouTube Playlist';
      }
      
      String? playlistArtwork;
      try {
        final header = data['header']?['playlistHeaderRenderer'];
        if (header != null && header['heroImage'] != null) {
          final img = header['heroImage']['contentPreviewImageViewModel']?['image'];
          if (img != null && img['sources'] != null && (img['sources'] as List).isNotEmpty) {
            playlistArtwork = img['sources'].last['url'];
          }
        }
      } catch (_) {}

      final List<Map<String, dynamic>> parsedTracks = [];
      _findTracksInJson(data, parsedTracks);

      // Fetch all remaining pages via continuation tokens
      String? continuation = _extractContinuation(data);
      while (continuation != null) {
        final pageData = await _fetchYoutubeContinuationPage(continuation);
        if (pageData == null) break;
        _findTracksInJson(pageData, parsedTracks);
        continuation = _extractContinuation(pageData);
      }

      if (playlistArtwork == null && parsedTracks.isNotEmpty) {
        playlistArtwork = parsedTracks.first['artworkUrl'];
      }

      final db = getIt<AppDatabase>();
      final playlistId = await db.createPlaylist(PlaylistsCompanion.insert(
        name: playlistTitle,
        artworkUrl: Value(playlistArtwork),
        sourceUrl: Value(url),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      final List<PlaylistTracksCompanion> tracks = [];
      for (final t in parsedTracks) {
        tracks.add(PlaylistTracksCompanion.insert(
          playlistId: playlistId,
          title: t['title'] ?? 'Unknown Track',
          artist: t['artist'] ?? 'Unknown Artist',
          youtubeId: t['youtubeId'] ?? '',
          duration: const Value(null),
          artworkUrl: Value(t['artworkUrl']),
        ));
      }

      if (tracks.isNotEmpty) {
        await db.addTracksToPlaylist(tracks);
        _showStatus("Imported '$playlistTitle' (${tracks.length} tracks)");
        _enrichPlaylistInBackground(playlistId);
      } else {
        _showStatus("Imported empty playlist '$playlistTitle'");
      }
    } catch (e) {
      print("[ShareHandler] Error processing YouTube playlist: $e");
      _showStatus("Error importing: $e");
    }
  }

  static String? _extractContinuation(dynamic data) {
    if (data is! Map) return null;
    try {
      final items = data['contents']?['twoColumnBrowseResultsRenderer']
          ?['tabs']?[0]?['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents']?[0]
          ?['itemSectionRenderer']?['contents']?[0]
          ?['playlistVideoListRenderer']?['contents'] as List?;
      if (items == null) {
        final contItems = data['continuationContents']
            ?['playlistVideoListContinuation']?['contents'] as List?;
        if (contItems == null) return null;
        for (final item in contItems.reversed) {
          if (item is Map && item.containsKey('continuationItemRenderer')) {
            return item['continuationItemRenderer']
                ?['continuationEndpoint']?['continuationCommand']?['token'] as String?;
          }
        }
        return null;
      }
      for (final item in items.reversed) {
        if (item is Map && item.containsKey('continuationItemRenderer')) {
          return item['continuationItemRenderer']
              ?['continuationEndpoint']?['continuationCommand']?['token'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchYoutubeContinuationPage(String token) async {
    try {
      final client = io.HttpClient();
      try {
        final req = await client.postUrl(
          Uri.parse('https://www.youtube.com/youtubei/v1/browse?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc'),
        );
        req.headers.set('Content-Type', 'application/json');
        req.add(utf8.encode(jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20250331.10.00',
            },
          },
          'continuation': token,
        })));
        final resp = await req.close();
        if (resp.statusCode != 200) return null;
        final body = await resp.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  static void _findTracksInJson(dynamic node, List<Map<String, dynamic>> results) {
    if (node is Map) {
      if (node.containsKey('lockupViewModel')) {
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

  static Future<void> _enrichPlaylistInBackground(int playlistId, {bool preserveTitleArtist = false}) async {
    print('[ShareHandler] Starting background enrichment for playlist: $playlistId');
    try {
      final db = getIt<AppDatabase>();
      final tracks = await db.getPlaylistTracks(playlistId);
      final itunes = getIt<ItunesMetadataService>();

      for (final track in tracks) {
        try {
          final cleanTitle = track.title
              .replaceAll(RegExp(r'\[.*?\]'), '')
              .replaceAll(RegExp(r'\(.*?\)'), '')
              .replaceAll(RegExp(r'ft\..*'), '')
              .replaceAll(RegExp(r'feat\..*'), '')
              .trim();
          
          final results = await itunes.searchMeta('$cleanTitle ${track.artist}');
          if (results.isNotEmpty) {
            final best = results.first;
            await db.updatePlaylistTrack(PlaylistTracksCompanion(
              id: Value(track.id),
              title: preserveTitleArtist ? Value(track.title) : Value(best.trackName ?? track.title),
              artist: preserveTitleArtist ? Value(track.artist) : Value(best.artistName ?? track.artist),
              artworkUrl: Value(best.artworkUrlHigh ?? best.artworkUrlLow ?? track.artworkUrl),
              album: Value(best.album),
              genre: Value(best.genre),
            ));
          }
        } catch (e) {
          print('[ShareHandler] Enrichment failed for track ${track.id}: $e');
        }
      }
      print('[ShareHandler] Background enrichment completed for playlist: $playlistId');
    } catch (e) {
      print('[ShareHandler] Background enrichment error: $e');
    }
  }

  static Future<void> _processSpotifyTrack(String url) async {
    print("[ShareHandler] Processing Spotify Track: $url");
    
    final trackIdRegExp = RegExp(r'track/([a-zA-Z0-9]+)');
    final match = trackIdRegExp.firstMatch(url);
    if (match == null) {
      throw Exception("Invalid Spotify track URL");
    }
    final trackId = match.group(1)!;
    
    final embedUrl = 'https://open.spotify.com/embed/track/$trackId';
    final response = await _dio.get(embedUrl);
    final html = response.data as String;
    
    final pattern = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', dotAll: true);
    final nextDataMatch = pattern.firstMatch(html);
    if (nextDataMatch == null) {
      throw Exception("Failed to parse Spotify embed page");
    }
    
    final data = jsonDecode(nextDataMatch.group(1)!);
    final props = data['props'] as Map<String, dynamic>?;
    final pageProps = props?['pageProps'] as Map<String, dynamic>?;
    final state = pageProps?['state'] as Map<String, dynamic>?;
    final stateData = state?['data'] as Map<String, dynamic>?;
    final entity = stateData?['entity'] as Map<String, dynamic>?;
    if (entity == null) {
      throw Exception("Failed to resolve Spotify track details");
    }
    
    final title = entity['name'] as String? ?? 'Unknown Track';
    final artistsList = entity['artists'] as List<dynamic>? ?? [];
    final artist = artistsList.map((a) => a['name'] as String).join(', ');
    final durationMs = entity['duration'] as int?;
    final images = entity['image'] as List<dynamic>? ?? [];
    final artworkUrl = images.isNotEmpty ? images.last['url'] as String? : '';

    print("[ShareHandler] Resolved Spotify Track: $title - $artist");
    await _playLazySong(title, artist, artworkUrl, durationMs);
  }

  static Future<void> _processYoutubeTrack(String url) async {
    print("[ShareHandler] Processing YouTube Track: $url");
    
    final encodedUrl = Uri.encodeComponent(url);
    final oembedUrl = 'https://www.youtube.com/oembed?url=$encodedUrl&format=json';
    final response = await _dio.get(oembedUrl);
    
    if (response.data == null) {
      throw Exception("Failed to load YouTube oEmbed");
    }
    
    final data = response.data as Map<String, dynamic>;
    final rawTitle = data['title'] as String? ?? 'Unknown';
    final authorName = data['author_name'] as String? ?? 'Unknown Artist';
    final artworkUrl = data['thumbnail_url'] as String? ?? '';
    
    // Parse/Clean author
    String artist = authorName.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '').trim();
    String title = rawTitle;
    
    // Attempt to split title if in "Artist - Track" or "Artist - Track (Official ...)" format
    final splitIndex = title.indexOf(" - ");
    if (splitIndex != -1) {
      final part1 = title.substring(0, splitIndex).trim();
      final part2 = title.substring(splitIndex + 3).trim();
      
      // Usually, part1 is artist, part2 is track name
      artist = part1;
      title = part2;
    }
    
    // Clean brackets and extra tags from title/artist
    title = _cleanString(title);
    artist = _cleanString(artist);
    
    print("[ShareHandler] Resolved YouTube Track: $title - $artist");
    await _playLazySong(title, artist, artworkUrl, null);
  }

  static String _cleanString(String val) {
    return val
        .replaceAll(RegExp(r'\(.*?Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Audio.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?Audio.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?Video.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?Lyric.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<void> _playLazySong(String title, String artist, String? artworkUrl, int? durationMs) async {
    final lazyId = 'https://lazy.flac.internal/?title=${Uri.encodeComponent(title)}&artist=${Uri.encodeComponent(artist)}';
    
    final item = MediaItem(
      id: lazyId,
      title: title,
      artist: artist,
      artUri: (artworkUrl != null && artworkUrl.isNotEmpty) ? Uri.parse(artworkUrl) : null,
      duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      extras: {
        'source': 'Shared Link',
        'linkType': 'flac', // Trigger internal resolution
        'torrentId': -1,
        'fileId': -lazyId.hashCode.abs(),
      },
    );
    
    print("[ShareHandler] Requesting playback for lazy media item: ${item.title}");
    await audioHandler.playMediaItem(item);
  }
}
