// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webdav_server_dao.dart';

// ignore_for_file: type=lint
mixin _$WebDavServerDaoMixin on DatabaseAccessor<AppDatabase> {
  $WebDavServersTable get webDavServers => attachedDatabase.webDavServers;
  WebDavServerDaoManager get managers => WebDavServerDaoManager(this);
}

class WebDavServerDaoManager {
  final _$WebDavServerDaoMixin _db;
  WebDavServerDaoManager(this._db);
  $$WebDavServersTableTableManager get webDavServers =>
      $$WebDavServersTableTableManager(_db.attachedDatabase, _db.webDavServers);
}
