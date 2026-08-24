class StorageEntry {
  const StorageEntry({
    required this.path,
    required this.sizeBytes,
    required this.modifiedAtMs,
  });

  final String path;
  final int sizeBytes;
  final int modifiedAtMs;
}
