import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';
import 'package:whisplayer/features/library/domain/browse_prefs.dart';

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String?> getString(String key) => _db.settingsDao.getValue(key);

  @override
  Future<void> setString(String key, String? value) {
    return _db.settingsDao.setValue(key, value);
  }

  @override
  Future<Map<String, String>> getAll() => _db.settingsDao.getAll();

  @override
  Future<BrowsePrefs> getBrowsePrefs() async =>
      BrowsePrefs.fromMap(await getAll());

  @override
  Future<void> setBrowsePrefs(BrowsePrefs prefs) async {
    final map = prefs.toMap();
    for (final entry in map.entries) {
      await setString(entry.key, entry.value);
    }
  }
}
