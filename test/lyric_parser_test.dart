import 'package:flutter_test/flutter_test.dart';

import 'package:whisplayer/domain/lyrics/lyric_parser.dart';

void main() {
  const parser = LyricParser();

  group('LRC', () {
    test('parses basic tags and fills end times', () {
      final doc = parser.parse('[00:01.00]hello\n[00:03.50]world');
      expect(doc.synced, isTrue);
      expect(doc.lines, hasLength(2));
      expect(doc.lines[0].startMs, 1000);
      expect(doc.lines[0].endMs, 3500);
      expect(doc.lines[1].startMs, 3500);
    });

    test('supports multiple timestamps per line', () {
      final doc = parser.parse('[00:05.00][00:20.00]chorus');
      expect(doc.lines.map((l) => l.startMs), [5000, 20000]);
      expect(doc.lines.every((l) => l.text == 'chorus'), isTrue);
    });

    test('applies offset tag', () {
      final doc = parser.parse(
        '[offset:+500]\n[00:02.00]line',
      );
      expect(doc.lines.single.startMs, 1500);
    });

    test('strips enhanced word-level tags', () {
      final doc = parser.parse(
        '[00:01.00]<00:01.00>he<00:01.50>llo',
      );
      expect(doc.lines.single.text, 'hello');
    });

    test('ignores metadata tags', () {
      final doc = parser.parse(
        '[ti:Song][ar:Artist][by:tool]\n[00:01.00]text',
      );
      expect(doc.lines, hasLength(1));
    });

    test('fraction digits 2 and 3', () {
      final doc = parser.parse('[00:01.50]a\n[00:02.250]b');
      expect(doc.lines[0].startMs, 1500);
      expect(doc.lines[1].startMs, 2250);
    });
  });

  group('SRT', () {
    const srt = '1\n'
        '00:00:01,000 --> 00:00:04,000\n'
        'first line\n'
        'second line\n'
        '\n'
        '2\n'
        '00:00:05,500 --> 00:00:08,250\n'
        'next cue';

    test('parses cues with multiline text and crlf', () {
      final doc = parser.parse(srt.replaceAll('\n', '\r\n'));
      expect(parser.detect(srt), LyricFormat.srt);
      expect(doc.synced, isTrue);
      expect(doc.lines, hasLength(2));
      expect(doc.lines[0].startMs, 1000);
      expect(doc.lines[0].endMs, 4000);
      expect(doc.lines[0].text, 'first line\nsecond line');
      expect(doc.lines[1].startMs, 5500);
      expect(doc.lines[1].endMs, 8250);
    });
  });

  group('VTT', () {
    const vtt = 'WEBVTT\n'
        '\n'
        'NOTE this is a comment block\n'
        'that spans lines\n'
        '\n'
        'intro-cue\n'
        '00:00:01.000 --> 00:00:04.000 align:start position:10%\n'
        'hello vtt\n'
        '\n'
        '00:01:06.120 --> 00:01:09.345\n'
        '<v Speaker>voice tag text';
    test('parses header, notes, settings and hours', () {
      final doc = parser.parse(vtt);
      expect(parser.detect(vtt), LyricFormat.vtt);
      expect(doc.lines, hasLength(2));
      expect(doc.lines[0].startMs, 1000);
      expect(doc.lines[0].endMs, 4000);
      expect(doc.lines[0].text, 'hello vtt');
      expect(doc.lines[1].startMs, 66120);
      expect(doc.lines[1].endMs, 69345);
    });
  });

  group('detection & plain fallback', () {
    test('detects lrc', () {
      expect(parser.detect('[00:01.00]x'), LyricFormat.lrc);
    });

    test('plain text becomes unsynced document', () {
      final doc = parser.parse('just some\nplain lines');
      expect(doc.synced, isFalse);
      expect(doc.indexAt(9999), -1);
    });

    test('indexAt binary search', () {
      final doc = parser.parse(
        '[00:01.00]a\n[00:10.00]b\n[00:30.00]c',
      );
      expect(doc.indexAt(0), -1);
      expect(doc.indexAt(999), -1);
      expect(doc.indexAt(1000), 0);
      expect(doc.indexAt(10500), 1);
      expect(doc.indexAt(99999), 2);
    });

    test('shifted moves all lines earlier', () {
      final base = parser.parse('[00:10.00]x\n[00:20.00]y');
      final shifted = base.shifted(2000);
      expect(shifted.lines[0].startMs, 8000);
      expect(shifted.lines[1].startMs, 18000);
    });
  });
}
