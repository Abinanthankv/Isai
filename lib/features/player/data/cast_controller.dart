import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../../core/di/injection.dart';
import '../../music/data/music_models.dart';
import '../../music/data/music_repository.dart';
import '../../music/data/plugins/eclipse_addon.dart';
import '../../music/data/plugins/js_plugin.dart';
import '../../music/data/plugins/plugin_manager.dart';

/// Resolves a castable stream URL for a [MediaItem], or returns null when the
/// item cannot be cast (local downloads, YouTube, plugin sources, etc).
typedef CastUrlResolver = Future<String?> Function(MediaItem item);

class CastLoadResult {
  final bool success;
  final String? error;

  const CastLoadResult.failed(this.error) : success = false;
  const CastLoadResult.success() : success = true, error = null;
}

/// Single controller for Chromecast playback.
///
/// Sends single tracks directly to the receiver using [loadMedia]. Track switching
/// and queue logic are driven entirely by the phone app ([MyAudioHandler]).
class CastPlaybackController {
  static final CastPlaybackController instance = CastPlaybackController._();

  CastPlaybackController._();

  /// Optional override used to resolve stream URLs.
  CastUrlResolver? urlResolver;

  final MusicRepository _repo = getIt<MusicRepository>();

  bool _initialized = false;
  bool _supported = true;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  GoggleCastMediaStatus? _mediaStatus;

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<CastMediaPlayerState?> playerState =
      ValueNotifier<CastMediaPlayerState?>(null);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<MediaItem?> currentTrack = ValueNotifier<MediaItem?>(null);

  GoggleCastMediaStatus? get mediaStatus => _mediaStatus;
  bool get isSupported => _supported;
  GoogleCastDevice? get connectedDevice => _connectedDevice;
  GoogleCastDevice? _connectedDevice;

  bool get isPlaying => playerState.value == CastMediaPlayerState.playing;

  bool get isBuffering =>
      playerState.value == CastMediaPlayerState.buffering ||
      playerState.value == CastMediaPlayerState.loading;

  /// Initializes the Cast context and subscribes to receiver state streams.
  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      _supported = false;
      return;
    }
    if (_initialized) return;
    _initialized = true;

    await GoogleCastContext.instance.setSharedInstanceWithOptions(
      GoogleCastOptionsAndroid(
        appId: GoogleCastDiscoveryCriteria.kDefaultApplicationId,
      ),
    );

    _subscriptions.add(GoogleCastSessionManager.instance.currentSessionStream
        .listen((session) {
      isConnected.value = session != null;
      if (session == null) {
        _connectedDevice = null;
      }
    }));

    _subscriptions.add(GoogleCastRemoteMediaClient.instance.mediaStatusStream
        .listen((status) {
      if (status == null) return;
      _mediaStatus = status;
      playerState.value = status.playerState;
    }));

    _subscriptions.add(
        GoogleCastRemoteMediaClient.instance.playerPositionStream.listen((p) {
      position.value = p;
    }));
  }

  Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  List<GoogleCastDevice> get devices => GoogleCastDiscoveryManager.instance.devices;

  Future<void> startDiscovery() async {
    if (!isSupported) return;
    await initialize();
    await GoogleCastDiscoveryManager.instance.startDiscovery();
  }

  Future<void> stopDiscovery() async {
    if (!isSupported) return;
    await GoogleCastDiscoveryManager.instance.stopDiscovery();
  }

  /// Starts a session with the given receiver device.
  Future<bool> connect(GoogleCastDevice device) async {
    if (!isSupported) return false;
    await initialize();
    final ok =
        await GoogleCastSessionManager.instance.startSessionWithDevice(device);
    if (ok) {
      _connectedDevice = device;
      isConnected.value = true;
    }
    return ok;
  }

  /// Ends the session and stops casting.
  Future<void> disconnect() async {
    if (!isSupported) return;
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    _resetState();
  }

  void _resetState() {
    _mediaStatus = null;
    playerState.value = null;
    position.value = Duration.zero;
    currentTrack.value = null;
    isConnected.value = false;
    _connectedDevice = null;
  }

  /// Resolves and loads a single [MediaItem] directly onto the Cast receiver.
  Future<CastLoadResult> playSingleTrack(
    MediaItem item, {
    Duration playPosition = Duration.zero,
  }) async {
    if (!isSupported || !isConnected.value) {
      return const CastLoadResult.failed('Not connected to a Cast device');
    }

    print('[CastController] playSingleTrack: "${item.title}" at ${playPosition.inMilliseconds}ms');

    final url = await resolveUrl(item).timeout(const Duration(seconds: 20));
    if (url == null || url.isEmpty) {
      print('[CastController] Failed to resolve playable URL for "${item.title}"');
      return const CastLoadResult.failed('Stream URL could not be resolved for casting');
    }

    print('[CastController] Resolved URL for Cast: $url');

    Uri? artUri = item.artUri;
    if (artUri == null && item.extras != null) {
      final ext = item.extras!;
      final art = (ext['artworkUrl'] ??
              ext['thumbnail'] ??
              ext['artworkUrlHigh'] ??
              ext['artworkUrlLow']) as String?;
      if (art != null && art.isNotEmpty) artUri = Uri.tryParse(art);
    }

    Duration? duration = item.duration;
    if ((duration?.inMilliseconds ?? 0) <= 0 && item.extras != null) {
      final ttm = item.extras?['trackTimeMillis'] ?? item.extras?['durationMs'];
      if (ttm is num && ttm > 0) duration = Duration(milliseconds: ttm.toInt());
    }

    final contentType = contentTypeFor(url, format: item.extras?['format'] as String?);

    final mediaInformation = GoogleCastMediaInformation(
      contentId: url,
      contentType: contentType,
      streamType: CastMediaStreamType.buffered,
      contentUrl: Uri.tryParse(url),
      duration: duration,
      metadata: GoogleCastMusicMediaMetadata(
        albumName: item.album,
        title: item.title,
        albumArtist: item.album,
        artist: item.artist,
        trackNumber: item.extras?['trackNumber'] as int?,
        images: artUri != null
            ? [GoogleCastImage(url: artUri, height: 600, width: 600)]
            : null,
      ),
    );

    try {
      await GoogleCastRemoteMediaClient.instance.loadMedia(
        mediaInformation,
        autoPlay: true,
        playPosition: playPosition,
      );
      currentTrack.value = item;
      return const CastLoadResult.success();
    } catch (e) {
      debugPrint('[CastController] loadMedia error: $e');
      return CastLoadResult.failed('Cast load failed: $e');
    }
  }

  Future<void> play() async {
    if (!isSupported || !isConnected.value) return;
    await GoogleCastRemoteMediaClient.instance.play();
  }

  Future<void> pause() async {
    if (!isSupported || !isConnected.value) return;
    await GoogleCastRemoteMediaClient.instance.pause();
  }

  Future<void> togglePlayPause() async {
    if (playerState.value == CastMediaPlayerState.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    if (!isSupported || !isConnected.value) return;
    await GoogleCastRemoteMediaClient.instance.seek(
      GoogleCastMediaSeekOption(
        position: position,
        relative: false,
        resumeState: GoogleCastMediaResumeState.play,
      ),
    );
  }

  Future<void> stop() async {
    if (!isSupported || !isConnected.value) return;
    await GoogleCastRemoteMediaClient.instance.stop();
  }

  Future<String?> resolveUrl(MediaItem item) async {
    final override = urlResolver;
    if (override != null) {
      final resolved = await override(item);
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }

    final id = item.id;

    if (item.extras?['linkType'] == 'youtube' ||
        id.contains('googlevideo') ||
        id.contains('youtube') ||
        id.startsWith('file://') ||
        id.startsWith('/') ||
        id.startsWith('content://')) {
      return null;
    }

    if (id.contains('lazy.torbox.internal')) {
      final torrentId = item.extras?['torrentId'] as num?;
      final fileId = item.extras?['fileId'] as num?;
      if (torrentId == null || fileId == null) return null;
      return _repo.getStreamUrl(torrentId.toInt(), fileId.toInt());
    }

    if (id.contains('lazy.flac.internal')) {
      return _resolveFlac(id, item);
    }

    if (id.contains('lazy.plugin.internal')) {
      return _resolvePlugin(id, item);
    }

    if (id.startsWith('http://') || id.startsWith('https://')) {
      return id;
    }

    return null;
  }

  Future<String?> _resolveFlac(String id, MediaItem item) async {
    final uri = Uri.tryParse(id);
    if (uri == null) return null;
    final title = uri.queryParameters['title'] ?? item.title;
    final artist = uri.queryParameters['artist'] ?? item.artist ?? '';
    final query = '$artist $title'.trim();
    if (query.isEmpty) return null;
    try {
      final results = <ScraperResult>[];
      await for (final r in _repo.searchFLACStream(query)) {
        if (r.url.isEmpty) continue;
        results.add(r);
        if (r.isGoodMatch(title, artist)) break;
      }
      if (results.isEmpty) return null;
      final good = results.firstWhere(
        (r) => r.isGoodMatch(title, artist),
        orElse: () => results.first,
      );
      final url = good.url;
      if (url.startsWith('http://') || url.startsWith('https://')) return url;
    } catch (e) {
      debugPrint('[CastController] FLAC resolve failed for "$query": $e');
    }
    return null;
  }

  Future<String?> _resolvePlugin(String id, MediaItem item) async {
    final uri = Uri.tryParse(id);
    if (uri == null || uri.pathSegments.length < 2) return null;
    final pluginId = uri.pathSegments[0];
    final trackId = Uri.decodeComponent(uri.pathSegments[1]);
    final pm = getIt<PluginManager>();

    try {
      String? realUrl;
      if (pluginId.startsWith('eclipse_')) {
        realUrl = await pm
            .resolveEclipseStream(pluginId.replaceFirst('eclipse_', ''), trackId)
            .timeout(const Duration(seconds: 20));
      } else {
        realUrl =
            await pm.resolveStream(pluginId, trackId).timeout(const Duration(seconds: 20));
      }
      if (realUrl != null && realUrl.isNotEmpty) return realUrl;

      final title = item.title;
      final artist = item.artist ?? '';
      final query = '$artist $title'.trim();
      for (final alt in pm.prioritizedActiveAddons) {
        final altId =
            alt is JsPlugin ? alt.id : 'eclipse_${(alt as EclipseAddon).id}';
        if (altId == pluginId) continue;
        try {
          final results = altId.startsWith('eclipse_')
              ? await pm
                  .searchEclipse(altId.replaceFirst('eclipse_', ''), query)
                  .timeout(const Duration(seconds: 15))
              : await pm.search(altId, query).timeout(const Duration(seconds: 15));
          if (results.isEmpty) continue;
          final altTrackId =
              results.first.extras?['trackId'] as String? ?? results.first.url;
          final altUrl = altId.startsWith('eclipse_')
              ? await pm
                  .resolveEclipseStream(
                      altId.replaceFirst('eclipse_', ''), altTrackId)
                  .timeout(const Duration(seconds: 20))
              : await pm.resolveStream(altId, altTrackId)
                  .timeout(const Duration(seconds: 20));
          if (altUrl != null && altUrl.isNotEmpty) return altUrl;
        } catch (e) {
          debugPrint('[CastController] Fallback resolve failed on $altId: $e');
        }
      }
    } catch (e) {
      debugPrint('[CastController] Plugin resolve failed for "$pluginId/$trackId": $e');
    }
    return null;
  }
}

const Map<String, String> _contentTypes = {
  '.mp3': 'audio/mpeg',
  '.flac': 'audio/flac',
  '.m4a': 'audio/mp4',
  '.m4b': 'audio/mp4',
  '.aac': 'audio/aac',
  '.ogg': 'audio/ogg',
  '.oga': 'audio/ogg',
  '.opus': 'audio/opus',
  '.wav': 'audio/wav',
  '.m3u8': 'application/x-mpegURL',
  '.mpd': 'application/dash+xml',
};

String contentTypeFor(String nameOrUrl, {String? format}) {
  final formatLower = format?.toLowerCase();
  switch (formatLower) {
    case 'mp3':
      return 'audio/mpeg';
    case 'flac':
      return 'audio/flac';
    case 'm4a':
    case 'm4b':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'ogg':
    case 'oga':
      return 'audio/ogg';
    case 'opus':
      return 'audio/opus';
    case 'wav':
      return 'audio/wav';
    case 'm3u8':
      return 'application/x-mpegURL';
    case 'mpd':
      return 'application/dash+xml';
  }

  final lower = nameOrUrl.toLowerCase();
  for (final entry in _contentTypes.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return 'audio/mpeg';
}
