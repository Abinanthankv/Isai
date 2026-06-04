import 'package:isai/core/utils/string_utils.dart';

class TorBoxTorrent {
  final int id;
  final String name;
  final String hash;
  final bool cached;
  final List<TorBoxFile> files;

  TorBoxTorrent({
    required this.id,
    required this.name,
    required this.hash,
    required this.cached,
    required this.files,
  });

  factory TorBoxTorrent.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as List<dynamic>? ?? [];
    final torrentId = (json['id'] as num?)?.toInt() ?? 0;
    return TorBoxTorrent(
      id: torrentId,
      name: json['name'] as String? ?? 'Unknown',
      hash: json['hash'] as String? ?? '',
      cached: json['cached'] as bool? ?? false,
      files: rawFiles
          .map((f) => TorBoxFile.fromJson(f as Map<String, dynamic>, torrentId))
          .where((f) => f.isAudio)
          .toList(),
    );
  }
}

class TorBoxFile {
  final int id;
  final String name;
  final int size;
  final int torrentId;
  final String? localPath;

  static const _audioExtensions = ['.mp3', '.flac', '.aac', '.m4a', '.ogg', '.opus', '.wav'];

  TorBoxFile({
    required this.id,
    required this.name,
    required this.size,
    required this.torrentId,
    this.localPath,
  });

  bool get isAudio {
    final lower = name.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }

  String get displayName {
    // Strip leading path if any
    return name.split('/').last.split('\\').last;
  }

  String get formattedSize {
    if (size > 1024 * 1024 * 1024) return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (size > 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }

  factory TorBoxFile.fromJson(Map<String, dynamic> json, [int? parentTorrentId]) {
    return TorBoxFile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      // prefer explicit field, fallback to parentTorrentId
      torrentId: (json['torrent_id'] as num?)?.toInt() ?? parentTorrentId ?? 0,
      localPath: json['local_path'] as String?,
    );
  }
}

// iTunes Search API models
class ItunesTrack {
  final int trackId;
  final String trackName;
  final String artistName;
  final String collectionName;
  final String artworkUrl;
  final String? previewUrl;
  final int? trackTimeMillis;
  final int? trackNumber;
  final DateTime? releaseDate;
  final String? artistViewUrl;

  ItunesTrack({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    required this.collectionName,
    required this.artworkUrl,
    this.previewUrl,
    this.trackTimeMillis,
    this.trackNumber,
    this.releaseDate,
    this.artistViewUrl,
  });

  ItunesTrack copyWith({
    int? trackId,
    String? trackName,
    String? artistName,
    String? collectionName,
    String? artworkUrl,
    String? previewUrl,
    int? trackTimeMillis,
    int? trackNumber,
    DateTime? releaseDate,
    String? artistViewUrl,
  }) {
    return ItunesTrack(
      trackId: trackId ?? this.trackId,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      collectionName: collectionName ?? this.collectionName,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      trackTimeMillis: trackTimeMillis ?? this.trackTimeMillis,
      trackNumber: trackNumber ?? this.trackNumber,
      releaseDate: releaseDate ?? this.releaseDate,
      artistViewUrl: artistViewUrl ?? this.artistViewUrl,
    );
  }

  factory ItunesTrack.fromJson(Map<String, dynamic> json) {
    // Upgrade artwork to 600x600
    final artwork = (json['artworkUrl100'] as String? ?? '')
        .replaceAll('100x100bb', '600x600bb');
    
    // iTunes returns trackId for songs, collectionId for albums
    // Try trackId first, then fall back to collectionId
    int id = 0;
    if (json.containsKey('trackId')) {
      id = (json['trackId'] is int)
          ? json['trackId'] as int
          : int.tryParse(json['trackId']?.toString() ?? '0') ?? 0;
    } else if (json.containsKey('collectionId')) {
      id = (json['collectionId'] is int)
          ? json['collectionId'] as int
          : int.tryParse(json['collectionId']?.toString() ?? '0') ?? 0;
    }
    
    return ItunesTrack(
      trackId: id,
      trackName: json['trackName'] as String? ?? json['collectionName'] as String? ?? 'Unknown',
      artistName: json['artistName'] as String? ?? 'Unknown Artist',
      collectionName: json['collectionName'] as String? ?? json['trackName'] as String? ?? 'Unknown Album',
      artworkUrl: artwork,
      previewUrl: json['previewUrl'] as String?,
      trackTimeMillis: (json['trackTimeMillis'] as num?)?.toInt(),
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      releaseDate: json['releaseDate'] != null ? DateTime.tryParse(json['releaseDate'] as String) : null,
      artistViewUrl: json['artistViewUrl'] as String?,
    );
  }

  String get torrentQuery => '$artistName $collectionName';

  static String formatDuration(int? millis) {
    if (millis == null) return '--:--';
    final duration = Duration(milliseconds: millis);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatDurationLong(int? millis) {
    if (millis == null) return '--';
    final duration = Duration(milliseconds: millis);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      if (minutes > 0) {
        return '$hours hr $minutes mins';
      }
      return '$hours hr';
    }
    if (minutes < 1) return '${duration.inSeconds} secs';
    return '$minutes mins';
  }

  static List<String> splitArtists(String artistName) {
    if (artistName.isEmpty) return [];
    
    // Pattern to split by: comma, &, feat., ft., and, with, ;
    final separators = RegExp(r',|&|\bfeat\.?\b|\bft\.?\b|\band\b|\bwith\b|;', caseSensitive: false);
    
    return artistName
        .split(separators)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

class ItunesArtist {
  final int artistId;
  final String artistName;
  final String? primaryGenreName;
  final String? artistLinkUrl;

  ItunesArtist({
    required this.artistId,
    required this.artistName,
    this.primaryGenreName,
    this.artistLinkUrl,
  });

  factory ItunesArtist.fromJson(Map<String, dynamic> json) {
    return ItunesArtist(
      artistId: (json['artistId'] as num?)?.toInt() ?? 0,
      artistName: json['artistName'] as String? ?? 'Unknown Artist',
      primaryGenreName: json['primaryGenreName'] as String?,
      artistLinkUrl: json['artistViewUrl'] as String?,
    );
  }
}

// Apibay torrent search result
class ApibayResult {
  final String name;
  final String infoHash;
  final int seeders;
  final int leechers;
  final int size;

  ApibayResult({
    required this.name,
    required this.infoHash,
    required this.seeders,
    required this.leechers,
    required this.size,
  });

  factory ApibayResult.fromJson(Map<String, dynamic> json) {
    return ApibayResult(
      name: json['name'] as String? ?? '',
      infoHash: json['info_hash'] as String? ?? '',
      seeders: int.tryParse(json['seeders']?.toString() ?? '0') ?? 0,
      leechers: int.tryParse(json['leechers']?.toString() ?? '0') ?? 0,
      size: int.tryParse(json['size']?.toString() ?? '0') ?? 0,
    );
  }

  String get magnetLink =>
      'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(name)}'
      '&tr=udp://tracker.opentrackr.org:1337/announce'
      '&tr=udp://open.stealth.si:80/announce'
      '&tr=udp://exodus.desync.com:6969/announce'
      '&tr=udp://tracker.torrent.eu.org:451/announce'
      '&tr=udp://explodie.org:6969/announce'
      '&tr=udp://tracker.moeking.me:6969/announce';

  String get formattedSize {
    if (size > 1024 * 1024 * 1024) return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (size > 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }
}

class YouTubeResult {
  final String id;
  final String title;
  final String author;
  final String duration;
  final String thumbnailUrl;

  YouTubeResult({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
  });

  String get videoUrl => 'https://www.youtube.com/watch?v=$id';
}

class TorrentSearchResult {
  final String name;
  final String infoHash;
  final int seeders;
  final int leechers;
  final int size;
  final String source;
  final String? magnetLink;

  TorrentSearchResult({
    required this.name,
    String? infoHash,
    required this.seeders,
    required this.leechers,
    required this.size,
    required this.source,
    this.magnetLink,
  }) : infoHash = (infoHash == null || infoHash.isEmpty) && magnetLink != null
            ? _extractHash(magnetLink)
            : infoHash ?? '';

  static String _extractHash(String magnet) {
    final match = RegExp(r'btih:([a-fA-F0-9]{40}|[a-zA-Z2-7]{32})', caseSensitive: false).firstMatch(magnet);
    return match?.group(1)?.toLowerCase() ?? '';
  }

  factory TorrentSearchResult.fromApibay(ApibayResult result) {
    return TorrentSearchResult(
      name: result.name,
      infoHash: result.infoHash,
      seeders: result.seeders,
      leechers: result.leechers,
      size: result.size,
      source: 'apibay',
      magnetLink: result.magnetLink,
    );
  }

  factory TorrentSearchResult.fromBitsearch(Map<String, dynamic> json) {
    return TorrentSearchResult(
      name: json['title'] as String? ?? '',
      infoHash: json['infohash'] as String? ?? '',
      seeders: (json['seeders'] as num?)?.toInt() ?? 0,
      leechers: (json['leechers'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      source: 'bitsearch',
    );
  }

  String get formattedSize {
    if (size > 1024 * 1024 * 1024) return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (size > 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }

  String get magnetUri {
    if (magnetLink != null) return magnetLink!;
    return 'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(name)}'
        '&tr=udp://tracker.opentrackr.org:1337/announce'
        '&tr=udp://open.stealth.si:80/announce'
        '&tr=udp://exodus.desync.com:6969/announce'
        '&tr=udp://tracker.torrent.eu.org:451/announce'
        '&tr=udp://explodie.org:6969/announce'
        '&tr=udp://tracker.moeking.me:6969/announce';
  }
}

class ScraperResult {
  final String title;
  final String artist;
  final String url;
  final int size;
  final String format;
  final String? thumbnail;
  final String source;
  final String? album;
  final String? linkType;
  final String? duration;
  final Map<String, dynamic>? extras;

  ScraperResult({
    required this.title,
    required this.artist,
    required this.url,
    required this.size,
    required this.format,
    this.thumbnail,
    required this.source,
    this.album,
    this.linkType,
    this.duration,
    this.extras,
  });

  String get formattedSize {
    if (size > 1024 * 1024 * 1024) return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (size > 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }

  bool isGoodMatch(String targetTitle, String targetArtist) {
    if (targetTitle.isEmpty) return false;
    
    final tTitle = StringUtils.normalize(targetTitle);
    final tArtist = StringUtils.normalize(targetArtist);
    final rTitle = StringUtils.normalize(title);
    final rArtist = StringUtils.normalize(artist);
    
    if (tTitle.isEmpty) return false;

    // Strict check for "remix", "live", "instrumental", "acoustic", "cover" 
    // to avoid wrong versions
    bool checkKeyword(String word) {
      bool targetHas = tTitle.contains(word);
      bool resultHas = rTitle.contains(word);
      return targetHas == resultHas;
    }
    
    final keywords = ['remix', 'live', 'instrumental', 'acoustic', 'cover'];
    for (final kw in keywords) {
      if (!checkKeyword(kw)) return false;
    }

    // 1. Title Match: The title MUST be present in the result title
    // or vice versa, but with a stricter containment check.
    bool titleMatches = rTitle.contains(tTitle) || tTitle.contains(rTitle);
    if (!titleMatches) return false;

    // 2. Artist Match: 
    // If target artist is "Unknown Artist" or empty, we allow any artist match.
    if (tArtist.isEmpty || tArtist == 'unknown artist') return true;

    // If result artist is empty but title matches, it's a weak match, 
    // but better than a wrong artist.
    if (rArtist.isEmpty) return true;

    // Check if one artist contains the other
    bool artistMatches = rArtist.contains(tArtist) || tArtist.contains(rArtist);
    
    // If no direct containment, check individual significant words
    if (!artistMatches) {
      final tWords = tArtist.split(' ').where((w) => w.length > 2).toList();
      final rWords = rArtist.split(' ').where((w) => w.length > 2).toList();
      
      // At least one significant word from target artist MUST match a significant word in result artist
      artistMatches = tWords.any((tw) => rWords.any((rw) => tw == rw));
    }

    return artistMatches;
  }
}

class AppleMusicPlaylist {
  final String id;
  final String name;
  final String artworkUrl;
  final String url;

  AppleMusicPlaylist({
    required this.id,
    required this.name,
    required this.artworkUrl,
    required this.url,
  });

  factory AppleMusicPlaylist.fromJson(Map<String, dynamic> json) {
    // Standardize artwork resolution to 600x600
    final rawArtwork = json['artworkUrl100'] as String? ?? '';
    final artwork = rawArtwork.replaceAll(RegExp(r'\d+x\d+'), '600x600');

    return AppleMusicPlaylist(
      id: json['id'] as String? ?? '0',
      name: json['name'] as String? ?? 'Unknown Playlist',
      artworkUrl: artwork,
      url: json['url'] as String? ?? '',
    );
  }
}

class DeezerPlaylist {
  final String id;
  final String title;
  final String artworkUrl;
  final int nbTracks;
  final String link;

  DeezerPlaylist({
    required this.id,
    required this.title,
    required this.artworkUrl,
    required this.nbTracks,
    required this.link,
  });

  factory DeezerPlaylist.fromJson(Map<String, dynamic> json) {
    return DeezerPlaylist(
      id: json['id']?.toString() ?? '0',
      title: json['title'] as String? ?? 'Unknown Playlist',
      artworkUrl: json['picture_big'] as String? ?? json['picture_medium'] as String? ?? json['picture'] as String? ?? '',
      nbTracks: int.tryParse(json['nb_tracks']?.toString() ?? '0') ?? 0,
      link: json['link'] as String? ?? '',
    );
  }
}

class DeezerGenre {
  final int id;
  final String name;
  final String picture;

  DeezerGenre({
    required this.id,
    required this.name,
    required this.picture,
  });

  factory DeezerGenre.fromJson(Map<String, dynamic> json) {
    return DeezerGenre(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      picture: json['picture_medium'] as String? ?? json['picture_big'] as String? ?? json['picture'] as String? ?? '',
    );
  }
}


