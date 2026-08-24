import 'package:whisplayer/domain/entities/scanned_song.dart';

// Kept as an interface so SMB or cache-backed readers can be swapped in.
// ignore: one_member_abstracts
abstract interface class MetadataReader {
  Future<ScannedSong> read({
    required String filePath,
    required int sizeBytes,
    required int modifiedAtMs,
  });
}
