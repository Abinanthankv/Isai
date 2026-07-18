import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/di/injection.dart';
import 'package:isai/core/utils/string_utils.dart';
import '../../settings/data/torbox_settings_repository.dart';
import '../../settings/data/hardcover_settings_repository.dart';
import '../../audiobooks/data/hardcover_api_service.dart';
import '../../music/data/music_repository.dart';
import '../../music/data/music_models.dart';
import 'downloads_screen.dart';
import 'playlist_providers.dart';
import '../../player/presentation/player_providers.dart';
import '../data/itunes_metadata_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/database/database.dart';
import 'package:isai/main.dart';
import '../../player/data/audio_handler.dart';
import 'package:drift/drift.dart' hide Column;
import 'dart:async';
import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:typed_data';
import '../data/lastfm_service.dart';
import '../../settings/data/lastfm_repository.dart';
import 'lastfm_provider.dart';
import 'package:audiotags/audiotags.dart';


/// Parses a raw audio filename like "Artist - Title.mp3" or "Title.mp3"
/// and returns (title, artist).
({String title, String artist}) parseFilename(String displayName) {
  // 1. Strip extension
  var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();

  // 2. Strip common track number patterns at the start (e.g. "01 - ", "01. ", "01 ")
  name = name.replaceAll(RegExp(r'^\d+\s*[-.]? \s*'), '');

  // 3. Common pattern: "Artist - Title" or "Artist – Title"
  final sep = RegExp(r' [-–] ');
  final match = sep.firstMatch(name);
  if (match != null) {
    return (
      artist: name.substring(0, match.start).trim(),
      title: name.substring(match.end).trim(),
    );
  }
  return (title: name.trim(), artist: '');
}

// ─── Settings Provider ───────────────────────────────────────────────────────
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

class SettingsState {
  final String apiKey;
  final bool isValidating;
  final bool isValid;
  final String? error;
  final bool enableYouTubeScraper;
  final List<String> downloadFolders;
  final String? selectedDownloadFolder;
  final String playerArtworkShape;
  final bool playerShowGlow;
  final String playerBackgroundType;
  final double playerArtworkSize;
  final String playerSeekBarStyle;
  final String playerLikeIcon;
  final String playerArtworkAnimation;
  final double playerLyricsFontSize;
  final String playerLyricsAlignment;
  final String playerControlLayout;
  final String playerButtonStyle;
  final bool playerMinimalistShowSource;
  final bool playerMinimalistShowLyrics;
  final bool playerMinimalistShowSleep;
  final bool playerMinimalistShowQueue;
  // Visualizer
  final bool visualizerEnabled;
  final bool visualizerShowNowPlaying;
  final bool visualizerShowMiniPlayer;
  final String visualizerStyle;
  final int visualizerPoints;
  final double visualizerSensitivity;
  final String visualizerColorMode;
  final double visualizerAlpha;
  final double visualizerHeightPct;
  final double visualizerAmplitude;
  final double visualizerBaseLift;
  final double visualizerBarSpacing;
  final double visualizerCornerRadius;
  final int maxSongCacheSize;
  final int maxImageCacheSize;
  final List<String> addonPriority;
  final String appThemeStyle;
  final String appFontFamily;
  final bool appleUseLiquidGlass;
  final double appleLiquidGlassOpacity;
  final bool miniPlayerSwipeEnabled;
  final double miniPlayerSwipeSensitivity;
  final bool playerSpotifyCanvasEnabled;
  final bool playerShowCurrentLyrics;
  final String? audiobookFolder;
  final String hardcoverApiKey;
  final bool hardcoverIsValid;
  final bool hardcoverIsValidating;
  final String? hardcoverError;
  final String? hardcoverUsername;

  bool get hardcoverHasKey => hardcoverApiKey.isNotEmpty;

  SettingsState({
    this.apiKey = '',
    this.isValidating = false,
    this.isValid = false,
    this.error,
    this.enableYouTubeScraper = true,
    this.downloadFolders = const [],
    this.selectedDownloadFolder,
    this.playerArtworkShape = 'circle',
    this.playerShowGlow = true,
    this.playerBackgroundType = 'blurred',
    this.playerArtworkSize = 270.0,
    this.playerSeekBarStyle = 'default',
    this.playerLikeIcon = 'heart',
    this.playerArtworkAnimation = 'zoom',
    this.playerLyricsFontSize = 18.0,
    this.playerLyricsAlignment = 'center',
    this.playerControlLayout = 'standard',
    this.playerButtonStyle = 'theme',
    this.playerMinimalistShowSource = false,
    this.playerMinimalistShowLyrics = false,
    this.playerMinimalistShowSleep = false,
    this.playerMinimalistShowQueue = false,
    this.visualizerEnabled = false,
    this.visualizerShowNowPlaying = true,
    this.visualizerShowMiniPlayer = true,
    this.visualizerStyle = 'bar',
    this.visualizerPoints = 24,
    this.visualizerSensitivity = 0.1,
    this.visualizerColorMode = 'albumArt',
    this.visualizerAlpha = 0.6,
    this.visualizerHeightPct = 0.8,
    this.visualizerAmplitude = 0.1,
    this.visualizerBaseLift = 105.0,
    this.visualizerBarSpacing = 0.0,
    this.visualizerCornerRadius = 0.0,
    this.maxSongCacheSize = 1024,
    this.maxImageCacheSize = 512,
    this.addonPriority = const [],
    this.appThemeStyle = 'material3',
    this.appFontFamily = 'Roboto Flex',
    this.appleUseLiquidGlass = true,
    this.appleLiquidGlassOpacity = 0.5,
    this.miniPlayerSwipeEnabled = true,
    this.miniPlayerSwipeSensitivity = 40.0,
    this.playerSpotifyCanvasEnabled = true,
    this.playerShowCurrentLyrics = false,
    this.audiobookFolder,
    this.hardcoverApiKey = '',
    this.hardcoverIsValid = false,
    this.hardcoverIsValidating = false,
    this.hardcoverError,
    this.hardcoverUsername,
  });

  SettingsState copyWith({
    String? apiKey, 
    bool? isValidating, 
    bool? isValid, 
    String? error,
    bool? enableYouTubeScraper,
    List<String>? downloadFolders,
    String? selectedDownloadFolder,
    String? playerArtworkShape,
    bool? playerShowGlow,
    String? playerBackgroundType,
    double? playerArtworkSize,
    String? playerSeekBarStyle,
    String? playerLikeIcon,
    String? playerArtworkAnimation,
    double? playerLyricsFontSize,
    String? playerLyricsAlignment,
    String? playerControlLayout,
    String? playerButtonStyle,
    bool? playerMinimalistShowSource,
    bool? playerMinimalistShowLyrics,
    bool? playerMinimalistShowSleep,
    bool? playerMinimalistShowQueue,
    bool? visualizerEnabled,
    bool? visualizerShowNowPlaying,
    bool? visualizerShowMiniPlayer,
    String? visualizerStyle,
    int? visualizerPoints,
    double? visualizerSensitivity,
    String? visualizerColorMode,
    double? visualizerAlpha,
    double? visualizerHeightPct,
    double? visualizerAmplitude,
    double? visualizerBaseLift,
    double? visualizerBarSpacing,
    double? visualizerCornerRadius,
    int? maxSongCacheSize,
    int? maxImageCacheSize,
    List<String>? addonPriority,
    String? appThemeStyle,
    String? appFontFamily,
    bool? appleUseLiquidGlass,
    double? appleLiquidGlassOpacity,
    bool? miniPlayerSwipeEnabled,
    double? miniPlayerSwipeSensitivity,
    bool? playerSpotifyCanvasEnabled,
    bool? playerShowCurrentLyrics,
    String? audiobookFolder,
    String? hardcoverApiKey,
    bool? hardcoverIsValid,
    bool? hardcoverIsValidating,
    String? hardcoverError,
    String? hardcoverUsername,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      isValidating: isValidating ?? this.isValidating,
      isValid: isValid ?? this.isValid,
      error: error,
      enableYouTubeScraper: enableYouTubeScraper ?? this.enableYouTubeScraper,
      downloadFolders: downloadFolders ?? this.downloadFolders,
      selectedDownloadFolder: selectedDownloadFolder ?? this.selectedDownloadFolder,
      playerArtworkShape: playerArtworkShape ?? this.playerArtworkShape,
      playerShowGlow: playerShowGlow ?? this.playerShowGlow,
      playerBackgroundType: playerBackgroundType ?? this.playerBackgroundType,
      playerArtworkSize: playerArtworkSize ?? this.playerArtworkSize,
      playerSeekBarStyle: playerSeekBarStyle ?? this.playerSeekBarStyle,
      playerLikeIcon: playerLikeIcon ?? this.playerLikeIcon,
      playerArtworkAnimation: playerArtworkAnimation ?? this.playerArtworkAnimation,
      playerLyricsFontSize: playerLyricsFontSize ?? this.playerLyricsFontSize,
      playerLyricsAlignment: playerLyricsAlignment ?? this.playerLyricsAlignment,
      playerControlLayout: playerControlLayout ?? this.playerControlLayout,
      playerButtonStyle: playerButtonStyle ?? this.playerButtonStyle,
      playerMinimalistShowSource: playerMinimalistShowSource ?? this.playerMinimalistShowSource,
      playerMinimalistShowLyrics: playerMinimalistShowLyrics ?? this.playerMinimalistShowLyrics,
      playerMinimalistShowSleep: playerMinimalistShowSleep ?? this.playerMinimalistShowSleep,
      playerMinimalistShowQueue: playerMinimalistShowQueue ?? this.playerMinimalistShowQueue,
      visualizerEnabled: visualizerEnabled ?? this.visualizerEnabled,
      visualizerShowNowPlaying: visualizerShowNowPlaying ?? this.visualizerShowNowPlaying,
      visualizerShowMiniPlayer: visualizerShowMiniPlayer ?? this.visualizerShowMiniPlayer,
      visualizerStyle: visualizerStyle ?? this.visualizerStyle,
      visualizerPoints: visualizerPoints ?? this.visualizerPoints,
      visualizerSensitivity: visualizerSensitivity ?? this.visualizerSensitivity,
      visualizerColorMode: visualizerColorMode ?? this.visualizerColorMode,
      visualizerAlpha: visualizerAlpha ?? this.visualizerAlpha,
      visualizerHeightPct: visualizerHeightPct ?? this.visualizerHeightPct,
      visualizerAmplitude: visualizerAmplitude ?? this.visualizerAmplitude,
      visualizerBaseLift: visualizerBaseLift ?? this.visualizerBaseLift,
      visualizerBarSpacing: visualizerBarSpacing ?? this.visualizerBarSpacing,
      visualizerCornerRadius: visualizerCornerRadius ?? this.visualizerCornerRadius,
      maxSongCacheSize: maxSongCacheSize ?? this.maxSongCacheSize,
      maxImageCacheSize: maxImageCacheSize ?? this.maxImageCacheSize,
      addonPriority: addonPriority ?? this.addonPriority,
      appThemeStyle: appThemeStyle ?? this.appThemeStyle,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      appleUseLiquidGlass: appleUseLiquidGlass ?? this.appleUseLiquidGlass,
      appleLiquidGlassOpacity: appleLiquidGlassOpacity ?? this.appleLiquidGlassOpacity,
      miniPlayerSwipeEnabled: miniPlayerSwipeEnabled ?? this.miniPlayerSwipeEnabled,
      miniPlayerSwipeSensitivity: miniPlayerSwipeSensitivity ?? this.miniPlayerSwipeSensitivity,
      playerSpotifyCanvasEnabled: playerSpotifyCanvasEnabled ?? this.playerSpotifyCanvasEnabled,
      playerShowCurrentLyrics: playerShowCurrentLyrics ?? this.playerShowCurrentLyrics,
      audiobookFolder: audiobookFolder ?? this.audiobookFolder,
      hardcoverApiKey: hardcoverApiKey ?? this.hardcoverApiKey,
      hardcoverIsValid: hardcoverIsValid ?? this.hardcoverIsValid,
      hardcoverIsValidating: hardcoverIsValidating ?? this.hardcoverIsValidating,
      hardcoverError: hardcoverError ?? this.hardcoverError,
      hardcoverUsername: hardcoverUsername ?? this.hardcoverUsername,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late final TorBoxSettingsRepository _settings;
  late final HardcoverSettingsRepository _hardcoverSettings;
  late final MusicRepository _repo;

  @override
  SettingsState build() {
    _settings = getIt<TorBoxSettingsRepository>();
    _hardcoverSettings = getIt<HardcoverSettingsRepository>();
    _repo = getIt<MusicRepository>();
    return SettingsState(
      apiKey: _settings.apiKey ?? '',
      isValid: (_settings.apiKey ?? '').isNotEmpty,
      enableYouTubeScraper: _settings.isYouTubeScraperEnabled,
      downloadFolders: _settings.downloadFolders,
      selectedDownloadFolder: _settings.selectedDownloadFolder,
      playerArtworkShape: _settings.playerArtworkShape,
      playerShowGlow: _settings.playerShowGlow,
      playerBackgroundType: _settings.playerBackgroundType,
      playerArtworkSize: _settings.playerArtworkSize,
      playerSeekBarStyle: _settings.playerSeekBarStyle,
      playerLikeIcon: _settings.playerLikeIcon,
      playerArtworkAnimation: _settings.playerArtworkAnimation,
      playerLyricsFontSize: _settings.playerLyricsFontSize,
      playerLyricsAlignment: _settings.playerLyricsAlignment,
      playerControlLayout: _settings.playerControlLayout,
      playerButtonStyle: _settings.playerButtonStyle,
      playerMinimalistShowSource: _settings.playerMinimalistShowSource,
      playerMinimalistShowLyrics: _settings.playerMinimalistShowLyrics,
      playerMinimalistShowSleep: _settings.playerMinimalistShowSleep,
      playerMinimalistShowQueue: _settings.playerMinimalistShowQueue,
      visualizerEnabled: _settings.visualizerEnabled,
      visualizerShowNowPlaying: _settings.visualizerShowNowPlaying,
      visualizerShowMiniPlayer: _settings.visualizerShowMiniPlayer,
      visualizerStyle: _settings.visualizerStyle,
      visualizerPoints: _settings.visualizerPoints,
      visualizerSensitivity: _settings.visualizerSensitivity,
      visualizerColorMode: _settings.visualizerColorMode,
      visualizerAlpha: _settings.visualizerAlpha,
      visualizerHeightPct: _settings.visualizerHeightPct,
      visualizerAmplitude: _settings.visualizerAmplitude,
      visualizerBaseLift: _settings.visualizerBaseLift,
      visualizerBarSpacing: _settings.visualizerBarSpacing,
      visualizerCornerRadius: _settings.visualizerCornerRadius,
      maxSongCacheSize: _settings.maxSongCacheSize,
      maxImageCacheSize: _settings.maxImageCacheSize,
      addonPriority: _settings.addonPriority,
      appThemeStyle: _settings.appThemeStyle,
      appFontFamily: _settings.appFontFamily,
      appleUseLiquidGlass: _settings.appleUseLiquidGlass,
      appleLiquidGlassOpacity: _settings.appleLiquidGlassOpacity,
      miniPlayerSwipeEnabled: _settings.miniPlayerSwipeEnabled,
      miniPlayerSwipeSensitivity: _settings.miniPlayerSwipeSensitivity,
      playerSpotifyCanvasEnabled: _settings.playerSpotifyCanvasEnabled,
      playerShowCurrentLyrics: _settings.playerShowCurrentLyrics,
      audiobookFolder: _settings.audiobookFolder,
      hardcoverApiKey: _hardcoverSettings.apiKey ?? '',
      hardcoverIsValid: (_hardcoverSettings.apiKey ?? '').isNotEmpty,
      hardcoverUsername: _hardcoverSettings.username,
    );
  }

  Future<void> setMaxSongCacheSize(int sizeInMb) async {
    await _settings.setMaxSongCacheSize(sizeInMb);
    state = state.copyWith(maxSongCacheSize: sizeInMb);
  }

  Future<void> setMaxImageCacheSize(int sizeInMb) async {
    await _settings.setMaxImageCacheSize(sizeInMb);
    state = state.copyWith(maxImageCacheSize: sizeInMb);
  }

  Future<void> setAddonPriority(List<String> priority) async {
    await _settings.setAddonPriority(priority);
    state = state.copyWith(addonPriority: priority);
  }

  Future<void> setAppThemeStyle(String style) async {
    state = state.copyWith(appThemeStyle: style);
    await _settings.setAppThemeStyle(style);
  }

  Future<void> setAppFontFamily(String font) async {
    state = state.copyWith(appFontFamily: font);
    await _settings.setAppFontFamily(font);
  }

  Future<void> setAppleUseLiquidGlass(bool value) async {
    state = state.copyWith(appleUseLiquidGlass: value);
    await _settings.setAppleUseLiquidGlass(value);
  }

  Future<void> setAppleLiquidGlassOpacity(double value) async {
    state = state.copyWith(appleLiquidGlassOpacity: value);
    await _settings.setAppleLiquidGlassOpacity(value);
  }

  Future<bool> saveAndValidateApiKey(String key) async {
    state = state.copyWith(isValidating: true, error: null);
    final valid = await _repo.validateApiKey(key);
    if (valid) {
      await _settings.setApiKey(key);
      state = state.copyWith(apiKey: key, isValid: true, isValidating: false);
    } else {
      state = state.copyWith(isValidating: false, isValid: false, error: 'Invalid API Key');
    }
    return valid;
  }

  void loadExistingKey() {
    final key = _settings.apiKey ?? '';
    state = state.copyWith(apiKey: key, isValid: key.isNotEmpty);
  }

  Future<void> clearApiKey() async {
    await _settings.setApiKey('');
    state = state.copyWith(apiKey: '', isValid: false, error: null);
  }

  Future<bool> saveAndValidateHardcoverKey(String key) async {
    state = state.copyWith(hardcoverIsValidating: true, hardcoverError: null);
    final service = HardcoverApiService();
    final username = await service.validateAndGetUsername(key);
    if (username != null) {
      await _hardcoverSettings.setApiKey(key);
      await _hardcoverSettings.setUsername(username);
      state = state.copyWith(
        hardcoverApiKey: key,
        hardcoverIsValid: true,
        hardcoverIsValidating: false,
        hardcoverUsername: username,
      );
    } else {
      state = state.copyWith(
        hardcoverIsValidating: false,
        hardcoverIsValid: false,
        hardcoverError: 'Invalid API Key',
      );
    }
    return username != null;
  }

  Future<void> clearHardcoverKey() async {
    await _hardcoverSettings.clearApiKey();
    state = state.copyWith(
      hardcoverApiKey: '',
      hardcoverIsValid: false,
      hardcoverError: null,
      hardcoverUsername: null,
    );
  }

  Future<void> setYouTubeScraperEnabled(bool enabled) async {
    await _settings.setYouTubeScraperEnabled(enabled);
    state = state.copyWith(enableYouTubeScraper: enabled);
  }

  Future<void> addDownloadFolder(String path) async {
    if (state.downloadFolders.contains(path)) return;
    final folders = [...state.downloadFolders, path];
    await _settings.setDownloadFolders(folders);
    
    // If it's the first folder, select it automatically
    String? selected = state.selectedDownloadFolder;
    if (selected == null) {
      selected = path;
      await _settings.setSelectedDownloadFolder(path);
    }
    
    state = state.copyWith(downloadFolders: folders, selectedDownloadFolder: selected);
  }

  Future<void> removeDownloadFolder(String path) async {
    final folders = state.downloadFolders.where((f) => f != path).toList();
    await _settings.setDownloadFolders(folders);
    
    String? selected = state.selectedDownloadFolder;
    if (selected == path) {
      selected = folders.isNotEmpty ? folders.first : null;
      await _settings.setSelectedDownloadFolder(selected);
    }
    
    state = state.copyWith(downloadFolders: folders, selectedDownloadFolder: selected);
  }

  Future<void> setSelectedDownloadFolder(String path) async {
    await _settings.setSelectedDownloadFolder(path);
    state = state.copyWith(selectedDownloadFolder: path);
  }

  Future<void> setPlayerArtworkShape(String shape) async {
    await _settings.setPlayerArtworkShape(shape);
    state = state.copyWith(playerArtworkShape: shape);
  }

  Future<void> setPlayerShowGlow(bool show) async {
    await _settings.setPlayerShowGlow(show);
    state = state.copyWith(playerShowGlow: show);
  }

  Future<void> setPlayerBackgroundType(String type) async {
    await _settings.setPlayerBackgroundType(type);
    state = state.copyWith(playerBackgroundType: type);
  }

  Future<void> setPlayerArtworkSize(double size) async {
    await _settings.setPlayerArtworkSize(size);
    state = state.copyWith(playerArtworkSize: size);
  }

  Future<void> setPlayerSeekBarStyle(String style) async {
    await _settings.setPlayerSeekBarStyle(style);
    state = state.copyWith(playerSeekBarStyle: style);
  }

  Future<void> setPlayerLikeIcon(String icon) async {
    await _settings.setPlayerLikeIcon(icon);
    state = state.copyWith(playerLikeIcon: icon);
  }

  Future<void> setPlayerArtworkAnimation(String animation) async {
    await _settings.setPlayerArtworkAnimation(animation);
    state = state.copyWith(playerArtworkAnimation: animation);
  }

  Future<void> setPlayerLyricsFontSize(double size) async {
    await _settings.setPlayerLyricsFontSize(size);
    state = state.copyWith(playerLyricsFontSize: size);
  }

  Future<void> setPlayerLyricsAlignment(String alignment) async {
    await _settings.setPlayerLyricsAlignment(alignment);
    state = state.copyWith(playerLyricsAlignment: alignment);
  }

  Future<void> setPlayerControlLayout(String layout) async {
    await _settings.setPlayerControlLayout(layout);
    state = state.copyWith(playerControlLayout: layout);
  }

  Future<void> setPlayerButtonStyle(String style) async {
    await _settings.setPlayerButtonStyle(style);
    state = state.copyWith(playerButtonStyle: style);
  }

  Future<void> setPlayerMinimalistShowSource(bool show) async {
    await _settings.setPlayerMinimalistShowSource(show);
    state = state.copyWith(playerMinimalistShowSource: show);
  }

  Future<void> setPlayerMinimalistShowLyrics(bool show) async {
    await _settings.setPlayerMinimalistShowLyrics(show);
    state = state.copyWith(playerMinimalistShowLyrics: show);
  }

  Future<void> setPlayerMinimalistShowSleep(bool show) async {
    await _settings.setPlayerMinimalistShowSleep(show);
    state = state.copyWith(playerMinimalistShowSleep: show);
  }

  Future<void> setPlayerMinimalistShowQueue(bool show) async {
    await _settings.setPlayerMinimalistShowQueue(show);
    state = state.copyWith(playerMinimalistShowQueue: show);
  }

  Future<void> setPlayerSpotifyCanvasEnabled(bool enabled) async {
    await _settings.setPlayerSpotifyCanvasEnabled(enabled);
    state = state.copyWith(playerSpotifyCanvasEnabled: enabled);
  }

  Future<void> setPlayerShowCurrentLyrics(bool show) async {
    await _settings.setPlayerShowCurrentLyrics(show);
    state = state.copyWith(playerShowCurrentLyrics: show);
  }

  // ── Visualizer Setters ──────────────────────────────────────────────────
  Future<void> setVisualizerEnabled(bool enabled) async {
    await _settings.setVisualizerEnabled(enabled);
    state = state.copyWith(visualizerEnabled: enabled);
  }

  Future<void> setVisualizerShowNowPlaying(bool show) async {
    await _settings.setVisualizerShowNowPlaying(show);
    state = state.copyWith(visualizerShowNowPlaying: show);
  }

  Future<void> setVisualizerShowMiniPlayer(bool show) async {
    await _settings.setVisualizerShowMiniPlayer(show);
    state = state.copyWith(visualizerShowMiniPlayer: show);
  }

  Future<void> setVisualizerStyle(String style) async {
    await _settings.setVisualizerStyle(style);
    state = state.copyWith(visualizerStyle: style);
  }

  Future<void> setVisualizerPoints(int points) async {
    await _settings.setVisualizerPoints(points);
    state = state.copyWith(visualizerPoints: points);
  }

  Future<void> setVisualizerSensitivity(double sensitivity) async {
    await _settings.setVisualizerSensitivity(sensitivity);
    state = state.copyWith(visualizerSensitivity: sensitivity);
  }

  Future<void> setVisualizerColorMode(String mode) async {
    await _settings.setVisualizerColorMode(mode);
    state = state.copyWith(visualizerColorMode: mode);
  }

  Future<void> setVisualizerAlpha(double alpha) async {
    await _settings.setVisualizerAlpha(alpha);
    state = state.copyWith(visualizerAlpha: alpha);
  }

  Future<void> setVisualizerHeightPct(double pct) async {
    await _settings.setVisualizerHeightPct(pct);
    state = state.copyWith(visualizerHeightPct: pct);
  }

  Future<void> setVisualizerAmplitude(double amplitude) async {
    await _settings.setVisualizerAmplitude(amplitude);
    state = state.copyWith(visualizerAmplitude: amplitude);
  }

  Future<void> setVisualizerBaseLift(double lift) async {
    await _settings.setVisualizerBaseLift(lift);
    state = state.copyWith(visualizerBaseLift: lift);
  }

  Future<void> setVisualizerBarSpacing(double spacing) async {
    await _settings.setVisualizerBarSpacing(spacing);
    state = state.copyWith(visualizerBarSpacing: spacing);
  }

  Future<void> setVisualizerCornerRadius(double radius) async {
    await _settings.setVisualizerCornerRadius(radius);
    state = state.copyWith(visualizerCornerRadius: radius);
  }

  Future<void> setMiniPlayerSwipeEnabled(bool enabled) async {
    await _settings.setMiniPlayerSwipeEnabled(enabled);
    state = state.copyWith(miniPlayerSwipeEnabled: enabled);
  }

  Future<void> setMiniPlayerSwipeSensitivity(double sensitivity) async {
    await _settings.setMiniPlayerSwipeSensitivity(sensitivity);
    state = state.copyWith(miniPlayerSwipeSensitivity: sensitivity);
  }

  Future<void> setAudiobookFolder(String path) async {
    await _settings.setAudiobookFolder(path);
    state = state.copyWith(audiobookFolder: path);
  }

  Future<void> removeAudiobookFolder() async {
    await _settings.setAudiobookFolder(null);
    // copyWith won't clear a nullable field to null, so rebuild manually
    state = SettingsState(
      apiKey: state.apiKey,
      isValidating: state.isValidating,
      isValid: state.isValid,
      error: state.error,
      enableYouTubeScraper: state.enableYouTubeScraper,
      downloadFolders: state.downloadFolders,
      selectedDownloadFolder: state.selectedDownloadFolder,
      playerArtworkShape: state.playerArtworkShape,
      playerShowGlow: state.playerShowGlow,
      playerBackgroundType: state.playerBackgroundType,
      playerArtworkSize: state.playerArtworkSize,
      playerSeekBarStyle: state.playerSeekBarStyle,
      playerLikeIcon: state.playerLikeIcon,
      playerArtworkAnimation: state.playerArtworkAnimation,
      playerLyricsFontSize: state.playerLyricsFontSize,
      playerLyricsAlignment: state.playerLyricsAlignment,
      playerControlLayout: state.playerControlLayout,
      visualizerEnabled: state.visualizerEnabled,
      visualizerShowNowPlaying: state.visualizerShowNowPlaying,
      visualizerShowMiniPlayer: state.visualizerShowMiniPlayer,
      visualizerStyle: state.visualizerStyle,
      visualizerPoints: state.visualizerPoints,
      visualizerSensitivity: state.visualizerSensitivity,
      visualizerColorMode: state.visualizerColorMode,
      visualizerAlpha: state.visualizerAlpha,
      visualizerHeightPct: state.visualizerHeightPct,
      visualizerAmplitude: state.visualizerAmplitude,
      visualizerBaseLift: state.visualizerBaseLift,
      visualizerBarSpacing: state.visualizerBarSpacing,
      visualizerCornerRadius: state.visualizerCornerRadius,
      maxSongCacheSize: state.maxSongCacheSize,
      maxImageCacheSize: state.maxImageCacheSize,
      addonPriority: state.addonPriority,
      appThemeStyle: state.appThemeStyle,
      appFontFamily: state.appFontFamily,
      appleUseLiquidGlass: state.appleUseLiquidGlass,
      appleLiquidGlassOpacity: state.appleLiquidGlassOpacity,
      miniPlayerSwipeEnabled: state.miniPlayerSwipeEnabled,
      miniPlayerSwipeSensitivity: state.miniPlayerSwipeSensitivity,
      playerSpotifyCanvasEnabled: state.playerSpotifyCanvasEnabled,
      audiobookFolder: null,
    );
  }
}

// ─── Music Search Provider ───────────────────────────────────────────────────
final musicSearchProvider = NotifierProvider<MusicSearchNotifier, MusicSearchState>(() {
  return MusicSearchNotifier();
});

class MusicSearchState {
  final List<ItunesTrack> tracks;
  final bool isLoading;
  final String query;
  final String searchMode; // 'songs', 'albums', or 'artists'

  MusicSearchState({
    this.tracks = const [], 
    this.isLoading = false, 
    this.query = '',
    this.searchMode = 'songs',
  });

  MusicSearchState copyWith({
    List<ItunesTrack>? tracks, 
    bool? isLoading, 
    String? query,
    String? searchMode,
  }) {
    return MusicSearchState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      searchMode: searchMode ?? this.searchMode,
    );
  }
}

class MusicSearchNotifier extends Notifier<MusicSearchState> {
  late final MusicRepository _repo;
  @override
  MusicSearchState build() {
    _repo = getIt<MusicRepository>();
    return MusicSearchState();
  }

  void setMode(String mode) {
    state = state.copyWith(searchMode: mode, tracks: []);
    if (state.query.isNotEmpty) {
      search(state.query);
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    state = state.copyWith(isLoading: true, query: query, tracks: []);
    
    List<ItunesTrack> tracks;
    if (state.searchMode == 'albums') {
      tracks = await _repo.searchItunesAlbums(query);
    } else if (state.searchMode == 'artists') {
      tracks = await _repo.searchItunesArtists(query);
    } else {
      tracks = await _repo.searchItunes(query);
    }
    
    state = state.copyWith(tracks: tracks, isLoading: false);
  }

  void clear() => state = MusicSearchState();
}

final genresProvider = FutureProvider<List<DeezerGenre>>((ref) async {
  return getIt<MusicRepository>().getDeezerGenres();
});

class GenrePlaylistsParams {
  final int id;
  final String name;

  GenrePlaylistsParams({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenrePlaylistsParams &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

final genrePlaylistsProvider = FutureProvider.family<List<DeezerPlaylist>, GenrePlaylistsParams>((ref, params) async {
  return getIt<MusicRepository>().getDeezerGenrePlaylists(params.id, genreName: params.name);
});

class MoodSearchParams {
  final String mood;
  final String? context;

  MoodSearchParams({required this.mood, this.context});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodSearchParams &&
          runtimeType == other.runtimeType &&
          mood == other.mood &&
          context == other.context;

  @override
  int get hashCode => mood.hashCode ^ context.hashCode;
}

int? getItunesGenreId(String genreName) {
  final clean = genreName.toLowerCase().trim();
  if (clean.contains('rock') || clean.contains('metal')) return 21;
  if (clean.contains('pop')) return 14;
  if (clean.contains('r&b') || clean.contains('soul') || clean.contains('rb')) return 15;
  if (clean.contains('dance') || clean.contains('electro') || clean.contains('house') || clean.contains('techno')) return 17;
  if (clean.contains('hip') || clean.contains('rap')) return 18;
  if (clean.contains('jazz')) return 11;
  if (clean.contains('classic')) return 5;
  if (clean.contains('country')) return 6;
  if (clean.contains('reggae')) return 24;
  if (clean.contains('alternative') || clean.contains('indie')) return 20;
  if (clean.contains('latin')) return 12;
  if (clean.contains('soundtrack') || clean.contains('film')) return 16;
  if (clean.contains('world') || clean.contains('folk')) return 19;
  if (clean.contains('j-pop') || clean.contains('jpop')) return 27;
  if (clean.contains('k-pop') || clean.contains('kpop')) return 51;
  return null;
}

final moodSongsProvider = FutureProvider.family<List<ItunesTrack>, MoodSearchParams>((ref, params) async {
  final repo = getIt<MusicRepository>();
  
  final itunesGenreId = getItunesGenreId(params.mood);
  if (itunesGenreId != null) {
    return repo.getTopSongs(genreId: itunesGenreId, limit: 50);
  }
  
  final baseQuery = {
    'Happy': 'Feel Good Hits',
    'Chill': 'Chill Session',
    'Sad': 'Sad Songs',
    'Focus': 'Study Music',
    'Energy': 'Workout Mix',
  }[params.mood] ?? params.mood;

  final finalQuery = params.context != null && params.context != 'All'
      ? '$baseQuery ${params.context}'
      : baseQuery;

  return repo.searchItunes(finalQuery);
});

final reccoMixStatsProvider = Provider<({List<String> topArtists, List<String> topGenres})>((ref) {
  // Use a string representation to ensure value equality for the selector
  final statsKey = ref.watch(libraryProvider.select((s) {
    final stats = s.libraryStats;
    return '${stats.topArtists.join(',')}|${stats.topGenres.join(',')}';
  }));
  
  // Since List equality is by identity, we need to be careful.
  // We'll return the record, but because the selector above is stable,
  // this provider will only re-emit if statsKey changes.
  return ref.read(libraryProvider).libraryStats;
});

final _reccoMixCache = <String, List<ItunesTrack>>{};
final _reccoMixPending = <String, Future<List<ItunesTrack>>>{};

final reccoMixProvider = FutureProvider.family<List<ItunesTrack>, MoodSearchParams>((ref, params) async {
  final stats = ref.watch(reccoMixStatsProvider);
  final repo = getIt<MusicRepository>();
  
  if (stats.topArtists.isEmpty && stats.topGenres.isEmpty) return [];

  // Pick a seed from top artists or genres
  String seed = '';
  if (stats.topArtists.isNotEmpty) {
    seed = stats.topArtists[params.mood.length % stats.topArtists.length];
  } else if (stats.topGenres.isNotEmpty) {
    seed = stats.topGenres[0];
  }

  final moodKeywords = {
    'Happy': 'Upbeat Happy Hits',
    'Chill': 'Chill Acoustic',
    'Focus': 'Deep Focus Lofi',
    'Energy': 'Hard Rock Energy',
  }[params.mood] ?? params.mood;

  final query = seed.isNotEmpty ? '$seed $moodKeywords' : moodKeywords;
  
  if (_reccoMixCache.containsKey(query)) return _reccoMixCache[query]!;
  if (_reccoMixPending.containsKey(query)) return _reccoMixPending[query]!;

  print('[ReccoMix] Performing search for ${params.mood} (Query: $query)');
  
  final searchFuture = _performSearchWithFallback(repo, query, moodKeywords);
  _reccoMixPending[query] = searchFuture;
  
  try {
    final results = await searchFuture;
    _reccoMixCache[query] = results;
    return results;
  } finally {
    _reccoMixPending.remove(query);
  }
});

Future<List<ItunesTrack>> _performSearchWithFallback(MusicRepository repo, String primaryQuery, String fallbackKeywords) async {
  final primaryResults = await repo.searchItunes(primaryQuery);
  if (primaryResults.isNotEmpty) return primaryResults;
  
  if (primaryQuery != fallbackKeywords) {
    print('[ReccoMix] Primary query yielded no results, falling back to: $fallbackKeywords');
    return repo.searchItunes(fallbackKeywords);
  }
  
  return [];
}

final hasLibrarySeedsProvider = Provider<bool>((ref) {
  // Only watch the count of metadata to avoid rebuilding on every detail change
  final metadataCount = ref.watch(libraryProvider.select((s) => s.metadata.length));
  return metadataCount >= 5; 
});

// ─── FLAC Search Provider ───────────────────────────────────────────────────
final flacSearchProvider = NotifierProvider<FlacSearchNotifier, FlacSearchState>(() {
  return FlacSearchNotifier();
});

class FlacSearchState {
  final List<ScraperResult> results;
  final bool isLoading;
  final String query;
  final String? selectedSource;

  FlacSearchState({
    this.results = const [],
    this.isLoading = false,
    this.query = '',
    this.selectedSource,
  });

  List<String> get availableSources {
    final sources = results.map((r) => r.source).toSet().toList();
    sources.sort();
    return sources;
  }

  List<ScraperResult> get filteredResults {
    if (selectedSource == null || selectedSource == 'All') {
      return results;
    }
    return results.where((r) => r.source == selectedSource).toList();
  }

  FlacSearchState copyWith({
    List<ScraperResult>? results,
    bool? isLoading,
    String? query,
    String? selectedSource,
  }) {
    return FlacSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      selectedSource: selectedSource ?? this.selectedSource,
    );
  }
}

class FlacSearchNotifier extends Notifier<FlacSearchState> {
  late final MusicRepository _repo;
  StreamSubscription<ScraperResult>? _searchSubscription;
  final Map<String, List<ScraperResult>> _cache = {};

  @override
  FlacSearchState build() {
    _repo = getIt<MusicRepository>();
    ref.onDispose(() => _searchSubscription?.cancel());
    return FlacSearchState();
  }


  void setSource(String? source) {
    state = state.copyWith(selectedSource: source);
  }

  void clearCache() {
    _cache.clear();
  }

  Future<void> search(String query, {bool force = false}) async {
    if (query.isEmpty) return;
    
    final normalizedQuery = query.toLowerCase().trim();
    if (!force && _cache.containsKey(normalizedQuery)) {
      state = state.copyWith(
        results: _cache[normalizedQuery],
        isLoading: false,
        query: query,
        selectedSource: 'All',
      );
      return;
    }

    await _searchSubscription?.cancel();
    state = state.copyWith(
      isLoading: true, 
      query: query, 
      results: [],
      selectedSource: 'All', // Reset to All on new search
    );

    final List<ScraperResult> tempResults = [];

    _searchSubscription = _repo.searchFLACStream(query).listen(
      (result) {
        tempResults.add(result);
        state = state.copyWith(results: [...state.results, result]);
      },
      onError: (e) {
        print('[FlacSearch] Search error: $e');
      },
      onDone: () {
        _cache[normalizedQuery] = tempResults;
        state = state.copyWith(isLoading: false);
      },
    );
  }

  /// Attempts to find a direct FLAC stream for a given title and artist.
  /// Returns the FIRST found result immediately, but continues the search 
  /// in the background to fill state.results for the "Source Selection" sheet.
  Future<ScraperResult?> resolveDirectFlac(String title, String artist, {bool force = false}) async {
    final query = '$title $artist'.trim();
    if (query.isEmpty) return null;
    
    final normalizedQuery = query.toLowerCase().trim();
    if (!force && _cache.containsKey(normalizedQuery)) {
      final cached = _cache[normalizedQuery]!;
      if (cached.isNotEmpty) {
        // Find a good match in cache
        final goodMatch = cached.firstWhere(
          (r) => r.isGoodMatch(title, artist),
          orElse: () => cached.firstWhere(
            (r) => r.source.toLowerCase().contains('tidal'),
            orElse: () => cached.first,
          ),
        );
        
        // Even if we have cache, we update state for the UI
        state = state.copyWith(results: cached, query: query, isLoading: false);
        return goodMatch;
      }
    }

    await _searchSubscription?.cancel();
    state = state.copyWith(isLoading: true, query: query, results: []);

    _cache[normalizedQuery] = [];
    Completer<ScraperResult?> completer = Completer<ScraperResult?>();
    
    // Fallback: If no "good" match found, we'll pick the first one after a timeout
    Timer? timeoutTimer;

    _searchSubscription = _repo.searchFLACStream(query).listen(
      (result) {
        final updatedResults = [...state.results, result];
        _cache[normalizedQuery] = updatedResults;
        state = state.copyWith(results: updatedResults);

        // If it's a good match, resolve immediately (Prefer Tidal if multiple)
        if (!completer.isCompleted && result.isGoodMatch(title, artist)) {
          timeoutTimer?.cancel();
          completer.complete(result);
        }
      },
      onError: (e) {
        print('[FlacSearch] Resolve error: $e');
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () {
        state = state.copyWith(isLoading: false);
        if (!completer.isCompleted) {
          if (state.results.isEmpty) {
            completer.complete(null);
            return;
          }
          // If we are done but haven't resolved a "good" match, 
          // pick Tidal first as fallback, then the first result.
          final fallback = state.results.firstWhere(
            (r) => r.source.toLowerCase().contains('tidal'),
            orElse: () => state.results.first,
          );
          completer.complete(fallback);
        }
      },
    );

    // Timeout: After 5 seconds, if we haven't found a "good" match,
    // prefer selecting any Tidal result found so far.
    timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        print('[FlacSearch] Direct resolve timeout, looking for fallbacks');
        if (state.results.isEmpty) {
          completer.complete(null);
          return;
        }
        final fallback = state.results.firstWhere(
            (r) => r.source.toLowerCase().contains('tidal'),
            orElse: () => state.results.first,
          );
        completer.complete(fallback);
      }
    });

    return completer.future;
  }

  void clear() {
    _searchSubscription?.cancel();
    state = FlacSearchState();
  }


}

// ─── YouTube Search Provider ──────────────────────────────────────────────────
final youtubeSearchProvider = NotifierProvider<YouTubeSearchNotifier, YouTubeSearchState>(() {
  return YouTubeSearchNotifier();
});

class YouTubeSearchState {
  final List<YouTubeResult> results;
  final bool isLoading;
  final bool? addSuccess;
  final String? addError;

  YouTubeSearchState({this.results = const [], this.isLoading = false, this.addSuccess, this.addError});

  YouTubeSearchState copyWith({List<YouTubeResult>? results, bool? isLoading, bool? addSuccess, String? addError}) {
    return YouTubeSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      addSuccess: addSuccess,
      addError: addError,
    );
  }
}

class YouTubeSearchNotifier extends Notifier<YouTubeSearchState> {
  late final MusicRepository _repo;
  @override
  YouTubeSearchState build() {
    _repo = getIt<MusicRepository>();
    return YouTubeSearchState();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    state = state.copyWith(isLoading: true, results: [], addSuccess: null, addError: null);
    try {
      final results = await _repo.searchYouTube(query);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, results: []);
    }
  }

  Future<bool> addWebDownload(String url) async {
    state = state.copyWith(isLoading: true, addSuccess: null, addError: null);
    try {
      final success = await _repo.addWebDownload(url);
      if (success) {
        state = state.copyWith(isLoading: false, addSuccess: true);
        return true;
      } else {
        state = state.copyWith(isLoading: false, addSuccess: false, addError: "Failed to add download");
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, addSuccess: false, addError: e.toString());
      return false;
    }
  }

  void clear() => state = YouTubeSearchState();
}

// ─── Torrent Search Provider ─────────────────────────────────────────────────
final torrentSearchProvider = NotifierProvider<TorrentSearchNotifier, TorrentSearchState>(() {
  return TorrentSearchNotifier();
});

class TorrentSearchState {
  final List<TorrentSearchResult> results;
  final Set<String> cachedHashes;
  final bool isLoading;
  final bool? addSuccess;
  final String? addError;

  TorrentSearchState({
    this.results = const [], 
    this.cachedHashes = const {},
    this.isLoading = false, 
    this.addSuccess, 
    this.addError,
  });

  TorrentSearchState copyWith({
    List<TorrentSearchResult>? results, 
    Set<String>? cachedHashes,
    bool? isLoading, 
    bool? addSuccess, 
    String? addError,
  }) {
    return TorrentSearchState(
      results: results ?? this.results,
      cachedHashes: cachedHashes ?? this.cachedHashes,
      isLoading: isLoading ?? this.isLoading,
      addSuccess: addSuccess,
      addError: addError,
    );
  }
}

class TorrentSearchNotifier extends Notifier<TorrentSearchState> {
  late final MusicRepository _repo;
  @override
  TorrentSearchState build() {
    _repo = getIt<MusicRepository>();
    return TorrentSearchState();
  }

  Future<void> searchTorrents(String query) async {
    state = state.copyWith(isLoading: true, results: [], cachedHashes: {});
    final results = await _repo.searchAllTorrents(query);
    state = state.copyWith(results: results, isLoading: false);
    
    // Check which of these are cached
    final hashes = results.map((r) => r.infoHash).where((h) => h.isNotEmpty).toList();
    if (hashes.isNotEmpty) {
      final cached = await _repo.checkCached(hashes);
      state = state.copyWith(cachedHashes: cached.toSet());
    }
  }

  Future<void> addToTorBox(TorrentSearchResult torrent) async {
    state = state.copyWith(addSuccess: null, addError: null);
    final success = await _repo.addTorrent(torrent.magnetUri);
    state = state.copyWith(addSuccess: success, addError: success ? null : 'Failed to add torrent');
  }
}

// ─── Library Provider ────────────────────────────────────────────────────────
// ─── Library Search Providers ───────────────────────────────────────────────
class LibrarySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  
  void set(String query) => state = query;
}

final librarySearchQueryProvider = NotifierProvider<LibrarySearchQueryNotifier, String>(() {
  return LibrarySearchQueryNotifier();
});

final filteredLibraryProvider = Provider<List<TorBoxFile>>((ref) {
  final state = ref.watch(libraryProvider);
  final query = ref.watch(librarySearchQueryProvider).toLowerCase().trim();

  if (query.isEmpty) {
    return state.allAudioFiles;
  }

  return state.allAudioFiles.where((file) {
    // 1. Check title and artist from filename
    final parsed = parseFilename(file.displayName);
    if (parsed.title.toLowerCase().contains(query) || 
        parsed.artist.toLowerCase().contains(query)) {
      return true;
    }

    // 2. Check metadata
    final meta = state.metadata['${file.torrentId}-${file.id}'];
    if (meta != null) {
      if (meta.trackName?.toLowerCase().contains(query) == true ||
          meta.artistName?.toLowerCase().contains(query) == true ||
          meta.album?.toLowerCase().contains(query) == true) {
        return true;
      }
    }

    return false;
  }).toList();
});

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(() {
  return LibraryNotifier();
});

class LibraryState {
  final List<TorBoxTorrent> torrents;
  final bool isLoading;
  final bool isEnriching;
  /// iTunes metadata keyed by "torrentId-fileId"
  final Map<String, ItunesMeta> metadata;
  /// Set of "torrentId-fileId" currently downloading
  final Set<String> downloadingIds;

  /// Map of "torrentId-fileId" to progress (0.0 to 1.0)
  final Map<String, double> downloadProgress;

  final Set<String> enrichingKeys;
  final String? downloadError;

  LibraryState({
    this.torrents = const [],
    this.isLoading = false,
    this.isEnriching = false,
    this.metadata = const {},
    this.downloadingIds = const {},
    this.downloadProgress = const {},
    this.enrichingKeys = const {},
    this.downloadError,
  });

  List<TorBoxFile> get allAudioFiles {
    final files = torrents.expand((t) => t.files).where((f) => f.mediaType == 'music').toList();
    // Sort files by torrentId descending (most recent torrent first)
    // Use a safe compare that handles potential nulls or default to 0
    files.sort((a, b) => (b.torrentId).compareTo(a.torrentId));
    return files;
  }

  LibraryState copyWith({
    List<TorBoxTorrent>? torrents,
    bool? isLoading,
    bool? isEnriching,
    Map<String, ItunesMeta>? metadata,
    Set<String>? downloadingIds,
    Map<String, double>? downloadProgress,
    Set<String>? enrichingKeys,
    String? downloadError,
  }) {
    // Ensure torrents are sorted by ID descending
    final sortedTorrents = torrents != null 
        ? (List<TorBoxTorrent>.from(torrents)..sort((a, b) => (b.id).compareTo(a.id)))
        : this.torrents;

    return LibraryState(
      torrents: sortedTorrents,
      isLoading: isLoading ?? this.isLoading,
      isEnriching: isEnriching ?? this.isEnriching,
      metadata: metadata ?? this.metadata,
      downloadingIds: downloadingIds ?? this.downloadingIds,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      enrichingKeys: enrichingKeys ?? this.enrichingKeys,
      downloadError: downloadError,
    );
  }

  /// Returns stats about the user's library (top artists and genres)
  ({List<String> topArtists, List<String> topGenres}) get libraryStats {
    final artistsCount = <String, int>{};
    final genresCount = <String, int>{};

    for (final meta in metadata.values) {
      if (meta.artistName != null && meta.artistName!.isNotEmpty) {
        artistsCount[meta.artistName!] = (artistsCount[meta.artistName!] ?? 0) + 1;
      }
      if (meta.genre != null && meta.genre!.isNotEmpty) {
        genresCount[meta.genre!] = (genresCount[meta.genre!] ?? 0) + 1;
      }
    }

    final sortedArtists = artistsCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedGenres = genresCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return (
      topArtists: sortedArtists.take(5).map((e) => e.key).toList(),
      topGenres: sortedGenres.take(5).map((e) => e.key).toList(),
    );
  }
}

extension LibraryMatching on LibraryState {
  TorBoxFile? findMatchingTrack(String title, String artist) {
    if (title.isEmpty) return null;
    final normalizedTitle = StringUtils.normalize(title);
    final normalizedArtist = StringUtils.normalize(artist);

    // Pass 1: Strict match using enriched metadata
    for (final torrent in torrents) {
      for (final file in torrent.files) {
        final meta = metadata['${torrent.id}-${file.id}'];
        if (meta != null) {
          final metaTitle = StringUtils.normalize(meta.trackName ?? '');
          final metaArtist = StringUtils.normalize(meta.artistName ?? '');
          if (metaTitle == normalizedTitle && 
              (normalizedArtist.isEmpty || metaArtist == normalizedArtist)) {
            return file;
          }
        }
      }
    }

    // Pass 2: Loose match using filename parsing
    for (final torrent in torrents) {
      for (final file in torrent.files) {
        final parsed = parseFilename(file.displayName);
        final fileTitle = parsed.title.toLowerCase().trim();
        final fileArtist = parsed.artist.toLowerCase().trim();

        if (fileTitle == normalizedTitle && 
            (normalizedArtist.isEmpty || fileArtist == normalizedArtist)) {
          return file;
        }
      }
    }

    return null;
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  late final MusicRepository _repo;
  late final ItunesMetadataService _itunes;
  late final AppDatabase _db;

  final Set<int> _enrichingIds = {};
  int? _lastKnownHash;

  @override
  LibraryState build() {
    _repo = getIt<MusicRepository>();
    _itunes = getIt<ItunesMetadataService>();
    _db = getIt<AppDatabase>();
    return LibraryState();
  }

  Future<void> loadLibrary({bool force = false}) async {
    // 1. Try Loading from DB first if not already loaded
    if (state.torrents.isEmpty && !force) {
      await _loadFromDb();
      final syncMeta = await _db.getSyncMeta();

      // 2. Refresh in background if needed (smart sync)
      final needsRefresh = force || _db.shouldRefreshLibrary(syncMeta?.lastLibrarySync);
      if (needsRefresh) {
        if (state.torrents.isNotEmpty) {
          _checkForNewSongs();
        } else {
          await _fetchFromApi();
        }
      }
      
      _syncLocalFoldersInBackground();
      return;
    }

    // 3. Forced reload
    if (force) {
      await _fetchFromApi();
    }
    
    _syncLocalFoldersInBackground();
  }

  Future<void> clearLibrary() async {
    state = LibraryState(isLoading: true);
    await _db.clearAllLibraryData();
    state = LibraryState(torrents: []);
  }

  Future<void> _loadFromDb() async {
    final dbTorrents = await _db.getAllTorrents();
    final dbFiles = await _db.getAllFiles();
    final dbMeta = await _db.getAllMetadata();

    bool isAudiobookTorrentName(String name) {
      final nameLower = name.toLowerCase();
      const keywords = [
        'audiobook', 'audio book', 'audio-book', 'unabridged', 'narrated by',
        'read by', ' mp3 book', 'librivox',
      ];
      return keywords.any((kw) => nameLower.contains(kw));
    }

    final List<TorBoxTorrent> torrents = dbTorrents.map((dt) {
      final isAudiobook = isAudiobookTorrentName(dt.name);
      
      final List<TorBoxFile> files = dbFiles
          .where((df) => df.torrentId == dt.id)
          .map((df) {
            final isM4b = df.name.toLowerCase().endsWith('.m4b');
            return TorBoxFile(
              id: df.id,
              name: df.name,
              size: df.size,
              torrentId: df.torrentId,
              localPath: df.localPath,
              mediaType: (isAudiobook || isM4b) ? 'audiobook' : 'music',
            );
          })
          .toList();
      return TorBoxTorrent(
        id: dt.id,
        name: dt.name,
        hash: dt.hash,
        cached: dt.cached,
        files: files,
      );
    }).toList();

    // Ensure virtual "Local Downloads" torrent exists if there are local files
    final localFiles = dbFiles.where((f) => f.torrentId == -1).toList();
    if (localFiles.isNotEmpty && !torrents.any((t) => t.id == -1)) {
      torrents.add(TorBoxTorrent(
        id: -1,
        name: 'Local Downloads',
        hash: 'local',
        cached: true,
        files: localFiles.map((df) => TorBoxFile(
          id: df.id,
          name: df.name,
          size: df.size,
          torrentId: df.torrentId,
          localPath: df.localPath,
          mediaType: df.name.toLowerCase().endsWith('.m4b') ? 'audiobook' : 'music',
        )).toList(),
      ));
    }

    final metaMap = <String, ItunesMeta>{};
    for (final dm in dbMeta) {
      metaMap['${dm.torrentId}-${dm.fileId}'] = ItunesMeta(
        trackName: dm.trackTitle,
        artistName: dm.artist,
        album: dm.album,
        genre: dm.genre,
        releaseYear: dm.releaseYear,
        artworkUrlLow: dm.artworkUrlLow,
        artworkUrlHigh: dm.artworkUrlHigh,
        trackTimeMillis: dm.trackTimeMillis,
      );
    }

    state = state.copyWith(torrents: torrents, metadata: metaMap);
  }

  Future<void> _checkForNewSongs() async {
    try {
      final remoteHash = await _repo.getLibraryHash();
      if (remoteHash != _lastKnownHash && remoteHash != 0) {
        print('[LibraryNotifier] New songs detected, refreshing library...');
        await _fetchFromApi();
      } else {
        print('[LibraryNotifier] Library unchanged, using cached data');
      }
    } catch (e) {
      print('[LibraryNotifier] Error checking for new songs: $e');
    }
  }

  Future<void> _syncLocalFoldersInBackground() async {
    try {
      final settings = ref.read(settingsProvider);
      final folders = settings.downloadFolders;
      if (folders.isEmpty) return;

      final dbFiles = await _db.getAllFiles();
      final existingPaths = dbFiles.map((f) => f.localPath).whereType<String>().toSet();

      final validExtensions = ['.mp3', '.flac', '.m4a', '.wav', '.aac', '.ogg'];
      bool addedNew = false;

      for (final folderPath in folders) {
        final dir = io.Directory(folderPath);
        if (!await dir.exists()) continue;

        final entities = dir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is io.File) {
            final path = entity.path;
            final ext = p.extension(path).toLowerCase();
            if (validExtensions.contains(ext) && !existingPaths.contains(path)) {
              // Found a new local file
              addedNew = true;
              final fileId = path.hashCode;
              final fileName = p.basename(path);
              final size = await entity.length();

              // Add to files table
              await _db.into(_db.files).insertOnConflictUpdate(FilesCompanion.insert(
                id: fileId,
                torrentId: -1,
                name: fileName,
                size: size,
                isAudio: true,
                localPath: Value(path),
              ));

              // Try to read metadata
              String title = fileName;
              String artist = 'Unknown';
              String? album;
              try {
                final tag = await AudioTags.read(path);
                if (tag != null) {
                  if (tag.title != null && tag.title!.isNotEmpty) title = tag.title!;
                  if (tag.artist != null && tag.artist!.isNotEmpty) artist = tag.artist!;
                  if (tag.album != null && tag.album!.isNotEmpty) album = tag.album!;
                }
              } catch (e) {
                print('[LibraryNotifier] Error reading tags for $path: $e');
                final parsed = parseFilename(fileName);
                title = parsed.title;
                if (parsed.artist.isNotEmpty) artist = parsed.artist;
              }

              await _db.saveTrackMetadata(TrackMetadataCompanion.insert(
                fileId: fileId,
                torrentId: -1,
                trackTitle: Value(title),
                artist: Value(artist),
                album: Value(album),
              ));
            }
          }
        }
      }

      if (addedNew) {
        // Ensure virtual torrent exists
        await _db.into(_db.torrents).insertOnConflictUpdate(TorrentsCompanion.insert(
          id: const Value(-1),
          name: 'Local Downloads',
          hash: 'local',
          cached: true,
        ));
        await _loadFromDb();
        print('[LibraryNotifier] Local folders synced, new files added.');
      }
    } catch (e) {
      print('[LibraryNotifier] Error syncing local folders: $e');
    }
  }

  Future<void> _fetchFromApi() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, isEnriching: false);

    try {
      print('[LibraryNotifier] Fetching library from TorBox API...');
      final torrents = await _repo.getLibrary();
      
      // Save to DB and AWAIT it
      await _db.saveLibrary(
        torrents.map((t) => TorrentsCompanion.insert(
          id: Value(t.id),
          name: t.name,
          hash: t.hash,
          cached: t.cached,
        )).toList(),
        torrents.expand((t) => t.files).map((f) => FilesCompanion.insert(
          id: f.id,
          torrentId: f.torrentId,
          name: f.name,
          size: f.size,
          isAudio: true,
          // localPath is OMITTED so insertOnConflictUpdate preserves what's in DB
        )).toList(),
      );

      // Update sync timestamp
      await _db.updateLibrarySync();

      // RELOAD from DB to get the combined state (API torrents + DB localPaths)
      await _loadFromDb();
      _lastKnownHash = state.torrents.hashCode;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      print('[LibraryNotifier] API fetch error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// On-demand enrichment for a single file. Usually called when the ListTile is bound or manually.
  Future<void> enrichTrack(TorBoxFile file) async {
    final key = '${file.torrentId}-${file.id}';
    // Skip if already enriched OR already enriching
    if (state.metadata.containsKey(key)) {
      final existingMeta = state.metadata[key];
      if (existingMeta != null && 
          existingMeta.genre != null && existingMeta.genre!.isNotEmpty &&
          existingMeta.album != null && existingMeta.album!.isNotEmpty) {
        return;
      }
    }
    final enriching = Set<String>.from(state.enrichingKeys);
    enriching.add(key);
    state = state.copyWith(isEnriching: true, enrichingKeys: enriching);

    try {
      final parsed = parseFilename(file.displayName);

      // 1. Check library DB first — fastest, no network needed
      final dbMeta = await _db.getTrackMetadata(file.torrentId, file.id);
      if (dbMeta != null && 
          dbMeta.genre != null && dbMeta.genre!.isNotEmpty &&
          dbMeta.album != null && dbMeta.album!.isNotEmpty) {
        final metaMap = Map<String, ItunesMeta>.from(state.metadata);
        metaMap[key] = ItunesMeta(
          trackName: dbMeta.trackTitle,
          artistName: dbMeta.artist,
          artworkUrlLow: dbMeta.artworkUrlLow,
          artworkUrlHigh: dbMeta.artworkUrlHigh,
          album: dbMeta.album,
          genre: dbMeta.genre,
          releaseYear: dbMeta.releaseYear,
          trackTimeMillis: dbMeta.trackTimeMillis,
        );
        state = state.copyWith(metadata: metaMap);
        return;
      }

      // 2. Check external cache — previously fetched from iTunes
      final cacheKey = '${parsed.title}|${parsed.artist}';
      final cached = await _db.getExternalTrackMetadata(cacheKey);
      if (cached != null) {
        final meta = ItunesMeta(
          trackName: dbMeta?.trackTitle ?? cached.trackTitle,
          artistName: dbMeta?.artist ?? cached.artist,
          artworkUrlLow: dbMeta?.artworkUrlLow ?? cached.artworkUrlLow,
          artworkUrlHigh: dbMeta?.artworkUrlHigh ?? cached.artworkUrlHigh,
          album: (dbMeta?.album == null || dbMeta!.album!.isEmpty) ? cached.album : dbMeta.album,
          genre: (dbMeta?.genre == null || dbMeta!.genre!.isEmpty) ? cached.genre : dbMeta.genre,
          trackTimeMillis: dbMeta?.trackTimeMillis ?? cached.trackTimeMillis,
        );
        final metaMap = Map<String, ItunesMeta>.from(state.metadata);
        metaMap[key] = meta;
        state = state.copyWith(metadata: metaMap);
        // Persist to library DB so next load is instant
        _db.saveTrackMetadata(TrackMetadataCompanion.insert(
          fileId: file.id,
          torrentId: file.torrentId,
          trackTitle: Value(meta.trackName ?? parsed.title),
          artist: Value(meta.artistName ?? parsed.artist),
          artworkUrlLow: Value(meta.artworkUrlLow),
          artworkUrlHigh: Value(meta.artworkUrlHigh),
          album: Value(meta.album),
          genre: Value(meta.genre),
          trackTimeMillis: Value(meta.trackTimeMillis),
        ));
        return;
      }

      // 3. Fetch from iTunes as last resort
      // Politeness delay to prevent 429 lockout if scrolling fast
      await Future.delayed(const Duration(milliseconds: 400));
      final res = await _itunes.fetchMeta(dbMeta?.trackTitle ?? parsed.title, dbMeta?.artist ?? parsed.artist);

      if (res != null) {
        final existingStateMeta = state.metadata[key];
        final meta = ItunesMeta(
          trackName: existingStateMeta?.trackName ?? dbMeta?.trackTitle ?? res.trackName ?? parsed.title,
          artistName: existingStateMeta?.artistName ?? dbMeta?.artist ?? res.artistName ?? parsed.artist,
          artworkUrlLow: existingStateMeta?.artworkUrlLow ?? dbMeta?.artworkUrlLow ?? res.artworkUrlLow,
          artworkUrlHigh: existingStateMeta?.artworkUrlHigh ?? dbMeta?.artworkUrlHigh ?? res.artworkUrlHigh,
          album: existingStateMeta?.album ?? (dbMeta?.album?.isNotEmpty == true ? dbMeta!.album : res.album),
          genre: existingStateMeta?.genre ?? (dbMeta?.genre?.isNotEmpty == true ? dbMeta!.genre : res.genre),
          releaseYear: existingStateMeta?.releaseYear ?? dbMeta?.releaseYear ?? res.releaseYear,
          trackTimeMillis: existingStateMeta?.trackTimeMillis ?? dbMeta?.trackTimeMillis ?? res.trackTimeMillis,
        );
        final metaMap = Map<String, ItunesMeta>.from(state.metadata);
        metaMap[key] = meta;
        state = state.copyWith(metadata: metaMap);

        // PERSIST metadata to DB
        _db.saveTrackMetadata(TrackMetadataCompanion.insert(
          fileId: file.id,
          torrentId: file.torrentId,
          trackTitle: Value(meta.trackName ?? parsed.title),
          artist: Value(meta.artistName ?? parsed.artist),
          artworkUrlLow: Value(meta.artworkUrlLow),
          artworkUrlHigh: Value(meta.artworkUrlHigh),
          album: Value(meta.album),
          genre: Value(meta.genre),
          releaseYear: Value(meta.releaseYear),
          trackTimeMillis: Value(meta.trackTimeMillis),
        ));
      }
    } finally {
      final enriching = Set<String>.from(state.enrichingKeys);
      enriching.remove(key);
      state = state.copyWith(enrichingKeys: enriching, isEnriching: enriching.isNotEmpty);
    }
  }

  List<TorBoxFile> findMatches(String title, String artist) {
    if (title.isEmpty) return [];
    final normalizedTitle = StringUtils.normalize(title);
    final normalizedArtist = StringUtils.normalize(artist);
    final matches = <TorBoxFile>[];
    final seen = <String>{};

    void addMatch(TorBoxFile file) {
      final key = '${file.torrentId}-${file.id}';
      if (!seen.contains(key)) {
        matches.add(file);
        seen.add(key);
      }
    }

    // Pass 1: Strict match using enriched metadata
    for (final torrent in state.torrents) {
      for (final file in torrent.files) {
        final meta = state.metadata['${torrent.id}-${file.id}'];
        if (meta != null) {
          final metaTitle = StringUtils.normalize(meta.trackName ?? '');
          final metaArtist = StringUtils.normalize(meta.artistName ?? '');
          if (metaTitle == normalizedTitle && 
              (normalizedArtist.isEmpty || metaArtist == normalizedArtist)) {
            addMatch(file);
          }
        }
      }
    }

    // Pass 2: Strict match using parsed filename
    for (final torrent in state.torrents) {
      for (final file in torrent.files) {
        final parsed = parseFilename(file.displayName);
        final fileTitle = StringUtils.normalize(parsed.title);
        final fileArtist = StringUtils.normalize(parsed.artist);
        
        if (fileTitle == normalizedTitle && 
            (normalizedArtist.isEmpty || fileArtist == normalizedArtist)) {
          addMatch(file);
        }
      }
    }

    // Pass 3: Loose match (contains) 
    for (final torrent in state.torrents) {
      for (final file in torrent.files) {
        final parsed = parseFilename(file.displayName);
        final fileTitle = parsed.title.toLowerCase().trim();
        final fileArtist = parsed.artist.toLowerCase().trim();

        bool titleMatch = normalizedTitle.contains(fileTitle) || 
                         fileTitle.contains(normalizedTitle);
        bool artistMatch = normalizedArtist.isEmpty || 
                          normalizedArtist.contains(fileArtist) || 
                          fileArtist.contains(normalizedArtist);

        if (titleMatch && (normalizedArtist.isEmpty || artistMatch)) {
          addMatch(file);
        }
      }
    }
    return matches;
  }


  /// Manually update or inject metadata for a file.
  Future<void> updateTrackMetadata(TorBoxFile file, ItunesMeta meta) async {
    final key = '${file.torrentId}-${file.id}';
    final metaMap = Map<String, ItunesMeta>.from(state.metadata);
    metaMap[key] = meta;
    state = state.copyWith(metadata: metaMap);

    // Persist to DB
    await _db.saveTrackMetadata(TrackMetadataCompanion.insert(
      fileId: file.id,
      torrentId: file.torrentId,
      trackTitle: Value(meta.trackName),
      artist: Value(meta.artistName),
      album: Value(meta.album),
      genre: Value(meta.genre),
      releaseYear: Value(meta.releaseYear),
      trackTimeMillis: Value(meta.trackTimeMillis),
      artworkUrlLow: Value(meta.artworkUrlLow),
      artworkUrlHigh: Value(meta.artworkUrlHigh),
    ));

    // Refresh AudioHandler if this track is currently playing (pass metadata directly)
    await audioHandler.customAction('refresh_metadata', {
      'torrentId': file.torrentId,
      'fileId': file.id,
      '_meta_title': meta.trackName,
      '_meta_artist': meta.artistName,
      '_meta_album': meta.album,
      '_meta_genre': meta.genre,
      '_meta_releaseYear': meta.releaseYear,
      '_meta_trackTimeMillis': meta.trackTimeMillis,
      '_meta_artworkHigh': meta.artworkUrlHigh,
      '_meta_artworkLow': meta.artworkUrlLow,
    });
  }

  ItunesMeta? getMetadataForFile(TorBoxFile file) {
    return state.metadata['${file.torrentId}-${file.id}'];
  }

  Future<void> downloadTrack(TorBoxFile file) async {
    final settings = ref.read(settingsProvider);
    if (settings.selectedDownloadFolder == null) {
      state = state.copyWith(downloadError: 'No download folder selected. Please go to Settings to add one.');
      return;
    }
    
    state = state.copyWith(downloadError: null);

    if (io.Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          state = state.copyWith(downloadError: 'Storage permission denied. Please allow "All files access" in system settings.');
          return;
        }
      }
    }

    final key = '${file.torrentId}-${file.id}';
    if (state.downloadingIds.contains(key)) return;

    state = state.copyWith(downloadingIds: {...state.downloadingIds, key});

    try {
      final url = await _repo.getStreamUrl(file.torrentId, file.id);
      if (url == null) throw Exception("Could not get stream URL");

      final downloadDirPath = settings.selectedDownloadFolder!;
      final downloadDir = io.Directory(downloadDirPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final meta = state.metadata['${file.torrentId}-${file.id}'];
      final extension = p.extension(file.name).isEmpty ? '.mp3' : p.extension(file.name);
      
      String baseName;
      if (meta != null && meta.trackName != null) {
        baseName = '${meta.artistName ?? 'Unknown'} - ${meta.trackName}';
      } else {
        baseName = p.basenameWithoutExtension(file.name);
      }
      
      final fileName = '${_sanitizeFileName(baseName)}$extension';
      final savePath = p.join(downloadDirPath, fileName);

      print('[LibraryNotifier] Downloading ${file.name} to $savePath');
      
      final client = io.HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      
      final contentLength = response.contentLength;
      int downloaded = 0;
      
      final fileToSave = io.File(savePath);
      final sink = fileToSave.openWrite();
      
      await for (final data in response) {
        sink.add(data);
        downloaded += data.length;
        if (contentLength > 0) {
          final progress = downloaded / contentLength;
          // Throttle updates to avoid excessive state rebuilds
          if ((progress * 100).toInt() % 2 == 0) {
            state = state.copyWith(
              downloadProgress: {...state.downloadProgress, key: progress},
            );
          }
        }
      }
      await sink.flush();
      await sink.close();

      print('[LibraryNotifier] Download complete: $savePath');
      await _db.updateFileLocalPath(file.torrentId, file.id, savePath);
      
      // Apply metadata tags
      if (meta != null) {
        await _applyMetadata(
          savePath,
          title: meta.trackName ?? file.name,
          artist: meta.artistName ?? 'Unknown',
          album: meta.album,
          artworkUrl: meta.artworkUrlHigh,
        );
      } else {
        final parsed = parseFilename(file.name);
        await _applyMetadata(
          savePath,
          title: parsed.title,
          artist: parsed.artist,
        );
      }
      
      await _loadFromDb();
    } catch (e) {
      print('[LibraryNotifier] Download failed: $e');
      state = state.copyWith(downloadError: 'Download failed: $e');
    } finally {
      state = state.copyWith(
        downloadingIds: state.downloadingIds.where((id) => id != key).toSet(),
        downloadProgress: Map.from(state.downloadProgress)..remove(key),
      );
    }
  }

  Future<void> downloadTrackFromUri({
    required String url,
    required String title,
    required String artist,
    String? artworkUrl,
    int? durationMs,
    int? fileId,
    String? extension,
  }) async {
    final settings = ref.read(settingsProvider);
    if (settings.selectedDownloadFolder == null) {
      state = state.copyWith(downloadError: 'No download folder selected. Please go to Settings to add one.');
      return;
    }

    state = state.copyWith(downloadError: null);

    if (io.Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          state = state.copyWith(downloadError: 'Storage permission denied. Please allow "All files access" in system settings.');
          return;
        }
      }
    }

    final effectiveFileId = fileId ?? (title.hashCode ^ artist.hashCode ^ url.hashCode);
    final key = '-1-$effectiveFileId';
    if (state.downloadingIds.contains(key)) return;

    state = state.copyWith(downloadingIds: {...state.downloadingIds, key});

    try {
      final downloadDirPath = settings.selectedDownloadFolder!;
      final downloadDir = io.Directory(downloadDirPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final effectiveExt = extension ?? '.flac';
      final fileName = '${_sanitizeFileName("$artist - $title")}$effectiveExt';
      final savePath = p.join(downloadDirPath, fileName);

      print('[LibraryNotifier] Downloading local track $title to $savePath');
      
      final client = io.HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      
      final contentLength = response.contentLength;
      int downloaded = 0;
      
      final fileToSave = io.File(savePath);
      final sink = fileToSave.openWrite();
      
      await for (final data in response) {
        sink.add(data);
        downloaded += data.length;
        if (contentLength > 0) {
          final progress = downloaded / contentLength;
          if ((progress * 100).toInt() % 2 == 0) {
            state = state.copyWith(
              downloadProgress: {...state.downloadProgress, key: progress},
            );
          }
        }
      }
      await sink.flush();
      await sink.close();

      // Save to Files table
      await _db.into(_db.files).insertOnConflictUpdate(FilesCompanion.insert(
        id: effectiveFileId,
        torrentId: -1,
        name: fileName,
        size: await fileToSave.length(),
        isAudio: true,
        localPath: Value(savePath),
      ));

      // Save Metadata
      await _db.saveTrackMetadata(TrackMetadataCompanion.insert(
        fileId: effectiveFileId,
        torrentId: -1,
        trackTitle: Value(title),
        artist: Value(artist),
        artworkUrlHigh: Value(artworkUrl),
        trackTimeMillis: Value(durationMs),
      ));

      // Apply metadata tags so other apps can see them
      await _applyMetadata(
        savePath,
        title: title,
        artist: artist,
        artworkUrl: artworkUrl,
      );

      // Ensure the "Local Downloads" torrent entry exists in DB so it loads correctly
      await _db.into(_db.torrents).insertOnConflictUpdate(TorrentsCompanion.insert(
        id: const Value(-1),
        name: 'Local Downloads',
        hash: 'local',
        cached: true,
      ));

      await _loadFromDb();
      print('[LibraryNotifier] Local download complete: $title');
    } catch (e) {
      print('[LibraryNotifier] Local download failed: $e');
      state = state.copyWith(downloadError: 'Local download failed: $e');
    } finally {
      state = state.copyWith(
        downloadingIds: state.downloadingIds.where((v) => v != key).toSet(),
        downloadProgress: Map.from(state.downloadProgress)..remove(key),
      );
    }
  }

  bool isDownloaded(TorBoxFile file) {
    if (file.localPath == null) return false;
    return io.File(file.localPath!).existsSync();
  }

  void clearDownloadError() {
    state = state.copyWith(downloadError: null);
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  Future<void> _applyMetadata(String filePath, {
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
  }) async {
    try {
      // Download artwork to a temp file
      String? artworkPath;
      if (artworkUrl != null && artworkUrl.isNotEmpty) {
        final client = io.HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(artworkUrl));
          final response = await request.close();
          if (response.statusCode == 200) {
            final List<int> bytes = await response.fold<List<int>>([], (acc, e) => acc..addAll(e));
            final tempDir = await getTemporaryDirectory();
            final ext = artworkUrl.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
            final artFile = io.File(p.join(tempDir.path, 'artwork_tmp.$ext'));
            await artFile.writeAsBytes(bytes);
            artworkPath = artFile.path;
          }
        } catch (e) {
          print('[LibraryNotifier] Failed to fetch artwork for tagging: $e');
        } finally {
          client.close();
        }
      }

      // Use audiotags to write metadata natively
      try {
        List<Picture> pictures = [];
        if (artworkPath != null) {
          final ext = artworkPath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
          pictures.add(Picture(
            bytes: await io.File(artworkPath).readAsBytes(),
            mimeType: ext == 'png' ? MimeType.png : MimeType.jpeg,
            pictureType: PictureType.coverFront,
          ));
        }

        final tag = Tag(
          title: title,
          artist: artist,
          album: album,
          pictures: pictures,
        );

        await AudioTags.write(filePath, tag);
        print('[LibraryNotifier] Successfully applied metadata tags to $filePath using audiotags');
      } catch (e) {
        print('[LibraryNotifier] audiotags tagging failed: $e');
      }

      // Clean up artwork temp file
      if (artworkPath != null) {
        final artFile = io.File(artworkPath);
        if (await artFile.exists()) await artFile.delete();
      }
    } catch (e) {
      print('[LibraryNotifier] Failed to apply tags: $e');
    }
  }
}

// ─── Playback Provider ───────────────────────────────────────────────────────
final streamUrlProvider = FutureProvider.family<String?, ({int torrentId, int fileId})>((ref, ids) async {
  return getIt<MusicRepository>().getStreamUrl(ids.torrentId, ids.fileId);
});

final trendingSongsProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final repo = getIt<MusicRepository>();
  return repo.getTopSongs();
});



final albumTracksProvider = FutureProvider.family<List<ItunesTrack>, ItunesTrack>((ref, album) async {
  final repo = getIt<MusicRepository>();
  int collectionId = album.trackId;
  
  List<ItunesTrack> tracks = [];
  if (collectionId > 0) {
    tracks = await repo.getAlbumTracks(collectionId);
  }
  
  if (tracks.isEmpty || (tracks.length == 1 && tracks.first.trackId == collectionId)) {
    final query = '${album.artistName} ${album.collectionName}'.trim();
    if (query.isNotEmpty) {
      final albums = await repo.searchItunesAlbums(query);
      if (albums.isNotEmpty) {
        final matchedAlbum = albums.firstWhere(
          (a) => a.collectionName.toLowerCase() == album.collectionName.toLowerCase(),
          orElse: () => albums.first,
        );
        final resolvedId = matchedAlbum.trackId;
        if (resolvedId > 0 && resolvedId != collectionId) {
          tracks = await repo.getAlbumTracks(resolvedId);
        }
      }
    }
  }
  return tracks;
});

final searchItunesAlbumsProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repo = getIt<MusicRepository>();
  return repo.searchItunesAlbums(query);
});

// --- Cached Trending Providers ---

class CachedTrendingSongsNotifier extends StateNotifier<AsyncValue<List<ItunesTrack>>> {
  final MusicRepository _repo;
  final AppDatabase _db;

  CachedTrendingSongsNotifier(this._repo, this._db) : super(const AsyncValue.loading()) {
    _loadCached();
  }

  Future<void> _loadCached() async {
    try {
      final syncMeta = await _db.getSyncMeta();
      final cached = syncMeta?.cachedTopSongs;
      final lastSync = syncMeta?.lastTopSongsSync;
      
      // Use cache if fresh (within 2 hours)
      if (cached != null && cached.isNotEmpty && !_db.shouldRefreshLibrary(lastSync, minIntervalMinutes: 120)) {
        final decoded = (jsonDecode(cached) as List).map((e) => ItunesTrack.fromJson(e)).toList();
        state = AsyncValue.data(decoded);
        print('[CachedTrending] Loaded ${decoded.length} songs from cache');
        return;
      }

      // Fetch fresh data
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final songs = await _repo.getTopSongs();
      // Cache the results
      final jsonStr = jsonEncode(songs.map((e) => {
        'trackId': e.trackId,
        'trackName': e.trackName,
        'artistName': e.artistName,
        'collectionName': e.collectionName,
        'artworkUrl100': e.artworkUrl,
      }).toList());
      await _db.updateTopSongsSync(jsonStr);
      state = AsyncValue.data(songs);
      print('[CachedTrending] Fetched and cached ${songs.length} songs');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final cachedTrendingSongsProvider = StateNotifierProvider<CachedTrendingSongsNotifier, AsyncValue<List<ItunesTrack>>>((ref) {
  return CachedTrendingSongsNotifier(getIt<MusicRepository>(), getIt<AppDatabase>());
});



// --- Connectivity Provider ---
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider).value;
  if (connectivity == null) return false;
  return connectivity.contains(ConnectivityResult.none);
});

class SelectedRegionNotifier extends Notifier<String> {
  @override
  String build() => 'in';
  
  void set(String region) => state = region;
}

final selectedRegionProvider = NotifierProvider<SelectedRegionNotifier, String>(() {
  return SelectedRegionNotifier();
});

class RegionalChartParams {
  final String countryCode;
  final int? genreId;
  final int limit;

  RegionalChartParams(this.countryCode, {this.genreId, this.limit = 30});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegionalChartParams &&
          runtimeType == other.runtimeType &&
          countryCode == other.countryCode &&
          genreId == other.genreId &&
          limit == other.limit;

  @override
  int get hashCode => countryCode.hashCode ^ genreId.hashCode ^ limit.hashCode;
}

final regionalTrendingSongsProvider = FutureProvider.family<List<ItunesTrack>, RegionalChartParams>((ref, params) async {
  final repo = getIt<MusicRepository>();
  return repo.getTopSongs(limit: params.limit, countryCode: params.countryCode, genreId: params.genreId);
});




final newReleasesProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, region) async {
  final repo = getIt<MusicRepository>();
  return repo.getNewReleases(limit: 30, countryCode: region);
});

final yearlyHitsProvider = FutureProvider.family<List<ItunesTrack>, ({String region, int year})>((ref, params) async {
  final repo = getIt<MusicRepository>();
  return repo.getYearlyHits(params.year, limit: 30, countryCode: params.region);
});

final recentlyAddedSongsProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final repo = getIt<MusicRepository>();
  final recent = await repo.getRecentTracks();
  return recent.map((r) => ItunesTrack(
    trackId: r.fileId,
    trackName: r.trackTitle,
    artistName: r.artist,
    collectionName: r.album,
    artworkUrl: r.artworkUrlHigh ?? r.artworkUrlLow ?? '',
  )).toList();
});

final everydayListeningProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, region) async {
  final repo = getIt<MusicRepository>();
  // We search for curated playlists first or direct popular hits for the term
  return repo.searchItunes('Everyone is Listening', limit: 40);
});

final madeToSingProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, region) async {
  final repo = getIt<MusicRepository>();
  return repo.searchItunes('Apple Music Sing', limit: 40);
});



// ─── Deezer-based Recommendation Providers ────────────────────────────────────



/// "Because you listened to X" recommendations
final becauseYouListenedToProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getBecauseYouListenedToRecommendations(artistName);
});

/// Recommendations based on recent playback history
final recommendationsBasedOnHistoryProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final repo = getIt<MusicRepository>();
  return repo.getRecommendationsBasedOnRecentHistory();
});

// --- Library Redesign Providers ---

final recentlyPlayedProvider = StreamProvider<List<DbPlaybackHistory>>((ref) {
  final repo = getIt<MusicRepository>();
  return repo.watchRecentTracks();
});

final libraryStatsProvider = Provider<Map<String, int>>((ref) {
  final state = ref.watch(libraryProvider);
  final likedAsync = ref.watch(likedSongsProvider);
  final playlistsAsync = ref.watch(playlistProvider);
  final followedAsync = ref.watch(followedArtistsProvider);
  
  final likedCount = likedAsync.value?.length ?? 0;
  final playlistsCount = playlistsAsync.value?.where((p) => p.playlist.sourceUrl == null || !p.playlist.sourceUrl!.contains('album_')).length ?? 0;
  final followedCount = followedAsync.value?.length ?? 0;
  final allFiles = state.allAudioFiles;
  final downloaded = allFiles.where((f) => f.localPath != null).length;

  return {
    'liked': likedCount,
    'downloads': downloaded,
    'total': allFiles.length,
    'playlists': playlistsCount,
    'artists': followedCount,
  };
});

final regionalPlaylistsProvider = FutureProvider.family<List<AppleMusicPlaylist>, String>((ref, region) async {
  final repo = getIt<MusicRepository>();
  return repo.getRegionalPlaylists(region: region, limit: 100);
});

final appleMusicPlaylistNotifierProvider = StateNotifierProvider.family<AppleMusicPlaylistNotifier, AsyncValue<List<ItunesTrack>>, String>((ref, playlistUrl) {
  return AppleMusicPlaylistNotifier(getIt<MusicRepository>(), getIt<AppDatabase>(), getIt<ItunesMetadataService>(), playlistUrl);
});

class AppleMusicPlaylistNotifier extends StateNotifier<AsyncValue<List<ItunesTrack>>> {
  final MusicRepository _repo;
  final AppDatabase _db;
  final ItunesMetadataService _itunes;
  final String playlistUrl;

  final Set<int> _enrichingIndices = {};
  final Set<int> _processedIndices = {};

  AppleMusicPlaylistNotifier(this._repo, this._db, this._itunes, this.playlistUrl) : super(const AsyncValue.loading()) {
    _fetchTracks();
  }

  Future<void> _fetchTracks() async {
    try {
      state = const AsyncValue.loading();
      final tracks = await _repo.getAppleMusicPlaylistTracks(playlistUrl);
      
      // Initially, use tracks as they are (maybe from cache already if repo does that, 
      // but repo currently scrapes fresh). We need to check database cache for EACH track.
      final enrichedTracks = <ItunesTrack>[];
      for (final t in tracks) {
        // Find a way to uniquely identify scraped tracks. 
        // Apple Music scraped tracks have a track URL or ID.
        // If we don't have a stable ID, we use title+artist as key for external metadata.
        final cacheKey = t.trackId > 0 ? t.trackId.toString() : '${t.trackName}|${t.artistName}';
        final cached = await _db.getExternalTrackMetadata(cacheKey);
        
        if (cached != null) {
          enrichedTracks.add(t.copyWith(
            artistName: cached.artist,
            trackName: cached.trackTitle,
            collectionName: cached.album ?? t.collectionName,
            artworkUrl: cached.artworkUrlHigh ?? cached.artworkUrlLow ?? t.artworkUrl,
            trackTimeMillis: cached.trackTimeMillis,
          ));
        } else {
          enrichedTracks.add(t);
        }
      }

      state = AsyncValue.data(enrichedTracks);
      // Only enrich the first 20 tracks initially
      _enrichRange(0, 20);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _enrichRange(int start, int end) async {
    final currentTracks = state.value;
    if (currentTracks == null) return;
    final actualEnd = end > currentTracks.length ? currentTracks.length : end;
    
    for (var i = start; i < actualEnd; i++) {
      enrichTrackAtIndex(i); // Fire and forget individual enrichments
      if (i % 5 == 0) await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> enrichTrackAtIndex(int index) async {
    final currentTracks = state.value;
    if (currentTracks == null || index < 0 || index >= currentTracks.length) return;
    
    final t = currentTracks[index];
    // Check if already enriched in this session
    if (_processedIndices.contains(index)) return;

    // Check if looks fully enriched already
    final bool isApplePlaceholder = t.artworkUrl.contains('apple.com/assets') || t.artworkUrl.contains('apple.com/image');
    if (t.artworkUrl.isNotEmpty && t.artistName.isNotEmpty && t.trackId > 0 && !isApplePlaceholder) {
       _processedIndices.add(index);
       return; 
    }

    if (_enrichingIndices.contains(index)) return;

    _enrichingIndices.add(index);
    try {
      final cacheKey = t.trackId > 0 ? t.trackId.toString() : '${t.trackName}|${t.artistName}';
      final cached = await _db.getExternalTrackMetadata(cacheKey);
      
      final newList = List<ItunesTrack>.from(state.value ?? []);
      if (index >= newList.length) return;

      if (cached != null) {
        newList[index] = t.copyWith(
          artistName: cached.artist,
          trackName: cached.trackTitle,
          collectionName: cached.album ?? t.collectionName,
          artworkUrl: cached.artworkUrlHigh ?? cached.artworkUrlLow ?? t.artworkUrl,
          trackTimeMillis: cached.trackTimeMillis,
        );
        state = AsyncValue.data(newList);
        _processedIndices.add(index);
        return;
      }

      // Fetch from iTunes
      final meta = await _itunes.fetchMeta(t.trackName, t.artistName);
      if (meta != null) {
        final enriched = t.copyWith(
          trackName: meta.trackName ?? t.trackName,
          artistName: meta.artistName ?? t.artistName,
          collectionName: meta.album ?? t.collectionName,
          artworkUrl: meta.artworkUrlHigh ?? meta.artworkUrlLow ?? t.artworkUrl,
          trackTimeMillis: meta.trackTimeMillis,
        );
        
        final latestList = List<ItunesTrack>.from(state.value ?? []);
        if (index < latestList.length) {
          latestList[index] = enriched;
          state = AsyncValue.data(latestList);
        }

          // Save to cache
          await _db.saveExternalTrackMetadata(ExternalTrackMetadataCompanion.insert(
            trackUrl: cacheKey,
            trackTitle: meta.trackName ?? t.trackName,
            artist: meta.artistName ?? t.artistName,
            album: Value(meta.album),
            genre: Value(meta.genre),
            releaseYear: Value(meta.releaseYear),
            artworkUrlLow: Value(meta.artworkUrlLow),
            artworkUrlHigh: Value(meta.artworkUrlHigh),
            trackTimeMillis: Value(meta.trackTimeMillis),
            lastUpdated: DateTime.now().millisecondsSinceEpoch,
          ));
        } else {
          // Save a dummy entry so we don't query iTunes repeatedly for missing tracks
          await _db.saveExternalTrackMetadata(ExternalTrackMetadataCompanion.insert(
            trackUrl: cacheKey,
            trackTitle: t.trackName,
            artist: t.artistName,
            album: Value(t.collectionName),
            artworkUrlHigh: Value(t.artworkUrl),
            artworkUrlLow: Value(t.artworkUrl),
            trackTimeMillis: Value(t.trackTimeMillis),
            lastUpdated: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      } catch (e) {
      print('[AppleMusicPlaylistNotifier] Enrichment error for index $index: $e');
    } finally {
      _enrichingIndices.remove(index);
      _processedIndices.add(index); // Mark as tried in this session
    }
  }
}

final recentTracksProvider = Provider<List<TorBoxFile>>((ref) {
  final state = ref.watch(libraryProvider);
  final files = state.torrents.expand((t) => t.files ?? []).toList();
  // Most recent torrents first already by ID, so just take top 20
  return files.cast<TorBoxFile>().take(20).toList();
});

// ─── Artist Providers ──────────────────────────────────────────────────────
final artistSongsProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getArtistTopSongs(artistName);
});

final artistAlbumsProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getArtistAlbums(artistName);
});

class ArtistImageParams {
  final String name;
  final String? url;
  const ArtistImageParams({required this.name, this.url});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistImageParams &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => name.hashCode ^ url.hashCode;
}

final artistImageProvider = FutureProvider.family<String?, ArtistImageParams>((ref, params) async {
  final repo = getIt<MusicRepository>();
  return repo.getArtistImage(params.name, artistUrl: params.url);
});

final trendingArtistsProvider = FutureProvider<List<ItunesTrack>>((ref) async {
  final repo = getIt<MusicRepository>();
  return repo.getTopArtists();
});

final artistDetailsProvider = FutureProvider.family<ItunesArtist?, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getArtistDetails(artistName);
});

final followedArtistsProvider = StreamProvider<List<DbFollowedArtist>>((ref) {
  final repo = getIt<MusicRepository>();
  return repo.watchFollowedArtists();
});

final isArtistFollowedProvider = StreamProvider.family<bool, int>((ref, artistId) {
  final repo = getIt<MusicRepository>();
  return repo.watchFollowedArtists().map((list) => list.any((a) => a.id == artistId));
});

final artistBioProvider = FutureProvider.family<String?, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getArtistBio(artistName);
});

final similarArtistsProvider = FutureProvider.family<List<String>, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getSimilarArtists(artistName);
});

final artistMetadataProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getArtistMetadata(artistName);
});

final trendingArtistImageProvider = FutureProvider.family<String?, ArtistImageParams>((ref, params) async {
  final repo = getIt<MusicRepository>();
  return repo.getArtistImage(params.name, highRes: false, artistUrl: params.url);
});

final deezerArtistPlaylistsProvider = FutureProvider.family<List<DeezerPlaylist>, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getDeezerArtistPlaylists(artistName);
});

final deezerArtistTopTracksProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getDeezerArtistTopTracks(artistName);
});

final deezerRelatedArtistsProvider = FutureProvider.family<List<String>, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getDeezerRelatedArtists(artistName);
});

final deezerPlaylistTracksProvider = StateNotifierProvider.family<DeezerPlaylistTracksNotifier, AsyncValue<List<ItunesTrack>>, String>((ref, playlistId) {
  return DeezerPlaylistTracksNotifier(playlistId);
});

class DeezerPlaylistTracksNotifier extends StateNotifier<AsyncValue<List<ItunesTrack>>> {
  final String _playlistId;
  int _currentIndex = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  DeezerPlaylistTracksNotifier(this._playlistId) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      _currentIndex = 0;
      _hasMore = true;
      final repo = getIt<MusicRepository>();
      final tracks = await repo.getDeezerPlaylistTracks(_playlistId, index: 0);
      _currentIndex = tracks.length;
      if (tracks.length < 50) _hasMore = false;
      state = AsyncValue.data(tracks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> fetchNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading || state.hasError) return;
    
    _isLoadingMore = true;
    try {
      final repo = getIt<MusicRepository>();
      final newTracks = await repo.getDeezerPlaylistTracks(_playlistId, index: _currentIndex);
      
      if (newTracks.isEmpty) {
        _hasMore = false;
      } else {
        final currentTracks = state.value ?? [];
        state = AsyncData([...currentTracks, ...newTracks]);
        _currentIndex += newTracks.length;
        if (newTracks.length < 50) _hasMore = false;
      }
    } catch (e, st) {
      print('[DeezerPlaylistTracksNotifier] fetchNextPage error: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
}

final deezerArtistDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, artistName) async {
  final repo = getIt<MusicRepository>();
  return repo.getDeezerArtistDetails(artistName);
});

// ─── Liked Songs Provider ────────────────────────────────────────────────────

class LikedSongEntry {
  final TorBoxFile file;
  final ItunesMeta meta;
  LikedSongEntry(this.file, this.meta);
}

final likedSongsProvider = StateNotifierProvider<LikedSongsNotifier, AsyncValue<List<LikedSongEntry>>>((ref) {
  return LikedSongsNotifier(getIt<AppDatabase>(), ref);
});

class LikedSongsNotifier extends StateNotifier<AsyncValue<List<LikedSongEntry>>> {
  final AppDatabase _db;
  final Ref _ref;
  StreamSubscription? _subscription;

  LikedSongsNotifier(this._db, this._ref) : super(const AsyncValue.loading()) {
    refresh();
    
    // 🌟 Listen to DB changes for reactive updates from background triggers 🌟
    _subscription = (_db.select(_db.trackMetadata)..where((t) => t.isLiked.equals(true)))
        .watch()
        .listen((_) {
      refresh();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }


  Future<void> refresh() async {
    try {
      final likedMetas = await _db.getLikedTracks();
      final allFiles = await _db.getAllFiles();

      final entries = <LikedSongEntry>[];
      for (final meta in likedMetas) {
        final dbFile = allFiles.where((f) => f.id == meta.fileId && f.torrentId == meta.torrentId).firstOrNull;
        final file = dbFile != null
            ? TorBoxFile(
                id: dbFile.id,
                name: dbFile.name,
                size: dbFile.size,
                torrentId: dbFile.torrentId,
                localPath: dbFile.localPath,
              )
            : TorBoxFile(
                id: meta.fileId,
                name: meta.trackTitle ?? 'Unknown Track',
                size: 0,
                torrentId: meta.torrentId,
                localPath: null,
              );
        final trackMeta = ItunesMeta(
          trackName: meta.trackTitle,
          artistName: meta.artist,
          album: meta.album,
          genre: meta.genre,
          artworkUrlLow: meta.artworkUrlLow,
          artworkUrlHigh: meta.artworkUrlHigh,
          trackTimeMillis: meta.trackTimeMillis,
          releaseYear: meta.releaseYear,
        );
        entries.add(LikedSongEntry(file, trackMeta));
      }
      
      // Sort recently liked first (assuming ID order loosely correlates or we just reverse it)
      state = AsyncValue.data(entries.reversed.toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleLike(int torrentId, int fileId, bool isCurrentlyLiked, {String? title, String? artist}) async {
    final nextState = !isCurrentlyLiked;
    await _db.toggleTrackLike(torrentId, fileId, nextState, title: title, artist: artist);
    
    // 🌟 Bidirectional Last.fm Sync 🌟
    try {
      final lastfmRepo = getIt<LastfmRepository>();
      if (lastfmRepo.isConnected && title != null && artist != null) {
        final lastfmService = getIt<LastFmService>();
        final key = lastfmRepo.sessionKey;
        if (key != null) {
          if (nextState) {
            await lastfmService.loveTrack(title, artist, key);
          } else {
            await lastfmService.unloveTrack(title, artist, key);
          }
        }
      }
    } catch (e) {
      print('[LikedSongsNotifier] Last.fm sync error: $e');
    }

    await refresh(); // Re-fetch all liked songs to update the list
  }
}

final isTrackLikedProvider = Provider.family<bool, ({int torrentId, int fileId})>((ref, ids) {
  final likedSongs = ref.watch(likedSongsProvider).value;
  if (likedSongs == null) return false;
  return likedSongs.any((e) => e.file.id == ids.fileId && e.file.torrentId == ids.torrentId);
});

final selectedJioSaavnLanguageProvider = StateProvider<String>((ref) => 'english');

final jiosaavnFeaturedPlaylistsProvider = FutureProvider.family<List<AppleMusicPlaylist>, String>((ref, language) async {
  final dio = Dio();
  dio.options.headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
  };
  
  final response = await dio.get('https://www.jiosaavn.com/featured-playlists/$language');
  final html = response.data as String;
  
  String? jsonStr;
  final lines = html.split('\n');
  for (var line in lines) {
    if (line.contains('window.__INITIAL_DATA__')) {
      final startIndex = line.indexOf('window.__INITIAL_DATA__');
      final equalIndex = line.indexOf('=', startIndex);
      if (equalIndex != -1) {
        var str = line.substring(equalIndex + 1).trim();
        if (str.endsWith(';')) {
          str = str.substring(0, str.length - 1).trim();
        }
        jsonStr = str;
      }
      break;
    }
  }
  
  if (jsonStr == null) return [];
  
  jsonStr = jsonStr.replaceAll(RegExp(r':\s*undefined'), ': null');
  jsonStr = jsonStr.replaceAll(RegExp(r'new Date\([^)]+\)'), 'null');
  
  final data = jsonDecode(jsonStr);
  final browseList = data['browse']?['browse_list'] as List<dynamic>? ?? [];
  
  return browseList.map((item) {
    final images = item['image'] as List<dynamic>? ?? [];
    final artwork = images.isNotEmpty ? images.first?.toString() ?? '' : '';
    
    return AppleMusicPlaylist(
      id: item['id']?.toString() ?? '',
      name: item['title']?['text']?.toString() ?? 'Featured Playlist',
      artworkUrl: artwork,
      url: item['perma_url']?.toString() ?? '',
    );
  }).toList();
});

final jiosaavnPlaylistTracksProvider = FutureProvider.family<List<ItunesTrack>, String>((ref, playlistUrl) async {
  final dio = Dio();
  dio.options.headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
  };
  
  final response = await dio.get(playlistUrl);
  final html = response.data as String;
  
  String? jsonStr;
  final lines = html.split('\n');
  for (var line in lines) {
    if (line.contains('window.__INITIAL_DATA__')) {
      final startIndex = line.indexOf('window.__INITIAL_DATA__');
      final equalIndex = line.indexOf('=', startIndex);
      if (equalIndex != -1) {
        var str = line.substring(equalIndex + 1).trim();
        if (str.endsWith(';')) {
          str = str.substring(0, str.length - 1).trim();
        }
        jsonStr = str;
      }
      break;
    }
  }
  
  if (jsonStr == null) return [];
  
  jsonStr = jsonStr.replaceAll(RegExp(r':\s*undefined'), ': null');
  jsonStr = jsonStr.replaceAll(RegExp(r'new Date\([^)]+\)'), 'null');
  
  final data = jsonDecode(jsonStr);
  final playlist = data['playlist']?['playlist'] as Map<String, dynamic>?;
  if (playlist == null) return [];
  
  final list = playlist['list'] as List<dynamic>? ?? [];
  return list.map((item) {
    final artistsList = item['artists'] as List<dynamic>? ?? [];
    var filteredArtists = artistsList.where((a) {
      final role = a['role']?.toString().toLowerCase() ?? '';
      return role == 'singer' || role == 'primary_artist' || role == 'primary' || role == 'artist';
    }).toList();

    if (filteredArtists.isEmpty) {
      filteredArtists = artistsList;
    }

    final artistName = filteredArtists
        .map((a) => a['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .take(2)
        .join(', ');
    
    final images = item['image'] as List<dynamic>? ?? [];
    final artwork = images.isNotEmpty ? images.first?.toString() ?? '' : '';
    
    return ItunesTrack(
      trackId: int.tryParse(item['id']?.toString() ?? '') ?? (item['id']?.toString().hashCode.abs() ?? 0),
      trackName: item['title']?['text']?.toString() ?? 'Unknown Track',
      artistName: artistName.isNotEmpty ? artistName : 'Unknown Artist',
      collectionName: item['album']?['text']?.toString() ?? '',
      artworkUrl: artwork,
    );
  }).toList();
});
