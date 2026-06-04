import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';

@module
abstract class StorageModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  @lazySingleton
  AppDatabase get database => AppDatabase();
}
