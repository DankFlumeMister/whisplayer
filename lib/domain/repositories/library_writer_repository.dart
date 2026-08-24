import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';

abstract interface class LibraryWriterRepository {
  Future<List<ExistingSongInfo>> loadExistingSongs();

  Future<int> upsertScannedSong(ScannedSong song);

  Future<int> removeSongsMissingFrom(Set<String> validPaths);

  Future<void> saveLyricsText({
    required int songId,
    required String text,
  });
}
