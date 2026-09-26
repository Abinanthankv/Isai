import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TorBoxSettingsRepository {
  Future<void> setApiKey(String key);
  String? get apiKey;
  bool get hasApiKey;
  
  Future<void> setYouTubeScraperEnabled(bool enabled);
  bool get isYouTubeScraperEnabled;

  Future<void> setDownloadFolders(List<String> folders);
  List<String> get downloadFolders;

  Future<void> setSelectedDownloadFolder(String? folder);
  String? get selectedDownloadFolder;
  
  Future<void> setPlayerArtworkShape(String shape);
  String get playerArtworkShape;

  Future<void> setPlayerShowGlow(bool show);
  bool get playerShowGlow;

  Future<void> setPlayerBackgroundType(String type);
  String get playerBackgroundType;

  Future<void> setPlayerArtworkSize(double size);
  double get playerArtworkSize;

  Future<void> setPlayerSeekBarStyle(String style);
  String get playerSeekBarStyle;

  Future<void> setPlayerLikeIcon(String icon);
  String get playerLikeIcon;

  Future<void> setPlayerArtworkAnimation(String animation);
  String get playerArtworkAnimation;

  Future<void> setPlayerLyricsFontSize(double size);
  double get playerLyricsFontSize;

  Future<void> setPlayerLyricsAlignment(String alignment);
  String get playerLyricsAlignment;

  Future<void> setPlayerLyricsFontWeight(String weight);
  String get playerLyricsFontWeight;

  Future<void> setPlayerControlLayout(String layout);
  String get playerControlLayout;

  Future<void> setPlayerButtonStyle(String style);
  String get playerButtonStyle;

  Future<void> setPlayerMinimalistShowSource(bool show);
  bool get playerMinimalistShowSource;

  Future<void> setPlayerMinimalistShowLyrics(bool show);
  bool get playerMinimalistShowLyrics;

  Future<void> setPlayerMinimalistShowSleep(bool show);
  bool get playerMinimalistShowSleep;

  Future<void> setPlayerMinimalistShowQueue(bool show);
  bool get playerMinimalistShowQueue;

  Future<void> setPlayerSpotifyCanvasEnabled(bool enabled);
  bool get playerSpotifyCanvasEnabled;

  Future<void> setBitPerfectUsbOutputEnabled(bool enabled);
  bool get bitPerfectUsbOutputEnabled;



  Future<void> setMaxSongCacheSize(int sizeInMb);
  int get maxSongCacheSize;

  Future<void> setMaxImageCacheSize(int sizeInMb);
  int get maxImageCacheSize;

  Future<void> setAddonPriority(List<String> priority);
  List<String> get addonPriority;

  Future<void> setMetadataProviderEnabled(String id, bool enabled);
  bool isMetadataProviderEnabled(String id);

  Future<void> setAppThemeStyle(String style);
  String get appThemeStyle;

  Future<void> setAppFontFamily(String font);
  String get appFontFamily;

  Future<void> setAppleUseLiquidGlass(bool value);
  bool get appleUseLiquidGlass;

  Future<void> setAppleLiquidGlassOpacity(double value);
  double get appleLiquidGlassOpacity;

  Future<void> setMiniPlayerSwipeEnabled(bool enabled);
  bool get miniPlayerSwipeEnabled;

  Future<void> setMiniPlayerSwipeSensitivity(double sensitivity);
  double get miniPlayerSwipeSensitivity;

  Future<void> setPlayerShowCurrentLyrics(bool show);
  bool get playerShowCurrentLyrics;

  Future<void> setPlayerShowNextUp(bool show);
  bool get playerShowNextUp;

  Future<void> setPlayerNextUpCount(int count);
  int get playerNextUpCount;

  Future<void> setPlayerNextUpStyle(String style);
  String get playerNextUpStyle;

  Future<void> setAudiobookFolder(String? folder);
  String? get audiobookFolder;

  Future<void> setDiscoverSectionOrder(List<String> order);
  List<String> get discoverSectionOrder;

  Future<void> setDisabledDiscoverSections(List<String> ids);
  List<String> get disabledDiscoverSections;

  Future<void> setHapticsEnabled(bool enabled);
  bool get hapticsEnabled;

  Future<void> setHapticIntensity(String intensity);
  String get hapticIntensity;
}

@LazySingleton(as: TorBoxSettingsRepository)
class TorBoxSettingsRepositoryImpl implements TorBoxSettingsRepository {
  final SharedPreferences _prefs;
  static const _keyApiKey = 'torbox_api_key';

  TorBoxSettingsRepositoryImpl(this._prefs);

  @override
  String? get apiKey => _prefs.getString(_keyApiKey);

  @override
  bool get hasApiKey {
    final key = apiKey;
    return key != null && key.isNotEmpty;
  }

  @override
  Future<void> setApiKey(String key) => _prefs.setString(_keyApiKey, key);

  @override
  bool get isYouTubeScraperEnabled => _prefs.getBool('enable_youtube_scraper') ?? true;
  @override
  Future<void> setYouTubeScraperEnabled(bool enabled) => _prefs.setBool('enable_youtube_scraper', enabled);

  @override
  List<String> get downloadFolders => _prefs.getStringList('download_folders') ?? [];

  @override
  Future<void> setDownloadFolders(List<String> folders) => _prefs.setStringList('download_folders', folders);

  @override
  String? get selectedDownloadFolder => _prefs.getString('selected_download_folder');

  @override
  Future<void> setSelectedDownloadFolder(String? folder) {
    if (folder == null) return _prefs.remove('selected_download_folder');
    return _prefs.setString('selected_download_folder', folder);
  }

  @override
  String get playerArtworkShape => _prefs.getString('player_artwork_shape') ?? 'circle';

  @override
  Future<void> setPlayerArtworkShape(String shape) => _prefs.setString('player_artwork_shape', shape);

  @override
  bool get playerShowGlow => _prefs.getBool('player_show_glow') ?? true;

  @override
  Future<void> setPlayerShowGlow(bool show) => _prefs.setBool('player_show_glow', show);

  @override
  String get playerBackgroundType => _prefs.getString('player_background_type') ?? 'blurred';

  @override
  Future<void> setPlayerBackgroundType(String type) => _prefs.setString('player_background_type', type);

  @override
  double get playerArtworkSize => _prefs.getDouble('player_artwork_size') ?? 270.0;

  @override
  Future<void> setPlayerArtworkSize(double size) => _prefs.setDouble('player_artwork_size', size);

  @override
  String get playerSeekBarStyle => _prefs.getString('player_seekbar_style') ?? 'default';

  @override
  Future<void> setPlayerSeekBarStyle(String style) => _prefs.setString('player_seekbar_style', style);

  @override
  String get playerLikeIcon => _prefs.getString('player_like_icon') ?? 'heart';

  @override
  Future<void> setPlayerLikeIcon(String icon) => _prefs.setString('player_like_icon', icon);

  @override
  String get playerArtworkAnimation => _prefs.getString('player_artwork_animation') ?? 'zoom';

  @override
  Future<void> setPlayerArtworkAnimation(String animation) => _prefs.setString('player_artwork_animation', animation);

  @override
  double get playerLyricsFontSize => _prefs.getDouble('player_lyrics_font_size') ?? 18.0;

  @override
  Future<void> setPlayerLyricsFontSize(double size) => _prefs.setDouble('player_lyrics_font_size', size);

  @override
  String get playerLyricsAlignment => _prefs.getString('player_lyrics_alignment') ?? 'center';

  @override
  Future<void> setPlayerLyricsAlignment(String alignment) => _prefs.setString('player_lyrics_alignment', alignment);

  @override
  String get playerLyricsFontWeight => _prefs.getString('player_lyrics_font_weight') ?? 'normal';

  @override
  Future<void> setPlayerLyricsFontWeight(String weight) => _prefs.setString('player_lyrics_font_weight', weight);

  @override
  String get playerControlLayout => _prefs.getString('player_control_layout') ?? 'standard';

  @override
  Future<void> setPlayerControlLayout(String layout) => _prefs.setString('player_control_layout', layout);

  @override
  String get playerButtonStyle => _prefs.getString('player_button_style') ?? 'theme';

  @override
  Future<void> setPlayerButtonStyle(String style) => _prefs.setString('player_button_style', style);

  @override
  bool get playerMinimalistShowSource => _prefs.getBool('player_minimalist_show_source') ?? false;

  @override
  bool get bitPerfectUsbOutputEnabled => _prefs.getBool('bit_perfect_usb_output_enabled') ?? true;

  @override
  Future<void> setBitPerfectUsbOutputEnabled(bool enabled) => _prefs.setBool('bit_perfect_usb_output_enabled', enabled);

  @override
  Future<void> setPlayerMinimalistShowSource(bool show) => _prefs.setBool('player_minimalist_show_source', show);

  @override
  bool get playerMinimalistShowLyrics => _prefs.getBool('player_minimalist_show_lyrics') ?? false;

  @override
  Future<void> setPlayerMinimalistShowLyrics(bool show) => _prefs.setBool('player_minimalist_show_lyrics', show);

  @override
  bool get playerMinimalistShowSleep => _prefs.getBool('player_minimalist_show_sleep') ?? false;

  @override
  Future<void> setPlayerMinimalistShowSleep(bool show) => _prefs.setBool('player_minimalist_show_sleep', show);

  @override
  bool get playerMinimalistShowQueue => _prefs.getBool('player_minimalist_show_queue') ?? false;

  @override
  Future<void> setPlayerMinimalistShowQueue(bool show) => _prefs.setBool('player_minimalist_show_queue', show);

  @override
  bool get playerSpotifyCanvasEnabled => _prefs.getBool('player_spotify_canvas_enabled') ?? false;

  @override
  Future<void> setPlayerSpotifyCanvasEnabled(bool enabled) => _prefs.setBool('player_spotify_canvas_enabled', enabled);



  @override
  int get maxSongCacheSize => _prefs.getInt('max_song_cache_size') ?? 1024;

  @override
  Future<void> setMaxSongCacheSize(int sizeInMb) => _prefs.setInt('max_song_cache_size', sizeInMb);

  @override
  int get maxImageCacheSize => _prefs.getInt('max_image_cache_size') ?? 512;

  @override
  Future<void> setMaxImageCacheSize(int sizeInMb) => _prefs.setInt('max_image_cache_size', sizeInMb);

  @override
  List<String> get addonPriority => _prefs.getStringList('addon_priority_order') ?? [];

  @override
  Future<void> setAddonPriority(List<String> priority) => _prefs.setStringList('addon_priority_order', priority);
  @override
  bool isMetadataProviderEnabled(String id) => _prefs.getBool('meta_provider_$id') ?? (id == 'apple_music');
  @override
  Future<void> setMetadataProviderEnabled(String id, bool enabled) => _prefs.setBool('meta_provider_$id', enabled);

  @override
  String get appThemeStyle => _prefs.getString('app_theme_style') ?? 'material3';

  @override
  Future<void> setAppThemeStyle(String style) => _prefs.setString('app_theme_style', style);

  @override
  String get appFontFamily => _prefs.getString('app_font_family') ?? 'Roboto Flex';

  @override
  Future<void> setAppFontFamily(String font) => _prefs.setString('app_font_family', font);

  @override
  bool get appleUseLiquidGlass => _prefs.getBool('apple_use_liquid_glass') ?? true;

  @override
  Future<void> setAppleUseLiquidGlass(bool value) => _prefs.setBool('apple_use_liquid_glass', value);

  @override
  double get appleLiquidGlassOpacity => _prefs.getDouble('apple_liquid_glass_opacity') ?? 0.5;

  @override
  Future<void> setAppleLiquidGlassOpacity(double value) => _prefs.setDouble('apple_liquid_glass_opacity', value);

  @override
  bool get miniPlayerSwipeEnabled => _prefs.getBool('mini_player_swipe_enabled') ?? true;

  @override
  Future<void> setMiniPlayerSwipeEnabled(bool enabled) => _prefs.setBool('mini_player_swipe_enabled', enabled);

  @override
  double get miniPlayerSwipeSensitivity => _prefs.getDouble('mini_player_swipe_sensitivity') ?? 40.0;

  @override
  Future<void> setMiniPlayerSwipeSensitivity(double sensitivity) => _prefs.setDouble('mini_player_swipe_sensitivity', sensitivity);

  @override
  bool get playerShowCurrentLyrics => _prefs.getBool('player_show_current_lyrics') ?? false;

  @override
  Future<void> setPlayerShowCurrentLyrics(bool show) => _prefs.setBool('player_show_current_lyrics', show);

  @override
  bool get playerShowNextUp => _prefs.getBool('player_show_next_up') ?? true;

  @override
  Future<void> setPlayerShowNextUp(bool show) => _prefs.setBool('player_show_next_up', show);

  @override
  int get playerNextUpCount => _prefs.getInt('player_next_up_count') ?? 2;

  @override
  Future<void> setPlayerNextUpCount(int count) => _prefs.setInt('player_next_up_count', count);

  @override
  String get playerNextUpStyle => _prefs.getString('player_next_up_style') ?? 'art_and_name';

  @override
  Future<void> setPlayerNextUpStyle(String style) => _prefs.setString('player_next_up_style', style);

  @override
  String? get audiobookFolder => _prefs.getString('audiobook_folder');

  @override
  Future<void> setAudiobookFolder(String? folder) {
    if (folder == null) return _prefs.remove('audiobook_folder');
    return _prefs.setString('audiobook_folder', folder);
  }

  @override
  List<String> get discoverSectionOrder => _prefs.getStringList('discover_section_order') ?? [];

  @override
  Future<void> setDiscoverSectionOrder(List<String> order) =>
      _prefs.setStringList('discover_section_order', order);

  @override
  List<String> get disabledDiscoverSections =>
      _prefs.getStringList('disabled_discover_sections') ?? [];

  @override
  Future<void> setDisabledDiscoverSections(List<String> ids) =>
      _prefs.setStringList('disabled_discover_sections', ids);

  @override
  bool get hapticsEnabled => _prefs.getBool('haptics_enabled') ?? true;

  @override
  Future<void> setHapticsEnabled(bool enabled) => _prefs.setBool('haptics_enabled', enabled);

  @override
  String get hapticIntensity => _prefs.getString('haptic_intensity') ?? 'medium';

  @override
  Future<void> setHapticIntensity(String intensity) => _prefs.setString('haptic_intensity', intensity);
}
