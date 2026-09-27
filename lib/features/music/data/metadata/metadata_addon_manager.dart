import 'package:injectable/injectable.dart';
import '../../../settings/data/torbox_settings_repository.dart';
import '../musicbrainz_service.dart';
import 'metadata_provider.dart';
import 'deezer_metadata_provider.dart';
import 'apple_music_metadata_provider.dart';

@lazySingleton
class MetadataAddonManager {
  final TorBoxSettingsRepository _settings;
  final DeezerMetadataProvider _deezer;
  final AppleMusicMetadataProvider _appleMusic;
  final MusicBrainzService _musicBrainz;

  List<MetadataProvider> _providers = [];
  final Map<String, TrackMeta> _cache = {};

  MetadataAddonManager(
    this._settings,
    this._deezer,
    this._appleMusic,
    this._musicBrainz,
  );

  List<MetadataProvider> get providers {
    _ensureInitialized();
    return List.unmodifiable(_providers);
  }

  void _ensureInitialized() {
    if (_providers.isNotEmpty) return;
    _providers = [
      _appleMusic,
      _deezer,
    ];
  }

  bool isEnabled(String id) {
    return _settings.isMetadataProviderEnabled(id);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _settings.setMetadataProviderEnabled(id, enabled);
  }

  String _buildKey(String title, String artist) =>
      '${title.trim().toLowerCase()}_${artist.trim().toLowerCase()}';

  TrackMeta? getCached({String? id, String? isrc, String? title, String? artist}) {
    if (id != null && id.isNotEmpty && _cache.containsKey(id)) {
      return _cache[id];
    }
    if (isrc != null && isrc.isNotEmpty && _cache.containsKey('isrc_$isrc')) {
      return _cache['isrc_$isrc'];
    }
    if (title != null && artist != null && title.isNotEmpty) {
      final key = _buildKey(title, artist);
      if (_cache.containsKey(key)) return _cache[key];
    }
    return null;
  }

  void cacheMeta(TrackMeta meta, {String? id, String? title, String? artist}) {
    if (id != null && id.isNotEmpty) {
      _cache[id] = meta;
    }
    if (meta.isrc != null && meta.isrc!.isNotEmpty) {
      _cache['isrc_${meta.isrc}'] = meta;
    }
    if (meta.trackName != null && meta.artistName != null) {
      _cache[_buildKey(meta.trackName!, meta.artistName!)] = meta;
    }
    if (title != null && artist != null && title.isNotEmpty) {
      _cache[_buildKey(title, artist)] = meta;
    }
  }

  Future<TrackMeta?> enrich(String title, String artist,
      {String? isrc, String? id}) async {
    final cached = getCached(id: id, isrc: isrc, title: title, artist: artist);
    if (cached != null) return cached;

    _ensureInitialized();

    TrackMeta? result;
    String? resolvedIsrc = isrc;

    // Pass 1: primary metadata from enabled providers (first non-null wins,
    // keeping the provider order preference such as Apple first).
    for (final provider in _providers) {
      if (!isEnabled(provider.id)) continue;

      try {
        final meta = await (resolvedIsrc != null
            ? provider.enrichByIsrc(resolvedIsrc)
            : provider.enrich(title, artist));
        if (meta != null) {
          result ??= meta;
          if (meta.isrc != null) resolvedIsrc = meta.isrc;
        }
      } catch (e) {
        print('[MetadataAddon] ${provider.id} failed: $e');
      }
    }

    // Pass 2: even when a provider (e.g. Apple Music) already returned
    // metadata, try to attach an ISRC via MusicBrainz -> Deezer when Deezer
    // is enabled, since the iTunes API never exposes ISRC.
    if (resolvedIsrc == null && isEnabled('deezer')) {
      try {
        final isrcs = await _musicBrainz.lookupIsrc(title, artist);
        for (final candidate in isrcs) {
          final meta = await _deezer.enrichByIsrc(candidate);
          if (meta != null) {
            result ??= meta;
            if (meta.isrc != null) {
              resolvedIsrc = meta.isrc;
              break;
            }
          }
        }
      } catch (e) {
        print('[MetadataAddon] ISRC resolution failed: $e');
      }
    }

    if (result != null && result.isrc == null && resolvedIsrc != null) {
      result = result.copyWith(isrc: resolvedIsrc);
    }

    if (result != null) {
      cacheMeta(result, id: id, title: title, artist: artist);
    }
    return result;
  }

  Future<TrackMeta?> enrichByIsrc(String isrc, {String? id}) async {
    final cached = getCached(id: id, isrc: isrc);
    if (cached != null) return cached;

    _ensureInitialized();

    for (final provider in _providers) {
      if (!isEnabled(provider.id)) continue;
      try {
        final result = await provider.enrichByIsrc(isrc);
        if (result != null) {
          cacheMeta(result, id: id);
          return result;
        }
      } catch (e) {
        print('[MetadataAddon] ${provider.id} enrichByIsrc failed: $e');
      }
    }
    return null;
  }
}
