import 'dart:convert';
import 'dart:io' as io;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_models.dart';

class YoutubeVideoService {
  final _yt = YoutubeExplode();

  static const _innertubeKey = 'AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc';
  static const _endpoint = 'https://www.youtube.com/youtubei/v1';

  static const _androidContext = {
    'clientName': 'ANDROID',
    'clientVersion': '20.10.38',
    'androidSdkVersion': 34,
    'hl': 'en',
    'gl': 'US',
    'osName': 'Android',
    'osVersion': '14',
    'userAgent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
    'timeZone': 'UTC',
    'utcOffsetMinutes': 0,
  };

  static const _androidVrContext = {
    'clientName': 'ANDROID_VR',
    'clientVersion': '20.9.3',
    'androidSdkVersion': 34,
    'hl': 'en',
    'gl': 'US',
    'osName': 'Android',
    'osVersion': '14',
    'userAgent': 'com.google.android.youtube/20.9.3 (Linux; U; Android 14; VR) gzip',
    'timeZone': 'UTC',
    'utcOffsetMinutes': 0,
  };

  static const _iosContext = {
    'clientName': 'IOS',
    'clientVersion': '20.10.4',
    'hl': 'en',
    'gl': 'US',
    'osName': 'iOS',
    'osVersion': '18.0',
    'userAgent': 'com.google.ios.youtube/20.10.4 (iPhone; U; iOS 18.0; en_US)',
    'timeZone': 'UTC',
    'utcOffsetMinutes': 0,
  };

  static const _webContext = {
    'clientName': 'WEB',
    'clientVersion': '2.20250331.10.00',
    'hl': 'en',
    'gl': 'US',
    'osName': 'Windows',
    'osVersion': '10.0',
    'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'timeZone': 'UTC',
    'utcOffsetMinutes': 0,
  };

  int? _signatureTimestamp;

  Future<int> _fetchSignatureTimestamp() async {
    if (_signatureTimestamp != null) return _signatureTimestamp!;
    try {
      final client = io.HttpClient();
      final req = await client.getUrl(Uri.parse('https://www.youtube.com'));
      final resp = await req.close();
      final html = await resp.transform(utf8.decoder).join();
      client.close();
      final match = RegExp(r'ytcfg\.set\s*\(\s*\{[^}]*"signatureTimestamp"\s*:\s*(\d+)').firstMatch(html);
      if (match != null) {
        _signatureTimestamp = int.parse(match.group(1)!);
        print('[YoutubeVideoService] signatureTimestamp: $_signatureTimestamp');
        return _signatureTimestamp!;
      }
    } catch (_) {}
    _signatureTimestamp = 19860;
    return _signatureTimestamp!;
  }

  Future<List<YoutubeSearchResult>> search(String query) async {
    try {
      final body = jsonEncode({
        'context': {'client': {..._androidContext}},
        'query': query,
      });

      final data = await _innertubeRequest('search', body);
      if (data == null) return [];

      final results = <YoutubeSearchResult>[];

      List<dynamic>? sections;
      final tc = data['contents'];
      if (tc is Map) {
        sections = tc['twoColumnSearchResultsRenderer']
            ?['primaryContents']?['sectionListRenderer']?['contents']
            as List<dynamic>?;
        sections ??= tc['sectionListRenderer']?['contents'] as List<dynamic>?;
      }
      if (sections == null) return [];

      for (final section in sections) {
        final itemRenderer = section['itemSectionRenderer'] as Map?;
        if (itemRenderer == null) continue;
        final items = itemRenderer['contents'] as List<dynamic>?;
        if (items == null) continue;

        for (final item in items) {
          final vr = (item['videoRenderer'] ?? item['compactVideoRenderer']) as Map<String, dynamic>?;
          if (vr == null) continue;

          final id = vr['videoId'] as String?;
          final title = vr['title']?['runs']?[0]?['text'] as String?
              ?? vr['title']?['simpleText'] as String?;
          final author = vr['ownerText']?['runs']?[0]?['text'] as String?
              ?? vr['longBylineText']?['runs']?[0]?['text'] as String?
              ?? vr['shortBylineText']?['runs']?[0]?['text'] as String?;
          final channelId = vr['ownerText']?['runs']?[0]?['navigationEndpoint']
              ?['browseEndpoint']?['browseId'] as String?;
          final lengthStr = vr['lengthText']?['simpleText'] as String?
              ?? vr['lengthText']?['runs']?[0]?['text'] as String?;
          final thumb = vr['thumbnail']?['thumbnails']?[0]?['url'] as String?;

          if (id == null || title == null) continue;

          int secs = 0;
          if (lengthStr != null) {
            final parts = lengthStr.split(':').map((e) => int.tryParse(e) ?? 0).toList();
            secs = parts.length == 3
                ? parts[0] * 3600 + parts[1] * 60 + parts[2]
                : parts.length == 2
                    ? parts[0] * 60 + parts[1]
                    : parts[0];
          }

          results.add(YoutubeSearchResult(
            id: id,
            title: title,
            author: author ?? '',
            channelId: channelId ?? '',
            durationSeconds: secs,
            thumbnailUrl: thumb,
          ));
        }
      }

      return results;
    } catch (e) {
      print('[YoutubeVideoService] search error: $e');
      return [];
    }
  }

  Future<YoutubeVideoInfo?> getVideoInfo(String videoId, {bool preferLibrary = true}) async {
    try {
      final cleanId = videoId.replaceAll(RegExp(r'^https?://.*[?&]v='), '');

      // 1. Proactively run the fast InnerTube request to get metadata
      final innerTubeInfo = await _getVideoInfoInnerTube(cleanId);

      print('[YoutubeVideoService] loading deciphered streams via library for $cleanId');

      // 2. Fall back to library to resolve deciphered streams using our pre-fetched metadata
      return await _getVideoInfoLibrary(cleanId, partialInfo: innerTubeInfo);
    } catch (e) {
      print('[YoutubeVideoService] getVideoInfo error: $e');
      return null;
    }
  }

  Future<YoutubeVideoInfo?> _getVideoInfoInnerTube(String videoId) async {
    final clients = [
      ('ANDROID', _androidContext),
      ('ANDROID_VR', _androidVrContext),
      ('IOS', _iosContext),
      ('WEB', _webContext),
    ];

    YoutubeVideoInfo? candidateInfo;

    for (final (name, client) in clients) {
      try {
        final ts = await _fetchSignatureTimestamp();
        final body = jsonEncode({
          'videoId': videoId,
          'context': {'client': client},
          'contentCheckOk': true,
          'racyCheckOk': true,
          'playbackContext': {
            'contentPlaybackContext': {
              'signatureTimestamp': ts,
              'html5Preference': 'HTML5_PREF_WANTS',
            },
          },
        });

        final data = await _innertubeRequest('player', body);
        if (data == null) continue;

        final playability = data['playabilityStatus'] as Map?;
        if (playability == null) continue;

        final status = playability['status'] as String?;
        if (status == null || status != 'OK') {
          final reason = playability['reason'] as String?;
          final sub = playability['errorScreen'];
          String? subText;
          if (sub is Map) {
            subText = (sub['reason'] as Map?)?['simpleText'] as String?;
          }
          print('[YoutubeVideoService] $name playability: $status $reason${subText != null ? " ($subText)" : ""}');
          continue;
        }

        final streamingData = data['streamingData'] as Map?;
        final videoDetails = data['videoDetails'] as Map?;
        if (streamingData == null) {
          print('[YoutubeVideoService] $name: no streamingData');
          continue;
        }

        final info = _parseVideoDetails(videoDetails, videoId);
        final (videos, audios) = _parseStreamingData(streamingData);

        if (videos.isNotEmpty || audios.isNotEmpty) {
          return YoutubeVideoInfo(
            id: videoId,
            title: info?.title ?? 'Unknown',
            author: info?.author ?? '',
            channelId: info?.channelId ?? '',
            durationSeconds: info?.durationSeconds ?? 0,
            description: info?.description ?? '',
            thumbnailUrl: info?.thumbnailUrl,
            videoStreams: videos,
            audioStreams: audios,
            clientUserAgent: client['userAgent'] as String?,
          );
        }

        // If no streams are playable directly but playability is OK, store metadata candidate
        if (info != null) {
          candidateInfo ??= YoutubeVideoInfo(
            id: videoId,
            title: info.title,
            author: info.author,
            channelId: info.channelId,
            durationSeconds: info.durationSeconds,
            description: info.description,
            thumbnailUrl: info.thumbnailUrl,
            videoStreams: const [],
            audioStreams: const [],
            clientUserAgent: client['userAgent'] as String?,
          );
        }
      } catch (e) {
        print('[YoutubeVideoService] $name error: $e');
      }
    }
    return candidateInfo;
  }

  Future<YoutubeVideoInfo?> _getVideoInfoLibrary(String videoId, {YoutubeVideoInfo? partialInfo}) async {
    try {
      final Video? video = partialInfo == null ? await _yt.videos.get(videoId) : null;

      final title = partialInfo?.title ?? video?.title ?? 'Unknown';
      final author = partialInfo?.author ?? video?.author ?? '';
      final channelId = partialInfo?.channelId ?? video?.channelId.value ?? '';
      final durationSeconds = partialInfo?.durationSeconds ?? video?.duration?.inSeconds ?? 0;
      final description = partialInfo?.description ?? video?.description ?? '';
      final thumbnailUrl = partialInfo?.thumbnailUrl ?? video?.thumbnails.highResUrl;

      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
      );

      final videoStreams = <YoutubeStreamInfo>[];
      final audioStreams = <YoutubeStreamInfo>[];

      if (manifest != null) {
        final seenVideoUrls = <String>{};
        for (final s in manifest.videoOnly) {
          final url = s.url.toString();
          if (seenVideoUrls.contains(url)) continue;
          seenVideoUrls.add(url);
          videoStreams.add(YoutubeStreamInfo(
            url: url,
            qualityLabel: s.videoQualityLabel,
            width: s.videoResolution.width,
            height: s.videoResolution.height,
            bitrate: s.bitrate.bitsPerSecond,
            contentLength: s.size.totalBytes,
            mimeType: s.codec.mimeType,
            container: s.container.name,
            codec: s.videoCodec,
            isVideo: true,
            rawStreamInfo: s,
          ));
        }

        final seenAudioUrls = <String>{};
        for (final s in manifest.audioOnly) {
          final url = s.url.toString();
          if (seenAudioUrls.contains(url)) continue;
          seenAudioUrls.add(url);
          audioStreams.add(YoutubeStreamInfo(
            url: url,
            qualityLabel: s.bitrate.toString(),
            width: 0,
            height: 0,
            bitrate: s.bitrate.bitsPerSecond,
            contentLength: s.size.totalBytes,
            mimeType: s.codec.mimeType,
            container: s.container.name,
            codec: s.codec.mimeType,
            isAudio: true,
            rawStreamInfo: s,
          ));
        }
      }

      videoStreams.sort((a, b) => b.height.compareTo(a.height));
      audioStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));

      return YoutubeVideoInfo(
        id: videoId,
        title: title,
        author: author,
        channelId: channelId,
        durationSeconds: durationSeconds,
        description: description,
        thumbnailUrl: thumbnailUrl,
        videoStreams: videoStreams,
        audioStreams: audioStreams,
      );
    } catch (e) {
      print('[YoutubeVideoService] library fallback error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _innertubeRequest(String endpoint, String body) async {
    final client = io.HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('$_endpoint/$endpoint?key=$_innertubeKey'),
      );
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(body));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final respBody = await resp.transform(utf8.decoder).join();
      return jsonDecode(respBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  (List<YoutubeStreamInfo>, List<YoutubeStreamInfo>) _parseStreamingData(Map streamingData) {
    final videos = <YoutubeStreamInfo>[];
    final audios = <YoutubeStreamInfo>[];
    final seenUrls = <String>{};

    void processFormat(Map fmt, bool isAdaptive) {
      final url = fmt['url'] as String?;
      if (url == null || !seenUrls.add(url)) return;

      final mimeType = fmt['mimeType'] as String? ?? '';
      final (container, codec) = _parseMimeType(mimeType);
      final itag = fmt['itag'] as int? ?? 0;
      final isVideo = mimeType.contains('video/');
      final isAudio = mimeType.contains('audio/');
      final qualityLabel = fmt['qualityLabel'] as String? ?? _itagLabel(itag, container);

      final info = YoutubeStreamInfo(
        url: url,
        qualityLabel: qualityLabel,
        width: (fmt['width'] as num?)?.toInt() ?? 0,
        height: (fmt['height'] as num?)?.toInt() ?? 0,
        bitrate: (fmt['bitrate'] as num?)?.toInt() ?? 0,
        contentLength: int.tryParse(fmt['contentLength']?.toString() ?? '') ?? 0,
        mimeType: mimeType,
        container: container,
        codec: codec,
        isVideo: isVideo,
        isAudio: isAudio,
      );

      if (isVideo) videos.add(info);
      if (isAudio) audios.add(info);
    }

    final formats = streamingData['formats'] as List?;
    if (formats != null) {
      for (final f in formats) {
        processFormat(f as Map, false);
      }
    }

    final adaptiveFormats = streamingData['adaptiveFormats'] as List?;
    if (adaptiveFormats != null) {
      for (final f in adaptiveFormats) {
        processFormat(f as Map, true);
      }
    }

    videos.sort((a, b) => b.height.compareTo(a.height));
    audios.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return (videos, audios);
  }

  YoutubeVideoInfo? _parseVideoDetails(Map? details, String videoId) {
    if (details == null) return null;
    try {
      final thumbs = details['thumbnail']?['thumbnails'] as List?;
      String? thumbUrl;
      if (thumbs != null && thumbs.isNotEmpty) {
        thumbUrl = (thumbs.last as Map)['url'] as String?;
      }
      return YoutubeVideoInfo(
        id: videoId,
        title: details['title'] as String? ?? '',
        author: details['author'] as String? ?? details['ownerChannelName'] as String? ?? '',
        channelId: details['channelId'] as String? ?? '',
        durationSeconds: int.tryParse(details['lengthSeconds']?.toString() ?? '') ?? 0,
        description: details['shortDescription'] as String? ?? '',
        thumbnailUrl: thumbUrl,
      );
    } catch (_) {
      return null;
    }
  }

  (String, String) _parseMimeType(String mime) {
    final parts = mime.split(';');
    final container = parts[0].trim();
    String codec = '';
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('codecs=')) {
        codec = trimmed.substring(7).replaceAll('"', '').replaceAll("'", '');
        break;
      }
    }
    return (container, codec);
  }

  String _itagLabel(int itag, String container) {
    return switch (itag) {
      >= 694 && <= 701 => 'AV1',
      571 => '2160p60 AV1',
      337 => '2160p HDR',
      336 => '1440p HDR',
      335 => '1080p HDR',
      334 => '720p HDR',
      330 || 331 || 332 || 333 => 'HDR',
      315 => '2160p60',
      313 => '2160p',
      308 => '1440p60',
      304 => '1440p',
      303 => '1080p60',
      302 => '720p60',
      299 => '1080p60 H.264',
      298 => '720p60 H.264',
      272 => '4320p',
      271 => '1440p',
      266 => '2160p',
      264 => '1440p',
      248 || 247 || 244 || 243 || 242 => 'VP9',
      138 || 137 || 136 || 135 || 134 || 133 || 160 => 'H.264',
      251 || 250 || 249 => 'Opus',
      141 || 140 || 139 => 'AAC',
      22 || 18 || 17 => container.contains('mp4') ? 'MP4' : '3GP',
      _ => 'Unknown',
    };
  }

  Stream<List<int>> getStreamBytes(dynamic rawStreamInfo) {
    return _yt.videos.streamsClient.get(rawStreamInfo);
  }

  Future<Stream<List<int>>> getResolvedStream(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final streamInfo = manifest.audioOnly
        .where((s) => s.container.toString().toLowerCase().contains('mp4'))
        .withHighestBitrate();
    return _yt.videos.streamsClient.get(streamInfo);
  }

  Future<String> resolveStreamUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final streamInfo = manifest.audioOnly
        .where((s) => s.container.toString().toLowerCase().contains('mp4'))
        .withHighestBitrate();
    return streamInfo.url.toString();
  }

  Future<({String url, String userAgent})?> resolveAudioUrlInnerTube(String videoId) async {
    try {
      final info = await _getVideoInfoInnerTube(videoId);
      if (info != null && info.audioStreams.isNotEmpty) {
        final best = info.audioStreams.reduce(
          (a, b) => a.bitrate > b.bitrate ? a : b,
        );
        return (
          url: best.url,
          userAgent: info.clientUserAgent ?? 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip'
        );
      }
    } catch (e) {
      print('[YoutubeVideoService] resolveAudioUrlInnerTube error: $e');
    }
    return null;
  }

  Future<List<YoutubeSearchResult>> searchAudioOnly(String query) async {
    final results = await search('$query audio');
    if (results.isEmpty) return [];
    await Future.wait(results.take(3).map((r) async {
      final res = await resolveAudioUrlInnerTube(r.id);
      if (res != null) {
        r.audioUrl = res.url;
      }
    }));
    return results;
  }

  void dispose() {
    _yt.close();
  }
}
