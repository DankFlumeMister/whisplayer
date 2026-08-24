import 'package:whisplayer/domain/entities/source_type.dart';

class ScannedSong {
  const ScannedSong({
    required this.path,
    required this.sourceType,
    required this.title,
    required this.fileName,
    required this.format,
    required this.durationMs,
    required this.fileSizeBytes,
    required this.modifiedAtMs,
    this.artistName,
    this.albumTitle,
    this.albumArtistName,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.bitrateKbps,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.artworkPath,
    this.lyricsPath,
    this.lyricsText,
    this.hasEmbeddedLyrics = false,
  });

  final String path;
  final SourceType sourceType;
  final String title;
  final String fileName;
  final String format;

  final String? artistName;
  final String? albumTitle;
  final String? albumArtistName;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int? year;

  final int durationMs;
  final int? bitrateKbps;
  final int? sampleRate;
  final int? bitDepth;
  final int? channels;

  final int fileSizeBytes;
  final int modifiedAtMs;

  final String? artworkPath;
  final String? lyricsPath;
  final String? lyricsText;
  final bool hasEmbeddedLyrics;
}
