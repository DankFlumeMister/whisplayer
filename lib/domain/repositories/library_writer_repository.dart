import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

abstract interface class LibraryWriterRepository {
  Future<List<ExistingSongInfo>> loadExistingSongs();

  Future<int> upsertScannedSong(ScannedSong song);

  /// Deletes songs of [sourceType] that [validPaths] no longer contains.
  ///
  /// Scoped to one source so a scan of one library can never delete the rows
  /// belonging to another.
  Future<int> removeSongsMissingFrom(
    Set<String> validPaths, {
    required SourceType sourceType,
  });

  /// Deletes **every** song of [sourceType], returning how many went away.
  ///
  /// Backs the deliberate "clear and rescan" action: when the import rules
  /// change, rows written by an older build can be wrong in ways an
  /// incremental scan cannot repair — their paths simply do not match
  /// anything the new scan produces, so they survive as duplicates. Wiping the
  /// source first is the only way to be certain. Other sources are untouched.
  Future<int> removeAllOfSource(SourceType sourceType);

  Future<void> saveLyricsText({
    required int songId,
    required String text,
  });

  /// Records a duration the player probed from the stream.
  ///
  /// WebDAV files carry no embedded tags, so their duration stays 0 until the
  /// engine reports the real value; writing it back makes the progress bar
  /// work on every later play. Callers must pass a positive [durationMs] and
  /// only for songs that are still at 0.
  Future<void> setSongDuration({
    required int songId,
    required int durationMs,
  });
}
