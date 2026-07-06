import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LastfmRepository {
  Future<void> setSessionKey(String? key);
  String? get sessionKey;
  
  Future<void> setUsername(String? name);
  String? get username;
  
  bool get isConnected;

  bool get scrobbleEnabled;
  Future<void> setScrobbleEnabled(bool value);

  int get scrobblePercentage;
  Future<void> setScrobblePercentage(int value);

  int get minScrobbleMinutes;
  Future<void> setMinScrobbleMinutes(int value);
}

@LazySingleton(as: LastfmRepository)
class LastfmRepositoryImpl implements LastfmRepository {
  final SharedPreferences _prefs;
  static const _keySessionKey = 'lastfm_session_key';
  static const _keyUsername = 'lastfm_username';
  static const _keyScrobbleEnabled = 'lastfm_scrobble_enabled';
  static const _keyScrobblePercentage = 'lastfm_scrobble_percentage';
  static const _keyMinScrobbleMinutes = 'lastfm_min_scrobble_minutes';

  LastfmRepositoryImpl(this._prefs);

  @override
  String? get sessionKey => _prefs.getString(_keySessionKey);

  @override
  Future<void> setSessionKey(String? key) {
    if (key == null) return _prefs.remove(_keySessionKey);
    return _prefs.setString(_keySessionKey, key);
  }

  @override
  String? get username => _prefs.getString(_keyUsername);

  @override
  Future<void> setUsername(String? name) {
    if (name == null) return _prefs.remove(_keyUsername);
    return _prefs.setString(_keyUsername, name);
  }

  @override
  bool get isConnected => sessionKey != null && sessionKey!.isNotEmpty;

  @override
  bool get scrobbleEnabled => _prefs.getBool(_keyScrobbleEnabled) ?? true;

  @override
  Future<void> setScrobbleEnabled(bool value) => _prefs.setBool(_keyScrobbleEnabled, value);

  @override
  int get scrobblePercentage => _prefs.getInt(_keyScrobblePercentage) ?? 50;

  @override
  Future<void> setScrobblePercentage(int value) => _prefs.setInt(_keyScrobblePercentage, value);

  @override
  int get minScrobbleMinutes => _prefs.getInt(_keyMinScrobbleMinutes) ?? 0;

  @override
  Future<void> setMinScrobbleMinutes(int value) => _prefs.setInt(_keyMinScrobbleMinutes, value);
}
