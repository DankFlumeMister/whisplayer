import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/scanner_providers.dart';
import 'package:whisplayer/domain/entities/existing_song_info.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/library_writer_repository.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';
import 'package:whisplayer/features/settings/presentation/webdav_scan_sheet.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

/// Records what the sheet asked the writer to do, so the destructive path can
/// be asserted without a database.
class _RecordingWriter implements LibraryWriterRepository {
  final List<SourceType> cleared = <SourceType>[];

  @override
  Future<int> removeAllOfSource(SourceType sourceType) async {
    cleared.add(sourceType);
    return 42;
  }

  @override
  Future<List<ExistingSongInfo>> loadExistingSongs() async => const [];

  @override
  Future<int> upsertScannedSong(ScannedSong song) async => 0;

  @override
  Future<int> removeSongsMissingFrom(
    Set<String> validPaths, {
    required SourceType sourceType,
  }) async =>
      0;

  @override
  Future<void> saveLyricsText({
    required int songId,
    required String text,
  }) async {}

  @override
  Future<void> setSongDuration({
    required int songId,
    required int durationMs,
  }) async {}
}

class _FakeServerRepo implements WebDavServerRepository {
  @override
  Stream<List<WebDavServer>> watchServers() => Stream.value(const []);

  @override
  Future<List<WebDavServer>> getServers() async => const [];

  @override
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String token,
    String rootPath = '/',
  }) async =>
      0;

  @override
  Future<void> removeServer(int serverId) async {}

  @override
  Future<String?> getToken(int serverId) async => 'token';
}

/// Port 1 refuses instantly, so the walk fails fast and the test never waits
/// on a real network round trip.
const _server = WebDavServer(
  id: 1,
  name: 'NAS',
  baseUrl: 'http://127.0.0.1:1',
  username: 'u',
  rootPath: '/',
  addedAtMs: 0,
);

Future<void> _pump(
  WidgetTester tester,
  _RecordingWriter writer, {
  required bool clearFirst,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryWriterRepositoryProvider.overrideWithValue(writer),
        webDavServerRepositoryProvider.overrideWithValue(_FakeServerRepo()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WebDavScanSheet(server: _server, clearFirst: clearFirst),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('clearFirst wipes the webdav source before walking', (
    tester,
  ) async {
    final writer = _RecordingWriter();
    await _pump(tester, writer, clearFirst: true);

    expect(writer.cleared, [SourceType.webdav]);
  });

  testWidgets('a plain scan never deletes anything', (tester) async {
    final writer = _RecordingWriter();
    await _pump(tester, writer, clearFirst: false);

    expect(writer.cleared, isEmpty);
  });
}
