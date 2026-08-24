import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:whisplayer/application/scanner/music_scanner.dart';
import 'package:whisplayer/core/providers/database_provider.dart';
import 'package:whisplayer/data/metadata/isolate_metadata_reader.dart';
import 'package:whisplayer/data/repositories/drift_library_writer_repository.dart';
import 'package:whisplayer/data/storage/local_storage_source.dart';
import 'package:whisplayer/domain/repositories/library_writer_repository.dart';
import 'package:whisplayer/domain/repositories/metadata_reader.dart';
import 'package:whisplayer/domain/repositories/storage_source.dart';

final storageSourceProvider = Provider<StorageSource>((ref) {
  return const LocalStorageSource();
});

final libraryWriterRepositoryProvider =
    Provider<LibraryWriterRepository>((ref) {
  return DriftLibraryWriterRepository(ref.watch(appDatabaseProvider));
});

final coversDirectoryProvider = FutureProvider<String>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}${Platform.pathSeparator}covers');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir.path;
});

final metadataReaderProvider = FutureProvider<MetadataReader>((ref) async {
  return IsolateMetadataReader(
    coversDirectory: await ref.watch(coversDirectoryProvider.future),
  );
});

final musicScannerProvider = FutureProvider<MusicScanner>((ref) async {
  return MusicScanner(
    storageSource: ref.watch(storageSourceProvider),
    metadataReader: await ref.watch(metadataReaderProvider.future),
    writerRepository: ref.watch(libraryWriterRepositoryProvider),
  );
});
