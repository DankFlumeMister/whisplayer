/// Write port for playback-listening records (one transaction updating the
/// song's stats and inserting a play-history row).
///
/// Split off LibraryRepository so the player side depends on a narrow
/// interface and library browsing does not carry recording semantics.
// ignore: one_member_abstracts - seam for test doubles; invented surface otherwise.
abstract interface class PlaybackRecordRepository {
  Future<void> recordPlayback({
    required int songId,
    required int playedMs,
    required int playedAtMs,
    required bool completed,
  });
}
