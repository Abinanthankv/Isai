import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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
      if (url.contains("spotify.com/track/")) {
        await _processSpotifyTrack(url);
      } else if (url.contains("youtube.com/") || url.contains("youtu.be/")) {
        await _processYoutubeTrack(url);
      } else {
        print("[ShareHandler] Unsupported shared URL: $url");
      }
    } catch (e) {
      print("[ShareHandler] Error processing shared URL: $e");
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
        'linkType': 'flac', // Triggers internal resolution
        'torrentId': -1,
        'fileId': -lazyId.hashCode.abs(),
      },
    );
    
    print("[ShareHandler] Requesting playback for lazy media item: ${item.title}");
    await audioHandler.playMediaItem(item);
  }
}
