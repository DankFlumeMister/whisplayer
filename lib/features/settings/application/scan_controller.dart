import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:whisplayer/application/scanner/music_scanner.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/providers/scanner_providers.dart';
import 'package:whisplayer/domain/entities/scan_progress.dart';

const _includeKey = 'scan.include_dirs';
const _excludeKey = 'scan.exclude_dirs';

class ScanConfig {
  const ScanConfig({
    required this.includeDirs,
    required this.excludeDirs,
  });

  final List<String> includeDirs;
  final Set<String> excludeDirs;

  ScanConfig copyWith({
    List<String>? includeDirs,
    Set<String>? excludeDirs,
  }) {
    return ScanConfig(
      includeDirs: includeDirs ?? this.includeDirs,
      excludeDirs: excludeDirs ?? this.excludeDirs,
    );
  }

  static Future<ScanConfig> defaults() async {
    if (Platform.isAndroid) {
      return const ScanConfig(
        includeDirs: [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
        ],
        excludeDirs: {},
      );
    }
    final docs = await getApplicationDocumentsDirectory();
    return ScanConfig(includeDirs: [docs.path], excludeDirs: {});
  }
}

class ScanUiState {
  const ScanUiState({this.isScanning = false, this.progress});

  final bool isScanning;
  final ScanProgress? progress;
}

class ScanController extends Notifier<ScanUiState> {
  StreamSubscription<ScanProgress>? _subscription;
  MusicScanner? _scanner;

  @override
  ScanUiState build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
    });
    return const ScanUiState();
  }

  Future<void> start(ScanConfig config) async {
    if (state.isScanning) {
      return;
    }
    final scanner = await ref.read(musicScannerProvider.future);
    _scanner = scanner;
    state = const ScanUiState(isScanning: true);
    _subscription = scanner
        .scan(
      includeDirs: config.includeDirs,
      excludeDirs: config.excludeDirs,
    )
        .listen((progress) {
      state = ScanUiState(isScanning: true, progress: progress);
      if (progress.phase == ScanPhase.done ||
          progress.phase == ScanPhase.error) {
        state = ScanUiState(progress: progress);
        _subscription = null;
        _scanner = null;
      }
    });
  }

  void cancel() {
    _scanner?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _scanner = null;
    state = ScanUiState(progress: state.progress);
  }

  Future<ScanConfig> loadConfig() async {
    final repo = ref.read(settingsRepositoryProvider);
    final includeJson = await repo.getString(_includeKey);
    final excludeJson = await repo.getString(_excludeKey);
    List<String> decode(String? json) {
      if (json == null || json.isEmpty) {
        return [];
      }
      try {
        final raw = jsonDecode(json) as List<dynamic>;
        return raw.whereType<String>().toList();
      } on FormatException catch (_) {
        return [];
      }
    }

    final includes = decode(includeJson);
    final excludes = decode(excludeJson);
    if (includes.isEmpty && excludes.isEmpty) {
      return ScanConfig.defaults();
    }
    return ScanConfig(
      includeDirs: includes,
      excludeDirs: excludes.toSet(),
    );
  }

  Future<void> saveConfig(ScanConfig config) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setString(
      _includeKey,
      jsonEncode(config.includeDirs),
    );
    await repo.setString(
      _excludeKey,
      jsonEncode(config.excludeDirs.toList()),
    );
  }
}

final scanControllerProvider =
    NotifierProvider<ScanController, ScanUiState>(
  ScanController.new,
);

final scanConfigProvider = FutureProvider<ScanConfig>((ref) {
  return ref.watch(scanControllerProvider.notifier).loadConfig();
});
