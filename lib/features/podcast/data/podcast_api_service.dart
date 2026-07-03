import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'package:injectable/injectable.dart';
import 'podcast_models.dart';

@lazySingleton
class PodcastApiService {
  final Dio _dio;
  static final _resolvedCache = <String, String>{};

  PodcastApiService() : _dio = Dio(BaseOptions(
    headers: {'User-Agent': 'Isai-Podcast/1.0'},
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const _itunesSearch = 'https://itunes.apple.com/search';
  static const _itunesLookup = 'https://itunes.apple.com/lookup';
  static const _rssFeed = 'https://rss.applemarketingtools.com/api/v2/us/podcasts';

  Map<String, dynamic>? _decodeJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  List<Map<String, dynamic>> _extractResults(Map<String, dynamic> json) {
    final results = json['results'];
    if (results is List) return results.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<List<PodcastSeries>> searchPodcasts(String term, {int limit = 20}) async {
    try {
      final res = await _dio.get(_itunesSearch, queryParameters: {
        'term': term, 'media': 'podcast', 'limit': limit, 'country': 'us',
      });
      final json = _decodeJson(res.data);
      if (json == null) return [];
      return _extractResults(json)
          .map((j) => PodcastSeries.fromItunes(j))
          .toList();
    } catch (e) {
      print('[PodcastApi] search error: $e');
      return [];
    }
  }

  Future<PodcastSeries?> lookupPodcast(int collectionId) async {
    try {
      final res = await _dio.get(_itunesLookup, queryParameters: {'id': collectionId, 'country': 'us'});
      final json = _decodeJson(res.data);
      if (json == null) return null;
      final first = _extractResults(json).firstOrNull;
      if (first == null) return null;
      return PodcastSeries.fromItunes(first);
    } catch (e) {
      print('[PodcastApi] lookup error: $e');
      return null;
    }
  }

  Future<List<PodcastEpisode>> fetchEpisodes(String feedUrl) async {
    try {
      final res = await _dio.get<String>(feedUrl);
      final raw = res.data;
      if (raw == null) return [];
      final xml = XmlDocument.parse(raw);
      final channel = xml.findAllElements('channel').firstOrNull;
      if (channel == null) return [];

      final collectionName = channel.findElements('title').firstOrNull?.text ?? '';
      final artwork = _artworkFromChannel(channel);

      return channel.findElements('item').map((item) {
        final enclosure = item.findElements('enclosure').firstOrNull;
        final audioUrl = enclosure?.getAttribute('url') ?? '';
        final duration = _parseDuration(item);
        final desc = item.findElements('description').firstOrNull?.text ?? '';
        final description = _stripHtml(desc);
        return PodcastEpisode(
          id: audioUrl.isNotEmpty ? audioUrl : item.findElements('guid').firstOrNull?.text ?? '',
          title: item.findElements('title').firstOrNull?.text ?? '',
          description: description.isNotEmpty ? description : null,
          audioUrl: audioUrl.isNotEmpty ? audioUrl : null,
          durationSec: duration,
          pubDate: item.findElements('pubDate').firstOrNull?.text,
          artworkUrl: _episodeArtwork(item) ?? artwork,
          feedUrl: feedUrl,
          collectionName: collectionName,
        );
      }).toList();
    } catch (e) {
      print('[PodcastApi] RSS parse error for $feedUrl: $e');
      return [];
    }
  }

  PodcastSeries _fromRssResult(Map<String, dynamic> json) {
    final idStr = json['id'] as String? ?? '0';
    final artwork100 = json['artworkUrl100'] as String?;
    return PodcastSeries(
      collectionId: int.tryParse(idStr) ?? 0,
      collectionName: json['name'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      feedUrl: null,
      artworkUrl: artwork100?.replaceAll('100x100', '600x600'),
      primaryGenre: _extractGenre(json),
      trackCount: null,
      releaseDate: json['releaseDate'] as String?,
    );
  }

  String? _extractGenre(Map<String, dynamic> json) {
    final genres = json['genres'];
    if (genres is List && genres.isNotEmpty) {
      if (genres.first is Map<String, dynamic>) {
        return (genres.first as Map<String, dynamic>)['name'] as String?;
      }
      return genres.first.toString();
    }
    return null;
  }

  Future<List<PodcastSeries>> trending({int limit = 20}) async {
    try {
      final res = await _dio.get('$_rssFeed/top/$limit/podcasts.json');
      final json = _decodeJson(res.data);
      final feed = json?['feed'] as Map<String, dynamic>?;
      if (feed == null) return [];
      final results = feed['results'] as List? ?? [];
      return results
          .whereType<Map<String, dynamic>>()
          .map((j) => _fromRssResult(j))
          .toList();
    } catch (e) {
      print('[PodcastApi] trending error: $e');
      return [];
    }
  }

  Future<List<PodcastSeries>> recent({int limit = 20}) async {
    try {
      final res = await _dio.get('$_rssFeed/top/$limit/podcasts.json');
      final json = _decodeJson(res.data);
      final feed = json?['feed'] as Map<String, dynamic>?;
      if (feed == null) return [];
      final results = feed['results'] as List? ?? [];
      final all = results
          .whereType<Map<String, dynamic>>()
          .map((j) => _fromRssResult(j))
          .toList();
      all.sort((a, b) {
        if (a.releaseDate == null && b.releaseDate == null) return 0;
        if (a.releaseDate == null) return 1;
        if (b.releaseDate == null) return -1;
        return b.releaseDate!.compareTo(a.releaseDate!);
      });
      return all;
    } catch (e) {
      print('[PodcastApi] recent error: $e');
      return [];
    }
  }

  Future<List<PodcastSeries>> byGenre(String genre, {int limit = 20}) async {
    try {
      final res = await _dio.get(_itunesSearch, queryParameters: {
        'term': genre, 'media': 'podcast', 'limit': limit, 'country': 'us',
      });
      final json = _decodeJson(res.data);
      if (json == null) return [];
      return _extractResults(json)
          .map((j) => PodcastSeries.fromItunes(j))
          .toList();
    } catch (e) {
      print('[PodcastApi] byGenre error: $e');
      return [];
    }
  }

  static final List<String> genres = [
    'Comedy', 'Technology', 'Science', 'News', 'Music',
    'History', 'True Crime', 'Business', 'Health', 'Education',
    'Sports', 'TV & Film', 'Religion', 'Society', 'Arts',
  ];

  String? _artworkFromChannel(XmlElement channel) {
    final itunes = channel.findElements('{http://www.itunes.com/dtds/podcast-1.0.dtd}image').firstOrNull;
    if (itunes != null) return itunes.getAttribute('href');
    return channel.findElements('image').firstOrNull
        ?.findElements('url').firstOrNull?.text;
  }

  String? _episodeArtwork(XmlElement item) {
    final itunes = item.findElements('{http://www.itunes.com/dtds/podcast-1.0.dtd}image').firstOrNull;
    if (itunes != null) return itunes.getAttribute('href');
    return null;
  }

  int? _parseDuration(XmlElement item) {
    for (final tag in ['duration', '{http://www.itunes.com/dtds/podcast-1.0.dtd}duration']) {
      final el = item.findElements(tag).firstOrNull;
      if (el == null) continue;
      final text = el.text.trim();
      final num = int.tryParse(text);
      if (num != null) return num;
      final parts = text.split(':');
      if (parts.length == 3) {
        return int.tryParse(parts[0])! * 3600 +
            int.tryParse(parts[1])! * 60 +
            int.tryParse(parts[2])!;
      }
      if (parts.length == 2) {
        return int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
      }
    }
    return null;
  }

  Future<String?> fetchDescription(String feedUrl) async {
    try {
      final res = await _dio.get<String>(feedUrl);
      final raw = res.data;
      if (raw == null) return null;
      final xml = XmlDocument.parse(raw);
      final channel = xml.findAllElements('channel').firstOrNull;
      if (channel == null) return null;
      final itunesSummary = channel
          .findElements('{http://www.itunes.com/dtds/podcast-1.0.dtd}summary')
          .firstOrNull?.text;
      if (itunesSummary != null && itunesSummary.isNotEmpty) return _stripHtml(itunesSummary);
      final description = channel.findElements('description').firstOrNull?.text;
      if (description != null && description.isNotEmpty) return _stripHtml(description);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String> resolveAudioUrl(String url) async {
    final cached = _resolvedCache[url];
    if (cached != null) return cached;
    if (url.endsWith('.mp3') || url.endsWith('.m4a') ||
        url.endsWith('.mp4') || url.endsWith('.ogg') ||
        url.endsWith('.wav') || url.endsWith('.aac')) {
      _resolvedCache[url] = url;
      return url;
    }
    try {
      final client = HttpClient();
      client.autoUncompress = false;
      client.connectionTimeout = const Duration(seconds: 2);
      var currentUrl = url;
      for (var i = 0; i < 5; i++) {
        final request = await client.getUrl(Uri.parse(currentUrl));
        request.followRedirects = false;
        final response = await request.close().timeout(const Duration(seconds: 2));
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value('location');
          if (location == null) break;
          currentUrl = Uri.parse(currentUrl).resolve(location).toString();
          await response.drain();
        } else {
          await response.drain();
          break;
        }
      }
      client.close(force: true);
      _resolvedCache[url] = currentUrl;
      return currentUrl;
    } catch (_) {
      _resolvedCache[url] = url;
      return url;
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
