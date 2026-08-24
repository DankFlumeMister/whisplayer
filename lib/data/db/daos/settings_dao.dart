import 'package:drift/drift.dart';

import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/data/db/tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [SettingsKv])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(settingsKv)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String? value) {
    return into(settingsKv).insertOnConflictUpdate(
      SettingsKvCompanion.insert(key: key, value: Value(value)),
    );
  }

  Future<Map<String, String>> getAll() async {
    final rows = await select(settingsKv).get();
    return {
      for (final row in rows)
        if (row.value != null) row.key: row.value!,
    };
  }
}
