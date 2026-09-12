import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/domain/entities/cloud_directory.dart';

/// Paths shaped exactly like the ones a WebDAV scan writes:
/// `webdav://{serverId}/{share-relative path}`.
const _root = 'webdav://1';

void main() {
  group('directoriesUnder', () {
    test('returns nothing for an empty share', () {
      expect(directoriesUnder(const [], parentPath: _root), isEmpty);
    });

    test('lists only the immediate children of the parent', () {
      final dirs = directoriesUnder(
        const [
          '$_root/RJ1/02_mp3/01_a.mp3',
          '$_root/RJ2/01_b.mp3',
          '$_root/RJ1/02_mp3/03_c.mp3',
        ],
        parentPath: _root,
      );

      expect(dirs.map((d) => d.name), ['RJ1', 'RJ2']);
      expect(dirs.map((d) => d.path), ['$_root/RJ1', '$_root/RJ2']);
    });

    test('counts songs directly inside a directory', () {
      final dirs = directoriesUnder(
        const [
          '$_root/RJ1/01_a.mp3',
          '$_root/RJ1/02_b.mp3',
          // Nested, so it must not count towards RJ1's direct total.
          '$_root/RJ1/02_mp3/03_c.mp3',
        ],
        parentPath: _root,
      );

      expect(dirs.single.songCount, 2);
    });

    test('totalSongCount reaches into nested directories', () {
      final dirs = directoriesUnder(
        const [
          '$_root/RJ1/01_a.mp3',
          '$_root/RJ1/02_mp3/03_c.mp3',
          '$_root/RJ1/02_mp3/04_d.mp3',
          '$_root/RJ1/イラスト/cover.jpg',
        ],
        parentPath: _root,
      );

      final rj1 = dirs.single;
      expect(rj1.songCount, 1, reason: 'only 01_a.mp3 sits at the top');
      expect(rj1.totalSongCount, 4);
    });

    test('counts immediate sub-directories', () {
      final dirs = directoriesUnder(
        const [
          '$_root/RJ1/02_mp3/a.mp3',
          '$_root/RJ1/イラスト/b.jpg',
          '$_root/RJ1/台本/c.txt',
        ],
        parentPath: _root,
      );

      expect(dirs.single.subDirectoryCount, 3);
      expect(dirs.single.songCount, 0);
    });

    test('keeps a directory that holds only sub-directories', () {
      // No song sits directly in RJ1, but it must still be listed.
      final dirs = directoriesUnder(
        const ['$_root/RJ1/02_mp3/a.mp3'],
        parentPath: _root,
      );

      expect(dirs.map((d) => d.name), ['RJ1']);
    });

    test('ignores files sitting directly in the parent', () {
      final dirs = directoriesUnder(
        const [
          '$_root/loose.mp3',
          '$_root/RJ1/a.mp3',
        ],
        parentPath: _root,
      );

      expect(dirs.map((d) => d.name), ['RJ1']);
    });

    test('sorts naturally, so 02 precedes 10', () {
      final dirs = directoriesUnder(
        const [
          '$_root/10_extra/a.mp3',
          '$_root/02_mp3/a.mp3',
          '$_root/01_flac/a.mp3',
        ],
        parentPath: _root,
      );

      expect(dirs.map((d) => d.name), ['01_flac', '02_mp3', '10_extra']);
    });

    test('does not leak another server into the listing', () {
      final dirs = directoriesUnder(
        const [
          '$_root/RJ1/a.mp3',
          'webdav://10/RJ9/a.mp3',
        ],
        parentPath: _root,
      );

      expect(dirs.map((d) => d.name), ['RJ1']);
    });

    test('drills into a nested parent', () {
      final dirs = directoriesUnder(
        const [
          '$_root/RJ1/02_mp3/01_a.mp3',
          '$_root/RJ1/02_mp3/01_b.mp3',
          '$_root/RJ1/イラスト/cover.jpg',
          '$_root/RJ2/01_c.mp3',
        ],
        parentPath: '$_root/RJ1',
      );

      expect(dirs.map((d) => d.name), ['02_mp3', 'イラスト']);
      expect(dirs.first.songCount, 2);
      expect(dirs.first.totalSongCount, 2);
    });

    test('handles names containing % and _ literally', () {
      final dirs = directoriesUnder(
        const [
          '$_root/100%_mix/a.mp3',
          '$_root/other/b.mp3',
        ],
        parentPath: _root,
      );

      expect(dirs.map((d) => d.name), ['100%_mix', 'other']);
    });
  });

  group('directoryNameOf', () {
    test('returns the final segment', () {
      expect(directoryNameOf('webdav://1/RJ1/02_mp3'), '02_mp3');
    });

    test('ignores a trailing slash', () {
      expect(directoryNameOf('webdav://1/RJ1/'), 'RJ1');
    });

    test('falls back to a slash for the root', () {
      expect(directoryNameOf(''), '/');
      expect(directoryNameOf('/'), '/');
    });
  });
}
