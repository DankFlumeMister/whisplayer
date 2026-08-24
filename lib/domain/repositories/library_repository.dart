import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/song.dart';

abstract interface class LibraryRepository {
  /// All songs regardless of source (queue restore, stats, history).
  Stream<List<Song>> watchSongs({SongSort sort, bool descending});

  /// Songs from this device only, for the local library browsing views.
  Stream<List<Song>> watchLocalSongs({SongSort sort, bool descending});

  Future<List<Song>> getAllSongs();

  Future<Song?> getSong(int songId);

  Future<Song?> getLastPlayedSong();

  Future<List<Song>> songsByAlbum(int albumId);

  Future<List<Song>> songsByArtist(int artistId);

  Future<List<Song>> searchSongs(String query);

  /// Full-text search restricted to songs stored on this device.
  Future<List<Song>> searchLocalSongs(String query);

  /// Albums with at least one locally stored song.
  Stream<List<Album>> watchAlbums();

  /// Artists with at least one locally stored song.
  Stream<List<Artist>> watchArtists();

  Future<void> setFavorite(int songId, {required bool favorite});

  Future<void> savePosition({
    required int songId,
    required int positionMs,
  });

  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  });

  Future<int> removeSongsMissingFrom(Set<String> validPaths);
}
