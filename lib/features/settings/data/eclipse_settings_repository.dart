import 'package:shared_preferences/shared_preferences.dart';
import 'package:injectable/injectable.dart';

abstract class EclipseSettingsRepository {
  Future<void> setToken(String token);
  String? get token;
  bool get hasToken;
  Future<void> clearToken();
  Future<void> setUserId(String id);
  String? get userId;
  Future<void> setUsername(String? username);
  String? get username;
  Future<void> setEmail(String email);
  String? get email;
  Future<void> setAvatarUrl(String? url);
  String? get avatarUrl;
  bool get scrobbleEnabled;
  Future<void> setScrobbleEnabled(bool enabled);
}

@LazySingleton(as: EclipseSettingsRepository)
class EclipseSettingsRepositoryImpl implements EclipseSettingsRepository {
  final SharedPreferences _prefs;
  static const _keyToken = 'eclipse_token';
  static const _keyUserId = 'eclipse_user_id';
  static const _keyUsername = 'eclipse_username';
  static const _keyEmail = 'eclipse_email';
  static const _keyAvatarUrl = 'eclipse_avatar_url';
  static const _keyScrobbleEnabled = 'eclipse_scrobble_enabled';

  EclipseSettingsRepositoryImpl(this._prefs);

  @override
  String? get token => _prefs.getString(_keyToken);

  @override
  bool get hasToken {
    final t = token;
    return t != null && t.isNotEmpty;
  }

  @override
  Future<void> setToken(String token) => _prefs.setString(_keyToken, token);

  @override
  Future<void> clearToken() {
    _prefs.remove(_keyUserId);
    _prefs.remove(_keyUsername);
    _prefs.remove(_keyEmail);
    _prefs.remove(_keyAvatarUrl);
    _prefs.remove(_keyScrobbleEnabled);
    return _prefs.remove(_keyToken);
  }

  @override
  Future<void> setUserId(String id) => _prefs.setString(_keyUserId, id);

  @override
  String? get userId => _prefs.getString(_keyUserId);

  @override
  Future<void> setUsername(String? username) {
    if (username == null) return _prefs.remove(_keyUsername);
    return _prefs.setString(_keyUsername, username);
  }

  @override
  String? get username => _prefs.getString(_keyUsername);

  @override
  Future<void> setEmail(String email) => _prefs.setString(_keyEmail, email);

  @override
  String? get email => _prefs.getString(_keyEmail);

  @override
  Future<void> setAvatarUrl(String? url) {
    if (url == null) return _prefs.remove(_keyAvatarUrl);
    return _prefs.setString(_keyAvatarUrl, url);
  }

  @override
  String? get avatarUrl => _prefs.getString(_keyAvatarUrl);

  @override
  bool get scrobbleEnabled => _prefs.getBool(_keyScrobbleEnabled) ?? false;

  @override
  Future<void> setScrobbleEnabled(bool enabled) => _prefs.setBool(_keyScrobbleEnabled, enabled);
}
