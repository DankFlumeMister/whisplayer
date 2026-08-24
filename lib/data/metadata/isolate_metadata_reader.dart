import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/metadata_reader.dart';

class IsolateMetadataReader implements MetadataReader {
  IsolateMetadataReader({required this.coversDirectory});

  final String coversDirectory;

  @override
  Future<ScannedSong> read({
    required String filePath,
    required int sizeBytes,
    required int modifiedAtMs,
  }) async {
    final raw = await Isolate.run(() => _parseRaw(filePath));
    final fileName = _fileNameOf(filePath);
    final format = _formatOf(filePath);

    if (raw == null) {
      return ScannedSong(
        path: filePath,
        sourceType: SourceType.local,
        title: _titleFallback(fileName),
        fileName: fileName,
        format: format,
        durationMs: 0,
        fileSizeBytes: sizeBytes,
        modifiedAtMs: modifiedAtMs,
      );
    }

    final sidecarPath = await _findSidecar(filePath);
    final artworkPath = await _persistCover(filePath, raw.artwork, raw.mime);

    return ScannedSong(
      path: filePath,
      sourceType: SourceType.local,
      title: raw.title ?? _titleFallback(fileName),
      fileName: fileName,
      format: format,
      durationMs: raw.durationMs,
      fileSizeBytes: sizeBytes,
      modifiedAtMs: modifiedAtMs,
      artistName: raw.artist,
      albumTitle: raw.album,
      genre: raw.genre,
      trackNumber: raw.trackNumber,
      discNumber: raw.discNumber,
      year: raw.year,
      bitrateKbps: raw.bitrateKbps,
      sampleRate: raw.sampleRate,
      artworkPath: artworkPath,
      lyricsPath: sidecarPath,
      lyricsText: raw.hasLyrics ? raw.lyrics : null,
      hasEmbeddedLyrics: raw.hasLyrics,
    );
  }

  Future<String?> _findSidecar(String audioPath) async {
    final dot = audioPath.lastIndexOf('.');
    final base = dot < 0 ? audioPath : audioPath.substring(0, dot);
    for (final ext in const ['.lrc', '.vtt', '.srt']) {
      final candidate = '$base$ext';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  Future<String?> _persistCover(
    String sourcePath,
    Uint8List? bytes,
    String? mime,
  ) async {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final dir = Directory(coversDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final name = sourcePath.hashCode.abs().toRadixString(36);
    final ext = switch (mime) {
      'image/png' => '.png',
      'image/jpeg' || 'image/jpg' => '.jpg',
      'image/webp' => '.webp',
      _ => '.img',
    };
    final file = File('${dir.path}${Platform.pathSeparator}$name$ext');
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  static String _fileNameOf(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx < 0 ? path : path.substring(idx + 1);
  }

  static String _formatOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) {
      return '';
    }
    return path.substring(dot + 1).toLowerCase();
  }

  static String _titleFallback(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final trimmed = base.trim();
    return trimmed.isEmpty ? fileName : trimmed;
  }
}

class _ParsedRaw {
  const _ParsedRaw({
    required this.durationMs,
    this.lyrics,
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.bitrateKbps,
    this.sampleRate,
    this.hasLyrics = false,
    this.artwork,
    this.mime,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? lyrics;
  final int durationMs;
  final int? bitrateKbps;
  final int? sampleRate;
  final bool hasLyrics;
  final Uint8List? artwork;
  final String? mime;
}

Future<String?> readEmbeddedLyrics(String filePath) {
  return Isolate.run(() {
    try {
      final lyrics = readMetadata(File(filePath)).lyrics;
      final trimmed = (lyrics ?? '').trim();
      return trimmed.isEmpty ? null : trimmed;
    } on Object catch (_) {
      return null;
    }
  });
}

_ParsedRaw? _parseRaw(String path) {
  final file = File(path);
  try {
    final m = readMetadata(file, getImage: true);
    Picture? cover;
    for (final p in m.pictures) {
      if (p.bytes.isNotEmpty) {
        cover = p;
        break;
      }
    }
    final genres = m.genres;
    return _ParsedRaw(
      title: m.title?.trim(),
      artist: m.artist?.trim(),
      album: m.album?.trim(),
      genre: genres.isEmpty ? null : genres.first.trim(),
      durationMs: m.duration?.inMilliseconds ?? 0,
      trackNumber: m.trackNumber,
      discNumber: m.discNumber,
      year: m.year?.year,
      bitrateKbps: m.bitrate,
      sampleRate: m.sampleRate,
      hasLyrics: (m.lyrics ?? '').trim().isNotEmpty,
      lyrics: (m.lyrics ?? '').trim().isEmpty ? null : m.lyrics,
      artwork: cover?.bytes,
      mime: cover?.mimetype,
    );
  } on Object catch (_) {
    // Unsupported or corrupt tags: fall back to filename-derived data.
    return null;
  }
}
