// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:isai/core/database/database.dart' as _i448;
import 'package:isai/core/di/storage_module.dart' as _i773;
import 'package:isai/core/network/network_module.dart' as _i377;
import 'package:isai/features/audiobooks/data/audiobook_addon_service.dart'
    as _i463;
import 'package:isai/features/audiobooks/data/audiobook_repository.dart'
    as _i168;
import 'package:isai/features/music/data/deezer_service.dart' as _i887;
import 'package:isai/features/music/data/itunes_metadata_service.dart' as _i39;
import 'package:isai/features/music/data/lastfm_service.dart' as _i1016;
import 'package:isai/features/music/data/music_repository.dart' as _i81;
import 'package:isai/features/music/data/musicbrainz_service.dart' as _i615;
import 'package:isai/features/music/data/plugins/plugin_manager.dart' as _i1006;
import 'package:isai/features/music/data/scrapers/last_fm_scraper.dart'
    as _i893;
import 'package:isai/features/player/data/audio_metadata_service.dart' as _i349;
import 'package:isai/features/settings/data/hardcover_settings_repository.dart'
    as _i1012;
import 'package:isai/features/settings/data/lastfm_repository.dart' as _i230;
import 'package:isai/features/settings/data/torbox_settings_repository.dart'
    as _i183;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final storageModule = _$StorageModule();
    final networkModule = _$NetworkModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => storageModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i448.AppDatabase>(() => storageModule.database);
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i349.AudioMetadataService>(
      () => _i349.AudioMetadataService(),
    );
    gh.lazySingleton<_i887.DeezerService>(
      () => _i887.DeezerService(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i39.ItunesMetadataService>(
      () => _i39.ItunesMetadataService(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i1016.LastFmService>(
      () => _i1016.LastFmService(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i615.MusicBrainzService>(
      () => _i615.MusicBrainzService(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i1006.PluginManager>(
      () => _i1006.PluginManager(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i893.LastFmScraper>(
      () => _i893.LastFmScraper(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i183.TorBoxSettingsRepository>(
      () => _i183.TorBoxSettingsRepositoryImpl(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i230.LastfmRepository>(
      () => _i230.LastfmRepositoryImpl(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i1012.HardcoverSettingsRepository>(
      () =>
          _i1012.HardcoverSettingsRepositoryImpl(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i81.MusicRepository>(
      () => _i81.MusicRepositoryImpl(
        gh<_i361.Dio>(),
        gh<_i183.TorBoxSettingsRepository>(),
        gh<_i39.ItunesMetadataService>(),
        gh<_i893.LastFmScraper>(),
        gh<_i448.AppDatabase>(),
        gh<_i615.MusicBrainzService>(),
        gh<_i887.DeezerService>(),
        gh<_i1016.LastFmService>(),
        gh<_i1006.PluginManager>(),
      ),
    );
    gh.lazySingleton<_i463.AudiobookAddonService>(
      () => _i463.AudiobookAddonService(
        gh<_i1006.PluginManager>(),
        gh<_i183.TorBoxSettingsRepository>(),
      ),
    );
    gh.lazySingleton<_i168.AudiobookRepository>(
      () => _i168.AudiobookRepository(
        gh<_i463.AudiobookAddonService>(),
        gh<_i448.AppDatabase>(),
        gh<_i81.MusicRepository>(),
      ),
    );
    return this;
  }
}

class _$StorageModule extends _i773.StorageModule {}

class _$NetworkModule extends _i377.NetworkModule {}
