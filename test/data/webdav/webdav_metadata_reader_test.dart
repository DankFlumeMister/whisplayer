import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/data/webdav/webdav_metadata_reader.dart';
import 'package:whisplayer/domain/entities/source_type.dart';

class _FakeCovers implements WebDavCoverResolver {
  _FakeCovers({this.path, this.throws = false});

  final String? path;
  final bool throws;
  final List<String> asked = <String>[];

  @override
  Future<String?> coverFor(String relativePath) async {
    asked.add(relativePath);
    if (throws) {
      throw StateError('cover backend down');
    }
    return path;
  }
}

class _FakeLyrics implements WebDavLyricsResolver {
  _FakeLyrics({this.text, this.throws = false});

  final String? text;
  final bool throws;
  final List<String> asked = <String>[];

  @override
  Future<String?> lyricsFor(String filePath) async {
    asked.add(filePath);
    if (throws) {
      throw StateError('sidecar backend down');
    }
    return text;
  }
}

void main() {
  group('WebDavMetadataReader', () {
    test('derives title, format and work from the path', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: 'webdav://1/RJ01008335/02_mp3/01_はじめまして.mp3',
        sizeBytes: 23294284,
        modifiedAtMs: 1785936474000,
      );

      expect(song.sourceType, SourceType.webdav);
      expect(song.title, '01_はじめまして');
      expect(song.fileName, '01_はじめまして.mp3');
      expect(song.format, 'mp3');
      expect(song.albumTitle, 'RJ01008335');
      expect(song.trackNumber, 1);
      expect(song.fileSizeBytes, 23294284);
      expect(song.modifiedAtMs, 1785936474000);
    });

    test('duration stays 0 until playback backfills it', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: 'webdav://1/RJ/a.wav',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.durationMs, 0);
    });

    test('a file at the share root has no work', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: 'webdav://1/loose.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.albumTitle, isNull);
    });

    test('a name without a numeric prefix has no track number', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: 'webdav://1/RJ/はじめまして.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.trackNumber, isNull);
    });

    test('a name without an extension keeps the whole title', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: 'webdav://1/RJ/noext',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.title, 'noext');
      expect(song.format, isEmpty);
    });

    test('attaches the resolved cover', () async {
      final covers = _FakeCovers(path: '/cache/cover.jpg');
      final reader = WebDavMetadataReader(coverResolver: covers);

      final song = await reader.read(
        filePath: 'webdav://1/RJ01008335/02_mp3/a.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.artworkPath, '/cache/cover.jpg');
      expect(covers.asked, <String>['/RJ01008335/02_mp3/a.mp3']);
    });

    test('a failing cover resolver yields null instead of throwing',
        () async {
      final reader = WebDavMetadataReader(
        coverResolver: _FakeCovers(throws: true),
      );

      final song = await reader.read(
        filePath: 'webdav://1/RJ/a.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.artworkPath, isNull);
    });

    test('leaves artwork null when no resolver is configured', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: 'webdav://1/RJ/a.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.artworkPath, isNull);
    });

    test('tolerates a path without the webdav scheme', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: '/RJ01003442/c.flac',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.albumTitle, 'RJ01003442');
      expect(song.format, 'flac');
    });

    test('attaches the fetched sidecar lyrics', () async {
      const text = '[00:01.00] 第一行\n[00:02.00] 第二行';
      final lyrics = _FakeLyrics(text: text);
      final reader = WebDavMetadataReader(lyricsResolver: lyrics);

      final song = await reader.read(
        filePath: 'webdav://1/RJ01008335/02_mp3/a.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.lyricsText, text);
      expect(lyrics.asked, <String>['webdav://1/RJ01008335/02_mp3/a.mp3']);
    });

    test('a failing lyrics resolver yields null instead of throwing',
        () async {
      final reader = WebDavMetadataReader(
        lyricsResolver: _FakeLyrics(throws: true),
      );

      final song = await reader.read(
        filePath: 'webdav://1/RJ/a.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.lyricsText, isNull);
    });

    test('leaves lyrics null when no resolver is configured', () async {
      const reader = WebDavMetadataReader();

      final song = await reader.read(
        filePath: 'webdav://1/RJ/a.mp3',
        sizeBytes: 10,
        modifiedAtMs: 1,
      );

      expect(song.lyricsText, isNull);
    });
  });
}
