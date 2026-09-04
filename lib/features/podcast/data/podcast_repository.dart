import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../../core/database/database.dart';
import '../../music/presentation/download_notifications.dart';
import 'podcast_models.dart';
import 'podcast_api_service.dart';
import 'opml_service.dart';

class PodcastRepository {
  final AppDatabase _db;
  final PodcastApiService _api;
  final Dio _dio;

  PodcastRepository(this._db, this._api) : _dio = Dio();

  // ─── SUBSCRIPTIONS ─────────────────────────────────────────────────────────

  Future<void> subscribe(PodcastSeries series) async {
    var feedUrl = series.feedUrl;
    if ((feedUrl == null || feedUrl.isEmpty) && series.collectionId > 0) {
      final lookedUp = await _api.lookupPodcast(series.collectionId);
      if (lookedUp?.feedUrl != null) {
        feedUrl = lookedUp!.feedUrl;
      }
    }

    final entry = PodcastSubscriptionsCompanion.insert(
      collectionId: Value(series.collectionId),
      title: series.collectionName,
      artist: series.artistName,
      feedUrl: feedUrl ?? '',
      artworkUrl: Value(series.artworkUrl),
      genres: Value(series.primaryGenre),
      subscribedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.subscribePodcast(entry);

    // Fetch and cache episodes for the newly subscribed podcast
    if (feedUrl != null && feedUrl.isNotEmpty) {
      unawaited(refreshEpisodes(feedUrl));
    }
  }

  Future<void> unsubscribe(String feedUrl) async {
    await _db.unsubscribePodcast(feedUrl);
  }

  Future<bool> isSubscribed(String feedUrl) async {
    return _db.isPodcastSubscribed(feedUrl);
  }

  Future<List<DbPodcastSubscription>> getSubscribedPodcasts() async {
    return _db.getSubscribedPodcasts();
  }

  Stream<List<DbPodcastSubscription>> watchSubscribedPodcasts() {
    return _db.watchSubscribedPodcasts();
  }

  // ─── EPISODES ─────────────────────────────────────────────────────────────

  Future<List<DbPodcastEpisodeData>> getEpisodes(String feedUrl, {bool forceRefresh = false}) async {
    final cached = await _db.getEpisodesForPodcast(feedUrl);
    if (cached.isNotEmpty && !forceRefresh) {
      return cached;
    }
    return refreshEpisodes(feedUrl);
  }

  Stream<List<DbPodcastEpisodeData>> watchEpisodes(String feedUrl) {
    return _db.watchEpisodesForPodcast(feedUrl);
  }

  Future<List<DbPodcastEpisodeData>> refreshEpisodes(String feedUrl) async {
    try {
      final episodes = await _api.fetchEpisodes(feedUrl);
      final companions = episodes.map((ep) {
        final pubDateMs = parseRssDate(ep.pubDate)?.millisecondsSinceEpoch;
        final epGuid = (ep.guid != null && ep.guid!.isNotEmpty) ? ep.guid! : (ep.audioUrl ?? '');
        return PodcastEpisodesCompanion.insert(
          feedUrl: feedUrl,
          guid: epGuid,
          title: ep.title,
          description: Value(ep.description),
          audioUrl: ep.audioUrl ?? '',
          pubDate: Value(pubDateMs),
          durationSeconds: Value(ep.durationSec ?? 0),
          artworkUrl: Value(ep.artworkUrl),
          chaptersUrl: Value(ep.chaptersUrl),
        );
      }).toList();

      if (companions.isNotEmpty) {
        await _db.savePodcastEpisodes(companions);
      }
      return await _db.getEpisodesForPodcast(feedUrl);
    } catch (e) {
      print('[PodcastRepository] Refresh episodes error for $feedUrl: $e');
      return _db.getEpisodesForPodcast(feedUrl);
    }
  }

  // ─── EPISODE DOWNLOADS ───────────────────────────────────────────────────

  final Map<String, ({CancelToken cancelToken, bool isPaused})> _activeDownloadTasks = {};

  bool isDownloadActive(String guid) {
    final task = _activeDownloadTasks[guid];
    return task != null && !task.isPaused;
  }

  bool isDownloadPaused(String guid) {
    final task = _activeDownloadTasks[guid];
    return task != null && task.isPaused;
  }

  Future<List<DbPodcastEpisodeData>> getDownloadedEpisodes() async {
    return _db.getDownloadedPodcastEpisodes();
  }

  Stream<List<DbPodcastEpisodeData>> watchDownloadedEpisodes() {
    return _db.watchDownloadedPodcastEpisodes();
  }

  Future<void> downloadEpisode(DbPodcastEpisodeData ep) async {
    final guid = ep.guid;
    if (_activeDownloadTasks.containsKey(guid) && !(_activeDownloadTasks[guid]?.isPaused ?? false)) {
      return; // Already downloading
    }

    final cancelToken = CancelToken();
    _activeDownloadTasks[guid] = (cancelToken: cancelToken, isPaused: false);

    final notifier = MusicDownloadNotifier();
    final notifId = guid.hashCode.abs();

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final podcastsDir = Directory(p.join(docDir.path, 'podcasts'));
      if (!await podcastsDir.exists()) {
        await podcastsDir.create(recursive: true);
      }

      final hash = md5.convert(utf8.encode(guid)).toString();
      final filePath = p.join(podcastsDir.path, '$hash.mp3');
      final tmpFilePath = '$filePath.tmp';
      final tmpFile = File(tmpFilePath);

      int existingBytes = 0;
      if (await tmpFile.exists()) {
        existingBytes = await tmpFile.length();
      }

      await _db.updateEpisodeDownloadState(
        guid: guid,
        isDownloaded: false,
        progress: existingBytes > 0 ? (ep.downloadProgress > 0 ? ep.downloadProgress : 0.01) : 0.01,
        isPaused: false,
      );

      await notifier.showProgress(
        id: notifId,
        title: ep.title,
        artist: 'Podcast Episode',
        artworkUrl: ep.artworkUrl,
        progress: ep.downloadProgress > 0 ? ep.downloadProgress : 0.01,
      );

      DateTime lastNotifTime = DateTime.now();

      final options = Options(
        headers: existingBytes > 0 ? {'range': 'bytes=$existingBytes-'} : null,
        responseType: ResponseType.stream,
      );

      final response = await _dio.get<ResponseBody>(
        ep.audioUrl,
        options: options,
        cancelToken: cancelToken,
      );

      final isPartial = response.statusCode == 206;
      int startByte = isPartial ? existingBytes : 0;
      int serverContentLength = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      int totalBytes = startByte + serverContentLength;

      final sink = tmpFile.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
      int receivedBytes = startByte;

      await for (final chunk in response.data!.stream) {
        final currentTask = _activeDownloadTasks[guid];
        if (currentTask != null && currentTask.isPaused) {
          await sink.close();
          return;
        }
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          _db.updateEpisodeDownloadState(
            guid: guid,
            isDownloaded: false,
            progress: progress,
            isPaused: false,
          );

          final now = DateTime.now();
          if (now.difference(lastNotifTime).inMilliseconds > 400 || progress >= 0.99) {
            lastNotifTime = now;
            notifier.showProgress(
              id: notifId,
              title: ep.title,
              artist: 'Podcast Episode',
              artworkUrl: ep.artworkUrl,
              progress: progress,
              downloadedBytes: receivedBytes,
              totalBytes: totalBytes,
            );
          }
        }
      }

      await sink.close();

      final finalFile = File(filePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tmpFile.rename(filePath);

      _activeDownloadTasks.remove(guid);

      await _db.updateEpisodeDownloadState(
        guid: guid,
        localPath: filePath,
        isDownloaded: true,
        progress: 1.0,
        isPaused: false,
      );

      await notifier.showComplete(
        id: notifId,
        title: ep.title,
        artworkUrl: ep.artworkUrl,
      );
      print('[PodcastRepository] Download completed: $filePath');
    } catch (e) {
      final currentTask = _activeDownloadTasks[guid];
      if (currentTask != null && currentTask.isPaused) {
        print('[PodcastRepository] Download paused by user.');
        return;
      }
      _activeDownloadTasks.remove(guid);
      if (cancelToken.isCancelled) {
        print('[PodcastRepository] Download cancelled.');
        return;
      }
      print('[PodcastRepository] Download error: $e');
      await _db.updateEpisodeDownloadState(
        guid: guid,
        isDownloaded: false,
        progress: 0.0,
        isPaused: false,
      );
      await notifier.showError(
        id: notifId,
        title: ep.title,
        artworkUrl: ep.artworkUrl,
        message: 'Download failed',
      );
    }
  }

  Future<void> pauseDownload(DbPodcastEpisodeData ep) async {
    final guid = ep.guid;
    final task = _activeDownloadTasks[guid];
    if (task != null) {
      _activeDownloadTasks[guid] = (cancelToken: task.cancelToken, isPaused: true);
      task.cancelToken.cancel('user_paused');
    }

    await _db.updateEpisodeDownloadState(
      guid: guid,
      isDownloaded: false,
      progress: ep.downloadProgress,
      isPaused: true,
    );

    final notifier = MusicDownloadNotifier();
    final notifId = guid.hashCode.abs();
    await notifier.showProgress(
      id: notifId,
      title: 'Paused: ${ep.title}',
      artist: 'Podcast Episode',
      artworkUrl: ep.artworkUrl,
      progress: ep.downloadProgress,
    );
  }

  Future<void> resumeDownload(DbPodcastEpisodeData ep) async {
    await downloadEpisode(ep);
  }

  Future<void> cancelDownload(DbPodcastEpisodeData ep) async {
    final guid = ep.guid;
    final task = _activeDownloadTasks[guid];
    if (task != null) {
      task.cancelToken.cancel('user_cancelled');
      _activeDownloadTasks.remove(guid);
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final hash = md5.convert(utf8.encode(guid)).toString();
      final tmpFile = File(p.join(docDir.path, 'podcasts', '$hash.mp3.tmp'));
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      final file = File(p.join(docDir.path, 'podcasts', '$hash.mp3'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    await _db.updateEpisodeDownloadState(
      guid: guid,
      localPath: null,
      isDownloaded: false,
      progress: 0.0,
      isPaused: false,
    );

    final notifier = MusicDownloadNotifier();
    final notifId = guid.hashCode.abs();
    await notifier.cancel(notifId);
  }

  Future<void> deleteDownload(DbPodcastEpisodeData ep) async {
    if (ep.localPath != null && ep.localPath!.isNotEmpty) {
      try {
        final file = File(ep.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('[PodcastRepository] Delete file error: $e');
      }
    }
    await _db.updateEpisodeDownloadState(
      guid: ep.guid,
      localPath: null,
      isDownloaded: false,
      progress: 0.0,
    );
  }

  // ─── PLAYBACK PROGRESS ─────────────────────────────────────────────────────

  Future<void> saveProgress({
    required String guid,
    required String feedUrl,
    required int positionMillis,
    required int durationMillis,
    bool isCompleted = false,
  }) async {
    final entry = PodcastProgressCompanion.insert(
      guid: guid,
      feedUrl: feedUrl,
      positionMillis: Value(positionMillis),
      durationMillis: Value(durationMillis),
      isCompleted: Value(isCompleted),
      lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.savePodcastProgress(entry);
  }

  Future<DbPodcastProgressData?> getProgress(String guid) {
    return _db.getPodcastProgress(guid);
  }

  Stream<DbPodcastProgressData?> watchProgress(String guid) {
    return _db.watchPodcastProgress(guid);
  }

  // ─── OPML IMPORT / EXPORT ──────────────────────────────────────────────────

  Future<int> importOpml(String xmlString) async {
    final items = OpmlService.parseOpml(xmlString);
    int imported = 0;
    for (final item in items) {
      try {
        final series = await _api.fetchSeriesFromFeed(item.xmlUrl);
        if (series != null) {
          await subscribe(series);
          imported++;
        } else {
          // Fallback minimal series entry if feed metadata fetching fails
          final fallbackSeries = PodcastSeries(
            collectionId: 0,
            collectionName: item.title,
            artistName: 'Podcast Host',
            feedUrl: item.xmlUrl,
            artworkUrl: '',
            primaryGenre: 'Podcast',
          );
          await subscribe(fallbackSeries);
          imported++;
        }
      } catch (e) {
        print('[PodcastRepository] OPML import item error: $e');
      }
    }
    return imported;
  }

  Future<String> exportOpml() async {
    final subs = await getSubscribedPodcasts();
    return OpmlService.exportOpml(subs);
  }
}
