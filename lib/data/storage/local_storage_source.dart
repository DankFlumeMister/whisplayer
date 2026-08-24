import 'dart:io';
import 'dart:isolate';

import 'package:whisplayer/domain/entities/audio_formats.dart';
import 'package:whisplayer/domain/entities/storage_entry.dart';
import 'package:whisplayer/domain/repositories/storage_source.dart';

class LocalStorageSource implements StorageSource {
  const LocalStorageSource();

  @override
  Future<List<StorageEntry>> listAudioFiles(
    String rootPath,
    Set<String> excludedPaths,
  ) {
    return Isolate.run(
      () => _walk(rootPath, _normalizePrefixes(excludedPaths)),
    );
  }
}

Set<String> _normalizePrefixes(Set<String> paths) {
  return paths
      .map((p) => p.replaceAll('/', Platform.pathSeparator))
      .map((p) => p.endsWith(Platform.pathSeparator) ? p : '$p/')
      .toSet();
}

bool _isExcluded(String path, Set<String> prefixes) {
  final normalized = path.replaceAll('/', Platform.pathSeparator);
  for (final prefix in prefixes) {
    if (normalized.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

List<StorageEntry> _walk(String rootPath, Set<String> excludedPrefixes) {
  final result = <StorageEntry>[];
  final root = Directory(rootPath);
  if (!root.existsSync()) {
    return result;
  }

  final stack = <Directory>[root];
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } on FileSystemException catch (_) {
      continue;
    }

    for (final entity in children) {
      if (entity is Directory) {
        if (!_isExcluded(entity.path, excludedPrefixes)) {
          stack.add(entity);
        }
        continue;
      }
      if (entity is! File || !AudioFormats.isSupported(entity.path)) {
        continue;
      }
      try {
        final stat = entity.statSync();
        result.add(
          StorageEntry(
            path: entity.path,
            sizeBytes: stat.size,
            modifiedAtMs: stat.modified.millisecondsSinceEpoch,
          ),
        );
      } on FileSystemException catch (_) {
        // File vanished or is unreadable mid-scan; skip it.
      }
    }
  }

  return result;
}
