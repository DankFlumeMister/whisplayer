/// A parsed album entry from the Subsonic `getAlbumList2` endpoint.
class SubsonicAlbum {
  const SubsonicAlbum({
    required this.id,
    required this.name,
    this.artist,
    this.coverArt,
    this.songCount = 0,
    this.duration = 0,
    this.year,
    this.created = '',
  });

  factory SubsonicAlbum.fromJson(Map<String, dynamic> json) {
    return SubsonicAlbum(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['album'] as String? ?? '',
      artist: json['artist'] as String?,
      coverArt: json['coverArt'] as String?,
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt(),
      created: json['created'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String? artist;
  final String? coverArt;
  final int songCount;
  final int duration;
  final int? year;

  /// ISO-8601 creation timestamp; lexicographic order equals time order.
  final String created;
}

/// A parsed song entry from the Subsonic `getAlbum` endpoint.
class SubsonicSong {
  const SubsonicSong({
    required this.id,
    required this.title,
    this.artist,
    this.albumId,
    this.artistId,
    this.coverArt,
    this.durationSec = 0,
    this.track,
    this.suffix,
    this.bitRate,
  });

  factory SubsonicSong.fromJson(Map<String, dynamic> json) {
    return SubsonicSong(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      albumId: json['albumId'] as String?,
      artistId: json['artistId'] as String?,
      coverArt: json['coverArt'] as String?,
      durationSec: (json['duration'] as num?)?.toInt() ?? 0,
      track: (json['track'] as num?)?.toInt(),
      suffix: json['suffix'] as String?,
      bitRate: (json['bitRate'] as num?)?.toInt(),
    );
  }

  final String id;
  final String title;
  final String? artist;
  final String? albumId;
  final String? artistId;
  final String? coverArt;
  final int durationSec;
  final int? track;
  final String? suffix;
  final int? bitRate;
}

/// An album with its songs, from the Subsonic `getAlbum` endpoint.
class SubsonicAlbumDetail {
  const SubsonicAlbumDetail({required this.album, required this.songs});

  final SubsonicAlbum album;
  final List<SubsonicSong> songs;
}

/// Fuzzy search results from the Subsonic `search3` endpoint.
class SubsonicSearchResult {
  const SubsonicSearchResult({required this.albums, required this.songs});

  final List<SubsonicAlbum> albums;
  final List<SubsonicSong> songs;
}

/// One line of OpenSubsonic structured lyrics.
class SubsonicLyricLine {
  const SubsonicLyricLine({required this.value, this.startMs});

  factory SubsonicLyricLine.fromJson(Map<String, dynamic> json) {
    return SubsonicLyricLine(
      value: json['value'] as String? ?? '',
      startMs: (json['start'] as num?)?.toInt(),
    );
  }

  final String value;
  final int? startMs;
}

/// Structured lyrics from the OpenSubsonic `getLyricsBySongId` endpoint.
class SubsonicLyrics {
  const SubsonicLyrics({required this.synced, required this.lines});

  factory SubsonicLyrics.fromJson(Map<String, dynamic> json) {
    final lines = json['line'] as List<dynamic>?;
    return SubsonicLyrics(
      synced: json['synced'] as bool? ?? false,
      lines: lines
              ?.whereType<Map<String, dynamic>>()
              .map(SubsonicLyricLine.fromJson)
              .toList() ??
          const <SubsonicLyricLine>[],
    );
  }

  factory SubsonicLyrics.fromStructuredJson(Map<String, dynamic>? payload) {
    final list = payload?['structuredLyrics'] as List<dynamic>?;
    final first = list
        ?.whereType<Map<String, dynamic>>()
        .map(SubsonicLyrics.fromJson)
        .firstWhere(
          (l) => l.lines.isNotEmpty,
          orElse: () => const SubsonicLyrics(synced: false, lines: []),
        );
    return first ?? const SubsonicLyrics(synced: false, lines: []);
  }

  final bool synced;
  final List<SubsonicLyricLine> lines;

  bool get hasContent =>
      lines.any((line) => line.value.trim().isNotEmpty);

  /// Converts to plain text; synced lyrics become standard `[mm:ss.xx]`
  /// LRC lines that the shared LyricParser understands.
  String toLrcText() {
    final buffer = StringBuffer();
    for (final line in lines) {
      if (valueless(line)) {
        continue;
      }
      final start = line.startMs;
      if (synced && start != null) {
        buffer.writeln('[${formatLrcTimestamp(start)}]${line.value}');
      } else {
        buffer.writeln(line.value);
      }
    }
    return buffer.toString().trim();
  }

  static bool valueless(SubsonicLyricLine line) =>
      line.value.trim().isEmpty;
}

/// Formats milliseconds as a LRC timestamp `mm:ss.xx`.
String formatLrcTimestamp(int ms) {
  final minutes = ms ~/ 60000;
  final seconds = (ms % 60000) ~/ 1000;
  final centis = (ms % 1000) ~/ 10;
  return '${minutes.toString().padLeft(2, '0')}'
      ':${seconds.toString().padLeft(2, '0')}'
      '.${centis.toString().padLeft(2, '0')}';
}

/// Thrown when the server answers a valid HTTP response whose
/// `subsonic-response.status` is `failed`.
class SubsonicException implements Exception {
  const SubsonicException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'SubsonicException($code): $message';
}
