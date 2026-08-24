class ExistingSongInfo {
  const ExistingSongInfo({
    required this.songId,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAtMs,
  });

  final int songId;
  final String path;
  final int sizeBytes;
  final int modifiedAtMs;
}
