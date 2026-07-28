import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'podcast_models.dart';

class PodcastApiService {
  final Dio _dio;
  static final _resolvedCache = <String, _ResolvedUrl>{};

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

      final ns = 'https://podcastindex.org/namespace/1.0';
      return channel.findElements('item').map((item) {
        final enclosure = item.findElements('enclosure').firstOrNull;
        final audioUrl = enclosure?.getAttribute('url') ?? '';
        final guid = item.findElements('guid').firstOrNull?.text;
        final duration = _parseDuration(item);
        final desc = item.findElements('description').firstOrNull?.text ?? '';
        final description = _stripHtml(desc);
        final chaptersEl = item.childElements.where((e) =>
            e.name.local == 'chapters' && e.name.namespaceUri == ns).firstOrNull ?? 
            item.findElements('chapters').firstOrNull;
        final chaptersUrl = chaptersEl?.getAttribute('url');
        return PodcastEpisode(
          id: audioUrl.isNotEmpty ? audioUrl : guid ?? '',
          title: item.findElements('title').firstOrNull?.text ?? '',
          description: description.isNotEmpty ? description : null,
          audioUrl: audioUrl.isNotEmpty ? audioUrl : null,
          durationSec: duration,
          pubDate: item.findElements('pubDate').firstOrNull?.text,
          artworkUrl: _episodeArtwork(item) ?? artwork,
          feedUrl: feedUrl,
          collectionName: collectionName,
          chaptersUrl: chaptersUrl,
          guid: guid,
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

  Future<List<PodcastSeries>> byGenre(String genre, {int limit = 20, int offset = 0}) async {
    try {
      final res = await _dio.get(_itunesSearch, queryParameters: {
        'term': genre, 'media': 'podcast', 'limit': limit, 'country': 'us', 'offset': offset,
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

  Future<List<SpotifyChartItem>> spotifyTopPodcasts(String region, {int limit = 50}) async {
    try {
      final res = await _dio.get(
        'https://podcastcharts.byspotify.com/api/charts/top-podcasts',
        queryParameters: {'region': region, 'limit': limit},
      );
      final data = res.data;
      if (data is List) {
        return data.map((e) => SpotifyChartItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('[PodcastApi] spotifyTopPodcasts error: $e');
      return [];
    }
  }

  Future<List<SpotifyChartItem>> spotifyTopEpisodes(String region, {int limit = 50}) async {
    try {
      final res = await _dio.get(
        'https://podcastcharts.byspotify.com/api/charts/top-episodes',
        queryParameters: {'region': region, 'limit': limit},
      );
      final data = res.data;
      if (data is List) {
        return data.map((e) => SpotifyChartItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('[PodcastApi] spotifyTopEpisodes error: $e');
      return [];
    }
  }

  static final List<String> genres = [
    'Comedy', 'Technology', 'Science', 'News', 'Music',
    'History', 'True Crime', 'Business', 'Health', 'Education',
    'Sports', 'TV & Film', 'Religion', 'Society', 'Arts',
  ];

  String? _artworkFromChannel(XmlElement channel) {
    final nsUri = 'http://www.itunes.com/dtds/podcast-1.0.dtd';
    final itunes = channel.childElements.where((e) =>
        e.name.local == 'image' && e.name.namespaceUri == nsUri).firstOrNull;
    if (itunes != null) return itunes.getAttribute('href');
    return channel.findElements('image').firstOrNull
        ?.findElements('url').firstOrNull?.text;
  }

  String? _episodeArtwork(XmlElement item) {
    final nsUri = 'http://www.itunes.com/dtds/podcast-1.0.dtd';
    final itunes = item.childElements.where((e) =>
        e.name.local == 'image' && e.name.namespaceUri == nsUri).firstOrNull;
    if (itunes != null) {
      final href = itunes.getAttribute('href');
      return href;
    }
    return null;
  }

  int? _parseDuration(XmlElement item) {
    final nsUri = 'http://www.itunes.com/dtds/podcast-1.0.dtd';
    for (final tag in ['duration', '$nsUri']) {
      final el = tag == nsUri
          ? item.childElements.where((e) =>
              e.name.local == 'duration' && e.name.namespaceUri == nsUri).firstOrNull
          : item.findElements(tag).firstOrNull;
      if (el == null) continue;
      final text = el.text.trim();
      final num = int.tryParse(text);
      if (num != null && num > 0) return num;
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
      final nsUri = 'http://www.itunes.com/dtds/podcast-1.0.dtd';
      final itunesSummary = channel.childElements.where((e) =>
          e.name.local == 'summary' && e.name.namespaceUri == nsUri)
          .firstOrNull?.text;
      if (itunesSummary != null && itunesSummary.isNotEmpty) return _stripHtml(itunesSummary);
      final description = channel.findElements('description').firstOrNull?.text;
      if (description != null && description.isNotEmpty) return _stripHtml(description);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<PodcastSeries?> fetchSeriesFromFeed(String feedUrl) async {
    try {
      final res = await _dio.get<String>(feedUrl);
      final raw = res.data;
      if (raw == null) return null;
      final xml = XmlDocument.parse(raw);
      final channel = xml.findAllElements('channel').firstOrNull;
      if (channel == null) return null;
      final title = channel.findElements('title').firstOrNull?.text ?? '';
      final artwork = _artworkFromChannel(channel);
      final itunesNs = 'http://www.itunes.com/dtds/podcast-1.0.dtd';
      final author = channel.findElements('author').firstOrNull?.text ??
          channel.childElements
              .where((e) => e.name.local == 'author' && e.name.namespaceUri == itunesNs)
              .firstOrNull?.text ?? '';
      return PodcastSeries(
        collectionId: feedUrl.hashCode,
        collectionName: title,
        artistName: author,
        feedUrl: feedUrl,
        artworkUrl: artwork,
      );
    } catch (e) {
      print('[PodcastApi] fetchSeriesFromFeed error: $e');
      return null;
    }
  }

  static Future<List<PodcastChapter>> fetchChapters(String chaptersUrl) async {
    try {
      final res = await Dio().get<Map<String, dynamic>>(
        chaptersUrl,
        options: Options(
          headers: {'User-Agent': 'Isai-Podcast/1.0'},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = res.data;
      if (data == null) return [];
      final rawChapters = data['chapters'];
      if (rawChapters is! List) return [];
      return rawChapters.whereType<Map<String, dynamic>>().map((ch) {
        final startSec = (ch['startTime'] as num?)?.toDouble() ?? 0;
        final endSec = (ch['endTime'] as num?)?.toDouble() ?? 0;
        return PodcastChapter(
          title: ch['title'] as String? ?? '',
          startTimeMs: (startSec * 1000).toInt(),
          endTimeMs: (endSec * 1000).toInt(),
          number: ch['number'] as int?,
        );
      }).toList();
    } catch (e) {
      print('[PodcastApi] fetchChapters error: $e');
      return [];
    }
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  static Future<String> resolveAudioUrl(String url) async {
    final cached = _resolvedCache[url];
    if (cached != null && !cached.isExpired) return cached.url;
    try {
      final client = HttpClient();
      client.autoUncompress = false;
      client.connectionTimeout = const Duration(seconds: 5);
      var currentUrl = url;
      int? finalStatus;
      for (var i = 0; i < 5; i++) {
        final request = await client.getUrl(Uri.parse(currentUrl));
        request.followRedirects = false;
        final response = await request.close().timeout(const Duration(seconds: 5));
        finalStatus = response.statusCode;
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
      if (finalStatus != null && finalStatus >= 200 && finalStatus < 400) {
        _resolvedCache[url] = _ResolvedUrl(currentUrl);
      } else if (finalStatus != null && finalStatus == 403) {
        final stallUrl = currentUrl;
        _resolvedCache[url] = _ResolvedUrl(stallUrl);
        return stallUrl;
      }
      return currentUrl;
    } catch (_) {
      _resolvedCache[url] = _ResolvedUrl(url);
      return url;
    }
  }
}

class _ResolvedUrl {
  final String url;
  final DateTime cachedAt;
  static const _ttl = Duration(hours: 1);

  _ResolvedUrl(this.url) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > _ttl;
}
