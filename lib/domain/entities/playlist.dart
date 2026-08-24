import 'package:whisplayer/domain/entities/song.dart';

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.songCount,
  });

  final int id;
  final String name;
  final int createdAtMs;
  final int updatedAtMs;
  final int songCount;
}

class PlaylistEntry {
  const PlaylistEntry({
    required this.entryId,
    required this.position,
    required this.song,
  });

  final int entryId;
  final int position;
  final Song song;
}
