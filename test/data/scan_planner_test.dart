import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/application/scanner/scan_planner.dart';
import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/storage_entry.dart';

void main() {
  const planner = ScanPlanner();

  StorageEntry entry(String path, {int size = 10, int mtime = 100}) =>
      StorageEntry(path: path, sizeBytes: size, modifiedAtMs: mtime);

  ExistingSongInfo existing(
    String path, {
    int id = 1,
    int size = 10,
    int mtime = 100,
  }) =>
      ExistingSongInfo(
        songId: id,
        path: path,
        sizeBytes: size,
        modifiedAtMs: mtime,
      );

  test('new files are queued for parsing', () {
    final plan = planner.plan(
      foundEntries: [entry('/a.flac'), entry('/b.flac')],
      existingSongs: [],
    );
    expect(plan.toParse, hasLength(2));
    expect(plan.unchangedCount, 0);
    expect(plan.stalePaths, isEmpty);
  });

  test('unchanged files are skipped incrementally', () {
    final plan = planner.plan(
      foundEntries: [entry('/a.flac', size: 5, mtime: 9)],
      existingSongs: [existing('/a.flac', id: 7, size: 5, mtime: 9)],
    );
    expect(plan.toParse, isEmpty);
    expect(plan.unchangedCount, 1);
    expect(plan.stalePaths, isEmpty);
  });

  test('changed size or mtime triggers re-parse', () {
    final plan = planner.plan(
      foundEntries: [
        entry('/a.flac', size: 6, mtime: 9),
        entry('/b.flac', size: 5, mtime: 11),
      ],
      existingSongs: [
        existing('/a.flac', size: 5, mtime: 9),
        existing('/b.flac', size: 5, mtime: 9),
      ],
    );
    expect(plan.toParse.map((e) => e.path), ['/a.flac', '/b.flac']);
  });

  test('missing files become stale paths for cleanup', () {
    final plan = planner.plan(
      foundEntries: [entry('/kept.flac')],
      existingSongs: [
        existing('/kept.flac'),
        existing('/gone.flac', id: 2),
      ],
    );
    expect(plan.toParse, isEmpty);
    expect(plan.unchangedCount, 1);
    expect(plan.stalePaths, ['/gone.flac']);
  });

  test('duplicate paths across roots are parsed once', () {
    final plan = planner.plan(
      foundEntries: [
        entry('/m/a.mp3'),
        entry('/m2/a.mp3'),
        entry('/m/a.mp3'),
      ],
      existingSongs: [],
    );
    expect(plan.toParse, hasLength(2));
    expect(plan.toParse.map((e) => e.path).toSet(), hasLength(2));
  });
}
