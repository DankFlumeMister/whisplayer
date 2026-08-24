import 'package:whisplayer/domain/entities/song.dart';

class PlayHistoryEntry {
  const PlayHistoryEntry({
    required this.id,
    required this.songId,
    required this.playedAtMs,
    required this.playedMs,
    required this.completed,
    required this.song,
  });

  final int id;
  final int songId;
  final int playedAtMs;
  final int playedMs;
  final bool completed;
  final Song song;
}
