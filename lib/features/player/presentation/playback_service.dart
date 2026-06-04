import 'package:audio_service/audio_service.dart';
import '../../../main.dart';
import '../../../core/di/injection.dart';
import '../../music/data/music_models.dart';
import '../../music/data/music_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playbackProvider = Provider((ref) => PlaybackService(ref));

class PlaybackService {
  final Ref _ref;

  PlaybackService(this._ref);

  Future<void> playTorBoxFile(TorBoxFile file, {String? artworkUrl, String? artist}) async {
    final repo = getIt<MusicRepository>();
    
    try {
      final streamUrl = await repo.getStreamUrl(file.torrentId, file.id);
      
      if (streamUrl != null) {
        await audioHandler.playMediaItem(MediaItem(
          id: streamUrl,
          album: 'TorBox Library',
          title: file.displayName,
          artist: artist ?? 'TorBox',
          artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
          extras: {
            'torrentId': file.torrentId,
            'fileId': file.id,
          },
        ));
      }
    } catch (e) {
      print('[Playback] Error getting stream URL: $e');
    }
  }

  /// Plays a track from search results (iTunes) — usually requires adding to TorBox first,
  /// but this helper is here if needed for direct previews or resolved flows.
  Future<void> playItunesTrack(ItunesTrack track) async {
    if (track.previewUrl != null) {
      await audioHandler.playMediaItem(MediaItem(
        id: track.previewUrl!,
        album: track.collectionName,
        title: track.trackName,
        artist: track.artistName,
        artUri: Uri.parse(track.artworkUrl),
      ));
    }
  }
}
