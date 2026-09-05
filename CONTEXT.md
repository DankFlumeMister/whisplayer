# Whisplayer

A local-first Android music player that also plays from self-hosted
Subsonic/Navidrome servers. Glossary terms below are the canonical names
used across the codebase and this project's docs.

## Playback

**Song**:
A playable track. Always has a unique `id` and a `path`; local songs use
file paths, remote songs use the encoded `subsonic://{serverId}/{songId}`
logical path.
_Avoid_: Track, file, media item

**Queue**:
The ordered list of Songs the player session is playing.
_Avoid_: Playlist, playlist (a Queue is a session concept; a Playlist is a
stored user collection)

**PlaybackSession**:
The restorable player state: queue ids, current index, position, loop mode
and shuffle flag. Persisted so a killed app can resume.
_Avoid_: Player state, now playing

**PlaybackSessionStore**:
The module that owns the PlaybackSession persistence keys and their string
encoding. Callers never touch key names or serialization.
_Avoid_: Settings helper, session repo

**PlaybackRecorder**:
The module that decides when a listen is recorded: on departure from a
song or on a completed listen, with loop-one wraps detected by a position
jump on the same track.
_Avoid_: Stats hook, analytics

**Listen record**:
One row stating that a Song was played: `songId`, `playedMs`,
`playedAtMs`, `completed`. Writing one updates both the song's stats and
the play-history in a single transaction.
_Avoid_: History entry (the entity is PlayHistoryEntry; a listen record is
the write-side concept)

**Completed listen**:
A listen whose departure position is within 3 seconds of the Song's
duration, or a full playthrough of a looping track.
_Avoid_: Finished play

**Loop wrap**:
The seamless replay of a song under loop-one mode, detected by the
playback position jumping backwards by more than 2 seconds on the same
track.
_Avoid_: Loop detection, replay

## Library

**Local source / Remote source**:
A Song's origin (`SourceType`). Local songs live on the device; remote
songs live on a Subsonic-compatible server and stream on demand.
_Avoid_: Online, streamed (a remote song may still be synced into the
local library table)

**Remote server**:
A configured Subsonic/Navidrome endpoint with stored credentials.
_Avoid_: Server profile, cloud account

**Subsonic path**:
The logical `subsonic://{serverId}/{songId}` string that identifies a
remote Song in the local library. Deliberately hand-parsed so song ids
keep their case.
_Avoid_: URI, stream URL (a stream URL is resolved later and carries auth)

## Tests

**Fake* repositories**:
In-memory test doubles shared from `test/helpers/fakes.dart`; one double
per interface, configured per test.
_Avoid_: Local per-file fakes (the pre-ADR duplication)
