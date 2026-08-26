/// A single audio file as returned by the Navidrome native API
/// (`GET /api/song`). Only fields Whisplayer consumes are parsed; the
/// endpoint returns many more.
class NavidromeSong {
  const NavidromeSong({
    required this.id,
    required this.path,
    required this.title,
    required this.album,
    required this.artist,
    required this.suffix,
    required this.durationSec,
    required this.sizeBytes,
    required this.hasCoverArt,
    this.trackNumber,
    this.year,
    this.bitRate,
    this.albumId,
  });

  factory NavidromeSong.fromJson(Map<String, dynamic> json) {
    return NavidromeSong(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      title: json['title'] as String? ?? '',
      album: json['album'] as String?,
      artist: json['artist'] as String?,
      suffix: json['suffix'] as String? ?? '',
      durationSec: (json['duration'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      hasCoverArt: json['hasCoverArt'] as bool? ?? false,
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      bitRate: (json['bitRate'] as num?)?.toInt(),
      albumId: json['albumId'] as String?,
    );
  }

  /// Relative path inside the music library, e.g.
  /// `RJ01003442/本編/1.wav`. The first segment is the work folder name.
  final String path;
  final String id;
  final String title;
  final String? album;
  final String? artist;
  final String suffix;
  final int durationSec;
  final int sizeBytes;
  final bool hasCoverArt;
  final int? trackNumber;
  final int? year;
  final int? bitRate;
  final String? albumId;

  /// First path segment, i.e. the work folder (RJ number) this file lives in.
  String get folderName {
    final slash = path.indexOf('/');
    return slash <= 0 ? path : path.substring(0, slash);
  }
}

/// Raised when login fails or a native-API request is rejected.
class NavidromeException implements Exception {
  const NavidromeException(this.message);

  final String message;

  @override
  String toString() => 'NavidromeException: $message';
}

/// Parsed `POST /auth/login` payload.
class NavidromeSession {
  const NavidromeSession({required this.token});

  factory NavidromeSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const NavidromeException('login response has no token');
    }
    return NavidromeSession(token: token);
  }

  final String token;
}

Map<String, dynamic> navidromeLoginBody(String username, String password) =>
    <String, dynamic>{'username': username, 'password': password};
