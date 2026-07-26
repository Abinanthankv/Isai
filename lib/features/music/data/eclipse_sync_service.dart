import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../../core/network/eclipse_api_service.dart';

class EclipseSyncService {
  final AppDatabase _db;
  final EclipseApiService _api;

  EclipseSyncService(this._db) : _api = EclipseApiService();

  Future<String?> createPlaylistOnEclipse({
    required String token,
    required String userId,
    required int localPlaylistId,
    required String name,
    String? description,
    String? artworkUrl,
  }) async {
    final eclipseId = await _api.createPlaylist(
      token, userId, name,
      description: description,
      coverUrl: artworkUrl,
    );
    if (eclipseId != null) {
      await _db.updatePlaylistEclipseId(localPlaylistId, eclipseId);
    }
    return eclipseId;
  }

  Future<String?> createPlaylistOnEclipseWithTracks({
    required String token,
    required String userId,
    required int localPlaylistId,
    required String name,
    String? artworkUrl,
    required List<Map<String, dynamic>> tracks,
  }) async {
    final eclipseId = await _api.createPlaylistWithTracks(
      token, userId, name,
      coverUrl: artworkUrl,
      tracks: tracks,
    );
    if (eclipseId != null) {
      await _db.updatePlaylistEclipseId(localPlaylistId, eclipseId);
    }
    return eclipseId;
  }

  Future<void> addTrackToEclipsePlaylist({
    required String token,
    required String userId,
    required String eclipsePlaylistId,
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  }) async {
    final tracks = [
      {
        'title': title,
        'artist': artist,
        if (album != null) 'album': album,
        if (artworkUrl != null) 'coverUrl': artworkUrl,
      }
    ];
    final success = await _api.addTracksToPlaylist(token, userId, eclipsePlaylistId, tracks);
    if (!success) {
      print('EclipseSyncService: failed to add track to remote playlist $eclipsePlaylistId');
    }
  }

  Future<void> removeTrackFromEclipsePlaylist({
    required String token,
    required String userId,
    required String eclipsePlaylistId,
    required String eclipseTrackId,
  }) async {
    await _api.removeTracksFromPlaylist(
      token, userId, eclipsePlaylistId, [eclipseTrackId],
    );
  }

  /// Removes a track from an Eclipse playlist by matching title+artist when no
  /// [eclipseTrackId] is available. Fetches the remote playlist, finds the
  /// matching track, and deletes it by its remote ID.
  Future<void> removeTrackFromEclipsePlaylistByMetadata({
    required String token,
    required String userId,
    required String eclipsePlaylistId,
    required String title,
    required String artist,
  }) async {
    final playlists = await _api.getPlaylists(token, userId);
    final remotePlaylist = playlists.where((p) => p.id == eclipsePlaylistId).firstOrNull;
    if (remotePlaylist == null) return;

    final remoteTrack = remotePlaylist.tracks.where((t) =>
      t.trackTitle == title && t.artistName == artist
    ).firstOrNull;
    if (remoteTrack?.id == null) return;

    await _api.removeTracksFromPlaylist(
      token, userId, eclipsePlaylistId, [remoteTrack!.id!],
    );
  }

  Future<void> deletePlaylistOnEclipse({
    required String token,
    required String userId,
    required String eclipsePlaylistId,
  }) async {
    await _api.deletePlaylist(token, userId, eclipsePlaylistId);
  }

  Future<void> importEclipsePlaylists({
    required String token,
    required String userId,
  }) async {
    final eclipsePlaylists = await _api.getPlaylists(token, userId);
    for (final ep in eclipsePlaylists) {
      final existing = await _db.getPlaylistByEclipseId(ep.id);
      if (existing != null) {
        // Update tracks for existing playlists — delete all local tracks and
        // re-insert from remote so deletions/edits on the Eclipse side are reflected.
        final localTracks = await _db.getPlaylistTracks(existing.id);
        for (final t in localTracks) {
          await _db.deletePlaylistTrack(t.id);
        }
        if (ep.tracks.isNotEmpty) {
          final tracks = ep.tracks.map((t) => PlaylistTracksCompanion.insert(
            playlistId: existing.id,
            title: t.trackTitle,
            artist: t.artistName ?? 'Unknown',
            album: Value(t.albumName),
            youtubeId: t.id ?? '',
            artworkUrl: Value(t.artworkUrl),
            eclipseTrackId: Value(t.id),
          )).toList();
          await _db.addTracksToPlaylist(tracks);
        }
        continue;
      }

      final localId = await _db.createPlaylist(PlaylistsCompanion.insert(
        name: ep.name,
        artworkUrl: Value(ep.coverUrl),
        eclipseId: Value(ep.id),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      if (ep.tracks.isNotEmpty) {
        final tracks = ep.tracks.map((t) => PlaylistTracksCompanion.insert(
          playlistId: localId,
          title: t.trackTitle,
          artist: t.artistName ?? 'Unknown',
          album: Value(t.albumName),
          youtubeId: t.id ?? '',
          artworkUrl: Value(t.artworkUrl),
          eclipseTrackId: Value(t.id),
        )).toList();
        await _db.addTracksToPlaylist(tracks);
      }
    }
  }

  /// Syncs all local playlists without an [eclipseId] to Eclipse, creating
  /// each playlist together with all its tracks in one batch call.
  Future<int> syncLocalPlaylistsToEclipse({
    required String token,
    required String userId,
  }) async {
    final allPlaylists = await _db.getAllPlaylists();
    final unsynced = allPlaylists.where((p) => p.eclipseId == null).toList();
    int syncedCount = 0;

    for (final playlist in unsynced) {
      final tracks = await _db.getPlaylistTracks(playlist.id);
      final tracksData = tracks.map((t) => {
        'title': t.title,
        'artist': t.artist,
        if (t.album != null) 'album': t.album,
        if (t.artworkUrl != null) 'coverUrl': t.artworkUrl,
      }).toList();

      if (tracksData.isNotEmpty) {
        final eclipseId = await createPlaylistOnEclipseWithTracks(
          token: token,
          userId: userId,
          localPlaylistId: playlist.id,
          name: playlist.name,
          artworkUrl: playlist.artworkUrl,
          tracks: tracksData,
        );
        if (eclipseId != null) syncedCount++;
      } else {
        final eclipseId = await createPlaylistOnEclipse(
          token: token,
          userId: userId,
          localPlaylistId: playlist.id,
          name: playlist.name,
          artworkUrl: playlist.artworkUrl,
        );
        if (eclipseId != null) syncedCount++;
      }
    }

    return syncedCount;
  }
}
