import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/playback_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/scanner_providers.dart';
import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/library_writer_repository.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

import 'helpers/fakes.dart';

/// Without this the stream service would reach for the real database (and
/// therefore the path_provider plugin, which has no implementation under
/// `flutter test`).
class _OneServer implements WebDavServerRepository {
  @override
  Future<List<WebDavServer>> getServers() async => <WebDavServer>[
        const WebDavServer(
          id: 1,
          name: 'pc',
          baseUrl: 'http://192.168.1.10:8765',
          username: 'whisplayer',
          rootPath: '/',
          addedAtMs: 0,
        ),
      ];

  @override
  Future<String?> getToken(int serverId) async => 'tok';

  @override
  Stream<List<WebDavServer>> watchServers() => Stream<List<WebDavServer>>.value(
        <WebDavServer>[
          const WebDavServer(
            id: 1,
            name: 'pc',
            baseUrl: 'http://192.168.1.10:8765',
            username: 'whisplayer',
            rootPath: '/',
            addedAtMs: 0,
          ),
        ],
      );

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String token,
    String rootPath = '/',
  }) async => 0;

  @override
  Future<void> removeServer(int serverId) async {}
}

class _RecordingWriter implements LibraryWriterRepository {
  final List<({int songId, int durationMs})> durations =
      <({int songId, int durationMs})>[];

  @override
  Future<void> setSongDuration({
    required int songId,
    required int durationMs,
  }) async {
    durations.add((songId: songId, durationMs: durationMs));
  }

  @override
  Future<List<ExistingSongInfo>> loadExistingSongs() async => [];

  @override
  Future<int> upsertScannedSong(ScannedSong song) async => 0;

  @override
  Future<int> removeSongsMissingFrom(
    Set<String> validPaths, {
    required SourceType sourceType,
  }) async =>
      0;

  @override
  Future<int> removeAllOfSource(SourceType sourceType) async => 0;

  @override
  Future<void> saveLyricsText({
    required int songId,
    required String text,
  }) async {}
}

Song _song({
  required int id,
  required SourceType sourceType,
  required int durationMs,
}) =>
    Song(
      id: id,
      path: sourceType == SourceType.webdav
          ? 'webdav://1/RJ01008335/02_mp3/$id.mp3'
          : '/tmp/$id.flac',
      sourceType: sourceType,
      title: 'Song $id',
      fileName: '$id.mp3',
      format: 'mp3',
      durationMs: durationMs,
      fileSizeBytes: 1024,
      addedAtMs: 0,
      modifiedAtMs: 0,
      playCount: 0,
      skipCount: 0,
      totalPlayMs: 0,
      lastPositionMs: 0,
      isFavorite: false,
    );

PlaybackSnapshot _snapshot({required int durationMs, int queueIndex = 0}) =>
    PlaybackSnapshot(
      state: EngineState.ready,
      playing: true,
      positionMs: 1000,
      durationMs: durationMs,
      queueIndex: queueIndex,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() async {
    await pumpEventQueue();
    await pumpEventQueue();
    await pumpEventQueue();
  }

  Future<(ProviderContainer, FakeAudioEngine, _RecordingWriter)> boot(
    Song song,
  ) async {
    final engine = FakeAudioEngine();
    final writer = _RecordingWriter();
    final container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(
          FakeLibraryRepository(songs: <Song>[song]),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        playbackRecordRepositoryProvider.overrideWithValue(
          FakePlaybackRecordRepository(),
        ),
        libraryWriterRepositoryProvider.overrideWithValue(writer),
        webDavServerRepositoryProvider.overrideWithValue(_OneServer()),
        playerHandlerProvider.overrideWith((ref) => FakeMediaSession()),
        audioEngineProvider.overrideWith((ref) => engine),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.restoreSession();
    await controller.playSongs(<Song>[song]);
    await settle();
    return (container, engine, writer);
  }

  test('a probed duration is written back for a WebDAV song', () async {
    final song = _song(
      id: 42,
      sourceType: SourceType.webdav,
      durationMs: 0,
    );
    final (_, engine, writer) = await boot(song);

    engine.emit(_snapshot(durationMs: 212000));
    await settle();

    expect(writer.durations, <({int songId, int durationMs})>[
      (songId: 42, durationMs: 212000),
    ]);
  });

  test('the write happens once even though the engine keeps reporting',
      () async {
    final song = _song(
      id: 42,
      sourceType: SourceType.webdav,
      durationMs: 0,
    );
    final (_, engine, writer) = await boot(song);

    engine.emit(_snapshot(durationMs: 212000));
    await settle();
    engine.emit(_snapshot(durationMs: 212000));
    await settle();

    expect(writer.durations, hasLength(1));
  });

  test('a song that already knows its duration is left alone', () async {
    final song = _song(
      id: 43,
      sourceType: SourceType.webdav,
      durationMs: 90000,
    );
    final (_, engine, writer) = await boot(song);

    engine.emit(_snapshot(durationMs: 212000));
    await settle();

    expect(writer.durations, isEmpty);
  });

  test('a local song is never backfilled', () async {
    final song = _song(
      id: 44,
      sourceType: SourceType.local,
      durationMs: 0,
    );
    final (_, engine, writer) = await boot(song);

    engine.emit(_snapshot(durationMs: 212000));
    await settle();

    expect(writer.durations, isEmpty);
  });

  test('a zero duration is never written', () async {
    final song = _song(
      id: 45,
      sourceType: SourceType.webdav,
      durationMs: 0,
    );
    final (_, engine, writer) = await boot(song);

    engine.emit(_snapshot(durationMs: 0));
    await settle();

    expect(writer.durations, isEmpty);
  });
}
