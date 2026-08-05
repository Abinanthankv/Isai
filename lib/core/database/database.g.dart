// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TorrentsTable extends Torrents
    with TableInfo<$TorrentsTable, DbTorrent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TorrentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedMeta = const VerificationMeta('cached');
  @override
  late final GeneratedColumn<bool> cached = GeneratedColumn<bool>(
    'cached',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cached" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, hash, cached];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'torrents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbTorrent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('cached')) {
      context.handle(
        _cachedMeta,
        cached.isAcceptableOrUnknown(data['cached']!, _cachedMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbTorrent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbTorrent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      cached: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cached'],
      )!,
    );
  }

  @override
  $TorrentsTable createAlias(String alias) {
    return $TorrentsTable(attachedDatabase, alias);
  }
}

class DbTorrent extends DataClass implements Insertable<DbTorrent> {
  final int id;
  final String name;
  final String hash;
  final bool cached;
  const DbTorrent({
    required this.id,
    required this.name,
    required this.hash,
    required this.cached,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['hash'] = Variable<String>(hash);
    map['cached'] = Variable<bool>(cached);
    return map;
  }

  TorrentsCompanion toCompanion(bool nullToAbsent) {
    return TorrentsCompanion(
      id: Value(id),
      name: Value(name),
      hash: Value(hash),
      cached: Value(cached),
    );
  }

  factory DbTorrent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbTorrent(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      hash: serializer.fromJson<String>(json['hash']),
      cached: serializer.fromJson<bool>(json['cached']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'hash': serializer.toJson<String>(hash),
      'cached': serializer.toJson<bool>(cached),
    };
  }

  DbTorrent copyWith({int? id, String? name, String? hash, bool? cached}) =>
      DbTorrent(
        id: id ?? this.id,
        name: name ?? this.name,
        hash: hash ?? this.hash,
        cached: cached ?? this.cached,
      );
  DbTorrent copyWithCompanion(TorrentsCompanion data) {
    return DbTorrent(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      hash: data.hash.present ? data.hash.value : this.hash,
      cached: data.cached.present ? data.cached.value : this.cached,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbTorrent(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hash: $hash, ')
          ..write('cached: $cached')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, hash, cached);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbTorrent &&
          other.id == this.id &&
          other.name == this.name &&
          other.hash == this.hash &&
          other.cached == this.cached);
}

class TorrentsCompanion extends UpdateCompanion<DbTorrent> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> hash;
  final Value<bool> cached;
  const TorrentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.hash = const Value.absent(),
    this.cached = const Value.absent(),
  });
  TorrentsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String hash,
    required bool cached,
  }) : name = Value(name),
       hash = Value(hash),
       cached = Value(cached);
  static Insertable<DbTorrent> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? hash,
    Expression<bool>? cached,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (hash != null) 'hash': hash,
      if (cached != null) 'cached': cached,
    });
  }

  TorrentsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? hash,
    Value<bool>? cached,
  }) {
    return TorrentsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      hash: hash ?? this.hash,
      cached: cached ?? this.cached,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (cached.present) {
      map['cached'] = Variable<bool>(cached.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TorrentsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hash: $hash, ')
          ..write('cached: $cached')
          ..write(')'))
        .toString();
  }
}

class $FilesTable extends Files with TableInfo<$FilesTable, DbFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _torrentIdMeta = const VerificationMeta(
    'torrentId',
  );
  @override
  late final GeneratedColumn<int> torrentId = GeneratedColumn<int>(
    'torrent_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAudioMeta = const VerificationMeta(
    'isAudio',
  );
  @override
  late final GeneratedColumn<bool> isAudio = GeneratedColumn<bool>(
    'is_audio',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_audio" IN (0, 1))',
    ),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    torrentId,
    name,
    size,
    isAudio,
    localPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'files';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('torrent_id')) {
      context.handle(
        _torrentIdMeta,
        torrentId.isAcceptableOrUnknown(data['torrent_id']!, _torrentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_torrentIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('is_audio')) {
      context.handle(
        _isAudioMeta,
        isAudio.isAcceptableOrUnknown(data['is_audio']!, _isAudioMeta),
      );
    } else if (isInserting) {
      context.missing(_isAudioMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, torrentId};
  @override
  DbFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      torrentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}torrent_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      isAudio: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_audio'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
    );
  }

  @override
  $FilesTable createAlias(String alias) {
    return $FilesTable(attachedDatabase, alias);
  }
}

class DbFile extends DataClass implements Insertable<DbFile> {
  final int id;
  final int torrentId;
  final String name;
  final int size;
  final bool isAudio;
  final String? localPath;
  const DbFile({
    required this.id,
    required this.torrentId,
    required this.name,
    required this.size,
    required this.isAudio,
    this.localPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['torrent_id'] = Variable<int>(torrentId);
    map['name'] = Variable<String>(name);
    map['size'] = Variable<int>(size);
    map['is_audio'] = Variable<bool>(isAudio);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    return map;
  }

  FilesCompanion toCompanion(bool nullToAbsent) {
    return FilesCompanion(
      id: Value(id),
      torrentId: Value(torrentId),
      name: Value(name),
      size: Value(size),
      isAudio: Value(isAudio),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
    );
  }

  factory DbFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbFile(
      id: serializer.fromJson<int>(json['id']),
      torrentId: serializer.fromJson<int>(json['torrentId']),
      name: serializer.fromJson<String>(json['name']),
      size: serializer.fromJson<int>(json['size']),
      isAudio: serializer.fromJson<bool>(json['isAudio']),
      localPath: serializer.fromJson<String?>(json['localPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'torrentId': serializer.toJson<int>(torrentId),
      'name': serializer.toJson<String>(name),
      'size': serializer.toJson<int>(size),
      'isAudio': serializer.toJson<bool>(isAudio),
      'localPath': serializer.toJson<String?>(localPath),
    };
  }

  DbFile copyWith({
    int? id,
    int? torrentId,
    String? name,
    int? size,
    bool? isAudio,
    Value<String?> localPath = const Value.absent(),
  }) => DbFile(
    id: id ?? this.id,
    torrentId: torrentId ?? this.torrentId,
    name: name ?? this.name,
    size: size ?? this.size,
    isAudio: isAudio ?? this.isAudio,
    localPath: localPath.present ? localPath.value : this.localPath,
  );
  DbFile copyWithCompanion(FilesCompanion data) {
    return DbFile(
      id: data.id.present ? data.id.value : this.id,
      torrentId: data.torrentId.present ? data.torrentId.value : this.torrentId,
      name: data.name.present ? data.name.value : this.name,
      size: data.size.present ? data.size.value : this.size,
      isAudio: data.isAudio.present ? data.isAudio.value : this.isAudio,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbFile(')
          ..write('id: $id, ')
          ..write('torrentId: $torrentId, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('isAudio: $isAudio, ')
          ..write('localPath: $localPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, torrentId, name, size, isAudio, localPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbFile &&
          other.id == this.id &&
          other.torrentId == this.torrentId &&
          other.name == this.name &&
          other.size == this.size &&
          other.isAudio == this.isAudio &&
          other.localPath == this.localPath);
}

class FilesCompanion extends UpdateCompanion<DbFile> {
  final Value<int> id;
  final Value<int> torrentId;
  final Value<String> name;
  final Value<int> size;
  final Value<bool> isAudio;
  final Value<String?> localPath;
  final Value<int> rowid;
  const FilesCompanion({
    this.id = const Value.absent(),
    this.torrentId = const Value.absent(),
    this.name = const Value.absent(),
    this.size = const Value.absent(),
    this.isAudio = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FilesCompanion.insert({
    required int id,
    required int torrentId,
    required String name,
    required int size,
    required bool isAudio,
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       torrentId = Value(torrentId),
       name = Value(name),
       size = Value(size),
       isAudio = Value(isAudio);
  static Insertable<DbFile> custom({
    Expression<int>? id,
    Expression<int>? torrentId,
    Expression<String>? name,
    Expression<int>? size,
    Expression<bool>? isAudio,
    Expression<String>? localPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (torrentId != null) 'torrent_id': torrentId,
      if (name != null) 'name': name,
      if (size != null) 'size': size,
      if (isAudio != null) 'is_audio': isAudio,
      if (localPath != null) 'local_path': localPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FilesCompanion copyWith({
    Value<int>? id,
    Value<int>? torrentId,
    Value<String>? name,
    Value<int>? size,
    Value<bool>? isAudio,
    Value<String?>? localPath,
    Value<int>? rowid,
  }) {
    return FilesCompanion(
      id: id ?? this.id,
      torrentId: torrentId ?? this.torrentId,
      name: name ?? this.name,
      size: size ?? this.size,
      isAudio: isAudio ?? this.isAudio,
      localPath: localPath ?? this.localPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (torrentId.present) {
      map['torrent_id'] = Variable<int>(torrentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (isAudio.present) {
      map['is_audio'] = Variable<bool>(isAudio.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilesCompanion(')
          ..write('id: $id, ')
          ..write('torrentId: $torrentId, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('isAudio: $isAudio, ')
          ..write('localPath: $localPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackMetadataTable extends TrackMetadata
    with TableInfo<$TrackMetadataTable, DbTrackMetadata> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<int> fileId = GeneratedColumn<int>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _torrentIdMeta = const VerificationMeta(
    'torrentId',
  );
  @override
  late final GeneratedColumn<int> torrentId = GeneratedColumn<int>(
    'torrent_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackTitleMeta = const VerificationMeta(
    'trackTitle',
  );
  @override
  late final GeneratedColumn<String> trackTitle = GeneratedColumn<String>(
    'track_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseYearMeta = const VerificationMeta(
    'releaseYear',
  );
  @override
  late final GeneratedColumn<int> releaseYear = GeneratedColumn<int>(
    'release_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlLowMeta = const VerificationMeta(
    'artworkUrlLow',
  );
  @override
  late final GeneratedColumn<String> artworkUrlLow = GeneratedColumn<String>(
    'artwork_url_low',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlHighMeta = const VerificationMeta(
    'artworkUrlHigh',
  );
  @override
  late final GeneratedColumn<String> artworkUrlHigh = GeneratedColumn<String>(
    'artwork_url_high',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackTimeMillisMeta = const VerificationMeta(
    'trackTimeMillis',
  );
  @override
  late final GeneratedColumn<int> trackTimeMillis = GeneratedColumn<int>(
    'track_time_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLikedMeta = const VerificationMeta(
    'isLiked',
  );
  @override
  late final GeneratedColumn<bool> isLiked = GeneratedColumn<bool>(
    'is_liked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_liked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileId,
    torrentId,
    trackTitle,
    artist,
    album,
    genre,
    releaseYear,
    artworkUrlLow,
    artworkUrlHigh,
    trackTimeMillis,
    isLiked,
    isrc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbTrackMetadata> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('torrent_id')) {
      context.handle(
        _torrentIdMeta,
        torrentId.isAcceptableOrUnknown(data['torrent_id']!, _torrentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_torrentIdMeta);
    }
    if (data.containsKey('track_title')) {
      context.handle(
        _trackTitleMeta,
        trackTitle.isAcceptableOrUnknown(data['track_title']!, _trackTitleMeta),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('release_year')) {
      context.handle(
        _releaseYearMeta,
        releaseYear.isAcceptableOrUnknown(
          data['release_year']!,
          _releaseYearMeta,
        ),
      );
    }
    if (data.containsKey('artwork_url_low')) {
      context.handle(
        _artworkUrlLowMeta,
        artworkUrlLow.isAcceptableOrUnknown(
          data['artwork_url_low']!,
          _artworkUrlLowMeta,
        ),
      );
    }
    if (data.containsKey('artwork_url_high')) {
      context.handle(
        _artworkUrlHighMeta,
        artworkUrlHigh.isAcceptableOrUnknown(
          data['artwork_url_high']!,
          _artworkUrlHighMeta,
        ),
      );
    }
    if (data.containsKey('track_time_millis')) {
      context.handle(
        _trackTimeMillisMeta,
        trackTimeMillis.isAcceptableOrUnknown(
          data['track_time_millis']!,
          _trackTimeMillisMeta,
        ),
      );
    }
    if (data.containsKey('is_liked')) {
      context.handle(
        _isLikedMeta,
        isLiked.isAcceptableOrUnknown(data['is_liked']!, _isLikedMeta),
      );
    }
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileId, torrentId};
  @override
  DbTrackMetadata map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbTrackMetadata(
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_id'],
      )!,
      torrentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}torrent_id'],
      )!,
      trackTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_title'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      releaseYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}release_year'],
      ),
      artworkUrlLow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url_low'],
      ),
      artworkUrlHigh: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url_high'],
      ),
      trackTimeMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_time_millis'],
      ),
      isLiked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_liked'],
      )!,
      isrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isrc'],
      ),
    );
  }

  @override
  $TrackMetadataTable createAlias(String alias) {
    return $TrackMetadataTable(attachedDatabase, alias);
  }
}

class DbTrackMetadata extends DataClass implements Insertable<DbTrackMetadata> {
  final int fileId;
  final int torrentId;
  final String? trackTitle;
  final String? artist;
  final String? album;
  final String? genre;
  final int? releaseYear;
  final String? artworkUrlLow;
  final String? artworkUrlHigh;
  final int? trackTimeMillis;
  final bool isLiked;
  final String? isrc;
  const DbTrackMetadata({
    required this.fileId,
    required this.torrentId,
    this.trackTitle,
    this.artist,
    this.album,
    this.genre,
    this.releaseYear,
    this.artworkUrlLow,
    this.artworkUrlHigh,
    this.trackTimeMillis,
    required this.isLiked,
    this.isrc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_id'] = Variable<int>(fileId);
    map['torrent_id'] = Variable<int>(torrentId);
    if (!nullToAbsent || trackTitle != null) {
      map['track_title'] = Variable<String>(trackTitle);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || releaseYear != null) {
      map['release_year'] = Variable<int>(releaseYear);
    }
    if (!nullToAbsent || artworkUrlLow != null) {
      map['artwork_url_low'] = Variable<String>(artworkUrlLow);
    }
    if (!nullToAbsent || artworkUrlHigh != null) {
      map['artwork_url_high'] = Variable<String>(artworkUrlHigh);
    }
    if (!nullToAbsent || trackTimeMillis != null) {
      map['track_time_millis'] = Variable<int>(trackTimeMillis);
    }
    map['is_liked'] = Variable<bool>(isLiked);
    if (!nullToAbsent || isrc != null) {
      map['isrc'] = Variable<String>(isrc);
    }
    return map;
  }

  TrackMetadataCompanion toCompanion(bool nullToAbsent) {
    return TrackMetadataCompanion(
      fileId: Value(fileId),
      torrentId: Value(torrentId),
      trackTitle: trackTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(trackTitle),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      releaseYear: releaseYear == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseYear),
      artworkUrlLow: artworkUrlLow == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrlLow),
      artworkUrlHigh: artworkUrlHigh == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrlHigh),
      trackTimeMillis: trackTimeMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(trackTimeMillis),
      isLiked: Value(isLiked),
      isrc: isrc == null && nullToAbsent ? const Value.absent() : Value(isrc),
    );
  }

  factory DbTrackMetadata.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbTrackMetadata(
      fileId: serializer.fromJson<int>(json['fileId']),
      torrentId: serializer.fromJson<int>(json['torrentId']),
      trackTitle: serializer.fromJson<String?>(json['trackTitle']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      genre: serializer.fromJson<String?>(json['genre']),
      releaseYear: serializer.fromJson<int?>(json['releaseYear']),
      artworkUrlLow: serializer.fromJson<String?>(json['artworkUrlLow']),
      artworkUrlHigh: serializer.fromJson<String?>(json['artworkUrlHigh']),
      trackTimeMillis: serializer.fromJson<int?>(json['trackTimeMillis']),
      isLiked: serializer.fromJson<bool>(json['isLiked']),
      isrc: serializer.fromJson<String?>(json['isrc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileId': serializer.toJson<int>(fileId),
      'torrentId': serializer.toJson<int>(torrentId),
      'trackTitle': serializer.toJson<String?>(trackTitle),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'genre': serializer.toJson<String?>(genre),
      'releaseYear': serializer.toJson<int?>(releaseYear),
      'artworkUrlLow': serializer.toJson<String?>(artworkUrlLow),
      'artworkUrlHigh': serializer.toJson<String?>(artworkUrlHigh),
      'trackTimeMillis': serializer.toJson<int?>(trackTimeMillis),
      'isLiked': serializer.toJson<bool>(isLiked),
      'isrc': serializer.toJson<String?>(isrc),
    };
  }

  DbTrackMetadata copyWith({
    int? fileId,
    int? torrentId,
    Value<String?> trackTitle = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> releaseYear = const Value.absent(),
    Value<String?> artworkUrlLow = const Value.absent(),
    Value<String?> artworkUrlHigh = const Value.absent(),
    Value<int?> trackTimeMillis = const Value.absent(),
    bool? isLiked,
    Value<String?> isrc = const Value.absent(),
  }) => DbTrackMetadata(
    fileId: fileId ?? this.fileId,
    torrentId: torrentId ?? this.torrentId,
    trackTitle: trackTitle.present ? trackTitle.value : this.trackTitle,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    genre: genre.present ? genre.value : this.genre,
    releaseYear: releaseYear.present ? releaseYear.value : this.releaseYear,
    artworkUrlLow: artworkUrlLow.present
        ? artworkUrlLow.value
        : this.artworkUrlLow,
    artworkUrlHigh: artworkUrlHigh.present
        ? artworkUrlHigh.value
        : this.artworkUrlHigh,
    trackTimeMillis: trackTimeMillis.present
        ? trackTimeMillis.value
        : this.trackTimeMillis,
    isLiked: isLiked ?? this.isLiked,
    isrc: isrc.present ? isrc.value : this.isrc,
  );
  DbTrackMetadata copyWithCompanion(TrackMetadataCompanion data) {
    return DbTrackMetadata(
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      torrentId: data.torrentId.present ? data.torrentId.value : this.torrentId,
      trackTitle: data.trackTitle.present
          ? data.trackTitle.value
          : this.trackTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      genre: data.genre.present ? data.genre.value : this.genre,
      releaseYear: data.releaseYear.present
          ? data.releaseYear.value
          : this.releaseYear,
      artworkUrlLow: data.artworkUrlLow.present
          ? data.artworkUrlLow.value
          : this.artworkUrlLow,
      artworkUrlHigh: data.artworkUrlHigh.present
          ? data.artworkUrlHigh.value
          : this.artworkUrlHigh,
      trackTimeMillis: data.trackTimeMillis.present
          ? data.trackTimeMillis.value
          : this.trackTimeMillis,
      isLiked: data.isLiked.present ? data.isLiked.value : this.isLiked,
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbTrackMetadata(')
          ..write('fileId: $fileId, ')
          ..write('torrentId: $torrentId, ')
          ..write('trackTitle: $trackTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('artworkUrlLow: $artworkUrlLow, ')
          ..write('artworkUrlHigh: $artworkUrlHigh, ')
          ..write('trackTimeMillis: $trackTimeMillis, ')
          ..write('isLiked: $isLiked, ')
          ..write('isrc: $isrc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fileId,
    torrentId,
    trackTitle,
    artist,
    album,
    genre,
    releaseYear,
    artworkUrlLow,
    artworkUrlHigh,
    trackTimeMillis,
    isLiked,
    isrc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbTrackMetadata &&
          other.fileId == this.fileId &&
          other.torrentId == this.torrentId &&
          other.trackTitle == this.trackTitle &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.genre == this.genre &&
          other.releaseYear == this.releaseYear &&
          other.artworkUrlLow == this.artworkUrlLow &&
          other.artworkUrlHigh == this.artworkUrlHigh &&
          other.trackTimeMillis == this.trackTimeMillis &&
          other.isLiked == this.isLiked &&
          other.isrc == this.isrc);
}

class TrackMetadataCompanion extends UpdateCompanion<DbTrackMetadata> {
  final Value<int> fileId;
  final Value<int> torrentId;
  final Value<String?> trackTitle;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String?> genre;
  final Value<int?> releaseYear;
  final Value<String?> artworkUrlLow;
  final Value<String?> artworkUrlHigh;
  final Value<int?> trackTimeMillis;
  final Value<bool> isLiked;
  final Value<String?> isrc;
  final Value<int> rowid;
  const TrackMetadataCompanion({
    this.fileId = const Value.absent(),
    this.torrentId = const Value.absent(),
    this.trackTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.artworkUrlLow = const Value.absent(),
    this.artworkUrlHigh = const Value.absent(),
    this.trackTimeMillis = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.isrc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackMetadataCompanion.insert({
    required int fileId,
    required int torrentId,
    this.trackTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.artworkUrlLow = const Value.absent(),
    this.artworkUrlHigh = const Value.absent(),
    this.trackTimeMillis = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.isrc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fileId = Value(fileId),
       torrentId = Value(torrentId);
  static Insertable<DbTrackMetadata> custom({
    Expression<int>? fileId,
    Expression<int>? torrentId,
    Expression<String>? trackTitle,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? genre,
    Expression<int>? releaseYear,
    Expression<String>? artworkUrlLow,
    Expression<String>? artworkUrlHigh,
    Expression<int>? trackTimeMillis,
    Expression<bool>? isLiked,
    Expression<String>? isrc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileId != null) 'file_id': fileId,
      if (torrentId != null) 'torrent_id': torrentId,
      if (trackTitle != null) 'track_title': trackTitle,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (genre != null) 'genre': genre,
      if (releaseYear != null) 'release_year': releaseYear,
      if (artworkUrlLow != null) 'artwork_url_low': artworkUrlLow,
      if (artworkUrlHigh != null) 'artwork_url_high': artworkUrlHigh,
      if (trackTimeMillis != null) 'track_time_millis': trackTimeMillis,
      if (isLiked != null) 'is_liked': isLiked,
      if (isrc != null) 'isrc': isrc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackMetadataCompanion copyWith({
    Value<int>? fileId,
    Value<int>? torrentId,
    Value<String?>? trackTitle,
    Value<String?>? artist,
    Value<String?>? album,
    Value<String?>? genre,
    Value<int?>? releaseYear,
    Value<String?>? artworkUrlLow,
    Value<String?>? artworkUrlHigh,
    Value<int?>? trackTimeMillis,
    Value<bool>? isLiked,
    Value<String?>? isrc,
    Value<int>? rowid,
  }) {
    return TrackMetadataCompanion(
      fileId: fileId ?? this.fileId,
      torrentId: torrentId ?? this.torrentId,
      trackTitle: trackTitle ?? this.trackTitle,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      releaseYear: releaseYear ?? this.releaseYear,
      artworkUrlLow: artworkUrlLow ?? this.artworkUrlLow,
      artworkUrlHigh: artworkUrlHigh ?? this.artworkUrlHigh,
      trackTimeMillis: trackTimeMillis ?? this.trackTimeMillis,
      isLiked: isLiked ?? this.isLiked,
      isrc: isrc ?? this.isrc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileId.present) {
      map['file_id'] = Variable<int>(fileId.value);
    }
    if (torrentId.present) {
      map['torrent_id'] = Variable<int>(torrentId.value);
    }
    if (trackTitle.present) {
      map['track_title'] = Variable<String>(trackTitle.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (releaseYear.present) {
      map['release_year'] = Variable<int>(releaseYear.value);
    }
    if (artworkUrlLow.present) {
      map['artwork_url_low'] = Variable<String>(artworkUrlLow.value);
    }
    if (artworkUrlHigh.present) {
      map['artwork_url_high'] = Variable<String>(artworkUrlHigh.value);
    }
    if (trackTimeMillis.present) {
      map['track_time_millis'] = Variable<int>(trackTimeMillis.value);
    }
    if (isLiked.present) {
      map['is_liked'] = Variable<bool>(isLiked.value);
    }
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackMetadataCompanion(')
          ..write('fileId: $fileId, ')
          ..write('torrentId: $torrentId, ')
          ..write('trackTitle: $trackTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('artworkUrlLow: $artworkUrlLow, ')
          ..write('artworkUrlHigh: $artworkUrlHigh, ')
          ..write('trackTimeMillis: $trackTimeMillis, ')
          ..write('isLiked: $isLiked, ')
          ..write('isrc: $isrc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, DbSyncMeta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastLibrarySyncMeta = const VerificationMeta(
    'lastLibrarySync',
  );
  @override
  late final GeneratedColumn<int> lastLibrarySync = GeneratedColumn<int>(
    'last_library_sync',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastTopSongsSyncMeta = const VerificationMeta(
    'lastTopSongsSync',
  );
  @override
  late final GeneratedColumn<int> lastTopSongsSync = GeneratedColumn<int>(
    'last_top_songs_sync',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastTopAlbumsSyncMeta = const VerificationMeta(
    'lastTopAlbumsSync',
  );
  @override
  late final GeneratedColumn<int> lastTopAlbumsSync = GeneratedColumn<int>(
    'last_top_albums_sync',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedTopSongsMeta = const VerificationMeta(
    'cachedTopSongs',
  );
  @override
  late final GeneratedColumn<String> cachedTopSongs = GeneratedColumn<String>(
    'cached_top_songs',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedTopAlbumsMeta = const VerificationMeta(
    'cachedTopAlbums',
  );
  @override
  late final GeneratedColumn<String> cachedTopAlbums = GeneratedColumn<String>(
    'cached_top_albums',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lastLibrarySync,
    lastTopSongsSync,
    lastTopAlbumsSync,
    cachedTopSongs,
    cachedTopAlbums,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbSyncMeta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_library_sync')) {
      context.handle(
        _lastLibrarySyncMeta,
        lastLibrarySync.isAcceptableOrUnknown(
          data['last_library_sync']!,
          _lastLibrarySyncMeta,
        ),
      );
    }
    if (data.containsKey('last_top_songs_sync')) {
      context.handle(
        _lastTopSongsSyncMeta,
        lastTopSongsSync.isAcceptableOrUnknown(
          data['last_top_songs_sync']!,
          _lastTopSongsSyncMeta,
        ),
      );
    }
    if (data.containsKey('last_top_albums_sync')) {
      context.handle(
        _lastTopAlbumsSyncMeta,
        lastTopAlbumsSync.isAcceptableOrUnknown(
          data['last_top_albums_sync']!,
          _lastTopAlbumsSyncMeta,
        ),
      );
    }
    if (data.containsKey('cached_top_songs')) {
      context.handle(
        _cachedTopSongsMeta,
        cachedTopSongs.isAcceptableOrUnknown(
          data['cached_top_songs']!,
          _cachedTopSongsMeta,
        ),
      );
    }
    if (data.containsKey('cached_top_albums')) {
      context.handle(
        _cachedTopAlbumsMeta,
        cachedTopAlbums.isAcceptableOrUnknown(
          data['cached_top_albums']!,
          _cachedTopAlbumsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbSyncMeta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbSyncMeta(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastLibrarySync: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_library_sync'],
      ),
      lastTopSongsSync: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_top_songs_sync'],
      ),
      lastTopAlbumsSync: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_top_albums_sync'],
      ),
      cachedTopSongs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cached_top_songs'],
      ),
      cachedTopAlbums: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cached_top_albums'],
      ),
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class DbSyncMeta extends DataClass implements Insertable<DbSyncMeta> {
  final int id;
  final int? lastLibrarySync;
  final int? lastTopSongsSync;
  final int? lastTopAlbumsSync;
  final String? cachedTopSongs;
  final String? cachedTopAlbums;
  const DbSyncMeta({
    required this.id,
    this.lastLibrarySync,
    this.lastTopSongsSync,
    this.lastTopAlbumsSync,
    this.cachedTopSongs,
    this.cachedTopAlbums,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lastLibrarySync != null) {
      map['last_library_sync'] = Variable<int>(lastLibrarySync);
    }
    if (!nullToAbsent || lastTopSongsSync != null) {
      map['last_top_songs_sync'] = Variable<int>(lastTopSongsSync);
    }
    if (!nullToAbsent || lastTopAlbumsSync != null) {
      map['last_top_albums_sync'] = Variable<int>(lastTopAlbumsSync);
    }
    if (!nullToAbsent || cachedTopSongs != null) {
      map['cached_top_songs'] = Variable<String>(cachedTopSongs);
    }
    if (!nullToAbsent || cachedTopAlbums != null) {
      map['cached_top_albums'] = Variable<String>(cachedTopAlbums);
    }
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      id: Value(id),
      lastLibrarySync: lastLibrarySync == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLibrarySync),
      lastTopSongsSync: lastTopSongsSync == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTopSongsSync),
      lastTopAlbumsSync: lastTopAlbumsSync == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTopAlbumsSync),
      cachedTopSongs: cachedTopSongs == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedTopSongs),
      cachedTopAlbums: cachedTopAlbums == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedTopAlbums),
    );
  }

  factory DbSyncMeta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbSyncMeta(
      id: serializer.fromJson<int>(json['id']),
      lastLibrarySync: serializer.fromJson<int?>(json['lastLibrarySync']),
      lastTopSongsSync: serializer.fromJson<int?>(json['lastTopSongsSync']),
      lastTopAlbumsSync: serializer.fromJson<int?>(json['lastTopAlbumsSync']),
      cachedTopSongs: serializer.fromJson<String?>(json['cachedTopSongs']),
      cachedTopAlbums: serializer.fromJson<String?>(json['cachedTopAlbums']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastLibrarySync': serializer.toJson<int?>(lastLibrarySync),
      'lastTopSongsSync': serializer.toJson<int?>(lastTopSongsSync),
      'lastTopAlbumsSync': serializer.toJson<int?>(lastTopAlbumsSync),
      'cachedTopSongs': serializer.toJson<String?>(cachedTopSongs),
      'cachedTopAlbums': serializer.toJson<String?>(cachedTopAlbums),
    };
  }

  DbSyncMeta copyWith({
    int? id,
    Value<int?> lastLibrarySync = const Value.absent(),
    Value<int?> lastTopSongsSync = const Value.absent(),
    Value<int?> lastTopAlbumsSync = const Value.absent(),
    Value<String?> cachedTopSongs = const Value.absent(),
    Value<String?> cachedTopAlbums = const Value.absent(),
  }) => DbSyncMeta(
    id: id ?? this.id,
    lastLibrarySync: lastLibrarySync.present
        ? lastLibrarySync.value
        : this.lastLibrarySync,
    lastTopSongsSync: lastTopSongsSync.present
        ? lastTopSongsSync.value
        : this.lastTopSongsSync,
    lastTopAlbumsSync: lastTopAlbumsSync.present
        ? lastTopAlbumsSync.value
        : this.lastTopAlbumsSync,
    cachedTopSongs: cachedTopSongs.present
        ? cachedTopSongs.value
        : this.cachedTopSongs,
    cachedTopAlbums: cachedTopAlbums.present
        ? cachedTopAlbums.value
        : this.cachedTopAlbums,
  );
  DbSyncMeta copyWithCompanion(SyncMetaCompanion data) {
    return DbSyncMeta(
      id: data.id.present ? data.id.value : this.id,
      lastLibrarySync: data.lastLibrarySync.present
          ? data.lastLibrarySync.value
          : this.lastLibrarySync,
      lastTopSongsSync: data.lastTopSongsSync.present
          ? data.lastTopSongsSync.value
          : this.lastTopSongsSync,
      lastTopAlbumsSync: data.lastTopAlbumsSync.present
          ? data.lastTopAlbumsSync.value
          : this.lastTopAlbumsSync,
      cachedTopSongs: data.cachedTopSongs.present
          ? data.cachedTopSongs.value
          : this.cachedTopSongs,
      cachedTopAlbums: data.cachedTopAlbums.present
          ? data.cachedTopAlbums.value
          : this.cachedTopAlbums,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbSyncMeta(')
          ..write('id: $id, ')
          ..write('lastLibrarySync: $lastLibrarySync, ')
          ..write('lastTopSongsSync: $lastTopSongsSync, ')
          ..write('lastTopAlbumsSync: $lastTopAlbumsSync, ')
          ..write('cachedTopSongs: $cachedTopSongs, ')
          ..write('cachedTopAlbums: $cachedTopAlbums')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lastLibrarySync,
    lastTopSongsSync,
    lastTopAlbumsSync,
    cachedTopSongs,
    cachedTopAlbums,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbSyncMeta &&
          other.id == this.id &&
          other.lastLibrarySync == this.lastLibrarySync &&
          other.lastTopSongsSync == this.lastTopSongsSync &&
          other.lastTopAlbumsSync == this.lastTopAlbumsSync &&
          other.cachedTopSongs == this.cachedTopSongs &&
          other.cachedTopAlbums == this.cachedTopAlbums);
}

class SyncMetaCompanion extends UpdateCompanion<DbSyncMeta> {
  final Value<int> id;
  final Value<int?> lastLibrarySync;
  final Value<int?> lastTopSongsSync;
  final Value<int?> lastTopAlbumsSync;
  final Value<String?> cachedTopSongs;
  final Value<String?> cachedTopAlbums;
  const SyncMetaCompanion({
    this.id = const Value.absent(),
    this.lastLibrarySync = const Value.absent(),
    this.lastTopSongsSync = const Value.absent(),
    this.lastTopAlbumsSync = const Value.absent(),
    this.cachedTopSongs = const Value.absent(),
    this.cachedTopAlbums = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    this.id = const Value.absent(),
    this.lastLibrarySync = const Value.absent(),
    this.lastTopSongsSync = const Value.absent(),
    this.lastTopAlbumsSync = const Value.absent(),
    this.cachedTopSongs = const Value.absent(),
    this.cachedTopAlbums = const Value.absent(),
  });
  static Insertable<DbSyncMeta> custom({
    Expression<int>? id,
    Expression<int>? lastLibrarySync,
    Expression<int>? lastTopSongsSync,
    Expression<int>? lastTopAlbumsSync,
    Expression<String>? cachedTopSongs,
    Expression<String>? cachedTopAlbums,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastLibrarySync != null) 'last_library_sync': lastLibrarySync,
      if (lastTopSongsSync != null) 'last_top_songs_sync': lastTopSongsSync,
      if (lastTopAlbumsSync != null) 'last_top_albums_sync': lastTopAlbumsSync,
      if (cachedTopSongs != null) 'cached_top_songs': cachedTopSongs,
      if (cachedTopAlbums != null) 'cached_top_albums': cachedTopAlbums,
    });
  }

  SyncMetaCompanion copyWith({
    Value<int>? id,
    Value<int?>? lastLibrarySync,
    Value<int?>? lastTopSongsSync,
    Value<int?>? lastTopAlbumsSync,
    Value<String?>? cachedTopSongs,
    Value<String?>? cachedTopAlbums,
  }) {
    return SyncMetaCompanion(
      id: id ?? this.id,
      lastLibrarySync: lastLibrarySync ?? this.lastLibrarySync,
      lastTopSongsSync: lastTopSongsSync ?? this.lastTopSongsSync,
      lastTopAlbumsSync: lastTopAlbumsSync ?? this.lastTopAlbumsSync,
      cachedTopSongs: cachedTopSongs ?? this.cachedTopSongs,
      cachedTopAlbums: cachedTopAlbums ?? this.cachedTopAlbums,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastLibrarySync.present) {
      map['last_library_sync'] = Variable<int>(lastLibrarySync.value);
    }
    if (lastTopSongsSync.present) {
      map['last_top_songs_sync'] = Variable<int>(lastTopSongsSync.value);
    }
    if (lastTopAlbumsSync.present) {
      map['last_top_albums_sync'] = Variable<int>(lastTopAlbumsSync.value);
    }
    if (cachedTopSongs.present) {
      map['cached_top_songs'] = Variable<String>(cachedTopSongs.value);
    }
    if (cachedTopAlbums.present) {
      map['cached_top_albums'] = Variable<String>(cachedTopAlbums.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('id: $id, ')
          ..write('lastLibrarySync: $lastLibrarySync, ')
          ..write('lastTopSongsSync: $lastTopSongsSync, ')
          ..write('lastTopAlbumsSync: $lastTopAlbumsSync, ')
          ..write('cachedTopSongs: $cachedTopSongs, ')
          ..write('cachedTopAlbums: $cachedTopAlbums')
          ..write(')'))
        .toString();
  }
}

class $PlaybackHistoryTable extends PlaybackHistory
    with TableInfo<$PlaybackHistoryTable, DbPlaybackHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<int> fileId = GeneratedColumn<int>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _torrentIdMeta = const VerificationMeta(
    'torrentId',
  );
  @override
  late final GeneratedColumn<int> torrentId = GeneratedColumn<int>(
    'torrent_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackTitleMeta = const VerificationMeta(
    'trackTitle',
  );
  @override
  late final GeneratedColumn<String> trackTitle = GeneratedColumn<String>(
    'track_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artworkUrlLowMeta = const VerificationMeta(
    'artworkUrlLow',
  );
  @override
  late final GeneratedColumn<String> artworkUrlLow = GeneratedColumn<String>(
    'artwork_url_low',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlHighMeta = const VerificationMeta(
    'artworkUrlHigh',
  );
  @override
  late final GeneratedColumn<String> artworkUrlHigh = GeneratedColumn<String>(
    'artwork_url_high',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseYearMeta = const VerificationMeta(
    'releaseYear',
  );
  @override
  late final GeneratedColumn<int> releaseYear = GeneratedColumn<int>(
    'release_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileId,
    torrentId,
    trackTitle,
    artist,
    album,
    genre,
    artworkUrlLow,
    artworkUrlHigh,
    playedAt,
    duration,
    releaseYear,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPlaybackHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('torrent_id')) {
      context.handle(
        _torrentIdMeta,
        torrentId.isAcceptableOrUnknown(data['torrent_id']!, _torrentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_torrentIdMeta);
    }
    if (data.containsKey('track_title')) {
      context.handle(
        _trackTitleMeta,
        trackTitle.isAcceptableOrUnknown(data['track_title']!, _trackTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_trackTitleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    } else if (isInserting) {
      context.missing(_genreMeta);
    }
    if (data.containsKey('artwork_url_low')) {
      context.handle(
        _artworkUrlLowMeta,
        artworkUrlLow.isAcceptableOrUnknown(
          data['artwork_url_low']!,
          _artworkUrlLowMeta,
        ),
      );
    }
    if (data.containsKey('artwork_url_high')) {
      context.handle(
        _artworkUrlHighMeta,
        artworkUrlHigh.isAcceptableOrUnknown(
          data['artwork_url_high']!,
          _artworkUrlHighMeta,
        ),
      );
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('release_year')) {
      context.handle(
        _releaseYearMeta,
        releaseYear.isAcceptableOrUnknown(
          data['release_year']!,
          _releaseYearMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbPlaybackHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPlaybackHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_id'],
      )!,
      torrentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}torrent_id'],
      )!,
      trackTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      )!,
      artworkUrlLow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url_low'],
      ),
      artworkUrlHigh: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url_high'],
      ),
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}played_at'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      releaseYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}release_year'],
      ),
    );
  }

  @override
  $PlaybackHistoryTable createAlias(String alias) {
    return $PlaybackHistoryTable(attachedDatabase, alias);
  }
}

class DbPlaybackHistory extends DataClass
    implements Insertable<DbPlaybackHistory> {
  final int id;
  final int fileId;
  final int torrentId;
  final String trackTitle;
  final String artist;
  final String album;
  final String genre;
  final String? artworkUrlLow;
  final String? artworkUrlHigh;
  final int playedAt;
  final int? duration;
  final int? releaseYear;
  const DbPlaybackHistory({
    required this.id,
    required this.fileId,
    required this.torrentId,
    required this.trackTitle,
    required this.artist,
    required this.album,
    required this.genre,
    this.artworkUrlLow,
    this.artworkUrlHigh,
    required this.playedAt,
    this.duration,
    this.releaseYear,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_id'] = Variable<int>(fileId);
    map['torrent_id'] = Variable<int>(torrentId);
    map['track_title'] = Variable<String>(trackTitle);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    map['genre'] = Variable<String>(genre);
    if (!nullToAbsent || artworkUrlLow != null) {
      map['artwork_url_low'] = Variable<String>(artworkUrlLow);
    }
    if (!nullToAbsent || artworkUrlHigh != null) {
      map['artwork_url_high'] = Variable<String>(artworkUrlHigh);
    }
    map['played_at'] = Variable<int>(playedAt);
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || releaseYear != null) {
      map['release_year'] = Variable<int>(releaseYear);
    }
    return map;
  }

  PlaybackHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlaybackHistoryCompanion(
      id: Value(id),
      fileId: Value(fileId),
      torrentId: Value(torrentId),
      trackTitle: Value(trackTitle),
      artist: Value(artist),
      album: Value(album),
      genre: Value(genre),
      artworkUrlLow: artworkUrlLow == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrlLow),
      artworkUrlHigh: artworkUrlHigh == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrlHigh),
      playedAt: Value(playedAt),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      releaseYear: releaseYear == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseYear),
    );
  }

  factory DbPlaybackHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPlaybackHistory(
      id: serializer.fromJson<int>(json['id']),
      fileId: serializer.fromJson<int>(json['fileId']),
      torrentId: serializer.fromJson<int>(json['torrentId']),
      trackTitle: serializer.fromJson<String>(json['trackTitle']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      genre: serializer.fromJson<String>(json['genre']),
      artworkUrlLow: serializer.fromJson<String?>(json['artworkUrlLow']),
      artworkUrlHigh: serializer.fromJson<String?>(json['artworkUrlHigh']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
      duration: serializer.fromJson<int?>(json['duration']),
      releaseYear: serializer.fromJson<int?>(json['releaseYear']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileId': serializer.toJson<int>(fileId),
      'torrentId': serializer.toJson<int>(torrentId),
      'trackTitle': serializer.toJson<String>(trackTitle),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'genre': serializer.toJson<String>(genre),
      'artworkUrlLow': serializer.toJson<String?>(artworkUrlLow),
      'artworkUrlHigh': serializer.toJson<String?>(artworkUrlHigh),
      'playedAt': serializer.toJson<int>(playedAt),
      'duration': serializer.toJson<int?>(duration),
      'releaseYear': serializer.toJson<int?>(releaseYear),
    };
  }

  DbPlaybackHistory copyWith({
    int? id,
    int? fileId,
    int? torrentId,
    String? trackTitle,
    String? artist,
    String? album,
    String? genre,
    Value<String?> artworkUrlLow = const Value.absent(),
    Value<String?> artworkUrlHigh = const Value.absent(),
    int? playedAt,
    Value<int?> duration = const Value.absent(),
    Value<int?> releaseYear = const Value.absent(),
  }) => DbPlaybackHistory(
    id: id ?? this.id,
    fileId: fileId ?? this.fileId,
    torrentId: torrentId ?? this.torrentId,
    trackTitle: trackTitle ?? this.trackTitle,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    genre: genre ?? this.genre,
    artworkUrlLow: artworkUrlLow.present
        ? artworkUrlLow.value
        : this.artworkUrlLow,
    artworkUrlHigh: artworkUrlHigh.present
        ? artworkUrlHigh.value
        : this.artworkUrlHigh,
    playedAt: playedAt ?? this.playedAt,
    duration: duration.present ? duration.value : this.duration,
    releaseYear: releaseYear.present ? releaseYear.value : this.releaseYear,
  );
  DbPlaybackHistory copyWithCompanion(PlaybackHistoryCompanion data) {
    return DbPlaybackHistory(
      id: data.id.present ? data.id.value : this.id,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      torrentId: data.torrentId.present ? data.torrentId.value : this.torrentId,
      trackTitle: data.trackTitle.present
          ? data.trackTitle.value
          : this.trackTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      genre: data.genre.present ? data.genre.value : this.genre,
      artworkUrlLow: data.artworkUrlLow.present
          ? data.artworkUrlLow.value
          : this.artworkUrlLow,
      artworkUrlHigh: data.artworkUrlHigh.present
          ? data.artworkUrlHigh.value
          : this.artworkUrlHigh,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      duration: data.duration.present ? data.duration.value : this.duration,
      releaseYear: data.releaseYear.present
          ? data.releaseYear.value
          : this.releaseYear,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPlaybackHistory(')
          ..write('id: $id, ')
          ..write('fileId: $fileId, ')
          ..write('torrentId: $torrentId, ')
          ..write('trackTitle: $trackTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('artworkUrlLow: $artworkUrlLow, ')
          ..write('artworkUrlHigh: $artworkUrlHigh, ')
          ..write('playedAt: $playedAt, ')
          ..write('duration: $duration, ')
          ..write('releaseYear: $releaseYear')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileId,
    torrentId,
    trackTitle,
    artist,
    album,
    genre,
    artworkUrlLow,
    artworkUrlHigh,
    playedAt,
    duration,
    releaseYear,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPlaybackHistory &&
          other.id == this.id &&
          other.fileId == this.fileId &&
          other.torrentId == this.torrentId &&
          other.trackTitle == this.trackTitle &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.genre == this.genre &&
          other.artworkUrlLow == this.artworkUrlLow &&
          other.artworkUrlHigh == this.artworkUrlHigh &&
          other.playedAt == this.playedAt &&
          other.duration == this.duration &&
          other.releaseYear == this.releaseYear);
}

class PlaybackHistoryCompanion extends UpdateCompanion<DbPlaybackHistory> {
  final Value<int> id;
  final Value<int> fileId;
  final Value<int> torrentId;
  final Value<String> trackTitle;
  final Value<String> artist;
  final Value<String> album;
  final Value<String> genre;
  final Value<String?> artworkUrlLow;
  final Value<String?> artworkUrlHigh;
  final Value<int> playedAt;
  final Value<int?> duration;
  final Value<int?> releaseYear;
  const PlaybackHistoryCompanion({
    this.id = const Value.absent(),
    this.fileId = const Value.absent(),
    this.torrentId = const Value.absent(),
    this.trackTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.artworkUrlLow = const Value.absent(),
    this.artworkUrlHigh = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.duration = const Value.absent(),
    this.releaseYear = const Value.absent(),
  });
  PlaybackHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int fileId,
    required int torrentId,
    required String trackTitle,
    required String artist,
    required String album,
    required String genre,
    this.artworkUrlLow = const Value.absent(),
    this.artworkUrlHigh = const Value.absent(),
    required int playedAt,
    this.duration = const Value.absent(),
    this.releaseYear = const Value.absent(),
  }) : fileId = Value(fileId),
       torrentId = Value(torrentId),
       trackTitle = Value(trackTitle),
       artist = Value(artist),
       album = Value(album),
       genre = Value(genre),
       playedAt = Value(playedAt);
  static Insertable<DbPlaybackHistory> custom({
    Expression<int>? id,
    Expression<int>? fileId,
    Expression<int>? torrentId,
    Expression<String>? trackTitle,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? genre,
    Expression<String>? artworkUrlLow,
    Expression<String>? artworkUrlHigh,
    Expression<int>? playedAt,
    Expression<int>? duration,
    Expression<int>? releaseYear,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileId != null) 'file_id': fileId,
      if (torrentId != null) 'torrent_id': torrentId,
      if (trackTitle != null) 'track_title': trackTitle,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (genre != null) 'genre': genre,
      if (artworkUrlLow != null) 'artwork_url_low': artworkUrlLow,
      if (artworkUrlHigh != null) 'artwork_url_high': artworkUrlHigh,
      if (playedAt != null) 'played_at': playedAt,
      if (duration != null) 'duration': duration,
      if (releaseYear != null) 'release_year': releaseYear,
    });
  }

  PlaybackHistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? fileId,
    Value<int>? torrentId,
    Value<String>? trackTitle,
    Value<String>? artist,
    Value<String>? album,
    Value<String>? genre,
    Value<String?>? artworkUrlLow,
    Value<String?>? artworkUrlHigh,
    Value<int>? playedAt,
    Value<int?>? duration,
    Value<int?>? releaseYear,
  }) {
    return PlaybackHistoryCompanion(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      torrentId: torrentId ?? this.torrentId,
      trackTitle: trackTitle ?? this.trackTitle,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      artworkUrlLow: artworkUrlLow ?? this.artworkUrlLow,
      artworkUrlHigh: artworkUrlHigh ?? this.artworkUrlHigh,
      playedAt: playedAt ?? this.playedAt,
      duration: duration ?? this.duration,
      releaseYear: releaseYear ?? this.releaseYear,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<int>(fileId.value);
    }
    if (torrentId.present) {
      map['torrent_id'] = Variable<int>(torrentId.value);
    }
    if (trackTitle.present) {
      map['track_title'] = Variable<String>(trackTitle.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (artworkUrlLow.present) {
      map['artwork_url_low'] = Variable<String>(artworkUrlLow.value);
    }
    if (artworkUrlHigh.present) {
      map['artwork_url_high'] = Variable<String>(artworkUrlHigh.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (releaseYear.present) {
      map['release_year'] = Variable<int>(releaseYear.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoryCompanion(')
          ..write('id: $id, ')
          ..write('fileId: $fileId, ')
          ..write('torrentId: $torrentId, ')
          ..write('trackTitle: $trackTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('artworkUrlLow: $artworkUrlLow, ')
          ..write('artworkUrlHigh: $artworkUrlHigh, ')
          ..write('playedAt: $playedAt, ')
          ..write('duration: $duration, ')
          ..write('releaseYear: $releaseYear')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, DbPlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eclipseIdMeta = const VerificationMeta(
    'eclipseId',
  );
  @override
  late final GeneratedColumn<String> eclipseId = GeneratedColumn<String>(
    'eclipse_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    artworkUrl,
    sourceUrl,
    eclipseId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPlaylist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('eclipse_id')) {
      context.handle(
        _eclipseIdMeta,
        eclipseId.isAcceptableOrUnknown(data['eclipse_id']!, _eclipseIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbPlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPlaylist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      eclipseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eclipse_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class DbPlaylist extends DataClass implements Insertable<DbPlaylist> {
  final int id;
  final String name;
  final String? artworkUrl;
  final String? sourceUrl;
  final String? eclipseId;
  final int createdAt;
  const DbPlaylist({
    required this.id,
    required this.name,
    this.artworkUrl,
    this.sourceUrl,
    this.eclipseId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || eclipseId != null) {
      map['eclipse_id'] = Variable<String>(eclipseId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      eclipseId: eclipseId == null && nullToAbsent
          ? const Value.absent()
          : Value(eclipseId),
      createdAt: Value(createdAt),
    );
  }

  factory DbPlaylist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPlaylist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      eclipseId: serializer.fromJson<String?>(json['eclipseId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'eclipseId': serializer.toJson<String?>(eclipseId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DbPlaylist copyWith({
    int? id,
    String? name,
    Value<String?> artworkUrl = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> eclipseId = const Value.absent(),
    int? createdAt,
  }) => DbPlaylist(
    id: id ?? this.id,
    name: name ?? this.name,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    eclipseId: eclipseId.present ? eclipseId.value : this.eclipseId,
    createdAt: createdAt ?? this.createdAt,
  );
  DbPlaylist copyWithCompanion(PlaylistsCompanion data) {
    return DbPlaylist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      eclipseId: data.eclipseId.present ? data.eclipseId.value : this.eclipseId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPlaylist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('eclipseId: $eclipseId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, artworkUrl, sourceUrl, eclipseId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPlaylist &&
          other.id == this.id &&
          other.name == this.name &&
          other.artworkUrl == this.artworkUrl &&
          other.sourceUrl == this.sourceUrl &&
          other.eclipseId == this.eclipseId &&
          other.createdAt == this.createdAt);
}

class PlaylistsCompanion extends UpdateCompanion<DbPlaylist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> artworkUrl;
  final Value<String?> sourceUrl;
  final Value<String?> eclipseId;
  final Value<int> createdAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.eclipseId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.artworkUrl = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.eclipseId = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<DbPlaylist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? artworkUrl,
    Expression<String>? sourceUrl,
    Expression<String>? eclipseId,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (eclipseId != null) 'eclipse_id': eclipseId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? artworkUrl,
    Value<String?>? sourceUrl,
    Value<String?>? eclipseId,
    Value<int>? createdAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      eclipseId: eclipseId ?? this.eclipseId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (eclipseId.present) {
      map['eclipse_id'] = Variable<String>(eclipseId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('eclipseId: $eclipseId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, DbPlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _youtubeIdMeta = const VerificationMeta(
    'youtubeId',
  );
  @override
  late final GeneratedColumn<String> youtubeId = GeneratedColumn<String>(
    'youtube_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _torrentIdMeta = const VerificationMeta(
    'torrentId',
  );
  @override
  late final GeneratedColumn<int> torrentId = GeneratedColumn<int>(
    'torrent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<int> fileId = GeneratedColumn<int>(
    'file_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eclipseTrackIdMeta = const VerificationMeta(
    'eclipseTrackId',
  );
  @override
  late final GeneratedColumn<String> eclipseTrackId = GeneratedColumn<String>(
    'eclipse_track_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    title,
    artist,
    album,
    youtubeId,
    duration,
    artworkUrl,
    genre,
    torrentId,
    fileId,
    eclipseTrackId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPlaylistTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('youtube_id')) {
      context.handle(
        _youtubeIdMeta,
        youtubeId.isAcceptableOrUnknown(data['youtube_id']!, _youtubeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_youtubeIdMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('torrent_id')) {
      context.handle(
        _torrentIdMeta,
        torrentId.isAcceptableOrUnknown(data['torrent_id']!, _torrentIdMeta),
      );
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    }
    if (data.containsKey('eclipse_track_id')) {
      context.handle(
        _eclipseTrackIdMeta,
        eclipseTrackId.isAcceptableOrUnknown(
          data['eclipse_track_id']!,
          _eclipseTrackIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbPlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPlaylistTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      youtubeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}youtube_id'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      torrentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}torrent_id'],
      ),
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_id'],
      ),
      eclipseTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eclipse_track_id'],
      ),
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class DbPlaylistTrack extends DataClass implements Insertable<DbPlaylistTrack> {
  final int id;
  final int playlistId;
  final String title;
  final String artist;
  final String? album;
  final String youtubeId;
  final int? duration;
  final String? artworkUrl;
  final String? genre;
  final int? torrentId;
  final int? fileId;
  final String? eclipseTrackId;
  const DbPlaylistTrack({
    required this.id,
    required this.playlistId,
    required this.title,
    required this.artist,
    this.album,
    required this.youtubeId,
    this.duration,
    this.artworkUrl,
    this.genre,
    this.torrentId,
    this.fileId,
    this.eclipseTrackId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    map['youtube_id'] = Variable<String>(youtubeId);
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || torrentId != null) {
      map['torrent_id'] = Variable<int>(torrentId);
    }
    if (!nullToAbsent || fileId != null) {
      map['file_id'] = Variable<int>(fileId);
    }
    if (!nullToAbsent || eclipseTrackId != null) {
      map['eclipse_track_id'] = Variable<String>(eclipseTrackId);
    }
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      title: Value(title),
      artist: Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      youtubeId: Value(youtubeId),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      torrentId: torrentId == null && nullToAbsent
          ? const Value.absent()
          : Value(torrentId),
      fileId: fileId == null && nullToAbsent
          ? const Value.absent()
          : Value(fileId),
      eclipseTrackId: eclipseTrackId == null && nullToAbsent
          ? const Value.absent()
          : Value(eclipseTrackId),
    );
  }

  factory DbPlaylistTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPlaylistTrack(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      youtubeId: serializer.fromJson<String>(json['youtubeId']),
      duration: serializer.fromJson<int?>(json['duration']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      genre: serializer.fromJson<String?>(json['genre']),
      torrentId: serializer.fromJson<int?>(json['torrentId']),
      fileId: serializer.fromJson<int?>(json['fileId']),
      eclipseTrackId: serializer.fromJson<String?>(json['eclipseTrackId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String?>(album),
      'youtubeId': serializer.toJson<String>(youtubeId),
      'duration': serializer.toJson<int?>(duration),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'genre': serializer.toJson<String?>(genre),
      'torrentId': serializer.toJson<int?>(torrentId),
      'fileId': serializer.toJson<int?>(fileId),
      'eclipseTrackId': serializer.toJson<String?>(eclipseTrackId),
    };
  }

  DbPlaylistTrack copyWith({
    int? id,
    int? playlistId,
    String? title,
    String? artist,
    Value<String?> album = const Value.absent(),
    String? youtubeId,
    Value<int?> duration = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> torrentId = const Value.absent(),
    Value<int?> fileId = const Value.absent(),
    Value<String?> eclipseTrackId = const Value.absent(),
  }) => DbPlaylistTrack(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album.present ? album.value : this.album,
    youtubeId: youtubeId ?? this.youtubeId,
    duration: duration.present ? duration.value : this.duration,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    genre: genre.present ? genre.value : this.genre,
    torrentId: torrentId.present ? torrentId.value : this.torrentId,
    fileId: fileId.present ? fileId.value : this.fileId,
    eclipseTrackId: eclipseTrackId.present
        ? eclipseTrackId.value
        : this.eclipseTrackId,
  );
  DbPlaylistTrack copyWithCompanion(PlaylistTracksCompanion data) {
    return DbPlaylistTrack(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      youtubeId: data.youtubeId.present ? data.youtubeId.value : this.youtubeId,
      duration: data.duration.present ? data.duration.value : this.duration,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      genre: data.genre.present ? data.genre.value : this.genre,
      torrentId: data.torrentId.present ? data.torrentId.value : this.torrentId,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      eclipseTrackId: data.eclipseTrackId.present
          ? data.eclipseTrackId.value
          : this.eclipseTrackId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPlaylistTrack(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('youtubeId: $youtubeId, ')
          ..write('duration: $duration, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('genre: $genre, ')
          ..write('torrentId: $torrentId, ')
          ..write('fileId: $fileId, ')
          ..write('eclipseTrackId: $eclipseTrackId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    title,
    artist,
    album,
    youtubeId,
    duration,
    artworkUrl,
    genre,
    torrentId,
    fileId,
    eclipseTrackId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPlaylistTrack &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.youtubeId == this.youtubeId &&
          other.duration == this.duration &&
          other.artworkUrl == this.artworkUrl &&
          other.genre == this.genre &&
          other.torrentId == this.torrentId &&
          other.fileId == this.fileId &&
          other.eclipseTrackId == this.eclipseTrackId);
}

class PlaylistTracksCompanion extends UpdateCompanion<DbPlaylistTrack> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String?> album;
  final Value<String> youtubeId;
  final Value<int?> duration;
  final Value<String?> artworkUrl;
  final Value<String?> genre;
  final Value<int?> torrentId;
  final Value<int?> fileId;
  final Value<String?> eclipseTrackId;
  const PlaylistTracksCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.youtubeId = const Value.absent(),
    this.duration = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.torrentId = const Value.absent(),
    this.fileId = const Value.absent(),
    this.eclipseTrackId = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String title,
    required String artist,
    this.album = const Value.absent(),
    required String youtubeId,
    this.duration = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.torrentId = const Value.absent(),
    this.fileId = const Value.absent(),
    this.eclipseTrackId = const Value.absent(),
  }) : playlistId = Value(playlistId),
       title = Value(title),
       artist = Value(artist),
       youtubeId = Value(youtubeId);
  static Insertable<DbPlaylistTrack> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? youtubeId,
    Expression<int>? duration,
    Expression<String>? artworkUrl,
    Expression<String>? genre,
    Expression<int>? torrentId,
    Expression<int>? fileId,
    Expression<String>? eclipseTrackId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (youtubeId != null) 'youtube_id': youtubeId,
      if (duration != null) 'duration': duration,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (genre != null) 'genre': genre,
      if (torrentId != null) 'torrent_id': torrentId,
      if (fileId != null) 'file_id': fileId,
      if (eclipseTrackId != null) 'eclipse_track_id': eclipseTrackId,
    });
  }

  PlaylistTracksCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? title,
    Value<String>? artist,
    Value<String?>? album,
    Value<String>? youtubeId,
    Value<int?>? duration,
    Value<String?>? artworkUrl,
    Value<String?>? genre,
    Value<int?>? torrentId,
    Value<int?>? fileId,
    Value<String?>? eclipseTrackId,
  }) {
    return PlaylistTracksCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      youtubeId: youtubeId ?? this.youtubeId,
      duration: duration ?? this.duration,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      genre: genre ?? this.genre,
      torrentId: torrentId ?? this.torrentId,
      fileId: fileId ?? this.fileId,
      eclipseTrackId: eclipseTrackId ?? this.eclipseTrackId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (youtubeId.present) {
      map['youtube_id'] = Variable<String>(youtubeId.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (torrentId.present) {
      map['torrent_id'] = Variable<int>(torrentId.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<int>(fileId.value);
    }
    if (eclipseTrackId.present) {
      map['eclipse_track_id'] = Variable<String>(eclipseTrackId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('youtubeId: $youtubeId, ')
          ..write('duration: $duration, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('genre: $genre, ')
          ..write('torrentId: $torrentId, ')
          ..write('fileId: $fileId, ')
          ..write('eclipseTrackId: $eclipseTrackId')
          ..write(')'))
        .toString();
  }
}

class $ExternalTrackMetadataTable extends ExternalTrackMetadata
    with TableInfo<$ExternalTrackMetadataTable, DbExternalTrackMetadata> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExternalTrackMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackUrlMeta = const VerificationMeta(
    'trackUrl',
  );
  @override
  late final GeneratedColumn<String> trackUrl = GeneratedColumn<String>(
    'track_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackTitleMeta = const VerificationMeta(
    'trackTitle',
  );
  @override
  late final GeneratedColumn<String> trackTitle = GeneratedColumn<String>(
    'track_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseYearMeta = const VerificationMeta(
    'releaseYear',
  );
  @override
  late final GeneratedColumn<int> releaseYear = GeneratedColumn<int>(
    'release_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlLowMeta = const VerificationMeta(
    'artworkUrlLow',
  );
  @override
  late final GeneratedColumn<String> artworkUrlLow = GeneratedColumn<String>(
    'artwork_url_low',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlHighMeta = const VerificationMeta(
    'artworkUrlHigh',
  );
  @override
  late final GeneratedColumn<String> artworkUrlHigh = GeneratedColumn<String>(
    'artwork_url_high',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackTimeMillisMeta = const VerificationMeta(
    'trackTimeMillis',
  );
  @override
  late final GeneratedColumn<int> trackTimeMillis = GeneratedColumn<int>(
    'track_time_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<int> lastUpdated = GeneratedColumn<int>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackUrl,
    trackTitle,
    artist,
    album,
    genre,
    releaseYear,
    artworkUrlLow,
    artworkUrlHigh,
    trackTimeMillis,
    lastUpdated,
    isrc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'external_track_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbExternalTrackMetadata> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_url')) {
      context.handle(
        _trackUrlMeta,
        trackUrl.isAcceptableOrUnknown(data['track_url']!, _trackUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_trackUrlMeta);
    }
    if (data.containsKey('track_title')) {
      context.handle(
        _trackTitleMeta,
        trackTitle.isAcceptableOrUnknown(data['track_title']!, _trackTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_trackTitleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('release_year')) {
      context.handle(
        _releaseYearMeta,
        releaseYear.isAcceptableOrUnknown(
          data['release_year']!,
          _releaseYearMeta,
        ),
      );
    }
    if (data.containsKey('artwork_url_low')) {
      context.handle(
        _artworkUrlLowMeta,
        artworkUrlLow.isAcceptableOrUnknown(
          data['artwork_url_low']!,
          _artworkUrlLowMeta,
        ),
      );
    }
    if (data.containsKey('artwork_url_high')) {
      context.handle(
        _artworkUrlHighMeta,
        artworkUrlHigh.isAcceptableOrUnknown(
          data['artwork_url_high']!,
          _artworkUrlHighMeta,
        ),
      );
    }
    if (data.containsKey('track_time_millis')) {
      context.handle(
        _trackTimeMillisMeta,
        trackTimeMillis.isAcceptableOrUnknown(
          data['track_time_millis']!,
          _trackTimeMillisMeta,
        ),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackUrl};
  @override
  DbExternalTrackMetadata map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbExternalTrackMetadata(
      trackUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_url'],
      )!,
      trackTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      releaseYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}release_year'],
      ),
      artworkUrlLow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url_low'],
      ),
      artworkUrlHigh: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url_high'],
      ),
      trackTimeMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_time_millis'],
      ),
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_updated'],
      )!,
      isrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isrc'],
      ),
    );
  }

  @override
  $ExternalTrackMetadataTable createAlias(String alias) {
    return $ExternalTrackMetadataTable(attachedDatabase, alias);
  }
}

class DbExternalTrackMetadata extends DataClass
    implements Insertable<DbExternalTrackMetadata> {
  final String trackUrl;
  final String trackTitle;
  final String artist;
  final String? album;
  final String? genre;
  final int? releaseYear;
  final String? artworkUrlLow;
  final String? artworkUrlHigh;
  final int? trackTimeMillis;
  final int lastUpdated;
  final String? isrc;
  const DbExternalTrackMetadata({
    required this.trackUrl,
    required this.trackTitle,
    required this.artist,
    this.album,
    this.genre,
    this.releaseYear,
    this.artworkUrlLow,
    this.artworkUrlHigh,
    this.trackTimeMillis,
    required this.lastUpdated,
    this.isrc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_url'] = Variable<String>(trackUrl);
    map['track_title'] = Variable<String>(trackTitle);
    map['artist'] = Variable<String>(artist);
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || releaseYear != null) {
      map['release_year'] = Variable<int>(releaseYear);
    }
    if (!nullToAbsent || artworkUrlLow != null) {
      map['artwork_url_low'] = Variable<String>(artworkUrlLow);
    }
    if (!nullToAbsent || artworkUrlHigh != null) {
      map['artwork_url_high'] = Variable<String>(artworkUrlHigh);
    }
    if (!nullToAbsent || trackTimeMillis != null) {
      map['track_time_millis'] = Variable<int>(trackTimeMillis);
    }
    map['last_updated'] = Variable<int>(lastUpdated);
    if (!nullToAbsent || isrc != null) {
      map['isrc'] = Variable<String>(isrc);
    }
    return map;
  }

  ExternalTrackMetadataCompanion toCompanion(bool nullToAbsent) {
    return ExternalTrackMetadataCompanion(
      trackUrl: Value(trackUrl),
      trackTitle: Value(trackTitle),
      artist: Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      releaseYear: releaseYear == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseYear),
      artworkUrlLow: artworkUrlLow == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrlLow),
      artworkUrlHigh: artworkUrlHigh == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrlHigh),
      trackTimeMillis: trackTimeMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(trackTimeMillis),
      lastUpdated: Value(lastUpdated),
      isrc: isrc == null && nullToAbsent ? const Value.absent() : Value(isrc),
    );
  }

  factory DbExternalTrackMetadata.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbExternalTrackMetadata(
      trackUrl: serializer.fromJson<String>(json['trackUrl']),
      trackTitle: serializer.fromJson<String>(json['trackTitle']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      genre: serializer.fromJson<String?>(json['genre']),
      releaseYear: serializer.fromJson<int?>(json['releaseYear']),
      artworkUrlLow: serializer.fromJson<String?>(json['artworkUrlLow']),
      artworkUrlHigh: serializer.fromJson<String?>(json['artworkUrlHigh']),
      trackTimeMillis: serializer.fromJson<int?>(json['trackTimeMillis']),
      lastUpdated: serializer.fromJson<int>(json['lastUpdated']),
      isrc: serializer.fromJson<String?>(json['isrc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackUrl': serializer.toJson<String>(trackUrl),
      'trackTitle': serializer.toJson<String>(trackTitle),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String?>(album),
      'genre': serializer.toJson<String?>(genre),
      'releaseYear': serializer.toJson<int?>(releaseYear),
      'artworkUrlLow': serializer.toJson<String?>(artworkUrlLow),
      'artworkUrlHigh': serializer.toJson<String?>(artworkUrlHigh),
      'trackTimeMillis': serializer.toJson<int?>(trackTimeMillis),
      'lastUpdated': serializer.toJson<int>(lastUpdated),
      'isrc': serializer.toJson<String?>(isrc),
    };
  }

  DbExternalTrackMetadata copyWith({
    String? trackUrl,
    String? trackTitle,
    String? artist,
    Value<String?> album = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> releaseYear = const Value.absent(),
    Value<String?> artworkUrlLow = const Value.absent(),
    Value<String?> artworkUrlHigh = const Value.absent(),
    Value<int?> trackTimeMillis = const Value.absent(),
    int? lastUpdated,
    Value<String?> isrc = const Value.absent(),
  }) => DbExternalTrackMetadata(
    trackUrl: trackUrl ?? this.trackUrl,
    trackTitle: trackTitle ?? this.trackTitle,
    artist: artist ?? this.artist,
    album: album.present ? album.value : this.album,
    genre: genre.present ? genre.value : this.genre,
    releaseYear: releaseYear.present ? releaseYear.value : this.releaseYear,
    artworkUrlLow: artworkUrlLow.present
        ? artworkUrlLow.value
        : this.artworkUrlLow,
    artworkUrlHigh: artworkUrlHigh.present
        ? artworkUrlHigh.value
        : this.artworkUrlHigh,
    trackTimeMillis: trackTimeMillis.present
        ? trackTimeMillis.value
        : this.trackTimeMillis,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    isrc: isrc.present ? isrc.value : this.isrc,
  );
  DbExternalTrackMetadata copyWithCompanion(
    ExternalTrackMetadataCompanion data,
  ) {
    return DbExternalTrackMetadata(
      trackUrl: data.trackUrl.present ? data.trackUrl.value : this.trackUrl,
      trackTitle: data.trackTitle.present
          ? data.trackTitle.value
          : this.trackTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      genre: data.genre.present ? data.genre.value : this.genre,
      releaseYear: data.releaseYear.present
          ? data.releaseYear.value
          : this.releaseYear,
      artworkUrlLow: data.artworkUrlLow.present
          ? data.artworkUrlLow.value
          : this.artworkUrlLow,
      artworkUrlHigh: data.artworkUrlHigh.present
          ? data.artworkUrlHigh.value
          : this.artworkUrlHigh,
      trackTimeMillis: data.trackTimeMillis.present
          ? data.trackTimeMillis.value
          : this.trackTimeMillis,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbExternalTrackMetadata(')
          ..write('trackUrl: $trackUrl, ')
          ..write('trackTitle: $trackTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('artworkUrlLow: $artworkUrlLow, ')
          ..write('artworkUrlHigh: $artworkUrlHigh, ')
          ..write('trackTimeMillis: $trackTimeMillis, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('isrc: $isrc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trackUrl,
    trackTitle,
    artist,
    album,
    genre,
    releaseYear,
    artworkUrlLow,
    artworkUrlHigh,
    trackTimeMillis,
    lastUpdated,
    isrc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbExternalTrackMetadata &&
          other.trackUrl == this.trackUrl &&
          other.trackTitle == this.trackTitle &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.genre == this.genre &&
          other.releaseYear == this.releaseYear &&
          other.artworkUrlLow == this.artworkUrlLow &&
          other.artworkUrlHigh == this.artworkUrlHigh &&
          other.trackTimeMillis == this.trackTimeMillis &&
          other.lastUpdated == this.lastUpdated &&
          other.isrc == this.isrc);
}

class ExternalTrackMetadataCompanion
    extends UpdateCompanion<DbExternalTrackMetadata> {
  final Value<String> trackUrl;
  final Value<String> trackTitle;
  final Value<String> artist;
  final Value<String?> album;
  final Value<String?> genre;
  final Value<int?> releaseYear;
  final Value<String?> artworkUrlLow;
  final Value<String?> artworkUrlHigh;
  final Value<int?> trackTimeMillis;
  final Value<int> lastUpdated;
  final Value<String?> isrc;
  final Value<int> rowid;
  const ExternalTrackMetadataCompanion({
    this.trackUrl = const Value.absent(),
    this.trackTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.artworkUrlLow = const Value.absent(),
    this.artworkUrlHigh = const Value.absent(),
    this.trackTimeMillis = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.isrc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExternalTrackMetadataCompanion.insert({
    required String trackUrl,
    required String trackTitle,
    required String artist,
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.artworkUrlLow = const Value.absent(),
    this.artworkUrlHigh = const Value.absent(),
    this.trackTimeMillis = const Value.absent(),
    required int lastUpdated,
    this.isrc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : trackUrl = Value(trackUrl),
       trackTitle = Value(trackTitle),
       artist = Value(artist),
       lastUpdated = Value(lastUpdated);
  static Insertable<DbExternalTrackMetadata> custom({
    Expression<String>? trackUrl,
    Expression<String>? trackTitle,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? genre,
    Expression<int>? releaseYear,
    Expression<String>? artworkUrlLow,
    Expression<String>? artworkUrlHigh,
    Expression<int>? trackTimeMillis,
    Expression<int>? lastUpdated,
    Expression<String>? isrc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackUrl != null) 'track_url': trackUrl,
      if (trackTitle != null) 'track_title': trackTitle,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (genre != null) 'genre': genre,
      if (releaseYear != null) 'release_year': releaseYear,
      if (artworkUrlLow != null) 'artwork_url_low': artworkUrlLow,
      if (artworkUrlHigh != null) 'artwork_url_high': artworkUrlHigh,
      if (trackTimeMillis != null) 'track_time_millis': trackTimeMillis,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (isrc != null) 'isrc': isrc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExternalTrackMetadataCompanion copyWith({
    Value<String>? trackUrl,
    Value<String>? trackTitle,
    Value<String>? artist,
    Value<String?>? album,
    Value<String?>? genre,
    Value<int?>? releaseYear,
    Value<String?>? artworkUrlLow,
    Value<String?>? artworkUrlHigh,
    Value<int?>? trackTimeMillis,
    Value<int>? lastUpdated,
    Value<String?>? isrc,
    Value<int>? rowid,
  }) {
    return ExternalTrackMetadataCompanion(
      trackUrl: trackUrl ?? this.trackUrl,
      trackTitle: trackTitle ?? this.trackTitle,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      releaseYear: releaseYear ?? this.releaseYear,
      artworkUrlLow: artworkUrlLow ?? this.artworkUrlLow,
      artworkUrlHigh: artworkUrlHigh ?? this.artworkUrlHigh,
      trackTimeMillis: trackTimeMillis ?? this.trackTimeMillis,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isrc: isrc ?? this.isrc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackUrl.present) {
      map['track_url'] = Variable<String>(trackUrl.value);
    }
    if (trackTitle.present) {
      map['track_title'] = Variable<String>(trackTitle.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (releaseYear.present) {
      map['release_year'] = Variable<int>(releaseYear.value);
    }
    if (artworkUrlLow.present) {
      map['artwork_url_low'] = Variable<String>(artworkUrlLow.value);
    }
    if (artworkUrlHigh.present) {
      map['artwork_url_high'] = Variable<String>(artworkUrlHigh.value);
    }
    if (trackTimeMillis.present) {
      map['track_time_millis'] = Variable<int>(trackTimeMillis.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<int>(lastUpdated.value);
    }
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExternalTrackMetadataCompanion(')
          ..write('trackUrl: $trackUrl, ')
          ..write('trackTitle: $trackTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('artworkUrlLow: $artworkUrlLow, ')
          ..write('artworkUrlHigh: $artworkUrlHigh, ')
          ..write('trackTimeMillis: $trackTimeMillis, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('isrc: $isrc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FollowedArtistsTable extends FollowedArtists
    with TableInfo<$FollowedArtistsTable, DbFollowedArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FollowedArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followedAtMeta = const VerificationMeta(
    'followedAt',
  );
  @override
  late final GeneratedColumn<int> followedAt = GeneratedColumn<int>(
    'followed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    artworkUrl,
    genre,
    followedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'followed_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbFollowedArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('followed_at')) {
      context.handle(
        _followedAtMeta,
        followedAt.isAcceptableOrUnknown(data['followed_at']!, _followedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_followedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbFollowedArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbFollowedArtist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      followedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}followed_at'],
      )!,
    );
  }

  @override
  $FollowedArtistsTable createAlias(String alias) {
    return $FollowedArtistsTable(attachedDatabase, alias);
  }
}

class DbFollowedArtist extends DataClass
    implements Insertable<DbFollowedArtist> {
  final int id;
  final String name;
  final String? artworkUrl;
  final String? genre;
  final int followedAt;
  const DbFollowedArtist({
    required this.id,
    required this.name,
    this.artworkUrl,
    this.genre,
    required this.followedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['followed_at'] = Variable<int>(followedAt);
    return map;
  }

  FollowedArtistsCompanion toCompanion(bool nullToAbsent) {
    return FollowedArtistsCompanion(
      id: Value(id),
      name: Value(name),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      followedAt: Value(followedAt),
    );
  }

  factory DbFollowedArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbFollowedArtist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      genre: serializer.fromJson<String?>(json['genre']),
      followedAt: serializer.fromJson<int>(json['followedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'genre': serializer.toJson<String?>(genre),
      'followedAt': serializer.toJson<int>(followedAt),
    };
  }

  DbFollowedArtist copyWith({
    int? id,
    String? name,
    Value<String?> artworkUrl = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    int? followedAt,
  }) => DbFollowedArtist(
    id: id ?? this.id,
    name: name ?? this.name,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    genre: genre.present ? genre.value : this.genre,
    followedAt: followedAt ?? this.followedAt,
  );
  DbFollowedArtist copyWithCompanion(FollowedArtistsCompanion data) {
    return DbFollowedArtist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      genre: data.genre.present ? data.genre.value : this.genre,
      followedAt: data.followedAt.present
          ? data.followedAt.value
          : this.followedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbFollowedArtist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('genre: $genre, ')
          ..write('followedAt: $followedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, artworkUrl, genre, followedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbFollowedArtist &&
          other.id == this.id &&
          other.name == this.name &&
          other.artworkUrl == this.artworkUrl &&
          other.genre == this.genre &&
          other.followedAt == this.followedAt);
}

class FollowedArtistsCompanion extends UpdateCompanion<DbFollowedArtist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> artworkUrl;
  final Value<String?> genre;
  final Value<int> followedAt;
  const FollowedArtistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.followedAt = const Value.absent(),
  });
  FollowedArtistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.artworkUrl = const Value.absent(),
    this.genre = const Value.absent(),
    required int followedAt,
  }) : name = Value(name),
       followedAt = Value(followedAt);
  static Insertable<DbFollowedArtist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? artworkUrl,
    Expression<String>? genre,
    Expression<int>? followedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (genre != null) 'genre': genre,
      if (followedAt != null) 'followed_at': followedAt,
    });
  }

  FollowedArtistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? artworkUrl,
    Value<String?>? genre,
    Value<int>? followedAt,
  }) {
    return FollowedArtistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      genre: genre ?? this.genre,
      followedAt: followedAt ?? this.followedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (followedAt.present) {
      map['followed_at'] = Variable<int>(followedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FollowedArtistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('genre: $genre, ')
          ..write('followedAt: $followedAt')
          ..write(')'))
        .toString();
  }
}

class $AudiobookProgressTable extends AudiobookProgress
    with TableInfo<$AudiobookProgressTable, DbAudiobookProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudiobookProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMillisMeta = const VerificationMeta(
    'positionMillis',
  );
  @override
  late final GeneratedColumn<int> positionMillis = GeneratedColumn<int>(
    'position_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMillisMeta = const VerificationMeta(
    'durationMillis',
  );
  @override
  late final GeneratedColumn<int> durationMillis = GeneratedColumn<int>(
    'duration_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastListenedAtMeta = const VerificationMeta(
    'lastListenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastListenedAt =
      GeneratedColumn<DateTime>(
        'last_listened_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    positionMillis,
    durationMillis,
    lastListenedAt,
    isCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audiobook_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAudiobookProgress> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('position_millis')) {
      context.handle(
        _positionMillisMeta,
        positionMillis.isAcceptableOrUnknown(
          data['position_millis']!,
          _positionMillisMeta,
        ),
      );
    }
    if (data.containsKey('duration_millis')) {
      context.handle(
        _durationMillisMeta,
        durationMillis.isAcceptableOrUnknown(
          data['duration_millis']!,
          _durationMillisMeta,
        ),
      );
    }
    if (data.containsKey('last_listened_at')) {
      context.handle(
        _lastListenedAtMeta,
        lastListenedAt.isAcceptableOrUnknown(
          data['last_listened_at']!,
          _lastListenedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastListenedAtMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAudiobookProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAudiobookProgress(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      positionMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_millis'],
      )!,
      durationMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_millis'],
      )!,
      lastListenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_listened_at'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
    );
  }

  @override
  $AudiobookProgressTable createAlias(String alias) {
    return $AudiobookProgressTable(attachedDatabase, alias);
  }
}

class DbAudiobookProgress extends DataClass
    implements Insertable<DbAudiobookProgress> {
  final int id;
  final String bookId;
  final int chapterIndex;
  final int positionMillis;
  final int durationMillis;
  final DateTime lastListenedAt;
  final bool isCompleted;
  const DbAudiobookProgress({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.positionMillis,
    required this.durationMillis,
    required this.lastListenedAt,
    required this.isCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['position_millis'] = Variable<int>(positionMillis);
    map['duration_millis'] = Variable<int>(durationMillis);
    map['last_listened_at'] = Variable<DateTime>(lastListenedAt);
    map['is_completed'] = Variable<bool>(isCompleted);
    return map;
  }

  AudiobookProgressCompanion toCompanion(bool nullToAbsent) {
    return AudiobookProgressCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      positionMillis: Value(positionMillis),
      durationMillis: Value(durationMillis),
      lastListenedAt: Value(lastListenedAt),
      isCompleted: Value(isCompleted),
    );
  }

  factory DbAudiobookProgress.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAudiobookProgress(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      positionMillis: serializer.fromJson<int>(json['positionMillis']),
      durationMillis: serializer.fromJson<int>(json['durationMillis']),
      lastListenedAt: serializer.fromJson<DateTime>(json['lastListenedAt']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'positionMillis': serializer.toJson<int>(positionMillis),
      'durationMillis': serializer.toJson<int>(durationMillis),
      'lastListenedAt': serializer.toJson<DateTime>(lastListenedAt),
      'isCompleted': serializer.toJson<bool>(isCompleted),
    };
  }

  DbAudiobookProgress copyWith({
    int? id,
    String? bookId,
    int? chapterIndex,
    int? positionMillis,
    int? durationMillis,
    DateTime? lastListenedAt,
    bool? isCompleted,
  }) => DbAudiobookProgress(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    positionMillis: positionMillis ?? this.positionMillis,
    durationMillis: durationMillis ?? this.durationMillis,
    lastListenedAt: lastListenedAt ?? this.lastListenedAt,
    isCompleted: isCompleted ?? this.isCompleted,
  );
  DbAudiobookProgress copyWithCompanion(AudiobookProgressCompanion data) {
    return DbAudiobookProgress(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      positionMillis: data.positionMillis.present
          ? data.positionMillis.value
          : this.positionMillis,
      durationMillis: data.durationMillis.present
          ? data.durationMillis.value
          : this.durationMillis,
      lastListenedAt: data.lastListenedAt.present
          ? data.lastListenedAt.value
          : this.lastListenedAt,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAudiobookProgress(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionMillis: $positionMillis, ')
          ..write('durationMillis: $durationMillis, ')
          ..write('lastListenedAt: $lastListenedAt, ')
          ..write('isCompleted: $isCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    positionMillis,
    durationMillis,
    lastListenedAt,
    isCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAudiobookProgress &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.positionMillis == this.positionMillis &&
          other.durationMillis == this.durationMillis &&
          other.lastListenedAt == this.lastListenedAt &&
          other.isCompleted == this.isCompleted);
}

class AudiobookProgressCompanion extends UpdateCompanion<DbAudiobookProgress> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> positionMillis;
  final Value<int> durationMillis;
  final Value<DateTime> lastListenedAt;
  final Value<bool> isCompleted;
  const AudiobookProgressCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.positionMillis = const Value.absent(),
    this.durationMillis = const Value.absent(),
    this.lastListenedAt = const Value.absent(),
    this.isCompleted = const Value.absent(),
  });
  AudiobookProgressCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int chapterIndex,
    this.positionMillis = const Value.absent(),
    this.durationMillis = const Value.absent(),
    required DateTime lastListenedAt,
    this.isCompleted = const Value.absent(),
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       lastListenedAt = Value(lastListenedAt);
  static Insertable<DbAudiobookProgress> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? positionMillis,
    Expression<int>? durationMillis,
    Expression<DateTime>? lastListenedAt,
    Expression<bool>? isCompleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (positionMillis != null) 'position_millis': positionMillis,
      if (durationMillis != null) 'duration_millis': durationMillis,
      if (lastListenedAt != null) 'last_listened_at': lastListenedAt,
      if (isCompleted != null) 'is_completed': isCompleted,
    });
  }

  AudiobookProgressCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<int>? positionMillis,
    Value<int>? durationMillis,
    Value<DateTime>? lastListenedAt,
    Value<bool>? isCompleted,
  }) {
    return AudiobookProgressCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionMillis: positionMillis ?? this.positionMillis,
      durationMillis: durationMillis ?? this.durationMillis,
      lastListenedAt: lastListenedAt ?? this.lastListenedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (positionMillis.present) {
      map['position_millis'] = Variable<int>(positionMillis.value);
    }
    if (durationMillis.present) {
      map['duration_millis'] = Variable<int>(durationMillis.value);
    }
    if (lastListenedAt.present) {
      map['last_listened_at'] = Variable<DateTime>(lastListenedAt.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudiobookProgressCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionMillis: $positionMillis, ')
          ..write('durationMillis: $durationMillis, ')
          ..write('lastListenedAt: $lastListenedAt, ')
          ..write('isCompleted: $isCompleted')
          ..write(')'))
        .toString();
  }
}

class $AudiobookMetadataCacheTable extends AudiobookMetadataCache
    with TableInfo<$AudiobookMetadataCacheTable, DbAudiobookMetadataCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudiobookMetadataCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _narratorMeta = const VerificationMeta(
    'narrator',
  );
  @override
  late final GeneratedColumn<String> narrator = GeneratedColumn<String>(
    'narrator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    title,
    author,
    narrator,
    artworkUrl,
    description,
    totalChapters,
    language,
    genre,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audiobook_metadata_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAudiobookMetadataCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('narrator')) {
      context.handle(
        _narratorMeta,
        narrator.isAcceptableOrUnknown(data['narrator']!, _narratorMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
        _totalChaptersMeta,
        totalChapters.isAcceptableOrUnknown(
          data['total_chapters']!,
          _totalChaptersMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  DbAudiobookMetadataCache map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAudiobookMetadataCache(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      narrator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrator'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $AudiobookMetadataCacheTable createAlias(String alias) {
    return $AudiobookMetadataCacheTable(attachedDatabase, alias);
  }
}

class DbAudiobookMetadataCache extends DataClass
    implements Insertable<DbAudiobookMetadataCache> {
  final String bookId;
  final String title;
  final String? author;
  final String? narrator;
  final String? artworkUrl;
  final String? description;
  final int totalChapters;
  final String? language;
  final String? genre;
  final DateTime lastUpdated;
  const DbAudiobookMetadataCache({
    required this.bookId,
    required this.title,
    this.author,
    this.narrator,
    this.artworkUrl,
    this.description,
    required this.totalChapters,
    this.language,
    this.genre,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || narrator != null) {
      map['narrator'] = Variable<String>(narrator);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['total_chapters'] = Variable<int>(totalChapters);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  AudiobookMetadataCacheCompanion toCompanion(bool nullToAbsent) {
    return AudiobookMetadataCacheCompanion(
      bookId: Value(bookId),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      narrator: narrator == null && nullToAbsent
          ? const Value.absent()
          : Value(narrator),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      totalChapters: Value(totalChapters),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory DbAudiobookMetadataCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAudiobookMetadataCache(
      bookId: serializer.fromJson<String>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      narrator: serializer.fromJson<String?>(json['narrator']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      description: serializer.fromJson<String?>(json['description']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
      language: serializer.fromJson<String?>(json['language']),
      genre: serializer.fromJson<String?>(json['genre']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'narrator': serializer.toJson<String?>(narrator),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'description': serializer.toJson<String?>(description),
      'totalChapters': serializer.toJson<int>(totalChapters),
      'language': serializer.toJson<String?>(language),
      'genre': serializer.toJson<String?>(genre),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  DbAudiobookMetadataCache copyWith({
    String? bookId,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> narrator = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    Value<String?> description = const Value.absent(),
    int? totalChapters,
    Value<String?> language = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    DateTime? lastUpdated,
  }) => DbAudiobookMetadataCache(
    bookId: bookId ?? this.bookId,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    narrator: narrator.present ? narrator.value : this.narrator,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    description: description.present ? description.value : this.description,
    totalChapters: totalChapters ?? this.totalChapters,
    language: language.present ? language.value : this.language,
    genre: genre.present ? genre.value : this.genre,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  DbAudiobookMetadataCache copyWithCompanion(
    AudiobookMetadataCacheCompanion data,
  ) {
    return DbAudiobookMetadataCache(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      narrator: data.narrator.present ? data.narrator.value : this.narrator,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      description: data.description.present
          ? data.description.value
          : this.description,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      language: data.language.present ? data.language.value : this.language,
      genre: data.genre.present ? data.genre.value : this.genre,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAudiobookMetadataCache(')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('narrator: $narrator, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('description: $description, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('language: $language, ')
          ..write('genre: $genre, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    title,
    author,
    narrator,
    artworkUrl,
    description,
    totalChapters,
    language,
    genre,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAudiobookMetadataCache &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.author == this.author &&
          other.narrator == this.narrator &&
          other.artworkUrl == this.artworkUrl &&
          other.description == this.description &&
          other.totalChapters == this.totalChapters &&
          other.language == this.language &&
          other.genre == this.genre &&
          other.lastUpdated == this.lastUpdated);
}

class AudiobookMetadataCacheCompanion
    extends UpdateCompanion<DbAudiobookMetadataCache> {
  final Value<String> bookId;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> narrator;
  final Value<String?> artworkUrl;
  final Value<String?> description;
  final Value<int> totalChapters;
  final Value<String?> language;
  final Value<String?> genre;
  final Value<DateTime> lastUpdated;
  final Value<int> rowid;
  const AudiobookMetadataCacheCompanion({
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.narrator = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.language = const Value.absent(),
    this.genre = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudiobookMetadataCacheCompanion.insert({
    required String bookId,
    required String title,
    this.author = const Value.absent(),
    this.narrator = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.language = const Value.absent(),
    this.genre = const Value.absent(),
    required DateTime lastUpdated,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       title = Value(title),
       lastUpdated = Value(lastUpdated);
  static Insertable<DbAudiobookMetadataCache> custom({
    Expression<String>? bookId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? narrator,
    Expression<String>? artworkUrl,
    Expression<String>? description,
    Expression<int>? totalChapters,
    Expression<String>? language,
    Expression<String>? genre,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (narrator != null) 'narrator': narrator,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (description != null) 'description': description,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (language != null) 'language': language,
      if (genre != null) 'genre': genre,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudiobookMetadataCacheCompanion copyWith({
    Value<String>? bookId,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? narrator,
    Value<String?>? artworkUrl,
    Value<String?>? description,
    Value<int>? totalChapters,
    Value<String?>? language,
    Value<String?>? genre,
    Value<DateTime>? lastUpdated,
    Value<int>? rowid,
  }) {
    return AudiobookMetadataCacheCompanion(
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      description: description ?? this.description,
      totalChapters: totalChapters ?? this.totalChapters,
      language: language ?? this.language,
      genre: genre ?? this.genre,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (narrator.present) {
      map['narrator'] = Variable<String>(narrator.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudiobookMetadataCacheCompanion(')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('narrator: $narrator, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('description: $description, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('language: $language, ')
          ..write('genre: $genre, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudiobookBookmarksTable extends AudiobookBookmarks
    with TableInfo<$AudiobookBookmarksTable, DbAudiobookBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudiobookBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMillisMeta = const VerificationMeta(
    'positionMillis',
  );
  @override
  late final GeneratedColumn<int> positionMillis = GeneratedColumn<int>(
    'position_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    positionMillis,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audiobook_bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAudiobookBookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('position_millis')) {
      context.handle(
        _positionMillisMeta,
        positionMillis.isAcceptableOrUnknown(
          data['position_millis']!,
          _positionMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionMillisMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAudiobookBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAudiobookBookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      positionMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_millis'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AudiobookBookmarksTable createAlias(String alias) {
    return $AudiobookBookmarksTable(attachedDatabase, alias);
  }
}

class DbAudiobookBookmark extends DataClass
    implements Insertable<DbAudiobookBookmark> {
  final int id;
  final String bookId;
  final int chapterIndex;
  final int positionMillis;
  final String? label;
  final int createdAt;
  const DbAudiobookBookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.positionMillis,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['position_millis'] = Variable<int>(positionMillis);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AudiobookBookmarksCompanion toCompanion(bool nullToAbsent) {
    return AudiobookBookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      positionMillis: Value(positionMillis),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory DbAudiobookBookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAudiobookBookmark(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      positionMillis: serializer.fromJson<int>(json['positionMillis']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'positionMillis': serializer.toJson<int>(positionMillis),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DbAudiobookBookmark copyWith({
    int? id,
    String? bookId,
    int? chapterIndex,
    int? positionMillis,
    Value<String?> label = const Value.absent(),
    int? createdAt,
  }) => DbAudiobookBookmark(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    positionMillis: positionMillis ?? this.positionMillis,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  DbAudiobookBookmark copyWithCompanion(AudiobookBookmarksCompanion data) {
    return DbAudiobookBookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      positionMillis: data.positionMillis.present
          ? data.positionMillis.value
          : this.positionMillis,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAudiobookBookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionMillis: $positionMillis, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, chapterIndex, positionMillis, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAudiobookBookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.positionMillis == this.positionMillis &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class AudiobookBookmarksCompanion extends UpdateCompanion<DbAudiobookBookmark> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> positionMillis;
  final Value<String?> label;
  final Value<int> createdAt;
  const AudiobookBookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.positionMillis = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AudiobookBookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int chapterIndex,
    required int positionMillis,
    this.label = const Value.absent(),
    required int createdAt,
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       positionMillis = Value(positionMillis),
       createdAt = Value(createdAt);
  static Insertable<DbAudiobookBookmark> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? positionMillis,
    Expression<String>? label,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (positionMillis != null) 'position_millis': positionMillis,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AudiobookBookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<int>? positionMillis,
    Value<String?>? label,
    Value<int>? createdAt,
  }) {
    return AudiobookBookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionMillis: positionMillis ?? this.positionMillis,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (positionMillis.present) {
      map['position_millis'] = Variable<int>(positionMillis.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudiobookBookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('positionMillis: $positionMillis, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TorrentsTable torrents = $TorrentsTable(this);
  late final $FilesTable files = $FilesTable(this);
  late final $TrackMetadataTable trackMetadata = $TrackMetadataTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $PlaybackHistoryTable playbackHistory = $PlaybackHistoryTable(
    this,
  );
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $ExternalTrackMetadataTable externalTrackMetadata =
      $ExternalTrackMetadataTable(this);
  late final $FollowedArtistsTable followedArtists = $FollowedArtistsTable(
    this,
  );
  late final $AudiobookProgressTable audiobookProgress =
      $AudiobookProgressTable(this);
  late final $AudiobookMetadataCacheTable audiobookMetadataCache =
      $AudiobookMetadataCacheTable(this);
  late final $AudiobookBookmarksTable audiobookBookmarks =
      $AudiobookBookmarksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    torrents,
    files,
    trackMetadata,
    syncMeta,
    playbackHistory,
    playlists,
    playlistTracks,
    externalTrackMetadata,
    followedArtists,
    audiobookProgress,
    audiobookMetadataCache,
    audiobookBookmarks,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_tracks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TorrentsTableCreateCompanionBuilder =
    TorrentsCompanion Function({
      Value<int> id,
      required String name,
      required String hash,
      required bool cached,
    });
typedef $$TorrentsTableUpdateCompanionBuilder =
    TorrentsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> hash,
      Value<bool> cached,
    });

class $$TorrentsTableFilterComposer
    extends Composer<_$AppDatabase, $TorrentsTable> {
  $$TorrentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cached => $composableBuilder(
    column: $table.cached,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TorrentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TorrentsTable> {
  $$TorrentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cached => $composableBuilder(
    column: $table.cached,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TorrentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TorrentsTable> {
  $$TorrentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<bool> get cached =>
      $composableBuilder(column: $table.cached, builder: (column) => column);
}

class $$TorrentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TorrentsTable,
          DbTorrent,
          $$TorrentsTableFilterComposer,
          $$TorrentsTableOrderingComposer,
          $$TorrentsTableAnnotationComposer,
          $$TorrentsTableCreateCompanionBuilder,
          $$TorrentsTableUpdateCompanionBuilder,
          (DbTorrent, BaseReferences<_$AppDatabase, $TorrentsTable, DbTorrent>),
          DbTorrent,
          PrefetchHooks Function()
        > {
  $$TorrentsTableTableManager(_$AppDatabase db, $TorrentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TorrentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TorrentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TorrentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<bool> cached = const Value.absent(),
              }) => TorrentsCompanion(
                id: id,
                name: name,
                hash: hash,
                cached: cached,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String hash,
                required bool cached,
              }) => TorrentsCompanion.insert(
                id: id,
                name: name,
                hash: hash,
                cached: cached,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TorrentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TorrentsTable,
      DbTorrent,
      $$TorrentsTableFilterComposer,
      $$TorrentsTableOrderingComposer,
      $$TorrentsTableAnnotationComposer,
      $$TorrentsTableCreateCompanionBuilder,
      $$TorrentsTableUpdateCompanionBuilder,
      (DbTorrent, BaseReferences<_$AppDatabase, $TorrentsTable, DbTorrent>),
      DbTorrent,
      PrefetchHooks Function()
    >;
typedef $$FilesTableCreateCompanionBuilder =
    FilesCompanion Function({
      required int id,
      required int torrentId,
      required String name,
      required int size,
      required bool isAudio,
      Value<String?> localPath,
      Value<int> rowid,
    });
typedef $$FilesTableUpdateCompanionBuilder =
    FilesCompanion Function({
      Value<int> id,
      Value<int> torrentId,
      Value<String> name,
      Value<int> size,
      Value<bool> isAudio,
      Value<String?> localPath,
      Value<int> rowid,
    });

class $$FilesTableFilterComposer extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAudio => $composableBuilder(
    column: $table.isAudio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FilesTableOrderingComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAudio => $composableBuilder(
    column: $table.isAudio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get torrentId =>
      $composableBuilder(column: $table.torrentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<bool> get isAudio =>
      $composableBuilder(column: $table.isAudio, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);
}

class $$FilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FilesTable,
          DbFile,
          $$FilesTableFilterComposer,
          $$FilesTableOrderingComposer,
          $$FilesTableAnnotationComposer,
          $$FilesTableCreateCompanionBuilder,
          $$FilesTableUpdateCompanionBuilder,
          (DbFile, BaseReferences<_$AppDatabase, $FilesTable, DbFile>),
          DbFile,
          PrefetchHooks Function()
        > {
  $$FilesTableTableManager(_$AppDatabase db, $FilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> torrentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<bool> isAudio = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FilesCompanion(
                id: id,
                torrentId: torrentId,
                name: name,
                size: size,
                isAudio: isAudio,
                localPath: localPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int id,
                required int torrentId,
                required String name,
                required int size,
                required bool isAudio,
                Value<String?> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FilesCompanion.insert(
                id: id,
                torrentId: torrentId,
                name: name,
                size: size,
                isAudio: isAudio,
                localPath: localPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FilesTable,
      DbFile,
      $$FilesTableFilterComposer,
      $$FilesTableOrderingComposer,
      $$FilesTableAnnotationComposer,
      $$FilesTableCreateCompanionBuilder,
      $$FilesTableUpdateCompanionBuilder,
      (DbFile, BaseReferences<_$AppDatabase, $FilesTable, DbFile>),
      DbFile,
      PrefetchHooks Function()
    >;
typedef $$TrackMetadataTableCreateCompanionBuilder =
    TrackMetadataCompanion Function({
      required int fileId,
      required int torrentId,
      Value<String?> trackTitle,
      Value<String?> artist,
      Value<String?> album,
      Value<String?> genre,
      Value<int?> releaseYear,
      Value<String?> artworkUrlLow,
      Value<String?> artworkUrlHigh,
      Value<int?> trackTimeMillis,
      Value<bool> isLiked,
      Value<String?> isrc,
      Value<int> rowid,
    });
typedef $$TrackMetadataTableUpdateCompanionBuilder =
    TrackMetadataCompanion Function({
      Value<int> fileId,
      Value<int> torrentId,
      Value<String?> trackTitle,
      Value<String?> artist,
      Value<String?> album,
      Value<String?> genre,
      Value<int?> releaseYear,
      Value<String?> artworkUrlLow,
      Value<String?> artworkUrlHigh,
      Value<int?> trackTimeMillis,
      Value<bool> isLiked,
      Value<String?> isrc,
      Value<int> rowid,
    });

class $$TrackMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $TrackMetadataTable> {
  $$TrackMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackTimeMillis => $composableBuilder(
    column: $table.trackTimeMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLiked => $composableBuilder(
    column: $table.isLiked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackMetadataTable> {
  $$TrackMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackTimeMillis => $composableBuilder(
    column: $table.trackTimeMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLiked => $composableBuilder(
    column: $table.isLiked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackMetadataTable> {
  $$TrackMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<int> get torrentId =>
      $composableBuilder(column: $table.torrentId, builder: (column) => column);

  GeneratedColumn<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackTimeMillis => $composableBuilder(
    column: $table.trackTimeMillis,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLiked =>
      $composableBuilder(column: $table.isLiked, builder: (column) => column);

  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);
}

class $$TrackMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackMetadataTable,
          DbTrackMetadata,
          $$TrackMetadataTableFilterComposer,
          $$TrackMetadataTableOrderingComposer,
          $$TrackMetadataTableAnnotationComposer,
          $$TrackMetadataTableCreateCompanionBuilder,
          $$TrackMetadataTableUpdateCompanionBuilder,
          (
            DbTrackMetadata,
            BaseReferences<_$AppDatabase, $TrackMetadataTable, DbTrackMetadata>,
          ),
          DbTrackMetadata,
          PrefetchHooks Function()
        > {
  $$TrackMetadataTableTableManager(_$AppDatabase db, $TrackMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> fileId = const Value.absent(),
                Value<int> torrentId = const Value.absent(),
                Value<String?> trackTitle = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<String?> artworkUrlLow = const Value.absent(),
                Value<String?> artworkUrlHigh = const Value.absent(),
                Value<int?> trackTimeMillis = const Value.absent(),
                Value<bool> isLiked = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackMetadataCompanion(
                fileId: fileId,
                torrentId: torrentId,
                trackTitle: trackTitle,
                artist: artist,
                album: album,
                genre: genre,
                releaseYear: releaseYear,
                artworkUrlLow: artworkUrlLow,
                artworkUrlHigh: artworkUrlHigh,
                trackTimeMillis: trackTimeMillis,
                isLiked: isLiked,
                isrc: isrc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int fileId,
                required int torrentId,
                Value<String?> trackTitle = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<String?> artworkUrlLow = const Value.absent(),
                Value<String?> artworkUrlHigh = const Value.absent(),
                Value<int?> trackTimeMillis = const Value.absent(),
                Value<bool> isLiked = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackMetadataCompanion.insert(
                fileId: fileId,
                torrentId: torrentId,
                trackTitle: trackTitle,
                artist: artist,
                album: album,
                genre: genre,
                releaseYear: releaseYear,
                artworkUrlLow: artworkUrlLow,
                artworkUrlHigh: artworkUrlHigh,
                trackTimeMillis: trackTimeMillis,
                isLiked: isLiked,
                isrc: isrc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackMetadataTable,
      DbTrackMetadata,
      $$TrackMetadataTableFilterComposer,
      $$TrackMetadataTableOrderingComposer,
      $$TrackMetadataTableAnnotationComposer,
      $$TrackMetadataTableCreateCompanionBuilder,
      $$TrackMetadataTableUpdateCompanionBuilder,
      (
        DbTrackMetadata,
        BaseReferences<_$AppDatabase, $TrackMetadataTable, DbTrackMetadata>,
      ),
      DbTrackMetadata,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int?> lastLibrarySync,
      Value<int?> lastTopSongsSync,
      Value<int?> lastTopAlbumsSync,
      Value<String?> cachedTopSongs,
      Value<String?> cachedTopAlbums,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int?> lastLibrarySync,
      Value<int?> lastTopSongsSync,
      Value<int?> lastTopAlbumsSync,
      Value<String?> cachedTopSongs,
      Value<String?> cachedTopAlbums,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLibrarySync => $composableBuilder(
    column: $table.lastLibrarySync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTopSongsSync => $composableBuilder(
    column: $table.lastTopSongsSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTopAlbumsSync => $composableBuilder(
    column: $table.lastTopAlbumsSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cachedTopSongs => $composableBuilder(
    column: $table.cachedTopSongs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cachedTopAlbums => $composableBuilder(
    column: $table.cachedTopAlbums,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLibrarySync => $composableBuilder(
    column: $table.lastLibrarySync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTopSongsSync => $composableBuilder(
    column: $table.lastTopSongsSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTopAlbumsSync => $composableBuilder(
    column: $table.lastTopAlbumsSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachedTopSongs => $composableBuilder(
    column: $table.cachedTopSongs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cachedTopAlbums => $composableBuilder(
    column: $table.cachedTopAlbums,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastLibrarySync => $composableBuilder(
    column: $table.lastLibrarySync,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastTopSongsSync => $composableBuilder(
    column: $table.lastTopSongsSync,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastTopAlbumsSync => $composableBuilder(
    column: $table.lastTopAlbumsSync,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cachedTopSongs => $composableBuilder(
    column: $table.cachedTopSongs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cachedTopAlbums => $composableBuilder(
    column: $table.cachedTopAlbums,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          DbSyncMeta,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            DbSyncMeta,
            BaseReferences<_$AppDatabase, $SyncMetaTable, DbSyncMeta>,
          ),
          DbSyncMeta,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lastLibrarySync = const Value.absent(),
                Value<int?> lastTopSongsSync = const Value.absent(),
                Value<int?> lastTopAlbumsSync = const Value.absent(),
                Value<String?> cachedTopSongs = const Value.absent(),
                Value<String?> cachedTopAlbums = const Value.absent(),
              }) => SyncMetaCompanion(
                id: id,
                lastLibrarySync: lastLibrarySync,
                lastTopSongsSync: lastTopSongsSync,
                lastTopAlbumsSync: lastTopAlbumsSync,
                cachedTopSongs: cachedTopSongs,
                cachedTopAlbums: cachedTopAlbums,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lastLibrarySync = const Value.absent(),
                Value<int?> lastTopSongsSync = const Value.absent(),
                Value<int?> lastTopAlbumsSync = const Value.absent(),
                Value<String?> cachedTopSongs = const Value.absent(),
                Value<String?> cachedTopAlbums = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                id: id,
                lastLibrarySync: lastLibrarySync,
                lastTopSongsSync: lastTopSongsSync,
                lastTopAlbumsSync: lastTopAlbumsSync,
                cachedTopSongs: cachedTopSongs,
                cachedTopAlbums: cachedTopAlbums,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      DbSyncMeta,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (DbSyncMeta, BaseReferences<_$AppDatabase, $SyncMetaTable, DbSyncMeta>),
      DbSyncMeta,
      PrefetchHooks Function()
    >;
typedef $$PlaybackHistoryTableCreateCompanionBuilder =
    PlaybackHistoryCompanion Function({
      Value<int> id,
      required int fileId,
      required int torrentId,
      required String trackTitle,
      required String artist,
      required String album,
      required String genre,
      Value<String?> artworkUrlLow,
      Value<String?> artworkUrlHigh,
      required int playedAt,
      Value<int?> duration,
      Value<int?> releaseYear,
    });
typedef $$PlaybackHistoryTableUpdateCompanionBuilder =
    PlaybackHistoryCompanion Function({
      Value<int> id,
      Value<int> fileId,
      Value<int> torrentId,
      Value<String> trackTitle,
      Value<String> artist,
      Value<String> album,
      Value<String> genre,
      Value<String?> artworkUrlLow,
      Value<String?> artworkUrlHigh,
      Value<int> playedAt,
      Value<int?> duration,
      Value<int?> releaseYear,
    });

class $$PlaybackHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<int> get torrentId =>
      $composableBuilder(column: $table.torrentId, builder: (column) => column);

  GeneratedColumn<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => column,
  );
}

class $$PlaybackHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackHistoryTable,
          DbPlaybackHistory,
          $$PlaybackHistoryTableFilterComposer,
          $$PlaybackHistoryTableOrderingComposer,
          $$PlaybackHistoryTableAnnotationComposer,
          $$PlaybackHistoryTableCreateCompanionBuilder,
          $$PlaybackHistoryTableUpdateCompanionBuilder,
          (
            DbPlaybackHistory,
            BaseReferences<
              _$AppDatabase,
              $PlaybackHistoryTable,
              DbPlaybackHistory
            >,
          ),
          DbPlaybackHistory,
          PrefetchHooks Function()
        > {
  $$PlaybackHistoryTableTableManager(
    _$AppDatabase db,
    $PlaybackHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> fileId = const Value.absent(),
                Value<int> torrentId = const Value.absent(),
                Value<String> trackTitle = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String> genre = const Value.absent(),
                Value<String?> artworkUrlLow = const Value.absent(),
                Value<String?> artworkUrlHigh = const Value.absent(),
                Value<int> playedAt = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
              }) => PlaybackHistoryCompanion(
                id: id,
                fileId: fileId,
                torrentId: torrentId,
                trackTitle: trackTitle,
                artist: artist,
                album: album,
                genre: genre,
                artworkUrlLow: artworkUrlLow,
                artworkUrlHigh: artworkUrlHigh,
                playedAt: playedAt,
                duration: duration,
                releaseYear: releaseYear,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int fileId,
                required int torrentId,
                required String trackTitle,
                required String artist,
                required String album,
                required String genre,
                Value<String?> artworkUrlLow = const Value.absent(),
                Value<String?> artworkUrlHigh = const Value.absent(),
                required int playedAt,
                Value<int?> duration = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
              }) => PlaybackHistoryCompanion.insert(
                id: id,
                fileId: fileId,
                torrentId: torrentId,
                trackTitle: trackTitle,
                artist: artist,
                album: album,
                genre: genre,
                artworkUrlLow: artworkUrlLow,
                artworkUrlHigh: artworkUrlHigh,
                playedAt: playedAt,
                duration: duration,
                releaseYear: releaseYear,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackHistoryTable,
      DbPlaybackHistory,
      $$PlaybackHistoryTableFilterComposer,
      $$PlaybackHistoryTableOrderingComposer,
      $$PlaybackHistoryTableAnnotationComposer,
      $$PlaybackHistoryTableCreateCompanionBuilder,
      $$PlaybackHistoryTableUpdateCompanionBuilder,
      (
        DbPlaybackHistory,
        BaseReferences<_$AppDatabase, $PlaybackHistoryTable, DbPlaybackHistory>,
      ),
      DbPlaybackHistory,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> artworkUrl,
      Value<String?> sourceUrl,
      Value<String?> eclipseId,
      required int createdAt,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> artworkUrl,
      Value<String?> sourceUrl,
      Value<String?> eclipseId,
      Value<int> createdAt,
    });

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, DbPlaylist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<DbPlaylistTrack>>
  _playlistTracksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistTracks,
    aliasName: $_aliasNameGenerator(
      db.playlists.id,
      db.playlistTracks.playlistId,
    ),
  );

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager(
      $_db,
      $_db.playlistTracks,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eclipseId => $composableBuilder(
    column: $table.eclipseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistTracksRefs(
    Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eclipseId => $composableBuilder(
    column: $table.eclipseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get eclipseId =>
      $composableBuilder(column: $table.eclipseId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          DbPlaylist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (DbPlaylist, $$PlaylistsTableReferences),
          DbPlaylist,
          PrefetchHooks Function({bool playlistTracksRefs})
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> eclipseId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                artworkUrl: artworkUrl,
                sourceUrl: sourceUrl,
                eclipseId: eclipseId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> eclipseId = const Value.absent(),
                required int createdAt,
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                artworkUrl: artworkUrl,
                sourceUrl: sourceUrl,
                eclipseId: eclipseId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksRefs) db.playlistTracks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksRefs)
                    await $_getPrefetchedData<
                      DbPlaylist,
                      $PlaylistsTable,
                      DbPlaylistTrack
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistTracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistTracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      DbPlaylist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (DbPlaylist, $$PlaylistsTableReferences),
      DbPlaylist,
      PrefetchHooks Function({bool playlistTracksRefs})
    >;
typedef $$PlaylistTracksTableCreateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      required int playlistId,
      required String title,
      required String artist,
      Value<String?> album,
      required String youtubeId,
      Value<int?> duration,
      Value<String?> artworkUrl,
      Value<String?> genre,
      Value<int?> torrentId,
      Value<int?> fileId,
      Value<String?> eclipseTrackId,
    });
typedef $$PlaylistTracksTableUpdateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<String> title,
      Value<String> artist,
      Value<String?> album,
      Value<String> youtubeId,
      Value<int?> duration,
      Value<String?> artworkUrl,
      Value<String?> genre,
      Value<int?> torrentId,
      Value<int?> fileId,
      Value<String?> eclipseTrackId,
    });

final class $$PlaylistTracksTableReferences
    extends
        BaseReferences<_$AppDatabase, $PlaylistTracksTable, DbPlaylistTrack> {
  $$PlaylistTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias(
        $_aliasNameGenerator(db.playlistTracks.playlistId, db.playlists.id),
      );

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get youtubeId => $composableBuilder(
    column: $table.youtubeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eclipseTrackId => $composableBuilder(
    column: $table.eclipseTrackId,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get youtubeId => $composableBuilder(
    column: $table.youtubeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get torrentId => $composableBuilder(
    column: $table.torrentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eclipseTrackId => $composableBuilder(
    column: $table.eclipseTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get youtubeId =>
      $composableBuilder(column: $table.youtubeId, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get torrentId =>
      $composableBuilder(column: $table.torrentId, builder: (column) => column);

  GeneratedColumn<int> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get eclipseTrackId => $composableBuilder(
    column: $table.eclipseTrackId,
    builder: (column) => column,
  );

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistTracksTable,
          DbPlaylistTrack,
          $$PlaylistTracksTableFilterComposer,
          $$PlaylistTracksTableOrderingComposer,
          $$PlaylistTracksTableAnnotationComposer,
          $$PlaylistTracksTableCreateCompanionBuilder,
          $$PlaylistTracksTableUpdateCompanionBuilder,
          (DbPlaylistTrack, $$PlaylistTracksTableReferences),
          DbPlaylistTrack,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistTracksTableTableManager(
    _$AppDatabase db,
    $PlaylistTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String> youtubeId = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> torrentId = const Value.absent(),
                Value<int?> fileId = const Value.absent(),
                Value<String?> eclipseTrackId = const Value.absent(),
              }) => PlaylistTracksCompanion(
                id: id,
                playlistId: playlistId,
                title: title,
                artist: artist,
                album: album,
                youtubeId: youtubeId,
                duration: duration,
                artworkUrl: artworkUrl,
                genre: genre,
                torrentId: torrentId,
                fileId: fileId,
                eclipseTrackId: eclipseTrackId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String title,
                required String artist,
                Value<String?> album = const Value.absent(),
                required String youtubeId,
                Value<int?> duration = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> torrentId = const Value.absent(),
                Value<int?> fileId = const Value.absent(),
                Value<String?> eclipseTrackId = const Value.absent(),
              }) => PlaylistTracksCompanion.insert(
                id: id,
                playlistId: playlistId,
                title: title,
                artist: artist,
                album: album,
                youtubeId: youtubeId,
                duration: duration,
                artworkUrl: artworkUrl,
                genre: genre,
                torrentId: torrentId,
                fileId: fileId,
                eclipseTrackId: eclipseTrackId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistId,
                                referencedTable: $$PlaylistTracksTableReferences
                                    ._playlistIdTable(db),
                                referencedColumn:
                                    $$PlaylistTracksTableReferences
                                        ._playlistIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistTracksTable,
      DbPlaylistTrack,
      $$PlaylistTracksTableFilterComposer,
      $$PlaylistTracksTableOrderingComposer,
      $$PlaylistTracksTableAnnotationComposer,
      $$PlaylistTracksTableCreateCompanionBuilder,
      $$PlaylistTracksTableUpdateCompanionBuilder,
      (DbPlaylistTrack, $$PlaylistTracksTableReferences),
      DbPlaylistTrack,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$ExternalTrackMetadataTableCreateCompanionBuilder =
    ExternalTrackMetadataCompanion Function({
      required String trackUrl,
      required String trackTitle,
      required String artist,
      Value<String?> album,
      Value<String?> genre,
      Value<int?> releaseYear,
      Value<String?> artworkUrlLow,
      Value<String?> artworkUrlHigh,
      Value<int?> trackTimeMillis,
      required int lastUpdated,
      Value<String?> isrc,
      Value<int> rowid,
    });
typedef $$ExternalTrackMetadataTableUpdateCompanionBuilder =
    ExternalTrackMetadataCompanion Function({
      Value<String> trackUrl,
      Value<String> trackTitle,
      Value<String> artist,
      Value<String?> album,
      Value<String?> genre,
      Value<int?> releaseYear,
      Value<String?> artworkUrlLow,
      Value<String?> artworkUrlHigh,
      Value<int?> trackTimeMillis,
      Value<int> lastUpdated,
      Value<String?> isrc,
      Value<int> rowid,
    });

class $$ExternalTrackMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $ExternalTrackMetadataTable> {
  $$ExternalTrackMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackUrl => $composableBuilder(
    column: $table.trackUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackTimeMillis => $composableBuilder(
    column: $table.trackTimeMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExternalTrackMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $ExternalTrackMetadataTable> {
  $$ExternalTrackMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackUrl => $composableBuilder(
    column: $table.trackUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackTimeMillis => $composableBuilder(
    column: $table.trackTimeMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExternalTrackMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExternalTrackMetadataTable> {
  $$ExternalTrackMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackUrl =>
      $composableBuilder(column: $table.trackUrl, builder: (column) => column);

  GeneratedColumn<String> get trackTitle => $composableBuilder(
    column: $table.trackTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrlLow => $composableBuilder(
    column: $table.artworkUrlLow,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrlHigh => $composableBuilder(
    column: $table.artworkUrlHigh,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackTimeMillis => $composableBuilder(
    column: $table.trackTimeMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);
}

class $$ExternalTrackMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExternalTrackMetadataTable,
          DbExternalTrackMetadata,
          $$ExternalTrackMetadataTableFilterComposer,
          $$ExternalTrackMetadataTableOrderingComposer,
          $$ExternalTrackMetadataTableAnnotationComposer,
          $$ExternalTrackMetadataTableCreateCompanionBuilder,
          $$ExternalTrackMetadataTableUpdateCompanionBuilder,
          (
            DbExternalTrackMetadata,
            BaseReferences<
              _$AppDatabase,
              $ExternalTrackMetadataTable,
              DbExternalTrackMetadata
            >,
          ),
          DbExternalTrackMetadata,
          PrefetchHooks Function()
        > {
  $$ExternalTrackMetadataTableTableManager(
    _$AppDatabase db,
    $ExternalTrackMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExternalTrackMetadataTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ExternalTrackMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExternalTrackMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> trackUrl = const Value.absent(),
                Value<String> trackTitle = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<String?> artworkUrlLow = const Value.absent(),
                Value<String?> artworkUrlHigh = const Value.absent(),
                Value<int?> trackTimeMillis = const Value.absent(),
                Value<int> lastUpdated = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExternalTrackMetadataCompanion(
                trackUrl: trackUrl,
                trackTitle: trackTitle,
                artist: artist,
                album: album,
                genre: genre,
                releaseYear: releaseYear,
                artworkUrlLow: artworkUrlLow,
                artworkUrlHigh: artworkUrlHigh,
                trackTimeMillis: trackTimeMillis,
                lastUpdated: lastUpdated,
                isrc: isrc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackUrl,
                required String trackTitle,
                required String artist,
                Value<String?> album = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<String?> artworkUrlLow = const Value.absent(),
                Value<String?> artworkUrlHigh = const Value.absent(),
                Value<int?> trackTimeMillis = const Value.absent(),
                required int lastUpdated,
                Value<String?> isrc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExternalTrackMetadataCompanion.insert(
                trackUrl: trackUrl,
                trackTitle: trackTitle,
                artist: artist,
                album: album,
                genre: genre,
                releaseYear: releaseYear,
                artworkUrlLow: artworkUrlLow,
                artworkUrlHigh: artworkUrlHigh,
                trackTimeMillis: trackTimeMillis,
                lastUpdated: lastUpdated,
                isrc: isrc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExternalTrackMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExternalTrackMetadataTable,
      DbExternalTrackMetadata,
      $$ExternalTrackMetadataTableFilterComposer,
      $$ExternalTrackMetadataTableOrderingComposer,
      $$ExternalTrackMetadataTableAnnotationComposer,
      $$ExternalTrackMetadataTableCreateCompanionBuilder,
      $$ExternalTrackMetadataTableUpdateCompanionBuilder,
      (
        DbExternalTrackMetadata,
        BaseReferences<
          _$AppDatabase,
          $ExternalTrackMetadataTable,
          DbExternalTrackMetadata
        >,
      ),
      DbExternalTrackMetadata,
      PrefetchHooks Function()
    >;
typedef $$FollowedArtistsTableCreateCompanionBuilder =
    FollowedArtistsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> artworkUrl,
      Value<String?> genre,
      required int followedAt,
    });
typedef $$FollowedArtistsTableUpdateCompanionBuilder =
    FollowedArtistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> artworkUrl,
      Value<String?> genre,
      Value<int> followedAt,
    });

class $$FollowedArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get followedAt => $composableBuilder(
    column: $table.followedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FollowedArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get followedAt => $composableBuilder(
    column: $table.followedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FollowedArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get followedAt => $composableBuilder(
    column: $table.followedAt,
    builder: (column) => column,
  );
}

class $$FollowedArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FollowedArtistsTable,
          DbFollowedArtist,
          $$FollowedArtistsTableFilterComposer,
          $$FollowedArtistsTableOrderingComposer,
          $$FollowedArtistsTableAnnotationComposer,
          $$FollowedArtistsTableCreateCompanionBuilder,
          $$FollowedArtistsTableUpdateCompanionBuilder,
          (
            DbFollowedArtist,
            BaseReferences<
              _$AppDatabase,
              $FollowedArtistsTable,
              DbFollowedArtist
            >,
          ),
          DbFollowedArtist,
          PrefetchHooks Function()
        > {
  $$FollowedArtistsTableTableManager(
    _$AppDatabase db,
    $FollowedArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FollowedArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FollowedArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FollowedArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int> followedAt = const Value.absent(),
              }) => FollowedArtistsCompanion(
                id: id,
                name: name,
                artworkUrl: artworkUrl,
                genre: genre,
                followedAt: followedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                required int followedAt,
              }) => FollowedArtistsCompanion.insert(
                id: id,
                name: name,
                artworkUrl: artworkUrl,
                genre: genre,
                followedAt: followedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FollowedArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FollowedArtistsTable,
      DbFollowedArtist,
      $$FollowedArtistsTableFilterComposer,
      $$FollowedArtistsTableOrderingComposer,
      $$FollowedArtistsTableAnnotationComposer,
      $$FollowedArtistsTableCreateCompanionBuilder,
      $$FollowedArtistsTableUpdateCompanionBuilder,
      (
        DbFollowedArtist,
        BaseReferences<_$AppDatabase, $FollowedArtistsTable, DbFollowedArtist>,
      ),
      DbFollowedArtist,
      PrefetchHooks Function()
    >;
typedef $$AudiobookProgressTableCreateCompanionBuilder =
    AudiobookProgressCompanion Function({
      Value<int> id,
      required String bookId,
      required int chapterIndex,
      Value<int> positionMillis,
      Value<int> durationMillis,
      required DateTime lastListenedAt,
      Value<bool> isCompleted,
    });
typedef $$AudiobookProgressTableUpdateCompanionBuilder =
    AudiobookProgressCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<int> positionMillis,
      Value<int> durationMillis,
      Value<DateTime> lastListenedAt,
      Value<bool> isCompleted,
    });

class $$AudiobookProgressTableFilterComposer
    extends Composer<_$AppDatabase, $AudiobookProgressTable> {
  $$AudiobookProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMillis => $composableBuilder(
    column: $table.positionMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastListenedAt => $composableBuilder(
    column: $table.lastListenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudiobookProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $AudiobookProgressTable> {
  $$AudiobookProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMillis => $composableBuilder(
    column: $table.positionMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastListenedAt => $composableBuilder(
    column: $table.lastListenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudiobookProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudiobookProgressTable> {
  $$AudiobookProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMillis => $composableBuilder(
    column: $table.positionMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastListenedAt => $composableBuilder(
    column: $table.lastListenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );
}

class $$AudiobookProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudiobookProgressTable,
          DbAudiobookProgress,
          $$AudiobookProgressTableFilterComposer,
          $$AudiobookProgressTableOrderingComposer,
          $$AudiobookProgressTableAnnotationComposer,
          $$AudiobookProgressTableCreateCompanionBuilder,
          $$AudiobookProgressTableUpdateCompanionBuilder,
          (
            DbAudiobookProgress,
            BaseReferences<
              _$AppDatabase,
              $AudiobookProgressTable,
              DbAudiobookProgress
            >,
          ),
          DbAudiobookProgress,
          PrefetchHooks Function()
        > {
  $$AudiobookProgressTableTableManager(
    _$AppDatabase db,
    $AudiobookProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudiobookProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudiobookProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudiobookProgressTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> positionMillis = const Value.absent(),
                Value<int> durationMillis = const Value.absent(),
                Value<DateTime> lastListenedAt = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
              }) => AudiobookProgressCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                positionMillis: positionMillis,
                durationMillis: durationMillis,
                lastListenedAt: lastListenedAt,
                isCompleted: isCompleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required int chapterIndex,
                Value<int> positionMillis = const Value.absent(),
                Value<int> durationMillis = const Value.absent(),
                required DateTime lastListenedAt,
                Value<bool> isCompleted = const Value.absent(),
              }) => AudiobookProgressCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                positionMillis: positionMillis,
                durationMillis: durationMillis,
                lastListenedAt: lastListenedAt,
                isCompleted: isCompleted,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudiobookProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudiobookProgressTable,
      DbAudiobookProgress,
      $$AudiobookProgressTableFilterComposer,
      $$AudiobookProgressTableOrderingComposer,
      $$AudiobookProgressTableAnnotationComposer,
      $$AudiobookProgressTableCreateCompanionBuilder,
      $$AudiobookProgressTableUpdateCompanionBuilder,
      (
        DbAudiobookProgress,
        BaseReferences<
          _$AppDatabase,
          $AudiobookProgressTable,
          DbAudiobookProgress
        >,
      ),
      DbAudiobookProgress,
      PrefetchHooks Function()
    >;
typedef $$AudiobookMetadataCacheTableCreateCompanionBuilder =
    AudiobookMetadataCacheCompanion Function({
      required String bookId,
      required String title,
      Value<String?> author,
      Value<String?> narrator,
      Value<String?> artworkUrl,
      Value<String?> description,
      Value<int> totalChapters,
      Value<String?> language,
      Value<String?> genre,
      required DateTime lastUpdated,
      Value<int> rowid,
    });
typedef $$AudiobookMetadataCacheTableUpdateCompanionBuilder =
    AudiobookMetadataCacheCompanion Function({
      Value<String> bookId,
      Value<String> title,
      Value<String?> author,
      Value<String?> narrator,
      Value<String?> artworkUrl,
      Value<String?> description,
      Value<int> totalChapters,
      Value<String?> language,
      Value<String?> genre,
      Value<DateTime> lastUpdated,
      Value<int> rowid,
    });

class $$AudiobookMetadataCacheTableFilterComposer
    extends Composer<_$AppDatabase, $AudiobookMetadataCacheTable> {
  $$AudiobookMetadataCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narrator => $composableBuilder(
    column: $table.narrator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudiobookMetadataCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $AudiobookMetadataCacheTable> {
  $$AudiobookMetadataCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrator => $composableBuilder(
    column: $table.narrator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudiobookMetadataCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudiobookMetadataCacheTable> {
  $$AudiobookMetadataCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get narrator =>
      $composableBuilder(column: $table.narrator, builder: (column) => column);

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$AudiobookMetadataCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudiobookMetadataCacheTable,
          DbAudiobookMetadataCache,
          $$AudiobookMetadataCacheTableFilterComposer,
          $$AudiobookMetadataCacheTableOrderingComposer,
          $$AudiobookMetadataCacheTableAnnotationComposer,
          $$AudiobookMetadataCacheTableCreateCompanionBuilder,
          $$AudiobookMetadataCacheTableUpdateCompanionBuilder,
          (
            DbAudiobookMetadataCache,
            BaseReferences<
              _$AppDatabase,
              $AudiobookMetadataCacheTable,
              DbAudiobookMetadataCache
            >,
          ),
          DbAudiobookMetadataCache,
          PrefetchHooks Function()
        > {
  $$AudiobookMetadataCacheTableTableManager(
    _$AppDatabase db,
    $AudiobookMetadataCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudiobookMetadataCacheTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AudiobookMetadataCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AudiobookMetadataCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> narrator = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudiobookMetadataCacheCompanion(
                bookId: bookId,
                title: title,
                author: author,
                narrator: narrator,
                artworkUrl: artworkUrl,
                description: description,
                totalChapters: totalChapters,
                language: language,
                genre: genre,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> narrator = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                required DateTime lastUpdated,
                Value<int> rowid = const Value.absent(),
              }) => AudiobookMetadataCacheCompanion.insert(
                bookId: bookId,
                title: title,
                author: author,
                narrator: narrator,
                artworkUrl: artworkUrl,
                description: description,
                totalChapters: totalChapters,
                language: language,
                genre: genre,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudiobookMetadataCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudiobookMetadataCacheTable,
      DbAudiobookMetadataCache,
      $$AudiobookMetadataCacheTableFilterComposer,
      $$AudiobookMetadataCacheTableOrderingComposer,
      $$AudiobookMetadataCacheTableAnnotationComposer,
      $$AudiobookMetadataCacheTableCreateCompanionBuilder,
      $$AudiobookMetadataCacheTableUpdateCompanionBuilder,
      (
        DbAudiobookMetadataCache,
        BaseReferences<
          _$AppDatabase,
          $AudiobookMetadataCacheTable,
          DbAudiobookMetadataCache
        >,
      ),
      DbAudiobookMetadataCache,
      PrefetchHooks Function()
    >;
typedef $$AudiobookBookmarksTableCreateCompanionBuilder =
    AudiobookBookmarksCompanion Function({
      Value<int> id,
      required String bookId,
      required int chapterIndex,
      required int positionMillis,
      Value<String?> label,
      required int createdAt,
    });
typedef $$AudiobookBookmarksTableUpdateCompanionBuilder =
    AudiobookBookmarksCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<int> positionMillis,
      Value<String?> label,
      Value<int> createdAt,
    });

class $$AudiobookBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $AudiobookBookmarksTable> {
  $$AudiobookBookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMillis => $composableBuilder(
    column: $table.positionMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudiobookBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $AudiobookBookmarksTable> {
  $$AudiobookBookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMillis => $composableBuilder(
    column: $table.positionMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudiobookBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudiobookBookmarksTable> {
  $$AudiobookBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMillis => $composableBuilder(
    column: $table.positionMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AudiobookBookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudiobookBookmarksTable,
          DbAudiobookBookmark,
          $$AudiobookBookmarksTableFilterComposer,
          $$AudiobookBookmarksTableOrderingComposer,
          $$AudiobookBookmarksTableAnnotationComposer,
          $$AudiobookBookmarksTableCreateCompanionBuilder,
          $$AudiobookBookmarksTableUpdateCompanionBuilder,
          (
            DbAudiobookBookmark,
            BaseReferences<
              _$AppDatabase,
              $AudiobookBookmarksTable,
              DbAudiobookBookmark
            >,
          ),
          DbAudiobookBookmark,
          PrefetchHooks Function()
        > {
  $$AudiobookBookmarksTableTableManager(
    _$AppDatabase db,
    $AudiobookBookmarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudiobookBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudiobookBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudiobookBookmarksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> positionMillis = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => AudiobookBookmarksCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                positionMillis: positionMillis,
                label: label,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required int chapterIndex,
                required int positionMillis,
                Value<String?> label = const Value.absent(),
                required int createdAt,
              }) => AudiobookBookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                positionMillis: positionMillis,
                label: label,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudiobookBookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudiobookBookmarksTable,
      DbAudiobookBookmark,
      $$AudiobookBookmarksTableFilterComposer,
      $$AudiobookBookmarksTableOrderingComposer,
      $$AudiobookBookmarksTableAnnotationComposer,
      $$AudiobookBookmarksTableCreateCompanionBuilder,
      $$AudiobookBookmarksTableUpdateCompanionBuilder,
      (
        DbAudiobookBookmark,
        BaseReferences<
          _$AppDatabase,
          $AudiobookBookmarksTable,
          DbAudiobookBookmark
        >,
      ),
      DbAudiobookBookmark,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TorrentsTableTableManager get torrents =>
      $$TorrentsTableTableManager(_db, _db.torrents);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db, _db.files);
  $$TrackMetadataTableTableManager get trackMetadata =>
      $$TrackMetadataTableTableManager(_db, _db.trackMetadata);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$PlaybackHistoryTableTableManager get playbackHistory =>
      $$PlaybackHistoryTableTableManager(_db, _db.playbackHistory);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$ExternalTrackMetadataTableTableManager get externalTrackMetadata =>
      $$ExternalTrackMetadataTableTableManager(_db, _db.externalTrackMetadata);
  $$FollowedArtistsTableTableManager get followedArtists =>
      $$FollowedArtistsTableTableManager(_db, _db.followedArtists);
  $$AudiobookProgressTableTableManager get audiobookProgress =>
      $$AudiobookProgressTableTableManager(_db, _db.audiobookProgress);
  $$AudiobookMetadataCacheTableTableManager get audiobookMetadataCache =>
      $$AudiobookMetadataCacheTableTableManager(
        _db,
        _db.audiobookMetadataCache,
      );
  $$AudiobookBookmarksTableTableManager get audiobookBookmarks =>
      $$AudiobookBookmarksTableTableManager(_db, _db.audiobookBookmarks);
}
