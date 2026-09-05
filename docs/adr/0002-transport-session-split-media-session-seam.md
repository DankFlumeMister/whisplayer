# 0002: Separate transport ticks from session state; media session behind a seam

**Status**: accepted

The engine snapshot stream emits at position-tick frequency, but the
controller republished every tick into `PlayerUiState`, rebuilding the
whole player UI (backdrop, cover, progress, queue sheet) several times a
second while playing. We split the transport tick into a narrow
`playbackPositionProvider` (int milliseconds) that updates on every tick,
while `PlayerUiState` (queue/index/loop/shuffle/snapshot) now only changes
on transitions (state, playing, duration or queue index changes). In the
same round we put the audio_service adapter behind a `MediaSession`
interface (`publishNowPlaying` / `publishQueue` / `bindSession`), typed
`playerHandlerProvider` as `FutureProvider<MediaSession>`, and fixed the
previously never-assigned `SessionDelegate` wiring so system-media
next/previous actually reaches the controller.

## Considered options

- Engine exposes two streams (position vs events): rejected — the single
  snapshot stream already carries everything and the split belongs at the
  consumption boundary, not the producer.
- Keeping the concrete `WhisAudioHandler` in the controller: rejected —
  tests had to swallow audio_service bootstrap noise with a zone guard;
  with the seam they inject a `FakeMediaSession` and never touch the
  platform channel (`runGuarded` helper deleted).
- Dropping the 5-second persistence timer as a "churn patch": rejected —
  the cadence is load-bearing for kill-and-resume (a killed app resumes
  from the last persisted position); the timer stays, now sourcing its
  position from the position channel.

## Consequences

- Position-only ticks no longer rebuild session consumers; `_Backdrop`
  blur cache, cover, and progress rows stop churning at tick frequency.
- The 5s persistence cadence, restore semantics and recording policy are
  unchanged; lyrics now consume the position channel instead of a second
  engine subscription.
- System media next/previous commands work for the first time (the
  delegate was never wired before); the controller's defensive
  Exception/Error swallow around bootstrap stays (decision 2).
- Tests no longer need zone guards; new `playback_transition_test` locks
  the tick/transition contract (identical session state on position ticks,
  persistence cadence via the widget-test clock).
