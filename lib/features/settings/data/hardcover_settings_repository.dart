import 'package:shared_preferences/shared_preferences.dart';
import 'package:injectable/injectable.dart';

abstract class HardcoverSettingsRepository {
  Future<void> setApiKey(String key);
  String? get apiKey;
  bool get hasApiKey;
  Future<void> clearApiKey();
  Future<void> setUsername(String username);
  String? get username;
}

@LazySingleton(as: HardcoverSettingsRepository)
class HardcoverSettingsRepositoryImpl implements HardcoverSettingsRepository {
  final SharedPreferences _prefs;
  static const _keyApiKey = 'hardcover_api_key';
  static const _keyUsername = 'hardcover_username';

  HardcoverSettingsRepositoryImpl(this._prefs);

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
  Future<void> clearApiKey() {
    _prefs.remove(_keyUsername);
    return _prefs.remove(_keyApiKey);
  }

  @override
  Future<void> setUsername(String username) => _prefs.setString(_keyUsername, username);

  @override
  String? get username => _prefs.getString(_keyUsername);
}
