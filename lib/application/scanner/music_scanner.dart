import 'dart:async';

import 'package:whisplayer/application/scanner/scan_planner.dart';
import 'package:whisplayer/domain/entities/scan_progress.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/entities/storage_entry.dart';
import 'package:whisplayer/domain/repositories/library_writer_repository.dart';
import 'package:whisplayer/domain/repositories/metadata_reader.dart';
import 'package:whisplayer/domain/repositories/storage_source.dart';

class MusicScanner {
  /// Creates a scanner for one source.
  ///
  /// [sourceType] scopes the end-of-scan cleanup: only rows of that source
  /// are eligible for deletion, so scanning a WebDAV share can never remove
  /// the local library and vice versa.
  MusicScanner({
    required StorageSource storageSource,
    required MetadataReader metadataReader,
    required LibraryWriterRepository writerRepository,
    this.sourceType = SourceType.local,
  })  : _storage = storageSource,
        _reader = metadataReader,
        _writer = writerRepository;

  final StorageSource _storage;
  final MetadataReader _reader;
  final LibraryWriterRepository _writer;

  /// Which `songs` rows this scan owns.
  final SourceType sourceType;

  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  Stream<ScanProgress> scan({
    required List<String> includeDirs,
    Set<String> excludeDirs = const {},
  }) async* {
    _cancelled = false;

    yield const ScanProgress(phase: ScanPhase.walking);

    final found = <StorageEntry>[];
    var walkFailed = false;
    for (final dir in includeDirs) {
      if (_cancelled) {
        return;
      }
      try {
        found.addAll(await _storage.listAudioFiles(dir, excludeDirs));
      } on Object catch (e) {
        walkFailed = true;
        yield ScanProgress(
          phase: ScanPhase.error,
          message: 'Failed to walk $dir: $e',
        );
      }
    }

    if (_cancelled) {
      return;
    }

    final existing = await _writer.loadExistingSongs();
    const planner = ScanPlanner();
    final plan = planner.plan(
      foundEntries: found,
      existingSongs: existing,
    );

    var added = 0;
    var failed = 0;
    var processed = 0;
    final total = plan.toParse.length;

    for (final entry in plan.toParse) {
      if (_cancelled) {
        return;
      }
      try {
        final song = await _reader.read(
          filePath: entry.path,
          sizeBytes: entry.sizeBytes,
          modifiedAtMs: entry.modifiedAtMs,
        );
        await _writer.upsertScannedSong(song);
        added++;
      } on Object catch (_) {
        failed++;
      }
      processed++;
      yield ScanProgress(
        phase: ScanPhase.parsing,
        processed: processed,
        total: total,
        currentFile: entry.path,
        addedCount: added,
        skippedCount: plan.unchangedCount,
        failedCount: failed,
      );
    }

    if (_cancelled) {
      return;
    }

    yield ScanProgress(
      phase: ScanPhase.cleanup,
      processed: total,
      total: total,
      addedCount: added,
      skippedCount: plan.unchangedCount,
      failedCount: failed,
    );

    final validPaths = {
      for (final entry in found) entry.path,
    };
    // A walk that failed anywhere reports an incomplete [found]. Deleting
    // "everything not seen" then would throw away songs that are merely
    // unreachable this run — an offline share would empty its whole source.
    // Tidiness is never worth that: skip the cleanup and keep the rows.
    final removed = walkFailed
        ? 0
        : await _writer.removeSongsMissingFrom(
            validPaths,
            sourceType: sourceType,
          );

    yield ScanProgress(
      phase: ScanPhase.done,
      processed: total,
      total: total,
      addedCount: added,
      updatedCount: plan.toParse.length - added - failed,
      skippedCount: plan.unchangedCount,
      removedCount: removed,
      failedCount: failed,
    );
  }
}
