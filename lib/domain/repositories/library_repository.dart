import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

abstract interface class LibraryRepository {
  /// All songs regardless of source (queue restore, stats, history).
  Stream<List<Song>> watchSongs({SongSort sort, bool descending});

  /// Songs from this device only, for the local library browsing views.
  Stream<List<Song>> watchLocalSongs({SongSort sort, bool descending});

  Future<List<Song>> getAllSongs();

  Future<Song?> getSong(int songId);

  Future<List<Song>> songsByAlbum(int albumId);

  Future<List<Song>> songsByArtist(int artistId);

  /// Full-text search restricted to songs stored on this device.
  Future<List<Song>> searchLocalSongs(String query);

  /// Albums holding at least one song of [sourceType].
  ///
  /// Passing `null` means "any source", not "local" — the local library view
  /// and the cloud view pass their own source explicitly so neither can
  /// silently inherit the other's scope.
  Stream<List<Album>> watchAlbums({SourceType? sourceType});

  /// Artists with at least one locally stored song.
  Stream<List<Artist>> watchArtists();

  Future<void> setFavorite(int songId, {required bool favorite});
}
