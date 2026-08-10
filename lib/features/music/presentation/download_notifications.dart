import 'dart:async';
import 'dart:io' as io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Shows silent progress notifications for music downloads, including album
/// artwork, a progress bar, and downloaded/total size. Errors are surfaced in
/// the notification itself rather than only in-app.
class MusicDownloadNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Cache of artwork URL -> local temp file path, so art is fetched once
  /// per track instead of on every progress tick.
  final Map<String, String> _artworkCache = {};

  /// Pending auto-dismiss timers for completed notifications, keyed by id.
  final Map<int, Timer> _pendingAutoDismiss = {};

  Future<void> _init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  String _formatBytes(int bytes) {
    if (bytes < 0) return '?';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<String?> _ensureArtworkPath(String? artworkUrl, int id) async {
    if (artworkUrl == null || artworkUrl.isEmpty) return null;
    final cached = _artworkCache[artworkUrl];
    if (cached != null) return cached;
    try {
      final client = io.HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(artworkUrl));
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final bytes =
            await response.fold<List<int>>([], (acc, e) => acc..addAll(e));
        if (bytes.isEmpty) return null;
        final tempDir = await getTemporaryDirectory();
        final ext = artworkUrl.toLowerCase().contains('.png') ? 'png' : 'jpg';
        final file = io.File(p.join(tempDir.path, 'dl_notif_art_$id.$ext'));
        await file.writeAsBytes(bytes);
        _artworkCache[artworkUrl] = file.path;
        return file.path;
      } finally {
        client.close();
      }
    } catch (e) {
      print('[MusicDownloadNotifier] Failed to fetch artwork: $e');
      return null;
    }
  }

  Future<void> showProgress({
    required int id,
    required String title,
    required String artist,
    String? artworkUrl,
    double progress = 0,
    int downloadedBytes = 0,
    int totalBytes = -1,
  }) async {
    try {
      await _init();
      final artworkPath = await _ensureArtworkPath(artworkUrl, id);
      final percent = (progress.clamp(0.0, 1.0) * 100).round();
      final body = totalBytes > 0
          ? '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)} ($percent%)'
          : '$percent%';

      final details = AndroidNotificationDetails(
        'music_downloads',
        'Music Downloads',
        channelDescription: 'Silent notifications for music download progress',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: percent,
        largeIcon:
            artworkPath != null ? FilePathAndroidBitmap(artworkPath) : null,
        styleInformation: artworkPath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(artworkPath),
                contentTitle: artist.isEmpty ? title : '$artist — $title',
                summaryText: body,
                largeIcon: FilePathAndroidBitmap(artworkPath),
                hideExpandedLargeIcon: true,
              )
            : BigTextStyleInformation(
                body,
                contentTitle: artist.isEmpty ? title : '$artist — $title',
              ),
      );
      await _plugin.show(id, title, body, NotificationDetails(android: details));
    } catch (e) {
      print('[MusicDownloadNotifier] Error showing progress notification: $e');
    }
  }

  Future<void> showComplete({
    required int id,
    required String title,
    String? artworkUrl,
    int totalBytes = -1,
  }) async {
    try {
      await _init();
      final artworkPath = await _ensureArtworkPath(artworkUrl, id);
      final body =
          totalBytes > 0 ? '${_formatBytes(totalBytes)} — Complete' : title;

      final details = AndroidNotificationDetails(
        'music_downloads',
        'Music Downloads',
        channelDescription: 'Silent notifications for music download progress',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        autoCancel: true,
        largeIcon:
            artworkPath != null ? FilePathAndroidBitmap(artworkPath) : null,
        styleInformation: artworkPath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(artworkPath),
                contentTitle: 'Download Complete',
                summaryText: body,
                largeIcon: FilePathAndroidBitmap(artworkPath),
                hideExpandedLargeIcon: true,
              )
            : null,
      );
      await _plugin.show(
        id,
        'Download Complete',
        body,
        NotificationDetails(android: details),
      );

      _pendingAutoDismiss[id]?.cancel();
      _pendingAutoDismiss[id] = Timer(const Duration(seconds: 4), () async {
        await _plugin.cancel(id);
        _pendingAutoDismiss.remove(id);
      });
    } catch (e) {
      print('[MusicDownloadNotifier] Error showing complete notification: $e');
    }
  }

  Future<void> showError({
    required int id,
    required String title,
    String? artworkUrl,
    String message = 'Download failed',
  }) async {
    try {
      await _init();
      final artworkPath = await _ensureArtworkPath(artworkUrl, id);
      final details = AndroidNotificationDetails(
        'music_downloads',
        'Music Downloads',
        channelDescription: 'Silent notifications for music download progress',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        autoCancel: true,
        largeIcon:
            artworkPath != null ? FilePathAndroidBitmap(artworkPath) : null,
        styleInformation: artworkPath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(artworkPath),
                contentTitle: 'Download Failed',
                summaryText: message,
                largeIcon: FilePathAndroidBitmap(artworkPath),
                hideExpandedLargeIcon: true,
              )
            : BigTextStyleInformation(
                message,
                contentTitle: 'Download Failed',
              ),
      );
      await _plugin.show(
        id,
        'Download Failed',
        message,
        NotificationDetails(android: details),
      );
    } catch (e) {
      print('[MusicDownloadNotifier] Error showing failure notification: $e');
    }
  }

  Future<void> cancel(int id) async {
    try {
      final timer = _pendingAutoDismiss.remove(id);
      if (timer != null) timer.cancel();
      if (_initialized) {
        await _plugin.cancel(id);
      }
    } catch (e) {
      print('[MusicDownloadNotifier] Error cancelling notification: $e');
    }
  }
}
