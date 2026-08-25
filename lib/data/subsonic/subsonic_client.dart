import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:whisplayer/data/subsonic/subsonic_models.dart';
/// Minimal read-only client for the Subsonic REST API (Navidrome and
/// compatible self-hosted music servers).
///
/// The base URL is normalized to point at the server's `/rest` endpoint.
class SubsonicClient {
  /// Creates a client for [baseUrl] (e.g. `http://192.168.1.10:4533`).
  ///
  /// [client] is injectable for testing.
  SubsonicClient({
    required String baseUrl,
    required this.username,
    required String password,
    http.Client? client,
    this.clientName = 'whisplayer',
    this.apiVersion = '1.16.1',
  })  : _client = client ?? http.Client(),
        // Named parameters cannot be private, so the lint suggestion of an
        // initializing formal is unavailable here.
        // ignore: prefer_initializing_formals
        _password = password {
    restRoot = normalizeBaseUrl(baseUrl);
  }

  /// Normalizes a user-typed server address into a
  /// `<scheme>://<host>[:port][/path]/rest` root.
  ///
  /// Tolerates the common typos: missing scheme (`192.168.1.10:4533`),
  /// single-slash scheme (`http:/host`) and triple slashes. Throws
  /// [FormatException] with a user-presentable message when nothing usable
  /// remains.
  static String normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Server address is required');
    }
    final match =
        RegExp(r'^(https?):/{0,3}(.*)$', caseSensitive: false)
            .firstMatch(trimmed);
    final scheme = (match?.group(1) ?? 'http').toLowerCase();
    var rest = match?.group(2) ?? trimmed;
    while (rest.startsWith('/')) {
      rest = rest.substring(1);
    }
    if (rest.isEmpty) {
      throw FormatException('Missing host in server address: $raw');
    }
    var url = '$scheme://$rest';
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.toLowerCase().endsWith('/rest')) {
      url = '$url/rest';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw FormatException('Cannot parse server address: $raw');
    }
    return url;
  }

  final String username;
  final String clientName;
  final String apiVersion;
  final http.Client _client;
  final String _password;

  late final String restRoot;
  final Random _random = Random.secure();

  /// Authenticates against the server; throws [SubsonicException] when the
  /// server reports a failure (bad credentials, wrong protocol version...).
  Future<void> ping() async {
    final response = await _get('ping');
    _assertOk(response);
  }

  /// Lists albums ordered alphabetically by name.
  Future<List<SubsonicAlbum>> getAlbumList2({
    int size = 30,
    int offset = 0,
  }) async {
    final response = await _get(
      'getAlbumList2',
      queryParameters: {
        'type': 'alphabeticalByName',
        'size': '$size',
        'offset': '$offset',
      },
    );
    final payload = response['albumList2'] as Map<String, dynamic>?;
    final albums = payload?['album'] as List<dynamic>?;
    return albums
            ?.whereType<Map<String, dynamic>>()
            .map(SubsonicAlbum.fromJson)
            .toList() ??
        const <SubsonicAlbum>[];
  }

  /// Fetches one album together with its songs.
  Future<SubsonicAlbumDetail> getAlbum(String albumId) async {
    final response = await _get(
      'getAlbum',
      queryParameters: {'id': albumId},
    );
    final albumJson =
        response['album'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final songs = albumJson['song'] as List<dynamic>?;
    return SubsonicAlbumDetail(
      album: SubsonicAlbum.fromJson(albumJson),
      songs: songs
              ?.whereType<Map<String, dynamic>>()
              .map(SubsonicSong.fromJson)
              .toList() ??
          const <SubsonicSong>[],
    );
  }

  /// Fuzzy server-side search across songs and albums.
  Future<SubsonicSearchResult> search3(
    String query, {
    int songCount = 20,
    int albumCount = 10,
  }) async {
    final response = await _get(
      'search3',
      queryParameters: {
        'query': query,
        'songCount': '$songCount',
        'albumCount': '$albumCount',
      },
    );
    final payload = response['searchResult3'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final albums = payload['album'] as List<dynamic>?;
    final songs = payload['song'] as List<dynamic>?;
    return SubsonicSearchResult(
      albums: albums
              ?.whereType<Map<String, dynamic>>()
              .map(SubsonicAlbum.fromJson)
              .toList() ??
          const <SubsonicAlbum>[],
      songs: songs
              ?.whereType<Map<String, dynamic>>()
              .map(SubsonicSong.fromJson)
              .toList() ??
          const <SubsonicSong>[],
    );
  }

  /// Fetches OpenSubsonic structured lyrics for [songId]; returns null when
  /// the server answers without usable lyric lines.
  Future<SubsonicLyrics?> getLyricsBySongId(String songId) async {
    final response = await _get(
      'getLyricsBySongId',
      queryParameters: {'id': songId},
    );
    final lyrics = SubsonicLyrics.fromStructuredJson(
      response['lyricsList'] as Map<String, dynamic>?,
    );
    return lyrics.hasContent ? lyrics : null;
  }

  /// Classic Subsonic plain-text lyrics lookup by artist/title. Returns the
  /// raw value (which may itself be LRC-formatted), or null when empty.
  Future<String?> getPlainLyrics({
    required String artist,
    required String title,
  }) async {
    final response = await _get(
      'getLyrics',
      queryParameters: {'artist': artist, 'title': title},
    );
    final lyrics = response['lyrics'] as Map<String, dynamic>?;
    final value = lyrics?['value'] as String?;
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  /// Builds an authenticated streaming URI for [songId]. No network call is
  /// made here; the URI is handed to the audio player.
  Uri streamUri(String songId) {
    return _buildUri(
      'stream',
      queryParameters: {'id': songId},
    );
  }

  /// Builds an authenticated cover art URI for [coverArtId].
  Uri coverArtUri(String coverArtId, {int? size}) {
    return _buildUri(
      'getCoverArt',
      queryParameters: {
        'id': coverArtId,
        if (size != null) 'size': '$size',
      },
    );
  }

  /// Fetches raw bytes for a URI built by this client (e.g. [coverArtUri]).
  /// Throws [SubsonicException] on non-200 responses.
  Future<List<int>> getBytes(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw SubsonicException(
        response.statusCode,
        'HTTP ${response.statusCode} from ${uri.path}',
      );
    }
    return response.bodyBytes;
  }

  Map<String, String> _authQueryParameters() {
    final salt = _generateSalt();
    final token = md5.convert(utf8.encode('$_password$salt')).toString();
    return {
      'u': username,
      't': token,
      's': salt,
      'v': apiVersion,
      'c': clientName,
      'f': 'json',
    };
  }

  Uri _buildUri(
    String endpoint, {
    Map<String, String> queryParameters = const {},
  }) {
    // Bare endpoint paths only: some servers (e.g. Navidrome 0.63+) do not
    // serve the `.json`/`.view` extension variants; JSON is selected via the
    // mandatory f=json auth parameter instead.
    return Uri.parse(restRoot).replace(
      pathSegments: [
        ...Uri.parse(restRoot).pathSegments,
        endpoint,
      ],
      queryParameters: {
        ..._authQueryParameters(),
        ...queryParameters,
      },
    );
  }

  Future<Map<String, dynamic>> _get(
    String endpoint, {
    Map<String, String> queryParameters = const {},
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw SubsonicException(
        response.statusCode,
        'HTTP ${response.statusCode} from ${uri.path}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['subsonic-response'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
  }

  void _assertOk(Map<String, dynamic> response) {
    if (response['status'] == 'ok') {
      return;
    }
    final error = response['error'] as Map<String, dynamic>?;
    throw SubsonicException(
      (error?['code'] as num?)?.toInt() ?? -1,
      error?['message'] as String? ?? 'unknown subsonic error',
    );
  }

  String _generateSalt() {
    const chars = '0123456789abcdef';
    return List.generate(
      12,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
