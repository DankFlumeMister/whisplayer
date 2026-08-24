import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/play_history_entry.dart';
import 'package:whisplayer/domain/entities/playlist.dart';
import 'package:whisplayer/domain/entities/song.dart';

extension SongRowX on SongRow {
  Song toEntity({String? artistName, String? albumTitle}) {
    return Song(
      id: id,
      path: path,
      sourceType: sourceType,
      title: title,
      fileName: fileName,
      format: format,
      durationMs: durationMs,
      fileSizeBytes: fileSizeBytes,
      addedAtMs: addedAtMs,
      modifiedAtMs: modifiedAtMs,
      playCount: playCount,
      skipCount: skipCount,
      totalPlayMs: totalPlayMs,
      lastPositionMs: lastPositionMs,
      isFavorite: isFavorite,
      artistId: artistId,
      albumId: albumId,
      genre: genre,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      channels: channels,
      bitrateKbps: bitrateKbps,
      trackNumber: trackNumber,
      discNumber: discNumber,
      year: year,
      artworkPath: artworkPath,
      lyricsPath: lyricsPath,
      lyricsText: lyricsText,
      hasEmbeddedLyrics: hasEmbeddedLyrics,
      lastPlayedAtMs: lastPlayedAtMs,
      artistName: artistName,
      albumTitle: albumTitle,
    );
  }
}

extension AlbumRowX on AlbumRow {
  Album toEntity({
    required int songCount,
    String? artistName,
  }) {
    return Album(
      id: id,
      title: title,
      groupKey: groupKey,
      songCount: songCount,
      artistId: artistId,
      artistName: artistName,
      year: year,
      artworkPath: artworkPath,
    );
  }
}

extension ArtistRowX on ArtistRow {
  Artist toEntity({
    required int songCount,
    required int albumCount,
  }) {
    return Artist(
      id: id,
      name: name,
      songCount: songCount,
      albumCount: albumCount,
    );
  }
}

extension PlaylistRowX on PlaylistRow {
  Playlist toEntity({required int songCount}) {
    return Playlist(
      id: id,
      name: name,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs,
      songCount: songCount,
    );
  }
}

extension PlayHistoryRowX on PlayHistoryRow {
  PlayHistoryEntry toEntity(Song song) {
    return PlayHistoryEntry(
      id: id,
      songId: songId,
      playedAtMs: playedAtMs,
      playedMs: playedMs,
      completed: completed,
      song: song,
    );
  }
}
