import 'dart:io' as io;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:injectable/injectable.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

@DataClassName('DbTorrent')
class Torrents extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get hash => text()();
  BoolColumn get cached => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DbFile')
class Files extends Table {
  IntColumn get id => integer()();
  IntColumn get torrentId => integer()();
  TextColumn get name => text()();
  IntColumn get size => integer()();
  BoolColumn get isAudio => boolean()();
  TextColumn get localPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id, torrentId};
}

@DataClassName('DbSyncMeta')
class SyncMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get lastLibrarySync => integer().nullable()();
  IntColumn get lastTopSongsSync => integer().nullable()();
  IntColumn get lastTopAlbumsSync => integer().nullable()();
  TextColumn get cachedTopSongs => text().nullable()();
  TextColumn get cachedTopAlbums => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
@DataClassName('DbTrackMetadata')
class TrackMetadata extends Table {
  IntColumn get fileId => integer()();
  IntColumn get torrentId => integer()(); // Link metadata to file+torrent combo
  TextColumn get trackTitle => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get releaseYear => integer().nullable()();
  TextColumn get artworkUrlLow => text().nullable()();
  TextColumn get artworkUrlHigh => text().nullable()();
  IntColumn get trackTimeMillis => integer().nullable()();
  BoolColumn get isLiked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {fileId, torrentId};
}

@DataClassName('DbPlaybackHistory')
class PlaybackHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fileId => integer()();
  IntColumn get torrentId => integer()();
  TextColumn get trackTitle => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get genre => text()();
  TextColumn get artworkUrlLow => text().nullable()();
  TextColumn get artworkUrlHigh => text().nullable()();
  IntColumn get playedAt => integer()(); // timestamp
  IntColumn get duration => integer().nullable()(); // listen duration in seconds
}

@DataClassName('DbPlaylist')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get sourceUrl => text().nullable()(); // YouTube Playlist URL
  IntColumn get createdAt => integer()();
}

@DataClassName('DbPlaylistTrack')
class PlaylistTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  TextColumn get youtubeId => text()();
  IntColumn get duration => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get torrentId => integer().nullable()();
  IntColumn get fileId => integer().nullable()();
}

@DataClassName('DbExternalTrackMetadata')
class ExternalTrackMetadata extends Table {
  TextColumn get trackUrl => text()(); // The unique Apple Music/External URL
  TextColumn get trackTitle => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get releaseYear => integer().nullable()();
  TextColumn get artworkUrlLow => text().nullable()();
  TextColumn get artworkUrlHigh => text().nullable()();
  IntColumn get trackTimeMillis => integer().nullable()();
  IntColumn get lastUpdated => integer()(); // timestamp

  @override
  Set<Column> get primaryKey => {trackUrl};
}

@DataClassName('DbFollowedArtist')
class FollowedArtists extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get followedAt => integer()(); // timestamp

  @override
  Set<Column> get primaryKey => {id};
}

// ─── AUDIOBOOK TABLES (Isolated from Music) ─────────────────────────────────

@DataClassName('DbAudiobookProgress')
class AudiobookProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();              // Stremio addon book ID
  IntColumn get chapterIndex => integer()();
  IntColumn get positionMillis => integer().withDefault(const Constant(0))();
  IntColumn get durationMillis => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastListenedAt => dateTime()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbAudiobookMetadataCache')
class AudiobookMetadataCache extends Table {
  TextColumn get bookId => text()();             // Stremio addon book ID
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get narrator => text().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get totalChapters => integer().withDefault(const Constant(0))();
  TextColumn get language => text().nullable()();
  TextColumn get genre => text().nullable()();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}

@DriftDatabase(tables: [Torrents, Files, TrackMetadata, SyncMeta, PlaybackHistory, Playlists, PlaylistTracks, ExternalTrackMetadata, FollowedArtists, AudiobookProgress, AudiobookMetadataCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
          if (from < 14) {
            await m.createTable(audiobookProgress);
            await m.createTable(audiobookMetadataCache);
          }
          if (from < 13) {
            await m.database.customStatement(
              'ALTER TABLE playlist_tracks ADD COLUMN torrent_id INTEGER'
            );
            await m.database.customStatement(
              'ALTER TABLE playlist_tracks ADD COLUMN file_id INTEGER'
            );
          }
          if (from < 12) {
            await m.database.customStatement(
              'ALTER TABLE playlist_tracks ADD COLUMN genre TEXT'
            );
          }
          if (from < 11) {
            await m.createTable(followedArtists);
          }
          if (from < 10) {
            await m.createTable(externalTrackMetadata);
          }
          if (from < 9) {
            await m.addColumn(playbackHistory, playbackHistory.artworkUrlLow);
            await m.addColumn(playbackHistory, playbackHistory.artworkUrlHigh);
          }
          if (from < 8) {
            await m.createTable(playlists);
            await m.createTable(playlistTracks);
          }
          if (from < 7) {
            await m.createTable(playbackHistory);
          }
          if (from < 6) {
            await m.addColumn(trackMetadata, trackMetadata.isLiked);
          }
          if (from < 5) {
            await m.addColumn(trackMetadata, trackMetadata.trackTimeMillis);
          }
          if (from < 4) {
            await m.createTable(syncMeta);
          }
          if (from < 3) {
            await m.drop(torrents);
            await m.drop(files);
            await m.drop(trackMetadata);
            await m.createAll();
          }
        },
      );

  // --- Helper methods for Library ---
  
  Future<void> saveLibrary(List<TorrentsCompanion> torrents, List<FilesCompanion> tracks) async {
    await transaction(() async {
      // Get current IDs to handle orphans
      final torrentIds = torrents.map((t) => t.id.value).toList();
      
      // 1. Update/Insert torrents
      for (final t in torrents) {
        await into(this.torrents).insertOnConflictUpdate(t);
      }
      
      // 2. Update/Insert tracks (insertOnConflictUpdate preserves localPath if not in Companion)
      for (final f in tracks) {
        await into(this.files).insertOnConflictUpdate(f);
      }

      // 3. Delete stale torrents and their files (EXCEPT local downloads with id -1)
      await (delete(this.torrents)..where((t) => t.id.isNotIn(torrentIds) & t.id.equals(-1).not())).go();
      await (delete(this.files)..where((f) => f.torrentId.isNotIn(torrentIds) & f.torrentId.equals(-1).not())).go();
    });
  }

  Future<void> saveTrackMetadata(TrackMetadataCompanion entry) async {
    await into(trackMetadata).insertOnConflictUpdate(entry);
  }

  Future<List<DbTorrent>> getAllTorrents() => select(this.torrents).get();
  Future<List<DbFile>> getAllFiles() => select(this.files).get();
  Future<List<DbTrackMetadata>> getAllMetadata() => select(trackMetadata).get();

  // --- Playback History ---
  
  Future<void> recordPlayback(PlaybackHistoryCompanion entry) async {
    print('[Database] Recording playback: ${entry.trackTitle.value} by ${entry.artist.value}');
    await into(playbackHistory).insert(entry);
  }

  Future<List<DbPlaybackHistory>> getRecentPlayback({int limit = 20}) async {
    return (select(playbackHistory)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  Future<List<DbPlaybackHistory>> getAllPlayback() async {
    return (select(playbackHistory)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<DbPlaybackHistory>> watchAllPlayback() {
    return (select(playbackHistory)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<DbPlaybackHistory>> watchRecentPlayback({int limit = 20}) {
    return (select(playbackHistory)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .watch();
  }

  Future<List<DbPlaybackHistory>> getRecentPlaybackUnique({int limit = 20}) async {
    final result = await (select(playbackHistory)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)])
          ..limit(limit * 3))
        .get();

    return _filterUnique(result, limit);
  }

  Stream<List<DbPlaybackHistory>> watchRecentPlaybackUnique({int limit = 20}) {
    return (select(playbackHistory)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)])
          ..limit(limit * 3))
        .watch()
        .map((result) => _filterUnique(result, limit));
  }

  List<DbPlaybackHistory> _filterUnique(List<DbPlaybackHistory> result, int limit) {
    final Set<String> seen = {};
    final List<DbPlaybackHistory> unique = [];
    for (final h in result) {
      final key = '${h.trackTitle}-${h.artist}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(h);
      }
      if (unique.length >= limit) break;
    }
    return unique;
  }

  Future<DbTrackMetadata?> getTrackMetadata(int torrentId, int fileId) {
    return (select(trackMetadata)
          ..where((t) => t.torrentId.equals(torrentId) & t.fileId.equals(fileId)))
        .getSingleOrNull();
  }

  Future<List<DbTrackMetadata>> getLikedTracks() {
    return (select(trackMetadata)..where((t) => t.isLiked.equals(true))).get();
  }

  Future<void> toggleTrackLike(int torrentId, int fileId, bool isLiked, {String? title, String? artist, String? artworkUrlLow, String? artworkUrlHigh, String? album}) async {
    final existing = await (select(trackMetadata)
          ..where((t) => t.torrentId.equals(torrentId) & t.fileId.equals(fileId)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(trackMetadata)
            ..where((t) => t.torrentId.equals(torrentId) & t.fileId.equals(fileId)))
          .write(TrackMetadataCompanion(isLiked: Value(isLiked)));
    } else {
      await into(trackMetadata).insert(TrackMetadataCompanion.insert(
        torrentId: torrentId,
        fileId: fileId,
        trackTitle: Value(title ?? 'Unknown Track'),
        artist: Value(artist ?? 'Unknown Artist'),
        album: Value(album ?? ''),
        artworkUrlLow: Value(artworkUrlLow),
        artworkUrlHigh: Value(artworkUrlHigh),
        isLiked: Value(isLiked),
      ));
    }

    if (isLiked) {
      final existingFile = await (select(files)
            ..where((f) => f.torrentId.equals(torrentId) & f.id.equals(fileId)))
          .getSingleOrNull();
      if (existingFile == null) {
        await into(files).insert(FilesCompanion.insert(
          id: fileId,
          torrentId: torrentId,
          name: title ?? 'Unknown Track',
          size: 0,
          isAudio: true,
        ));
      }
    }
  }

  Future<void> updateFileLocalPath(int torrentId, int fileId, String? path) async {
    await (update(files)
          ..where((t) => t.torrentId.equals(torrentId) & t.id.equals(fileId)))
        .write(FilesCompanion(localPath: Value(path)));
  }

  Future<void> clearAllLocalPaths() async {
    await (update(files)).write(const FilesCompanion(localPath: Value(null)));
    await (delete(files)..where((t) => t.torrentId.equals(-1))).go();
  }

  Future<void> clearAllLibraryData() async {
    await transaction(() async {
      await delete(torrents).go();
      await delete(files).go();
      await delete(trackMetadata).go();
      await delete(syncMeta).go();
    });
  }

  // --- Playlists ---

  Future<int> createPlaylist(PlaylistsCompanion entry) => into(playlists).insert(entry);

  Future<bool> checkTrackInPlaylist({
    required int playlistId,
    String? youtubeId,
    int? torrentId,
    int? fileId,
  }) async {
    final query = select(playlistTracks)..where((t) => t.playlistId.equals(playlistId));
    if (youtubeId != null && youtubeId.isNotEmpty) {
      query.where((t) => t.youtubeId.equals(youtubeId));
    } else if (torrentId != null && fileId != null) {
      query.where((t) => t.torrentId.equals(torrentId) & t.fileId.equals(fileId));
    } else {
      return false;
    }
    final result = await query.get();
    return result.isNotEmpty;
  }
  
  Future<void> addTracksToPlaylist(List<PlaylistTracksCompanion> tracks) async {
    await batch((batch) {
      batch.insertAll(playlistTracks, tracks);
    });
  }

  Future<List<DbPlaylist>> getAllPlaylists() => select(this.playlists).get();
  
  Stream<List<DbPlaylist>> watchAllPlaylists() => select(this.playlists).watch();

  Future<Map<int, int>> getPlaylistSongCounts() async {
    final query = selectOnly(playlistTracks)
      ..addColumns([playlistTracks.playlistId, playlistTracks.playlistId.count()]);
    query.groupBy([playlistTracks.playlistId]);
    
    final result = await query.get();
    return {for (final row in result) row.read(playlistTracks.playlistId)!: row.read(playlistTracks.playlistId.count())!};
  }

  Future<List<DbPlaylistTrack>> getPlaylistTracks(int playlistId) {
    return (select(playlistTracks)..where((t) => t.playlistId.equals(playlistId))).get();
  }

  Stream<List<DbPlaylistTrack>> watchPlaylistTracks(int playlistId) {
    return (select(playlistTracks)..where((t) => t.playlistId.equals(playlistId))).watch();
  }

  Stream<List<DbPlaylistTrack>> watchAllPlaylistTracks() => select(playlistTracks).watch();

  Future<void> updatePlaylistTrack(PlaylistTracksCompanion companion) {
    return (update(playlistTracks)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<void> deletePlaylistTrack(int id) {
    return (delete(playlistTracks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deletePlaylist(int id) async {
    await (delete(playlists)..where((t) => t.id.equals(id))).go();
  }

  // --- External Track Metadata Cache ---

  Future<void> saveExternalTrackMetadata(ExternalTrackMetadataCompanion entry) async {
    await into(externalTrackMetadata).insertOnConflictUpdate(entry);
  }

  Future<DbExternalTrackMetadata?> getExternalTrackMetadata(String trackUrl) {
    return (select(externalTrackMetadata)..where((t) => t.trackUrl.equals(trackUrl))).getSingleOrNull();
  }

  // --- Sync helpers ---
  
  Future<DbSyncMeta?> getSyncMeta() async {
    final result = await (select(syncMeta)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (result == null) {
      await into(syncMeta).insert(SyncMetaCompanion.insert(id: const Value(1)));
      return getSyncMeta();
    }
    return result;
  }

  Future<void> updateLibrarySync() async {
    await (update(syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(lastLibrarySync: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  Future<void> updateTopSongsSync(String cachedJson) async {
    await (update(syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(
          lastTopSongsSync: Value(DateTime.now().millisecondsSinceEpoch),
          cachedTopSongs: Value(cachedJson),
        ));
  }

  Future<void> updateTopAlbumsSync(String cachedJson) async {
    await (update(syncMeta)..where((t) => t.id.equals(1)))
        .write(SyncMetaCompanion(
          lastTopAlbumsSync: Value(DateTime.now().millisecondsSinceEpoch),
          cachedTopAlbums: Value(cachedJson),
        ));
  }

  // --- Followed Artists ---
  
  Future<void> followArtist(FollowedArtistsCompanion entry) => into(followedArtists).insertOnConflictUpdate(entry);
  Future<void> unfollowArtist(int artistId) => (delete(followedArtists)..where((t) => t.id.equals(artistId))).go();
  Future<List<DbFollowedArtist>> getAllFollowedArtists() => select(followedArtists).get();
  Stream<List<DbFollowedArtist>> watchFollowedArtists() => select(followedArtists).watch();
  Future<DbFollowedArtist?> getFollowedArtist(int artistId) => (select(followedArtists)..where((t) => t.id.equals(artistId))).getSingleOrNull();

  bool shouldRefreshLibrary(int? lastSync, {int minIntervalMinutes = 30}) {
    if (lastSync == null) return true;
    final diff = DateTime.now().millisecondsSinceEpoch - lastSync;
    return diff > (minIntervalMinutes * 60 * 1000);
  }

  // ─── AUDIOBOOK DATA (Isolated from Music) ─────────────────────────────────

  /// Save or update audiobook listening progress.
  Future<void> saveAudiobookProgress(AudiobookProgressCompanion entry) async {
    // Check if progress exists for this book+chapter combo
    final existing = await (select(audiobookProgress)
          ..where((t) => t.bookId.equals(entry.bookId.value) & t.chapterIndex.equals(entry.chapterIndex.value)))
        .getSingleOrNull();
    
    if (existing != null) {
      await (update(audiobookProgress)
            ..where((t) => t.id.equals(existing.id)))
          .write(entry);
    } else {
      await into(audiobookProgress).insert(entry);
    }
  }

  /// Get progress for a specific chapter of a book.
  Future<DbAudiobookProgress?> getAudiobookProgress(String bookId, int chapterIndex) {
    return (select(audiobookProgress)
          ..where((t) => t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex)))
        .getSingleOrNull();
  }

  /// Get the most recently listened chapter for a book.
  Future<DbAudiobookProgress?> getLatestAudiobookProgress(String bookId) {
    return (select(audiobookProgress)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm(expression: t.lastListenedAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get all audiobook progress entries, ordered by most recent.
  /// Used for the "Continue Listening" section.
  Future<List<DbAudiobookProgress>> getAllAudiobookProgress() {
    return (select(audiobookProgress)
          ..orderBy([(t) => OrderingTerm(expression: t.lastListenedAt, mode: OrderingMode.desc)]))
         .get();
  }

  Stream<List<DbAudiobookProgress>> watchAllAudiobookProgress() {
    return (select(audiobookProgress)
          ..orderBy([(t) => OrderingTerm(expression: t.lastListenedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Get all chapter progress entries for a specific book.
  Future<List<DbAudiobookProgress>> getBookChapterProgress(String bookId) {
    return (select(audiobookProgress)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm(expression: t.chapterIndex, mode: OrderingMode.asc)]))
        .get();
  }

  /// Clear all progress for a specific book.
  Future<void> clearAudiobookProgress(String bookId) {
    return (delete(audiobookProgress)..where((t) => t.bookId.equals(bookId))).go();
  }

  /// Save audiobook metadata to local cache.
  Future<void> saveAudiobookMetadataEntry(AudiobookMetadataCacheCompanion entry) {
    return into(audiobookMetadataCache).insertOnConflictUpdate(entry);
  }

  /// Get cached audiobook metadata.
  Future<DbAudiobookMetadataCache?> getAudiobookMetadata(String bookId) {
    return (select(audiobookMetadataCache)
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  /// Delete cached audiobook metadata.
  Future<int> deleteAudiobookMetadata(String bookId) {
    return (delete(audiobookMetadataCache)..where((t) => t.bookId.equals(bookId))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (io.Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = io.File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
