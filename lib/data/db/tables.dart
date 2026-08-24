import 'package:drift/drift.dart';

import 'package:whisplayer/domain/entities/source_type.dart';

@DataClassName('ArtistRow')
class Artists extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();
}

@DataClassName('AlbumRow')
class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get groupKey => text().unique()();

  IntColumn get artistId => integer()
      .nullable()
      .references(Artists, #id)();

  IntColumn get year => integer().nullable()();

  TextColumn get artworkPath => text().nullable()();
}

@DataClassName('SongRow')
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get path => text().unique()();

  IntColumn get sourceType => intEnum<SourceType>()();

  TextColumn get title => text()();

  TextColumn get fileName => text()();

  TextColumn get format => text()();

  IntColumn get artistId => integer()
      .nullable()
      .references(Artists, #id)();

  IntColumn get albumId => integer()
      .nullable()
      .references(Albums, #id)();

  TextColumn get genre => text().nullable()();

  IntColumn get sampleRate => integer().nullable()();

  IntColumn get bitDepth => integer().nullable()();

  IntColumn get channels => integer().nullable()();

  IntColumn get bitrateKbps => integer().nullable()();

  IntColumn get durationMs => integer()();

  IntColumn get fileSizeBytes => integer()();

  IntColumn get trackNumber => integer().nullable()();

  IntColumn get discNumber => integer().nullable()();

  IntColumn get year => integer().nullable()();

  TextColumn get artworkPath => text().nullable()();

  TextColumn get lyricsPath => text().nullable()();

  TextColumn get lyricsText => text().nullable()();

  BoolColumn get hasEmbeddedLyrics =>
      boolean().withDefault(const Constant(false))();

  TextColumn get searchText => text().withDefault(const Constant(''))();

  IntColumn get addedAtMs => integer()();

  IntColumn get modifiedAtMs => integer()();

  IntColumn get playCount => integer().withDefault(const Constant(0))();

  IntColumn get skipCount => integer().withDefault(const Constant(0))();

  IntColumn get totalPlayMs => integer().withDefault(const Constant(0))();

  IntColumn get lastPlayedAtMs => integer().nullable()();

  IntColumn get lastPositionMs => integer().withDefault(const Constant(0))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();

  IntColumn get createdAtMs => integer()();

  IntColumn get updatedAtMs => integer()();
}

@DataClassName('PlaylistEntryRow')
class PlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get playlistId => integer()
      .references(Playlists, #id, onDelete: KeyAction.cascade)();

  IntColumn get songId => integer()
      .references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  IntColumn get addedAtMs => integer()();
}

@DataClassName('PlayHistoryRow')
class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get songId => integer()
      .references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get playedAtMs => integer()();

  IntColumn get playedMs => integer()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

@DataClassName('SettingsKvRow')
class SettingsKv extends Table {
  TextColumn get key => text()();

  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('RemoteServerRow')
class RemoteServers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get baseUrl => text()();

  TextColumn get username => text()();

  IntColumn get addedAtMs => integer()();
}
