import 'package:audio_service/audio_service.dart';

/// The system media-session protocol the player controller publishes to.
///
/// The controller depends on this interface, not on audio_service:
/// production is one adapter (WhisAudioHandler), tests inject a fake, so
/// bootstrap failures never reach playback code and tests never touch the
/// platform channel.
abstract interface class MediaSession {
  /// Wires the session's next/previous commands back to the controller.
  void bindSession(SessionDelegate delegate);

  void publishNowPlaying(MediaItem? item);

  void publishQueue(List<MediaItem> items);
}

/// Commands the system media session can issue to the player.
abstract interface class SessionDelegate {
  Future<void> onNext();

  Future<void> onPrevious();
}
