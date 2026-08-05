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

  Future<TrackMeta?> enrich(String title, String artist,
      {String? isrc}) async {
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
    return result;
  }

  Future<TrackMeta?> enrichByIsrc(String isrc) async {
    _ensureInitialized();

    for (final provider in _providers) {
      if (!isEnabled(provider.id)) continue;
      try {
        final result = await provider.enrichByIsrc(isrc);
        if (result != null) return result;
      } catch (e) {
        print('[MetadataAddon] ${provider.id} enrichByIsrc failed: $e');
      }
    }
    return null;
  }
}
