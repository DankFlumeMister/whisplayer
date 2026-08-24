// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_server_dao.dart';

// ignore_for_file: type=lint
mixin _$RemoteServerDaoMixin on DatabaseAccessor<AppDatabase> {
  $RemoteServersTable get remoteServers => attachedDatabase.remoteServers;
  RemoteServerDaoManager get managers => RemoteServerDaoManager(this);
}

class RemoteServerDaoManager {
  final _$RemoteServerDaoMixin _db;
  RemoteServerDaoManager(this._db);
  $$RemoteServersTableTableManager get remoteServers =>
      $$RemoteServersTableTableManager(_db.attachedDatabase, _db.remoteServers);
}
