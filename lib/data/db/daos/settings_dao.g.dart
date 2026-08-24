// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_dao.dart';

// ignore_for_file: type=lint
mixin _$SettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SettingsKvTable get settingsKv => attachedDatabase.settingsKv;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$SettingsKvTableTableManager get settingsKv =>
      $$SettingsKvTableTableManager(_db.attachedDatabase, _db.settingsKv);
}
