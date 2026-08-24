import 'package:drift/drift.dart' show Value;
import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/repositories/library_writer_repository.dart';

class DriftLibraryWriterRepository implements LibraryWriterRepository {
  DriftLibraryWriterRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<ExistingSongInfo>> loadExistingSongs() {
    return _db.songDao.loadExistingLight();
  }

  @override
  Future<int> upsertScannedSong(ScannedSong song) {
    return _db.transaction(() async {
      final artistId = await _resolveArtist(song);
      final albumId = await _resolveAlbum(song, artistId);
      return _db.songDao.upsertByPath(
        _toCompanion(song, artistId, albumId),
      );
    });
  }

  @override
  Future<int> removeSongsMissingFrom(Set<String> validPaths) {
    return _db.songDao.removeMissingFrom(validPaths);
  }

  @override
  Future<void> saveLyricsText({
    required int songId,
    required String text,
  }) {
    return (_db.update(_db.songs)..where((t) => t.id.equals(songId)))
        .write(SongsCompanion(lyricsText: Value(text)));
  }

  Future<int?> _resolveArtist(ScannedSong song) async {
    final name = song.artistName;
    if (name == null || name.isEmpty) {
      return null;
    }
    return _db.artistDao.insertIfMissing(name);
  }

  Future<int?> _resolveAlbum(ScannedSong song, int? artistId) async {
    final title = song.albumTitle;
    if (title == null || title.isEmpty) {
      return null;
    }
    final albumArtist = song.albumArtistName ?? song.artistName;
    return _db.albumDao.upsert(
      groupKey: '${_norm(title)}|${_norm(albumArtist)}',
      title: title,
      artistId: artistId,
      year: song.year,
      artworkPath: song.artworkPath,
    );
  }

  SongsCompanion _toCompanion(
    ScannedSong song,
    int? artistId,
    int? albumId,
  ) {
    return SongsCompanion.insert(
      path: song.path,
      sourceType: song.sourceType,
      title: song.title,
      fileName: song.fileName,
      format: song.format,
      durationMs: song.durationMs,
      fileSizeBytes: song.fileSizeBytes,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
      modifiedAtMs: song.modifiedAtMs,
      artistId: Value(artistId),
      albumId: Value(albumId),
      genre: Value(song.genre),
      sampleRate: Value(song.sampleRate),
      bitDepth: Value(song.bitDepth),
      channels: Value(song.channels),
      bitrateKbps: Value(song.bitrateKbps),
      trackNumber: Value(song.trackNumber),
      discNumber: Value(song.discNumber),
      year: Value(song.year),
      artworkPath: Value(song.artworkPath),
      lyricsPath: Value(song.lyricsPath),
      lyricsText: song.lyricsText == null
          ? const Value.absent()
          : Value(song.lyricsText),
      hasEmbeddedLyrics: Value(song.hasEmbeddedLyrics),
      searchText: Value(_buildSearchText(song)),
    );
  }

  static String _buildSearchText(ScannedSong song) {
    return [
      song.title,
      song.artistName,
      song.albumTitle,
      song.genre,
      song.fileName,
    ]
        .whereType<String>()
        .map((part) => part.toLowerCase())
        .join(' ');
  }

  static String _norm(String? value) =>
      (value ?? '').trim().toLowerCase();
}
