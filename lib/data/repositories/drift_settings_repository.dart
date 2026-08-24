import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';

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
}
