import 'package:whisplayer/features/library/domain/browse_prefs.dart';

abstract interface class SettingsRepository {
  Future<String?> getString(String key);

  Future<void> setString(String key, String? value);

  Future<Map<String, String>> getAll();

  /// Reads the whole cloud-library browse preference struct.
  Future<BrowsePrefs> getBrowsePrefs();

  /// Persists the whole cloud-library browse preference struct.
  Future<void> setBrowsePrefs(BrowsePrefs prefs);
}
