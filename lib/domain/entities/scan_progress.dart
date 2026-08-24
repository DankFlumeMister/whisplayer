enum ScanPhase {
  walking,
  parsing,
  cleanup,
  done,
  error,
}

class ScanProgress {
  const ScanProgress({
    required this.phase,
    this.processed = 0,
    this.total = 0,
    this.currentFile = '',
    this.addedCount = 0,
    this.updatedCount = 0,
    this.skippedCount = 0,
    this.removedCount = 0,
    this.failedCount = 0,
    this.message,
  });

  final ScanPhase phase;
  final int processed;
  final int total;
  final String currentFile;
  final int addedCount;
  final int updatedCount;
  final int skippedCount;
  final int removedCount;
  final int failedCount;
  final String? message;

  double get fraction => total <= 0 ? 0 : processed / total;
}
