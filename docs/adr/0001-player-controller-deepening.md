# 0001: Deepen PlayerController into session store, recorder and record port

**Status**: accepted

PlayerController had grown into a 600-line module mixing the queue state
machine, string-keyed persistence, playback-recording policy and
media-session publishing; every feature round landed there and every test
had to fake four dependencies. We split the persistence into
`PlaybackSessionStore` (owns the `playback.*` keys, JSON/enum encoding and
index clamping), the recording policy into `PlaybackRecorder` (departure,
completed-listen and loop-wrap semantics, frozen from the historic
implementation), and the recording write path into the narrow
`PlaybackRecordRepository` port implemented by the song DAO's single
transaction. In the same pass we deleted five zero-call interface methods
(`savePosition`, `getLastPlayedSong`, `searchSongs`,
`LibraryRepository.removeSongsMissingFrom`, `HistoryRepository.addPlayRecord`)
and their DAO counterparts (`SongDao.savePosition`,
`SongDao.getLastPlayedSong`, `HistoryDao.add`), consolidated the duplicated
per-file fakes into `test/helpers/fakes.dart`, and fixed the `runGuarded`
test helper to forward assertion failures instead of silently swallowing
them (its old behavior made the restore/record/shuffle suites
assertion-vacuous).

## Considered options

- Persistence as a separate Drift table: rejected — zero schema gain, the
  typed-store-over-settings pattern (BrowsePrefs) already exists and keeps
  stores unit-testable without a database.
- Recording write path moved into HistoryRepository: rejected — its
  `addPlayRecord` was dead and did not do the single-transaction stats
  update the handoff mandates ("不要改回分开写").
- Keeping PlayerController as-is: rejected — the interface would stay as
  wide as the implementation, keeping the fake-tax on every new feature.

## Consequences

- `LibraryRepository` shrinks from 13 to 10 methods; adding a method no
  longer forces 7 fake files to change in lockstep.
- New unit tests (`playback_session_store_test`, `playback_recorder_test`)
  cover the extracted modules without touching the audio stack.
- The restore/record/shuffle suites now fail on real assertion failures
  (runGuarded forwards TestFailure and ignores audio_service bootstrap
  noise), so "134 green" style baselines are trustworthy again.
- PlayerController keeps orchestration only; semantics were frozen, not
  changed (restore idempotency, no auto-play, 3s/2s thresholds,
  skip-before-index-update ordering, recorded-index dedupe).
