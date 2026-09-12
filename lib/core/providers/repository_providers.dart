import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:whisplayer/core/providers/database_provider.dart';
import 'package:whisplayer/core/providers/scanner_providers.dart';
import 'package:whisplayer/data/remote/remote_library_service.dart';
import 'package:whisplayer/data/repositories/drift_cloud_browse_repository.dart';
import 'package:whisplayer/data/repositories/drift_library_repository.dart';
import 'package:whisplayer/data/repositories/drift_playback_record_repository.dart';
import 'package:whisplayer/data/repositories/drift_playlist_repository.dart';
import 'package:whisplayer/data/repositories/drift_remote_server_repository.dart';
import 'package:whisplayer/data/repositories/drift_settings_repository.dart';
import 'package:whisplayer/data/repositories/drift_webdav_server_repository.dart';
import 'package:whisplayer/data/repositories/secure_credential_store.dart';
import 'package:whisplayer/data/webdav/webdav_stream_service.dart';
import 'package:whisplayer/domain/repositories/cloud_browse_repository.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';
import 'package:whisplayer/domain/repositories/playback_record_repository.dart';
import 'package:whisplayer/domain/repositories/playlist_repository.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';
import 'package:whisplayer/domain/repositories/settings_repository.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return DriftLibraryRepository(ref.watch(appDatabaseProvider));
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return DriftPlaylistRepository(ref.watch(appDatabaseProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return DriftHistoryRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(appDatabaseProvider));
});

final playbackRecordRepositoryProvider =
    Provider<PlaybackRecordRepository>((ref) {
  return DriftPlaybackRecordRepository(ref.watch(appDatabaseProvider));
});

final credentialStoreProvider = Provider<CredentialStore>((ref) {
  // flutter_secure_storage 11.x uses EncryptedSharedPreferences on Android
  // by default; no per-platform options are required.
  const storage = FlutterSecureStorage();
  return const SecureCredentialStore(storage);
});

final remoteServerRepositoryProvider = Provider<RemoteServerRepository>((ref) {
  return DriftRemoteServerRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(credentialStoreProvider),
  );
});

final webDavServerRepositoryProvider =
    Provider<WebDavServerRepository>((ref) {
  return DriftWebDavServerRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(credentialStoreProvider),
  );
});

final webDavStreamServiceProvider = Provider<WebDavStreamService>((ref) {
  return WebDavStreamService(ref.watch(webDavServerRepositoryProvider));
});

final cloudBrowseRepositoryProvider = Provider<CloudBrowseRepository>((ref) {
  return DriftCloudBrowseRepository(ref.watch(appDatabaseProvider));
});

final remoteLibraryServiceProvider = Provider<RemoteLibraryService>((ref) {
  return RemoteLibraryService(
    ref.watch(remoteServerRepositoryProvider),
    ref.watch(libraryWriterRepositoryProvider),
    ref.watch(libraryRepositoryProvider),
  );
});
