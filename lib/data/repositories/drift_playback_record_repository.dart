import 'package:whisplayer/data/db/app_database.dart';
import 'package:whisplayer/domain/repositories/playback_record_repository.dart';

/// [PlaybackRecordRepository] backed by the song DAO's single-transaction
/// stats + history write.
class DriftPlaybackRecordRepository implements PlaybackRecordRepository {
  DriftPlaybackRecordRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  }) {
    return _db.songDao.recordPlayback(
      songId: songId,
      playedMs: playedMs,
      playedAtMs: playedAtMs,
      completed: completed,
    );
  }
}
