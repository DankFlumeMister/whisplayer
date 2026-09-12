import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// One resource returned by a WebDAV PROPFIND request.
///
/// [path] is the decoded, human-readable path (Japanese names stay intact);
/// [name] is the last segment of it. Only meaningful for files — collections
/// report `null` for [sizeBytes] and [contentType].
class WebDavEntry {
  const WebDavEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.sizeBytes,
    this.modifiedAt,
    this.contentType,
  });

  /// Server-relative path, always starting with `/`, no trailing slash.
  final String path;

  /// Last path segment — the file or directory name.
  final String name;

  /// Whether the resource is a collection (directory).
  final bool isDirectory;

  /// Byte length of the resource; `null` for directories.
  final int? sizeBytes;

  /// Last modification time reported by the server.
  final DateTime? modifiedAt;

  /// MIME type reported by the server; `null` for directories.
  final String? contentType;
}

/// Normalizes a server-relative path: leading slash present, trailing
/// slashes removed, backslashes folded to `/`.
String normalizeWebDavPath(String path) {
  var value = path.trim().isEmpty ? '/' : path.trim();
  if (!value.startsWith('/')) {
    value = '/$value';
  }
  while (value.length > 1 && value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/// Percent-encodes each segment so names containing spaces, `#` or CJK
/// characters survive, while `/` stays a separator.
///
/// Shared with the streaming path so a playable URL and a PROPFIND URL for
/// the same file cannot drift apart.
String encodeWebDavPath(String path) =>
    normalizeWebDavPath(path).split('/').map(Uri.encodeComponent).join('/');

/// Strips a `webdav://{serverId}` prefix, leaving the server-relative path
/// that a [WebDavClient] request expects.
///
/// The storage layer keeps entries under `webdav://{id}/...` so the local,
/// Navidrome, Subsonic and WebDAV libraries never collide in one library;
/// anything that talks to a specific server has to hand back the bare path.
/// A path without the prefix is returned unchanged.
String webDavRelativePath(String path) {
  const prefix = 'webdav://';
  if (!path.startsWith(prefix)) {
    return path;
  }
  final rest = path.substring(prefix.length);
  final slash = rest.indexOf('/');
  return slash < 0 ? '/' : rest.substring(slash);
}

/// The slice of [WebDavClient] that a directory walk needs.
///
/// A separate interface lets the storage source be tested against a fake
/// tree instead of a socket.
// ignore: one_member_abstracts
abstract interface class WebDavLister {
  /// Lists the children of [path]; see [WebDavClient.list].
  Future<List<WebDavEntry>> list(String path, {int depth});
}

/// Any failure talking to a WebDAV server.
class WebDavException implements Exception {
  /// Creates an exception with a user-presentable [message].
  WebDavException(this.message, {this.statusCode});

  /// Human-readable description of the failure.
  final String message;

  /// HTTP status code when the server answered at all.
  final int? statusCode;

  @override
  String toString() =>
      'WebDavException(${statusCode ?? 'no-status'}): $message';
}

/// Thrown when the server rejects the credentials (HTTP 401).
class WebDavAuthException extends WebDavException {
  /// Creates the exception.
  WebDavAuthException() : super('Authentication failed', statusCode: 401);
}

/// Thrown when the requested path does not exist (HTTP 404).
class WebDavNotFoundException extends WebDavException {
  /// Creates the exception for [path].
  WebDavNotFoundException(String path)
      : super('Not found: $path', statusCode: 404);
}

/// Minimal read-only WebDAV client.
///
/// Implements exactly what Whisplayer needs: `PROPFIND` for directory
/// listings and `GET` for bytes, with optional `Range` support for audio
/// streaming. Basic authentication carries a shared token as the password;
/// the username is ignored by the bundled server but kept for compatibility
/// with servers that require one.
///
/// Deliberately dependency-light and protocol-standard so it also works
/// against `rclone serve webdav`, a NAS's built-in service, or nginx — the
/// app is never locked to the bundled Python sidecar.
class WebDavClient implements WebDavLister {
  /// Creates a client for [baseUrl] (e.g. `http://192.168.1.10:8765`).
  ///
  /// [client] is injectable for testing.
  WebDavClient({
    required String baseUrl,
    required this.token,
    http.Client? client,
    this.username = 'whisplayer',
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _base = normalizeBaseUrl(baseUrl);

  /// Shared secret sent as the basic-auth password.
  final String token;

  /// Basic-auth username; ignored by the bundled sidecar.
  final String username;

  /// Per-request timeout. Directory walks rely on this to fail fast when a
  /// host goes away mid-scan.
  final Duration timeout;

  final http.Client _client;
  final bool _ownsClient;
  final String _base;

  /// Normalized root URL without a trailing slash.
  String get baseUrl => _base;

  /// Normalizes a user-typed address into `http(s)://host[:port][/path]`.
  ///
  /// Defaults to `http` when no scheme is given and tolerates the usual
  /// typos (single-slash scheme, triple slashes, trailing slash). Throws
  /// [FormatException] with a presentable message when nothing usable is
  /// left.
  static String normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Server address is required');
    }
    final match = RegExp(
      r'^(https?):/{0,3}(.*)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
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
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw FormatException('Cannot parse server address: $raw');
    }
    return url;
  }

  /// Checks credentials and reachability with a depth-0 PROPFIND on `/`.
  Future<void> ping() async {
    await list('/', depth: 0);
  }

  /// Lists the children of [path].
  ///
  /// [path] may be given with or without a leading slash. The collection
  /// itself is not included in the result. Throws [WebDavAuthException],
  /// [WebDavNotFoundException] or [WebDavException].
  @override
  Future<List<WebDavEntry>> list(String path, {int depth = 1}) async {
    final requestPath = _normalizePath(path);
    const body = '<?xml version="1.0" encoding="utf-8"?>'
        ' <d:propfind xmlns:d="DAV:"><d:allprop/></d:propfind>';
    final response = await _send(
      'PROPFIND',
      requestPath,
      headers: <String, String>{
        'Depth': '$depth',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      body: body,
    );
    if (response.statusCode != 207 && response.statusCode != 200) {
      throw _failure(response, requestPath);
    }
    // Decode from the raw bytes: many servers omit `charset=utf-8`, and
    // package:http would then fall back to latin-1 and mangle CJK names.
    final entries = _parseMultiStatus(response.bodyBytes);
    if (depth == 0) {
      return entries;
    }
    // Depth 1 also reports the collection itself — drop it.
    return entries
        .where((entry) => _normalizePath(entry.path) != requestPath)
        .toList(growable: false);
  }

  /// Downloads [path] and returns its bytes.
  ///
  /// When [start] is given, a `Range` header is sent; [end] is inclusive and
  /// may be omitted to request everything from [start] to EOF. A server that
  /// ignores `Range` answers 200 with the whole body, which callers accept.
  Future<Uint8List> getBytes(String path, {int? start, int? end}) async {
    final requestPath = _normalizePath(path);
    final headers = <String, String>{};
    if (start != null) {
      headers['Range'] = 'bytes=$start-${end ?? ''}';
    }
    final response = await _send('GET', requestPath, headers: headers);
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw _failure(response, requestPath);
    }
    return response.bodyBytes;
  }

  /// Reads a text resource (for example a sidecar lyrics file) as UTF-8.
  ///
  /// Decodes the raw response bytes so a server that omits
  /// `charset=utf-8` cannot mangle CJK lyrics. Returns `null` when the
  /// resource does not exist, the request fails, or the body is blank —
  /// a missing sidecar must never fail a scan.
  Future<String?> readTextFile(String path) async {
    final requestPath = _normalizePath(path);
    final response = await _send('GET', requestPath);
    if (response.statusCode != 200) {
      return null;
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    return text.isEmpty ? null : text;
  }

  /// Closes the HTTP client — only when this instance created it, so an
  /// injected test client is never closed behind the caller's back.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final uri = _uri(path);
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Basic ${_basicToken()}';
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      request.body = body;
    }
    try {
      final streamed = await _client.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException catch (_) {
      throw WebDavException('Request timed out after ${timeout.inSeconds}s');
    } on http.ClientException catch (e) {
      throw WebDavException(e.message);
    }
  }

  String _basicToken() => base64Encode(utf8.encode('$username:$token'));

  Uri _uri(String path) => Uri.parse('$_base${encodeWebDavPath(path)}');

  String _normalizePath(String path) => normalizeWebDavPath(path);

  WebDavException _failure(http.Response response, String path) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return WebDavAuthException();
    }
    if (response.statusCode == 404) {
      return WebDavNotFoundException(path);
    }
    return WebDavException(
      'Unexpected status ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
}

/// Every descendant element whose local name is [localName].
///
/// WebDAV servers disagree on the namespace prefix (`D:`, `d:`, or none), so
/// matching is done on the local name only. This also avoids the deprecated
/// `namespace` argument of `findAllElements`.
Iterable<XmlElement> _elementsNamed(XmlNode root, String localName) =>
    root.descendants.whereType<XmlElement>().where(
          (element) => element.name.local == localName,
        );

List<WebDavEntry> _parseMultiStatus(Uint8List body) {
  final document = XmlDocument.parse(utf8.decode(body, allowMalformed: true));
  final entries = <WebDavEntry>[];
  for (final response in _elementsNamed(document, 'response')) {
    final href = _childText(response, 'href');
    if (href == null || href.isEmpty) {
      continue;
    }
    final path = _decodeHref(href);
    final isDirectory = _isCollection(response);
    final name = _childText(response, 'displayname') ?? _nameOf(path);
    final size = int.tryParse(_childText(response, 'getcontentlength') ?? '');
    final modified = _parseHttpDate(
      _childText(response, 'getlastmodified') ?? '',
    );
    entries.add(
      WebDavEntry(
        path: path,
        name: name,
        isDirectory: isDirectory,
        sizeBytes: isDirectory ? null : size,
        modifiedAt: modified,
        contentType: isDirectory
            ? null
            : _childText(response, 'getcontenttype'),
      ),
    );
  }
  return entries;
}

String? _childText(XmlElement parent, String localName) {
  for (final element in _elementsNamed(parent, localName)) {
    final text = element.innerText.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

bool _isCollection(XmlElement response) {
  for (final resourcetype in _elementsNamed(response, 'resourcetype')) {
    for (final child in resourcetype.childElements) {
      if (child.name.local == 'collection') {
        return true;
      }
    }
  }
  return false;
}

/// Decodes an href that may be a full URL or a server-relative path.
String _decodeHref(String href) {
  var value = href;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    final uri = Uri.tryParse(value);
    value = uri?.path ?? value;
  }
  if (!value.startsWith('/')) {
    value = '/$value';
  }
  while (value.length > 1 && value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return _percentDecode(value);
}

/// Percent-decodes [value], tolerating a stray `%`.
///
/// `Uri.decodeComponent` throws [ArgumentError] on a malformed escape, which
/// is an [Error] and therefore not something to catch. Decoding by hand also
/// lets mixed content survive: an unencoded CJK character folded in as UTF-8
/// alongside properly escaped bytes.
String _percentDecode(String value) {
  final bytes = <int>[];
  var sawEscape = false;
  for (var i = 0; i < value.length; i++) {
    if (value[i] == '%' && i + 2 < value.length) {
      final byte = int.tryParse(value.substring(i + 1, i + 3), radix: 16);
      if (byte != null) {
        bytes.add(byte);
        sawEscape = true;
        i += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(value[i]));
  }
  if (!sawEscape) {
    return value;
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _nameOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}

/// Parses an RFC 1123 date, returning `null` instead of throwing.
///
/// `HttpDate` lives in `dart:io`, so it is avoided here: keeping the client
/// `dart:io`-free lets it run in any test without platform channels.
/// ISO-8601 is tried first, then the `Sun, 06 Nov 1994 08:49:37 GMT` shape.
DateTime? _parseHttpDate(String value) {
  if (value.isEmpty) {
    return null;
  }
  final direct = DateTime.tryParse(value);
  if (direct != null) {
    return direct;
  }
  // "Wed, 09 Sep 2026 10:00:00 GMT"
  final parts = value.split(' ');
  if (parts.length < 4) {
    return null;
  }
  const months = <String, int>{
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  final day = int.tryParse(parts[1]);
  final month = months[parts[2]];
  final year = int.tryParse(parts[3]);
  if (day == null || month == null || year == null) {
    return null;
  }
  var hour = 0;
  var minute = 0;
  var second = 0;
  if (parts.length > 4) {
    final clock = parts[4].split(':');
    if (clock.length == 3) {
      hour = int.tryParse(clock[0]) ?? 0;
      minute = int.tryParse(clock[1]) ?? 0;
      second = int.tryParse(clock[2]) ?? 0;
    }
  }
  return DateTime.utc(year, month, day, hour, minute, second);
}
