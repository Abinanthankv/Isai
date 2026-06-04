import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LastfmRepository {
  Future<void> setSessionKey(String? key);
  String? get sessionKey;
  
  Future<void> setUsername(String? name);
  String? get username;
  
  bool get isConnected;
}

@LazySingleton(as: LastfmRepository)
class LastfmRepositoryImpl implements LastfmRepository {
  final SharedPreferences _prefs;
  static const _keySessionKey = 'lastfm_session_key';
  static const _keyUsername = 'lastfm_username';

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
}
