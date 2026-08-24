enum LyricFormat {
  lrc,
  srt,
  vtt,
  plain,
}

class LyricLine {
  const LyricLine({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;
}

class LyricDocument {
  const LyricDocument({
    required this.lines,
    required this.synced,
  });

  final List<LyricLine> lines;
  final bool synced;

  static const empty = LyricDocument(lines: [], synced: false);

  int indexAt(int positionMs) {
    if (!synced || lines.isEmpty) {
      return -1;
    }
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].startMs <= positionMs) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  LyricDocument shifted(int deltaMs) {
    if (!synced || deltaMs == 0) {
      return this;
    }
    return LyricDocument(
      synced: true,
      lines: [
        for (final line in lines)
          LyricLine(
            startMs: line.startMs - deltaMs,
            endMs: line.endMs - deltaMs,
            text: line.text,
          ),
      ],
    );
  }
}

class LyricParser {
  const LyricParser();

  static final _lrcTagPattern =
      RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final _enhancedWordTag =
      RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');
  static final _offsetTag =
      RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);
  static final _srtTiming = RegExp(
    r'(\d{1,2}:)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})\s*-->\s*'
    r'(\d{1,2}:)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})',
  );

  LyricFormat detect(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('WEBVTT')) {
      return LyricFormat.vtt;
    }
    if (_srtTiming.hasMatch(trimmed)) {
      return LyricFormat.srt;
    }
    if (_lrcTagPattern.hasMatch(trimmed)) {
      return LyricFormat.lrc;
    }
    return LyricFormat.plain;
  }

  LyricDocument parse(String raw) {
    switch (detect(raw)) {
      case LyricFormat.lrc:
        return _parseLrc(raw);
      case LyricFormat.srt:
      case LyricFormat.vtt:
        return _parseCueBased(raw);
      case LyricFormat.plain:
        return _parsePlain(raw);
    }
  }

  LyricDocument _parseLrc(String raw) {
    var offset = 0;
    final entries = <(int, String)>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      final offsetMatch = _offsetTag.firstMatch(trimmed);
      if (offsetMatch != null) {
        offset = int.parse(offsetMatch.group(1)!);
        continue;
      }
      final content =
          trimmed.replaceAll(_lrcTagPattern, '').trim();
      final matches = _lrcTagPattern.allMatches(trimmed);
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fractionRaw = match.group(3);
        final ms = _fractionToMs(fractionRaw);
        final timeMs = minutes * 60000 + seconds * 1000 + ms;
        entries.add((timeMs, content));
      }
    }
    if (entries.isEmpty) {
      return _parsePlain(raw);
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    final shiftedEntries = [
      for (final entry in entries)
        (
          entry.$1 - offset,
          entry.$2.replaceAll(_enhancedWordTag, '').trim(),
        ),
    ];
    return LyricDocument(
      synced: true,
      lines: _buildLines(shiftedEntries),
    );
  }

  LyricDocument _parseCueBased(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split('\n\n');
    final entries = <(int, int, String)>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trim())
          .toList();
      final timingIndex =
          lines.indexWhere(_srtTiming.hasMatch);
      if (timingIndex < 0) {
        continue;
      }
      final timingLine = lines[timingIndex];
      final match = _srtTiming.firstMatch(timingLine)!;
      final startHours =
          match.group(1)?.replaceAll(':', '') ?? '';
      final startMs = _composeTimestamp(
        startHours,
        match.group(2)!,
        match.group(3)!,
        match.group(4)!,
      );
      final endHours =
          match.group(5)?.replaceAll(':', '') ?? '';
      final endMs = _composeTimestamp(
        endHours,
        match.group(6)!,
        match.group(7)!,
        match.group(8)!,
      );
      final textLines = lines.skip(timingIndex + 1).toList();
      while (textLines.isNotEmpty && textLines.last.isEmpty) {
        textLines.removeLast();
      }
      if (textLines.every((line) => line.isEmpty)) {
        continue;
      }
      entries.add((startMs, endMs, textLines.join('\n')));
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return LyricDocument(
      synced: true,
      lines: [
        for (final entry in entries)
          LyricLine(
            startMs: entry.$1,
            endMs: entry.$2 > entry.$1 ? entry.$2 : entry.$1,
            text: entry.$3,
          ),
      ],
    );
  }

  LyricDocument _parsePlain(String raw) {
    final lines = raw
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return LyricDocument(synced: false, lines: [
      for (var i = 0; i < lines.length; i++)
        LyricLine(startMs: i, endMs: i + 1, text: lines[i]),
    ]);
  }

  List<LyricLine> _buildLines(List<(int, String)> sorted) {
    final lines = <LyricLine>[];
    for (var i = 0; i < sorted.length; i++) {
      final start = sorted[i].$1.clamp(0, 1 << 31);
      final next = i + 1 < sorted.length
          ? sorted[i + 1].$1
          : start + 5000;
      final text = sorted[i].$2;
      if (text.isEmpty && lines.isNotEmpty) {
        lines[lines.length - 1] = LyricLine(
          startMs: lines.last.startMs,
          endMs: next,
          text: lines.last.text,
        );
        continue;
      }
      lines.add(
        LyricLine(
          startMs: start,
          endMs: next > start ? next : start,
          text: text,
        ),
      );
    }
    return lines;
  }

  int _fractionToMs(String? fraction) {
    if (fraction == null || fraction.isEmpty) {
      return 0;
    }
    final value = int.parse(fraction);
    switch (fraction.length) {
      case 1:
        return value * 100;
      case 2:
        return value * 10;
      default:
        return value;
    }
  }

  int _composeTimestamp(
    String hours,
    String minutes,
    String seconds,
    String fraction,
  ) {
    final h = hours.isEmpty ? 0 : int.parse(hours);
    return h * 3600000 +
        int.parse(minutes) * 60000 +
        int.parse(seconds) * 1000 +
        _fractionToMs(fraction);
  }
}
