abstract interface class SettingsRepository {
  Future<String?> getString(String key);

  Future<void> setString(String key, String? value);

  Future<Map<String, String>> getAll();
}
