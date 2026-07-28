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

    for (final provider in _providers) {
      if (!isEnabled(provider.id)) continue;

      try {
        final result = await (isrc != null
            ? provider.enrichByIsrc(isrc)
            : provider.enrich(title, artist));
        if (result != null) return result;
      } catch (e) {
        print('[MetadataAddon] ${provider.id} failed: $e');
      }

      if (isrc == null && provider.id == 'deezer') {
        try {
          final isrcs = await _musicBrainz.lookupIsrc(title, artist);
          for (final resolvedIsrc in isrcs) {
            final result =
                await provider.enrichByIsrc(resolvedIsrc);
            if (result != null) return result;
          }
        } catch (e) {
          print('[MetadataAddon] ${provider.id} ISRC resolution failed: $e');
        }
      }
    }
    return null;
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
