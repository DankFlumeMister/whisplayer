import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:whisplayer/data/navidrome/navidrome_models.dart';

/// Minimal client for the Navidrome native (non-Subsonic) REST API.
///
/// Whisplayer uses it for one thing the Subsonic protocol cannot do on
/// Navidrome 0.63: enumerating the music library's real folder tree.
/// `GET /api/song` returns every audio file with its library-relative
/// path, from which the work-folder structure is rebuilt client-side.
class NavidromeClient {
  /// Creates a client for [baseUrl], e.g. `http://192.168.1.10:4533`.
  ///
  /// [client] is injectable for testing.
  NavidromeClient({
    required String baseUrl,
    required this.username,
    required String password,
    http.Client? client,
    int pageSize = _defaultPageSize,
  })  :
        // Private fields cannot use initializing formals as named params.
        // ignore: prefer_initializing_formals
        _password = password,
        // Same constraint applies to the page size knob.
        // ignore: prefer_initializing_formals
        _pageSize = pageSize,
        _base = _normalizeOrigin(baseUrl),
        _client = client ?? http.Client();

  /// Normalizes the stored server address into an absolute origin the
  /// native API can be joined onto. Mirrors the Subsonic client's
  /// normalizeBaseUrl tolerances (missing scheme, trailing slashes) and
  /// strips a `/rest` suffix users copy from Subsonic-oriented configs.
  static String _normalizeOrigin(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      throw const NavidromeException('Server address is required');
    }
    final lower = value.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      value = 'http://$value';
    }
    final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      throw NavidromeException('Cannot parse server address: $raw');
    }
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw NavidromeException('Cannot parse server address: $raw');
    }
    final buffer = StringBuffer('${uri.scheme}://${uri.host}');
    if (uri.hasPort) {
      buffer.write(':${uri.port}');
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.toLowerCase().endsWith('/rest')) {
      path = path.substring(0, path.length - '/rest'.length);
    }
    buffer.write(path);
    return buffer.toString();
  }

  static const int _defaultPageSize = 2000;

  final String username;
  final http.Client _client;
  final String _password;
  final String _base;
  final int _pageSize;

  NavidromeSession? _session;
  String get _token => _session!.token;

  Map<String, String> get _authHeaders => <String, String>{
        'x-nd-authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$_base$path'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      final snippet = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );
      throw NavidromeException(
        'HTTP ${response.statusCode} from $path: '
        '${snippet.length > 80 ? snippet.substring(0, 80) : snippet}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
  }

  Future<http.Response> _getAuthorized(String path) async {
    var response = await _client.get(
      Uri.parse('$_base$path'),
      headers: _authHeaders,
    );
    if (response.statusCode == 401 && _session != null) {
      // Token expired (48h validity) — refresh once and retry.
      await login();
      response = await _client.get(
        Uri.parse('$_base$path'),
        headers: _authHeaders,
      );
    }
    return response;
  }

  /// Authenticates and caches the JWT session.
  Future<void> login() async {
    try {
      _session = NavidromeSession.fromJson(
        await _postJson('/auth/login', navidromeLoginBody(username, _password)),
      );
    } on NavidromeException {
      rethrow;
    } on FormatException {
      throw const NavidromeException('invalid login response');
    }
  }

  /// Fetches every audio file of the library, paging internally until the
  /// server-reported total is reached. Returns songs ordered by path.
  Future<List<NavidromeSong>> fetchAllSongs({
    void Function(int received, int total)? onProgress,
  }) async {
    if (_session == null) {
      await login();
    }
    final songs = <NavidromeSong>[];
    var total = -1;
    while (total < 0 || songs.length < total) {
      final start = songs.length;
      final response = await _getAuthorized(
        '/api/song?_start=$start&_end=${start + _pageSize}',
      );
      if (response.statusCode != 200) {
        throw NavidromeException(
          'HTTP ${response.statusCode} from /api/song',
        );
      }
      final headerTotal = response.headers['x-total-count'];
      if (headerTotal != null) {
        total = int.tryParse(headerTotal) ?? total;
      }
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (decoded.isEmpty) {
        break;
      }
      songs.addAll([
        for (final row in decoded)
          NavidromeSong.fromJson(row as Map<String, dynamic>),
      ]);
      onProgress?.call(songs.length, total);
    }
    return songs;
  }

  /// Releases the HTTP client; the service layer owns the lifecycle.
  void dispose() => _client.close();
}
