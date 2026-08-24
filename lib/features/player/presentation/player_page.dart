import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
// ScrollCacheExtent lives in rendering and is not re-exported by material.
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/domain/entities/playback.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/player/application/lyrics_controller.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/features/settings/application/overlay_controller.dart';

enum _LyricsMode { hidden, docked, immersive }

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  // Fired after LongPressStart (~500ms into the hold), so total hold ≈ 1.5s.
  static const _holdDuration = Duration(milliseconds: 1000);
  static const _returnDelay = Duration(milliseconds: 1500);
  static const _fadeEdge = 40.0;

  double? _dragValue;
  _LyricsMode _lyricsMode = _LyricsMode.hidden;
  bool _showLock = false;
  bool _followPaused = false;
  final _lineContexts = <int, BuildContext>{};
  Timer? _immersiveTimer;
  Timer? _revealTimer;
  Timer? _returnTimer;

  @override
  void initState() {
    super.initState();
      ref.listenManual<int>(
        lyricsControllerProvider.select((state) => state.activeIndex),
        (previous, next) {
          // index 0 must also re-center; only "no lyrics" (-1) skips.
          if (next < 0 || _followPaused) {
            return;
          }
          _ensureActiveLineVisible();
        },
        fireImmediately: false,
      );
    ref.listenManual<double>(
      lyricsControllerProvider.select((state) => state.fontScale),
      (previous, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _ensureActiveLineVisible();
          }
        });
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _immersiveTimer?.cancel();
    _revealTimer?.cancel();
    _returnTimer?.cancel();
    super.dispose();
  }

  void _beginUserInteraction() {
    _followPaused = true;
    _returnTimer?.cancel();
    _returnTimer = Timer(_returnDelay, () {
      if (!mounted) {
        return;
      }
      _followPaused = false;
      _ensureActiveLineVisible();
    });
  }

  void _ensureActiveLineVisible() {
    final index = ref.read(lyricsControllerProvider).activeIndex;
    if (index <= 0) {
      return;
    }
    final lineContext = _lineContexts[index];
    if (lineContext == null || !lineContext.mounted) {
      return;
    }
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final song = state.currentSong;
    final scheme = Theme.of(context).colorScheme;
    final snap = state.snapshot;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('队列为空')));
    }

    final position = _dragValue ?? snap.positionMs.toDouble();
    final durationMs = snap.durationMs > 0
        ? snap.durationMs
        : (song.durationMs > 0 ? song.durationMs : 1);
    final sliderMax = durationMs.toDouble();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(path: song.artworkPath, scheme: scheme),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface.withValues(alpha: 0.45),
                    scheme.surface.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Expanded(
                      child: _lyricsMode == _LyricsMode.docked
                          ? _buildDockedLyrics(scheme)
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(
                                  () => _lyricsMode =
                                      _LyricsMode.docked),
                              child: _buildCover(state, song),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        song.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        [song.artistName, song.albumTitle]
                            .whereType<String>()
                            .join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context)
                          .copyWith(trackHeight: 4),
                      child: Slider(
                        max: sliderMax,
                        value: position
                            .clamp(0, sliderMax)
                            .toDouble(),
                        onChanged: (v) =>
                            setState(() => _dragValue = v),
                        onChangeEnd: (v) {
                          setState(() => _dragValue = null);
                          ref
                              .read(playerControllerProvider.notifier)
                              .seekTo(v.round());
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(position.round())),
                        Text(_fmt(durationMs)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 38,
                          padding: const EdgeInsets.all(12),
                          onPressed: () => ref
                              .read(playerControllerProvider.notifier)
                              .onPrevious(),
                          icon: const Icon(
                              Icons.skip_previous_rounded),
                        ),
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: IconButton.filled(
                            iconSize: 48,
                            onPressed: () => ref
                                .read(
                                    playerControllerProvider.notifier)
                                .togglePlayPause(),
                            icon: Icon(
                              state.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ),
                        IconButton(
                          iconSize: 38,
                          padding: const EdgeInsets.all(12),
                          onPressed: () => ref
                              .read(playerControllerProvider.notifier)
                              .onNext(),
                          icon:
                              const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          tooltip: '循环模式',
                          iconSize: 28,
                          padding: const EdgeInsets.all(12),
                          onPressed: () => ref
                              .read(playerControllerProvider.notifier)
                              .cycleLoopMode(),
                          icon: Icon(_loopIcon(state.loopMode)),
                        ),
                        _OverlayToggleButton(scheme: scheme),
                        IconButton(
                          tooltip: '播放队列',
                          iconSize: 28,
                          padding: const EdgeInsets.all(12),
                          onPressed: () => _showQueue(context),
                          icon:
                              const Icon(Icons.queue_music_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_lyricsMode == _LyricsMode.immersive)
            _buildImmersiveLyrics(song, scheme),
        ],
      ),
    );
  }

  Widget _buildCover(PlayerUiState state, Song song) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Hero(
          tag: 'cover-${song.id}',
          child: RepaintBoundary(
            child: AnimatedScale(
              scale: state.isPlaying ? 1.0 : 0.9,
              duration: const Duration(milliseconds: 900),
              curve: const _JellyCurve(),
              child: _Cover(path: song.artworkPath),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockedLyrics(ColorScheme scheme) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(
                () => _lyricsMode = _LyricsMode.hidden),
            onLongPressStart: (_) {
              _immersiveTimer?.cancel();
              _immersiveTimer = Timer(
                _holdDuration,
                () {
                  if (mounted) {
                    setState(() {
                      _lyricsMode = _LyricsMode.immersive;
                      _showLock = false;
                    });
                  }
                },
              );
            },
            onLongPressEnd: (_) => _immersiveTimer?.cancel(),
            onLongPressCancel: _immersiveTimer?.cancel,
            child: ShaderMask(
              shaderCallback: _panelFadeShader,
              blendMode: BlendMode.dstIn,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 48, 16, 12),
                child: _buildLyricsBody(docked: true),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _buildLyricsToolbar(scheme),
        ),
      ],
    );
  }

  Shader _panelFadeShader(Rect bounds) {
    final height = bounds.height;
    final fade = _fadeEdge.clamp(0.0, height * 0.35);
    final t1 = fade / height;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0, t1, 1 - t1, 1],
    ).createShader(bounds);
  }

  Widget _buildLyricsToolbar(ColorScheme scheme) {
    final lyricsState = ref.watch(lyricsControllerProvider);
    final controller =
        ref.read(lyricsControllerProvider.notifier);
    IconData alignIcon;
    switch (lyricsState.align) {
      case LyricAlign.left:
        alignIcon = Icons.format_align_left_rounded;
      case LyricAlign.center:
        alignIcon = Icons.format_align_center_rounded;
      case LyricAlign.right:
        alignIcon = Icons.format_align_right_rounded;
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '返回封面',
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                setState(() => _lyricsMode = _LyricsMode.hidden),
            icon: const Icon(Icons.album_outlined, size: 20),
          ),
          IconButton(
            tooltip: '缩小字体',
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                controller.setFontScale(lyricsState.fontScale - 0.1),
            icon: const Icon(Icons.text_decrease_rounded, size: 20),
          ),
          IconButton(
            tooltip: '放大字体',
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                controller.setFontScale(lyricsState.fontScale + 0.1),
            icon: const Icon(Icons.text_increase_rounded, size: 20),
          ),
          IconButton(
            tooltip: '文字对齐',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final next = LyricAlign
                  .values[(lyricsState.align.index + 1) %
                      LyricAlign.values.length];
              unawaited(controller.setAlignment(next));
            },
            icon: Icon(alignIcon, size: 20),
          ),
          IconButton(
            tooltip: '导入歌词文件',
            visualDensity: VisualDensity.compact,
            onPressed: () => unawaited(_importLyrics()),
            icon: const Icon(Icons.upload_file_outlined, size: 20),
          ),
        ],
      ),
    );
  }
  Widget _buildLyricsBody({required bool docked}) {
    final lyricsState = ref.watch(lyricsControllerProvider);
    return switch (lyricsState.status) {
      LyricsStatus.loading ||
      LyricsStatus.idle =>
        const Center(child: CircularProgressIndicator()),
      LyricsStatus.none => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              const Text('暂无歌词'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(_importLyrics()),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('导入歌词文件'),
              ),
            ],
          ),
        ),
      LyricsStatus.synced ||
      LyricsStatus.unsynced =>
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _beginUserInteraction();
            } else if (notification is ScrollUpdateNotification &&
                notification.dragDetails != null) {
              _beginUserInteraction();
            }
            return false;
          },
          child: ListView.builder(
            // Keep every line's context alive so Scrollable.ensureVisible
            // can always reach the active line, even after the user flings
            // it far off-screen (lazy recycling would null the context).
            // Keep every line's context alive so Scrollable.ensureVisible
            // can always reach the active line, even after the user flings
            // it far off-screen (lazy recycling would null the context).
            scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
            padding: EdgeInsets.symmetric(
              vertical: docked
                  ? 8
                  : MediaQuery.of(context).size.height * 0.25,
            ),
            itemCount: lyricsState.document.synced
                ? lyricsState.document.lines.length
                : lyricsState.document.lines.length + 1,
            itemBuilder: (context, index) {
              var lineIndex = index;
              if (!lyricsState.document.synced) {
                if (index == 0) {
                  return const _UnsyncedBanner();
                }
                lineIndex = index - 1;
              }
              return _lyricLine(
                lyricsState,
                lineIndex,
                activeSize: docked ? 17 : 22,
                inactiveSize: docked ? 14 : 18,
              );
            },
          ),
        ),
    };
  }

  Widget _lyricLine(
    LyricsUiState lyricsState,
    int index, {
    required double activeSize,
    required double inactiveSize,
  }) {
    final lines = lyricsState.document.lines;
    final isActive = index == lyricsState.activeIndex;
    final scheme = Theme.of(context).colorScheme;

    final AlignmentGeometry boxAlign;
    final TextAlign textAlign;
    switch (lyricsState.align) {
      case LyricAlign.left:
        boxAlign = Alignment.centerLeft;
        textAlign = TextAlign.left;
      case LyricAlign.center:
        boxAlign = Alignment.center;
        textAlign = TextAlign.center;
      case LyricAlign.right:
        boxAlign = Alignment.centerRight;
        textAlign = TextAlign.right;
    }

    return Padding(
      key: ValueKey('line-$index'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: boxAlign,
        child: Builder(
          builder: (context) {
            _lineContexts[index] = context;
            return GestureDetector(
              onTap: () => _seekToLine(lyricsState, index),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  fontSize: (isActive ? activeSize : inactiveSize) *
                      lyricsState.fontScale,
                  height: 1.45,
                  fontWeight:
                      isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.55),
                ),
                child: Text(
                  lines[index].text.replaceAll('\n', ' '),
                  textAlign: textAlign,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _seekToLine(LyricsUiState lyricsState, int index) {
    _beginUserInteraction();
    final target =
        lyricsState.document.lines[index].startMs +
            lyricsState.offsetMs;
    ref
        .read(playerControllerProvider.notifier)
        .seekTo(target.clamp(0, 1 << 31));
  }

  Widget _buildImmersiveLyrics(Song song, ColorScheme scheme) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(path: song.artworkPath, scheme: scheme),
          SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildLyricsBody(docked: false),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPressStart: (_) => _startRevealTimer(),
                    onLongPressEnd: (_) => _revealTimer?.cancel(),
                    onLongPressCancel: _revealTimer?.cancel,
                  ),
                ),
                Positioned(
                  bottom: 64,
                  left: 0,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    ),
                    child: _showLock
                        ? _buildUnlockButton()
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startRevealTimer() {
    _revealTimer?.cancel();
    _revealTimer = Timer(_holdDuration, () {
      if (mounted) {
        setState(() => _showLock = true);
      }
    });
  }

  Widget _buildUnlockButton() {
    return Column(
      key: const ValueKey('unlock-button'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          iconSize: 30,
          padding: const EdgeInsets.all(16),
          onPressed: _exitImmersive,
          icon: const Icon(Icons.lock_open_rounded),
        ),
        const SizedBox(height: 6),
        Text(
          '解锁',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  void _exitImmersive() {
    _revealTimer?.cancel();
    setState(() {
      _lyricsMode = _LyricsMode.docked;
      _showLock = false;
    });
  }

  Future<void> _importLyrics() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'vtt', 'srt', 'txt'],
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes);
    await ref
        .read(lyricsControllerProvider.notifier)
        .importLyricsFile(content);
  }

  IconData _loopIcon(PlaybackLoopMode mode) {
    switch (mode) {
      case PlaybackLoopMode.off:
        return Icons.repeat_outlined;
      case PlaybackLoopMode.all:
        return Icons.repeat_rounded;
      case PlaybackLoopMode.one:
        return Icons.repeat_one_rounded;
    }
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final player = sheetRef.watch(playerControllerProvider);
          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: player.queue.length,
              itemBuilder: (context, index) {
                final item = player.queue[index];
                final active = index == player.currentIndex;
                final highlight =
                    Theme.of(sheetContext).colorScheme.primary;
                return ListTile(
                  leading: Text(
                    '${index + 1}',
                    style: TextStyle(color: active ? highlight : null),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? highlight : null,
                    ),
                  ),
                  subtitle: Text(
                    item.artistName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => sheetRef
                        .read(playerControllerProvider.notifier)
                        .removeFromQueue(index),
                  ),
                  onTap: () {
                    sheetRef
                        .read(playerControllerProvider.notifier)
                        .skipTo(index);
                    Navigator.pop(sheetContext);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _fmt(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _OverlayToggleButton extends ConsumerWidget {
  const _OverlayToggleButton({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(overlayControllerProvider);
    return IconButton(
      tooltip: enabled ? '关闭桌面歌词' : '开启桌面歌词',
      iconSize: 28,
      padding: const EdgeInsets.all(12),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final applied = await ref
            .read(overlayControllerProvider.notifier)
            .setEnabled(value: !enabled);
        if (!applied) {
          messenger.showSnackBar(
            const SnackBar(content: Text('需要“显示在应用上层”权限才能开启桌面歌词')),
          );
        }
      },
      icon: Icon(
        enabled ? Icons.lyrics_rounded : Icons.lyrics_outlined,
        color: enabled ? scheme.primary : null,
      ),
    );
  }
}

class _UnsyncedBanner extends StatelessWidget {
  const _UnsyncedBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '未检测到时间轴，仅显示文本',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatefulWidget {
  const _Backdrop({required this.path, required this.scheme});

  final String? path;
  final ColorScheme scheme;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

/// Pre-blurred backdrops keyed by artwork path. Blurring a tiny decoded
/// image once and reusing it avoids re-running a large gaussian on every
/// playback-snapshot rebuild of the page.
final _backdropCache = <String, ui.Image>{};

class _BackdropState extends State<_Backdrop> {
  static const _cacheLimit = 8;
  static const _thumbSize = 128.0;

  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _image = widget.path == null ? null : _backdropCache[widget.path!];
    _load();
  }

  @override
  void didUpdateWidget(covariant _Backdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _image = widget.path == null ? null : _backdropCache[widget.path!];
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    if (path == null || !File(path).existsSync()) {
      return;
    }
    final cached = _backdropCache[path];
    if (cached != null) {
      if (mounted) {
        setState(() => _image = cached);
      }
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final codec =
          await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final frame = await codec.getNextFrame();
      final source = frame.image;
      final side = math.min(
        source.width.toDouble(),
        source.height.toDouble(),
      );
      final src = ui.Rect.fromCenter(
        center: ui.Offset(source.width / 2, source.height / 2),
        width: side,
        height: side,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      const dst = ui.Rect.fromLTWH(0, 0, _thumbSize, _thumbSize);
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6);
      canvas.drawImageRect(source, src, dst, paint);
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(
        _thumbSize.toInt(),
        _thumbSize.toInt(),
      );
      picture.dispose();
      source.dispose();
      _backdropCache[path] = rendered;
      while (_backdropCache.length > _cacheLimit) {
        final oldest = _backdropCache.keys
            .firstWhere((k) => k != path, orElse: () => path);
        if (oldest == path) {
          break;
        }
        _backdropCache.remove(oldest)?.dispose();
      }
      if (mounted && widget.path == path) {
        setState(() => _image = rendered);
      }
    } on Exception {
      // Decode failures fall back to the plain surface color.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.scheme.surfaceContainerLowest,
      child: _image == null
          ? const SizedBox.expand()
          : CustomPaint(
              painter: _BlurPaint(image: _image!),
              child: const SizedBox.expand(),
            ),
    );
  }
}

class _BlurPaint extends CustomPainter {
  const _BlurPaint({required this.image});

  final ui.Image image;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final scale = math.max(
      size.width / image.width,
      size.height / image.height,
    );
    final dst = ui.Rect.fromCenter(
      center: ui.Offset(size.width / 2, size.height / 2),
      width: image.width * scale,
      height: image.height * scale,
    );
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      ),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_BlurPaint oldDelegate) => oldDelegate.image != image;
}

class _Cover extends StatelessWidget {
  const _Cover({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);
    Widget fallback() => ColoredBox(
          color: scheme.secondaryContainer,
          child: Icon(
            Icons.music_note,
            size: 96,
            color: scheme.onSecondaryContainer,
          ),
        );
    if (path == null || !File(path!).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: fallback(),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        File(path!),
        fit: BoxFit.cover,
        cacheWidth: 720,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

/// Linear travel followed by a damped elastic settle ("Q 弹" feel).
class _JellyCurve extends Curve {
  const _JellyCurve();

  static const _linearPortion = 0.62;
  static const _overshoot = 0.09;

  @override
  double transformInternal(double t) {
    if (t < _linearPortion) {
      return (t / _linearPortion) * (1 + _overshoot);
    }
    final u = (t - _linearPortion) / (1 - _linearPortion);
    return 1 +
        _overshoot *
            math.cos(u * math.pi * 3) *
            math.exp(-3.6 * u);
  }
}
