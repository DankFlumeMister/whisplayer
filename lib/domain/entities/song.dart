import 'package:whisplayer/domain/entities/source_type.dart';

class Song {
  const Song({
    required this.id,
    required this.path,
    required this.sourceType,
    required this.title,
    required this.fileName,
    required this.format,
    required this.durationMs,
    required this.fileSizeBytes,
    required this.addedAtMs,
    required this.modifiedAtMs,
    required this.playCount,
    required this.skipCount,
    required this.totalPlayMs,
    required this.lastPositionMs,
    required this.isFavorite,
    this.artistId,
    this.albumId,
    this.genre,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.bitrateKbps,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.artworkPath,
    this.lyricsPath,
    this.lyricsText,
    this.hasEmbeddedLyrics = false,
    this.lastPlayedAtMs,
    this.artistName,
    this.albumTitle,
  });

  final int id;
  final String path;
  final SourceType sourceType;
  final String title;
  final String fileName;
  final String format;

  final int? artistId;
  final int? albumId;
  final String? genre;

  final int? sampleRate;
  final int? bitDepth;
  final int? channels;
  final int? bitrateKbps;

  final int durationMs;
  final int fileSizeBytes;
  final int? trackNumber;
  final int? discNumber;
  final int? year;

  final String? artworkPath;
  final String? lyricsPath;
  final String? lyricsText;
  final bool hasEmbeddedLyrics;

  final int addedAtMs;
  final int modifiedAtMs;

  final int playCount;
  final int skipCount;
  final int totalPlayMs;
  final int? lastPlayedAtMs;
  final int lastPositionMs;
  final bool isFavorite;

  final String? artistName;
  final String? albumTitle;

  static const losslessFormats = {'flac', 'wav', 'aiff', 'aif', 'alac'};

  bool get isLossless => losslessFormats.contains(format.toLowerCase());

  Song copyWith({
    int? id,
    String? path,
    SourceType? sourceType,
    String? title,
    String? fileName,
    String? format,
    int? durationMs,
    int? fileSizeBytes,
    int? addedAtMs,
    int? modifiedAtMs,
    int? playCount,
    int? skipCount,
    int? totalPlayMs,
    int? lastPositionMs,
    bool? isFavorite,
    bool? hasEmbeddedLyrics,
    Object? artistId = _unset,
    Object? albumId = _unset,
    Object? genre = _unset,
    Object? sampleRate = _unset,
    Object? bitDepth = _unset,
    Object? channels = _unset,
    Object? bitrateKbps = _unset,
    Object? trackNumber = _unset,
    Object? discNumber = _unset,
    Object? year = _unset,
    Object? artworkPath = _unset,
    Object? lyricsPath = _unset,
    Object? lastPlayedAtMs = _unset,
    Object? artistName = _unset,
    Object? albumTitle = _unset,
  }) {
    return Song(
      id: id ?? this.id,
      path: path ?? this.path,
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      format: format ?? this.format,
      durationMs: durationMs ?? this.durationMs,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      modifiedAtMs: modifiedAtMs ?? this.modifiedAtMs,
      playCount: playCount ?? this.playCount,
      skipCount: skipCount ?? this.skipCount,
      totalPlayMs: totalPlayMs ?? this.totalPlayMs,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      isFavorite: isFavorite ?? this.isFavorite,
      hasEmbeddedLyrics: hasEmbeddedLyrics ?? this.hasEmbeddedLyrics,
      artistId: _pick(artistId, this.artistId),
      albumId: _pick(albumId, this.albumId),
      genre: _pick(genre, this.genre),
      sampleRate: _pick(sampleRate, this.sampleRate),
      bitDepth: _pick(bitDepth, this.bitDepth),
      channels: _pick(channels, this.channels),
      bitrateKbps: _pick(bitrateKbps, this.bitrateKbps),
      trackNumber: _pick(trackNumber, this.trackNumber),
      discNumber: _pick(discNumber, this.discNumber),
      year: _pick(year, this.year),
      artworkPath: _pick(artworkPath, this.artworkPath),
      lyricsPath: _pick(lyricsPath, this.lyricsPath),
      lastPlayedAtMs: _pick(lastPlayedAtMs, this.lastPlayedAtMs),
      artistName: _pick(artistName, this.artistName),
      albumTitle: _pick(albumTitle, this.albumTitle),
    );
  }
}

class _Unset {
  const _Unset();
}

const _unset = _Unset();

T? _pick<T>(Object? replacement, T? current) {
  if (identical(replacement, _unset)) {
    return current;
  }
  return replacement as T?;
}

enum SongSort {
  title,
  artist,
  album,
  addedAt,
  playCount,
  duration,
}
