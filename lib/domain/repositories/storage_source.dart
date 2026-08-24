import 'package:whisplayer/domain/entities/storage_entry.dart';

// Kept as an interface so the SMB source can share the scanner pipeline.
// ignore: one_member_abstracts
abstract interface class StorageSource {
  Future<List<StorageEntry>> listAudioFiles(
    String rootPath,
    Set<String> excludedPaths,
  );
}
