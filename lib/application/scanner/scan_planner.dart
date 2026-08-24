import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/storage_entry.dart';

class ScanPlan {
  const ScanPlan({
    required this.toParse,
    required this.unchangedCount,
    required this.stalePaths,
  });

  final List<StorageEntry> toParse;
  final int unchangedCount;
  final List<String> stalePaths;
}

class ScanPlanner {
  const ScanPlanner();

  ScanPlan plan({
    required List<StorageEntry> foundEntries,
    required List<ExistingSongInfo> existingSongs,
  }) {
    final byPath = {
      for (final song in existingSongs) song.path: song,
    };
    final seen = <String>{};
    final toParse = <StorageEntry>[];
    var unchanged = 0;

    for (final entry in foundEntries) {
      if (!seen.add(entry.path)) {
        continue;
      }
      final current = byPath[entry.path];
      final isChanged = current == null ||
          current.sizeBytes != entry.sizeBytes ||
          current.modifiedAtMs != entry.modifiedAtMs;
      if (isChanged) {
        toParse.add(entry);
      } else {
        unchanged++;
      }
    }

    final foundPaths = seen;
    final stalePaths = [
      for (final song in existingSongs)
        if (!foundPaths.contains(song.path)) song.path,
    ];

    return ScanPlan(
      toParse: toParse,
      unchangedCount: unchanged,
      stalePaths: stalePaths,
    );
  }
}
