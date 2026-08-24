import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:whisplayer/domain/repositories/remote_server_repository.dart';

/// [CredentialStore] backed by flutter_secure_storage (Android
/// EncryptedSharedPreferences / Keystore).
class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
