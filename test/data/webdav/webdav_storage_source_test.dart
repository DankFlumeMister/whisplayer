import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/data/webdav/webdav_storage_source.dart';
import 'package:whisplayer/domain/entities/storage_entry.dart';

/// A fake remote tree. Keys are directory paths as [WebDavClient] reports
/// them — no trailing slash.
class _FakeLister implements WebDavLister {
  _FakeLister(this.tree, {this.failOn = const <String>{}});

  final Map<String, List<WebDavEntry>> tree;
  final Set<String> failOn;
  final List<String> visited = <String>[];

  @override
  Future<List<WebDavEntry>> list(String path, {int depth = 1}) async {
    visited.add(path);
    if (failOn.contains(path)) {
      throw WebDavException('boom: $path');
    }
    return tree[path] ?? const <WebDavEntry>[];
  }
}

WebDavEntry _dir(String path) =>
    WebDavEntry(path: path, name: _name(path), isDirectory: true);

WebDavEntry _file(
  String path, {
  int size = 1000,
  DateTime? modified,
}) =>
    WebDavEntry(
      path: path,
      name: _name(path),
      isDirectory: false,
      sizeBytes: size,
      modifiedAt: modified,
    );

String _name(String path) => path.substring(path.lastIndexOf('/') + 1);

final DateTime kModified = DateTime.utc(2026, 8, 5, 14, 20, 41);

Map<String, List<WebDavEntry>> _tree() => <String, List<WebDavEntry>>{
      '/': <WebDavEntry>[
        _dir('/RJ01008335'),
        _dir('/RJ01003442'),
        _file('/readme.txt', size: 12),
      ],
      '/RJ01008335': <WebDavEntry>[
        _dir('/RJ01008335/01_wav'),
        _dir('/RJ01008335/02_mp3'),
        _file('/RJ01008335/cover.jpg', size: 999),
      ],
      '/RJ01008335/01_wav': <WebDavEntry>[
        _file('/RJ01008335/01_wav/a.wav', size: 11, modified: kModified),
        _file('/RJ01008335/01_wav/b.wav', size: 22),
      ],
      '/RJ01008335/02_mp3': <WebDavEntry>[
        _file('/RJ01008335/02_mp3/a.mp3', size: 33),
        _file('/RJ01008335/02_mp3/b.mp3', size: 44),
      ],
      '/RJ01003442': <WebDavEntry>[
        _file('/RJ01003442/c.flac', size: 55),
      ],
    };

void main() {
  group('WebDavStorageSource', () {
    test('walks every level and keeps only audio files', () async {
      final lister = _FakeLister(_tree());
      final source = WebDavStorageSource(
        lister: lister,
        pathPrefix: 'webdav://1',
      );

      final entries = await source.listAudioFiles('/', const <String>{});

      expect(
        entries.map((StorageEntry e) => e.path).toList()..sort(),
        <String>[
          'webdav://1/RJ01003442/c.flac',
          'webdav://1/RJ01008335/01_wav/a.wav',
          'webdav://1/RJ01008335/01_wav/b.wav',
          'webdav://1/RJ01008335/02_mp3/a.mp3',
          'webdav://1/RJ01008335/02_mp3/b.mp3',
        ],
      );
    });

    test('carries size and modification time through', () async {
      final source = WebDavStorageSource(
        lister: _FakeLister(_tree()),
        pathPrefix: 'webdav://1',
      );

      final entries = await source.listAudioFiles('/', const <String>{});
      final a = entries.firstWhere(
        (StorageEntry e) => e.path.endsWith('/01_wav/a.wav'),
      );

      expect(a.sizeBytes, 11);
      expect(
        a.modifiedAtMs,
        kModified.millisecondsSinceEpoch,
      );
    });

    test('skips excluded directories', () async {
      final lister = _FakeLister(_tree());
      final source = WebDavStorageSource(
        lister: lister,
        pathPrefix: 'webdav://1',
      );

      final entries = await source.listAudioFiles(
        '/',
        <String>{'/RJ01008335/02_mp3'},
      );

      expect(entries, hasLength(3));
      expect(
        lister.visited,
        isNot(contains('/RJ01008335/02_mp3')),
      );
    });

    test('a failing directory is skipped, not fatal', () async {
      final failures = <String>[];
      final source = WebDavStorageSource(
        lister: _FakeLister(_tree(), failOn: <String>{'/RJ01008335/01_wav'}),
        pathPrefix: 'webdav://1',
        onError: (String path, Object _) => failures.add(path),
      );

      final entries = await source.listAudioFiles('/', const <String>{});

      expect(entries, hasLength(3));
      expect(failures, <String>['/RJ01008335/01_wav']);
    });

    test('maxDepth stops the descent', () async {
      final source = WebDavStorageSource(
        lister: _FakeLister(_tree()),
        pathPrefix: 'webdav://1',
        maxDepth: 2,
      );

      final entries = await source.listAudioFiles('/', const <String>{});

      // Only /RJ01003442/c.flac lives at depth 2; the wav/mp3 files are
      // one level deeper.
      expect(
        entries.map((StorageEntry e) => e.path),
        <String>['webdav://1/RJ01003442/c.flac'],
      );
    });

    test('a rooted walk starts below the library root', () async {
      final lister = _FakeLister(_tree());
      final source = WebDavStorageSource(
        lister: lister,
        pathPrefix: 'webdav://1',
      );

      final entries =
          await source.listAudioFiles('/RJ01003442', const <String>{});

      expect(
        entries.map((StorageEntry e) => e.path),
        <String>['webdav://1/RJ01003442/c.flac'],
      );
      expect(lister.visited, isNot(contains('/RJ01008335')));
    });

    test('emits nothing when the root is missing', () async {
      final source = WebDavStorageSource(
        lister: _FakeLister(const <String, List<WebDavEntry>>{}),
        pathPrefix: 'webdav://1',
      );

      await expectLater(
        source.listAudioFiles('/nope', const <String>{}),
        completion(isEmpty),
      );
    });

    test('indexes sibling sidecars next to audio files', () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!
        ..add(_file('/RJ01008335/02_mp3/a.lrc'))
        ..add(_file('/RJ01008335/02_mp3/a.vtt'))
        ..add(_file('/RJ01008335/02_mp3/a.srt'))
        ..add(_file('/RJ01008335/02_mp3/b.lrc'));
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      // `a` has three sidecars — `.lrc` wins over `.vtt` and `.srt`.
      expect(source.sidecarPaths, <String, String>{
        'webdav://1/RJ01008335/02_mp3/a.mp3':
            'webdav://1/RJ01008335/02_mp3/a.lrc',
        'webdav://1/RJ01008335/02_mp3/b.mp3':
            'webdav://1/RJ01008335/02_mp3/b.lrc',
      });
    });

    test('gives a shared sidecar to every format of the same base', () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!
        ..add(_file('/RJ01008335/02_mp3/a.flac'))
        ..add(_file('/RJ01008335/02_mp3/a.lrc'));
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      expect(source.sidecarPaths, <String, String>{
        'webdav://1/RJ01008335/02_mp3/a.mp3':
            'webdav://1/RJ01008335/02_mp3/a.lrc',
        'webdav://1/RJ01008335/02_mp3/a.flac':
            'webdav://1/RJ01008335/02_mp3/a.lrc',
      });
    });

    test('ignores sidecars without a matching audio file', () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!.add(
        _file('/RJ01008335/02_mp3/orphan.lrc'),
      );
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      expect(source.sidecarPaths, isEmpty);
    });

    test('matches sidecar extensions case-insensitively', () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!.add(_file('/RJ01008335/02_mp3/a.LRC'));
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      expect(
        source.sidecarPaths['webdav://1/RJ01008335/02_mp3/a.mp3'],
        'webdav://1/RJ01008335/02_mp3/a.LRC',
      );
    });

    test(
      'indexes video-rip style sidecars named after the audio file',
      () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!
        ..add(_file('/RJ01008335/02_mp3/a.mp3.vtt'))
        ..add(_file('/RJ01008335/02_mp3/b.mp3.srt'));
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      expect(source.sidecarPaths, <String, String>{
        'webdav://1/RJ01008335/02_mp3/a.mp3':
            'webdav://1/RJ01008335/02_mp3/a.mp3.vtt',
        'webdav://1/RJ01008335/02_mp3/b.mp3':
            'webdav://1/RJ01008335/02_mp3/b.mp3.srt',
      });
    });

    test(
      'lets a plain .lrc beat a two-extension .vtt on the same audio',
      () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!
        ..add(_file('/RJ01008335/02_mp3/a.lrc'))
        ..add(_file('/RJ01008335/02_mp3/a.mp3.vtt'));
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      expect(source.sidecarPaths, <String, String>{
        'webdav://1/RJ01008335/02_mp3/a.mp3':
            'webdav://1/RJ01008335/02_mp3/a.lrc',
      });
    });

    test('lets a two-extension .vtt beat a two-extension .srt', () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!
        ..add(_file('/RJ01008335/02_mp3/a.mp3.srt'))
        ..add(_file('/RJ01008335/02_mp3/a.mp3.vtt'));
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      expect(source.sidecarPaths, <String, String>{
        'webdav://1/RJ01008335/02_mp3/a.mp3':
            'webdav://1/RJ01008335/02_mp3/a.mp3.vtt',
      });
    });

    test('ignores a two-extension sidecar without its audio file', () async {
      final tree = _tree();
      tree['/RJ01008335/02_mp3']!.add(
        _file('/RJ01008335/02_mp3/missing.mp3.vtt'),
      );
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});

      expect(source.sidecarPaths, isEmpty);
    });

    test('resets the index when a later walk finds no sidecars', () async {
      final tree = _tree();
      final mp3 = tree['/RJ01008335/02_mp3']!
        ..add(_file('/RJ01008335/02_mp3/a.lrc'));
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );

      await source.listAudioFiles('/', const <String>{});
      expect(source.sidecarPaths, isNotEmpty);

      mp3.removeWhere((WebDavEntry e) => e.path.endsWith('.lrc'));
      await source.listAudioFiles('/', const <String>{});

      expect(source.sidecarPaths, isEmpty);
    });
  });
}
