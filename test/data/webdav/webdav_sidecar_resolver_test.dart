import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/data/webdav/webdav_sidecar_resolver.dart';
import 'package:whisplayer/data/webdav/webdav_storage_source.dart';

class _FakeLister implements WebDavLister {
  _FakeLister(this.tree);

  final Map<String, List<WebDavEntry>> tree;

  @override
  Future<List<WebDavEntry>> list(String path, {int depth = 1}) async {
    return tree[path] ?? const <WebDavEntry>[];
  }
}

WebDavEntry _file(String path) => WebDavEntry(
      path: path,
      name: path.substring(path.lastIndexOf('/') + 1),
      isDirectory: false,
      sizeBytes: 100,
    );

Map<String, List<WebDavEntry>> _tree() => <String, List<WebDavEntry>>{
      '/': <WebDavEntry>[_file('/a.mp3'), _file('/a.lrc')],
    };

void main() {
  group('WebDavSidecarLyricsResolver', () {
    test('returns null and never touches the network without a sidecar',
        () async {
      var requests = 0;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((_) async {
          requests++;
          return http.Response('lyrics', 200);
        }),
      );
      final source = WebDavStorageSource(
        lister: _FakeLister(const <String, List<WebDavEntry>>{}),
        pathPrefix: 'webdav://1',
      );
      final resolver = WebDavSidecarLyricsResolver(
        client: client,
        source: source,
      );

      await source.listAudioFiles('/', const <String>{});
      final text = await resolver.lyricsFor('webdav://1/b.mp3');

      expect(text, isNull);
      expect(requests, 0);
    });

    test('downloads the sidecar body found by the walk', () async {
      late Uri requested;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((http.Request request) async {
          requested = request.url;
          return http.Response.bytes(
            utf8.encode('[00:01.00] 行'),
            200,
          );
        }),
      );
      final source = WebDavStorageSource(
        lister: _FakeLister(_tree()),
        pathPrefix: 'webdav://1',
      );
      final resolver = WebDavSidecarLyricsResolver(
        client: client,
        source: source,
      );

      await source.listAudioFiles('/', const <String>{});
      final text = await resolver.lyricsFor('webdav://1/a.mp3');

      expect(text, '[00:01.00] 行');
      // The client must receive the server-relative path, not the
      // library-wide `webdav://1` key.
      expect(requested.path, '/a.lrc');
    });

    test('resolves a two-extension sidecar through the client', () async {
      late Uri requested;
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient((http.Request request) async {
          requested = request.url;
          return http.Response.bytes(utf8.encode('[00:01.00] 行'), 200);
        }),
      );
      final tree = <String, List<WebDavEntry>>{
        '/': <WebDavEntry>[
          _file('/a.mp3'),
          _file('/a.mp3.vtt'),
        ],
      };
      final source = WebDavStorageSource(
        lister: _FakeLister(tree),
        pathPrefix: 'webdav://1',
      );
      final resolver = WebDavSidecarLyricsResolver(
        client: client,
        source: source,
      );

      await source.listAudioFiles('/', const <String>{});
      final text = await resolver.lyricsFor('webdav://1/a.mp3');

      expect(text, '[00:01.00] 行');
      expect(requested.path, '/a.mp3.vtt');
    });

    test('propagates client failures for the reader to swallow', () async {
      final client = WebDavClient(
        baseUrl: 'http://nas.local:8765',
        token: 'tok',
        client: MockClient(
          (_) async => throw http.ClientException('host down'),
        ),
      );
      final source = WebDavStorageSource(
        lister: _FakeLister(_tree()),
        pathPrefix: 'webdav://1',
      );
      final resolver = WebDavSidecarLyricsResolver(
        client: client,
        source: source,
      );

      await source.listAudioFiles('/', const <String>{});
      await expectLater(
        resolver.lyricsFor('webdav://1/a.mp3'),
        throwsA(isA<WebDavException>()),
      );
    });
  });
}
