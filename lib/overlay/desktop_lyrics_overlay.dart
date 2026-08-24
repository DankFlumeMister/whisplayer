import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayPayload {
  const OverlayPayload({
    this.title = '',
    this.line = '',
  });

  factory OverlayPayload.decode(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      return OverlayPayload(
        title: map['title'] as String? ?? '',
        line: map['line'] as String? ?? '',
      );
    } on FormatException catch (_) {
      return const OverlayPayload();
    }
  }

  final String title;
  final String line;
}

class DesktopLyricsOverlayApp extends StatelessWidget {
  const DesktopLyricsOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _OverlayHome(),
    );
  }
}

class _OverlayHome extends StatefulWidget {
  const _OverlayHome();

  @override
  State<_OverlayHome> createState() => _OverlayHomeState();
}

class _OverlayHomeState extends State<_OverlayHome> {
  StreamSubscription<dynamic>? _sub;
  OverlayPayload _payload = const OverlayPayload(
    title: 'Whisplayer 桌面歌词',
    line: '等待播放…',
  );

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted) {
        return;
      }
      setState(() => _payload = OverlayPayload.decode(data));
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = _payload.line.isEmpty ? '♪' : _payload.line;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        alignment: Alignment.center,
        child: Text(
          line,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: line == '♪' ? Colors.white70 : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
            shadows: _lyricShadows(),
          ),
        ),
      ),
    );
  }

  /// Soft black outline + glow so white lyrics stay readable over any
  /// wallpaper now that the bar background is transparent.
  List<Shadow> _lyricShadows() {
    const stroke = Color(0x99000000);
    const glow = Color(0x66000000);
    return const [
      Shadow(color: stroke, offset: Offset(1.4, 0)),
      Shadow(color: stroke, offset: Offset(-1.4, 0)),
      Shadow(color: stroke, offset: Offset(0, 1.4)),
      Shadow(color: stroke, offset: Offset(0, -1.4)),
      Shadow(color: stroke, offset: Offset(1, 1)),
      Shadow(color: stroke, offset: Offset(-1, -1)),
      Shadow(color: glow, blurRadius: 8),
    ];
  }
}
