import 'dart:async';
import 'dart:convert';
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
        _handleSharedText(value.first.path);
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

    final yt = YoutubeExplode();
    try {
      final playlist = await yt.playlists.get(url);
      
      final db = getIt<AppDatabase>();
      final playlistId = await db.createPlaylist(PlaylistsCompanion.insert(
        name: playlist.title,
        artworkUrl: Value(playlist.thumbnails.highResUrl),
        sourceUrl: Value(url),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      final List<PlaylistTracksCompanion> tracks = [];
      await for (final video in yt.playlists.getVideos(playlist.id)) {
        tracks.add(PlaylistTracksCompanion.insert(
          playlistId: playlistId,
          title: video.title,
          artist: video.author,
          youtubeId: video.id.value,
          duration: Value(video.duration?.inSeconds),
          artworkUrl: Value(video.thumbnails.mediumResUrl),
        ));
      }

      if (tracks.isNotEmpty) {
        await db.addTracksToPlaylist(tracks);
        _showStatus("Imported '${playlist.title}' (${tracks.length} tracks)");
        _enrichPlaylistInBackground(playlistId);
      } else {
        _showStatus("Imported empty playlist '${playlist.title}'");
      }
    } finally {
      yt.close();
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
