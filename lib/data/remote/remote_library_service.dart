import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'package:whisplayer/data/subsonic/subsonic_client.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/entities/scanned_song.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/domain/repositories/library_repository.dart';
import 'package:whisplayer/domain/repositories/library_writer_repository.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';

const String subsonicScheme = 'subsonic';

/// Encodes a remote song's stable identity as the library-unique `path`.
///
/// Deliberately parsed by hand (not [Uri]) so song ids keep their case.
String encodeSubsonicPath(int serverId, String songId) =>
    '$subsonicScheme://$serverId/$songId';

({int serverId, String songId})? decodeSubsonicPath(String path) {
  const prefix = '$subsonicScheme://';
  if (!path.startsWith(prefix)) {
    return null;
  }
  final rest = path.substring(prefix.length);
  final slash = rest.indexOf('/');
  if (slash <= 0 || slash == rest.length - 1) {
    return null;
  }
  final serverId = int.tryParse(rest.substring(0, slash));
  if (serverId == null) {
    return null;
  }
  return (serverId: serverId, songId: rest.substring(slash + 1));
}

/// Signature for injecting pre-configured clients (tests).
typedef SubsonicClientFactory = SubsonicClient Function(
  String baseUrl,
  String username,
  String password,
);

/// Bridges the Subsonic server world and the local library: lazily syncs
/// browsed albums into the `songs` table and resolves logical
/// `subsonic://` paths into authenticated stream URIs for playback.
class RemoteLibraryService {
  RemoteLibraryService(
    this._servers,
    this._writer,
    this._library, {
    SubsonicClientFactory? clientFactory,
  })  : // Named parameters cannot be private, so an initializing formal is
        // unavailable here (same constraint as SubsonicClient's password).
        // ignore: prefer_initializing_formals
        _clientFactory = clientFactory;

  final RemoteServerRepository _servers;
  final LibraryWriterRepository _writer;
  final LibraryRepository _library;
  final SubsonicClientFactory? _clientFactory;

  /// Builds an authenticated client for [server].
  Future<SubsonicClient> clientFor(RemoteServer server) async {
    final password = await _servers.getPassword(server.id);
    if (password == null) {
      throw StateError('no stored password for server ${server.id}');
    }
    final factory = _clientFactory;
    if (factory != null) {
      return factory(server.baseUrl, server.username, password);
    }
    return SubsonicClient(
      baseUrl: server.baseUrl,
      username: server.username,
      password: password,
    );
  }

  Future<SubsonicClient> clientForServerId(int serverId) async {
    final match = await _findServer(serverId);
    return clientFor(match);
  }

  Future<List<SubsonicAlbum>> fetchAlbums(
    int serverId, {
    int size = 100,
    int offset = 0,
  }) async {
    final client = await clientForServerId(serverId);
    return client.getAlbumList2(size: size, offset: offset);
  }

  Future<SubsonicAlbumDetail> fetchAlbum(int serverId, String albumId) async {
    final client = await clientForServerId(serverId);
    return client.getAlbum(albumId);
  }

  /// Server-side fuzzy search across songs and albums.
  Future<SubsonicSearchResult> search(
    int serverId,
    String query, {
    int songCount = 20,
    int albumCount = 10,
  }) async {
    final client = await clientForServerId(serverId);
    return client.search3(
      query,
      songCount: songCount,
      albumCount: albumCount,
    );
  }

  /// Fetches lyric text for a remote song: OpenSubsonic structured lyrics
  /// (converted to LRC text) with a classic plain-text fallback. Any
  /// failure yields null so the caller degrades to "no lyrics".
  Future<String?> fetchLyricsText(Song song) async {
    final parsed = decodeSubsonicPath(song.path);
    if (parsed == null) {
      return null;
    }
    RemoteServer? server;
    for (final candidate in await _servers.getServers()) {
      if (candidate.id == parsed.serverId) {
        server = candidate;
        break;
      }
    }
    if (server == null) {
      return null;
    }
    try {
      final client = await clientFor(server);
      final structured = await client.getLyricsBySongId(parsed.songId);
      if (structured != null) {
        return structured.toLrcText();
      }
      final plain = await client.getPlainLyrics(
        artist: song.artistName ?? '',
        title: song.title,
      );
      return (plain == null || plain.trim().isEmpty) ? null : plain;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Makes sure [remoteSong] exists in the local library (syncing its whole
  /// album like a browse would) and returns the synced local song.
  Future<Song?> ensureSongSynced(
    RemoteServer server,
    SubsonicSong remoteSong,
  ) async {
    final albumRef = remoteSong.albumId;
    if (albumRef == null) {
      return null;
    }
    final detail = await fetchAlbum(server.id, albumRef);
    final localAlbumId = await syncAlbumToLibrary(
      server: server,
      detail: detail,
    );
    if (localAlbumId == null) {
      return null;
    }
    final wantedPath = encodeSubsonicPath(server.id, remoteSong.id);
    for (final song in await _library.songsByAlbum(localAlbumId)) {
      if (song.path == wantedPath) {
        return song;
      }
    }
    return null;
  }

  /// Upserts every song of [detail] into the local library (idempotent,
  /// keyed by the encoded subsonic path) and returns the local album id,
  /// or null when the album had no songs.
  ///
  /// When the album (or its first song) carries cover art, it is downloaded
  /// once into a local cache directory and attached to both the songs and
  /// the album rows; download failures never block syncing.
  Future<int?> syncAlbumToLibrary({
    required RemoteServer server,
    required SubsonicAlbumDetail detail,
  }) async {
    final artworkPath = await _cacheAlbumCover(server, detail);
    int? firstSongId;
    for (final remoteSong in detail.songs) {
      final id = await _writer.upsertScannedSong(
        _toScannedSong(
          server.id,
          detail.album,
          remoteSong,
          artworkPath: artworkPath,
        ),
      );
      firstSongId ??= id;
    }
    if (firstSongId == null) {
      return null;
    }
    final song = await _library.getSong(firstSongId);
    return song?.albumId;
  }

  /// Downloads [coverArtId] once into a per-server cache file and returns
  /// its local path. Returns an existing cache hit immediately; any failure
  /// yields null so callers can degrade to placeholder art.
  Future<String?> cacheCover({
    required RemoteServer server,
    required String coverArtId,
    int size = 300,
    Directory? baseDir,
  }) async {
    Directory dir;
    try {
      dir = baseDir ??
          await getApplicationDocumentsDirectory()
              .then((docs) => Directory('${docs.path}/covers'));
    } on Exception catch (_) {
      return null;
    }
    final digest = md5.convert(utf8.encode(coverArtId)).toString();
    final file = File(
      '${dir.path}${Platform.pathSeparator}${server.id}_$digest.jpg',
    );
    if (file.existsSync()) {
      return file.path;
    }
    try {
      final client = await clientFor(server);
      final bytes = Uint8List.fromList(
        await client.getBytes(client.coverArtUri(coverArtId, size: size)),
      );
      if (bytes.isEmpty) {
        return null;
      }
      await dir.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on Exception catch (_) {
      return null;
    }
  }

  Future<String?> _cacheAlbumCover(
    RemoteServer server,
    SubsonicAlbumDetail detail,
  ) async {
    final coverArtId = detail.album.coverArt ??
        detail.songs.map((s) => s.coverArt).firstWhere(
              (id) => id != null && id.isNotEmpty,
              orElse: () => null,
            );
    if (coverArtId == null || coverArtId.isEmpty) {
      return null;
    }
    return cacheCover(server: server, coverArtId: coverArtId);
  }

  /// Resolves a logical `subsonic://{serverId}/{songId}` path into an
  /// authenticated streaming URI. No network call is made here; the URI is
  /// handed to the audio engine which streams from it.
  Future<Uri> resolveStreamUri(String logicalPath) async {
    final parsed = decodeSubsonicPath(logicalPath);
    if (parsed == null) {
      throw FormatException('not a subsonic library path', logicalPath);
    }
    final server = await _findServer(parsed.serverId);
    final client = await clientFor(server);
    return client.streamUri(parsed.songId);
  }

  Future<RemoteServer> _findServer(int serverId) async {
    for (final server in await _servers.getServers()) {
      if (server.id == serverId) {
        return server;
      }
    }
    throw StateError('unknown remote server $serverId');
  }

  ScannedSong _toScannedSong(
    int serverId,
    SubsonicAlbum album,
    SubsonicSong song, {
    String? artworkPath,
  }) {
    final format = song.suffix ?? '';
    return ScannedSong(
      path: encodeSubsonicPath(serverId, song.id),
      sourceType: SourceType.remote,
      title: song.title,
      fileName: '${song.title}'
          '${format.isEmpty ? '' : '.$format'}',
      format: format,
      durationMs: song.durationSec * 1000,
      fileSizeBytes: 0,
      modifiedAtMs: DateTime.now().millisecondsSinceEpoch,
      artistName: song.artist,
      albumTitle:
          album.name.isEmpty ? null : album.name,
      trackNumber: song.track,
      year: album.year,
      bitrateKbps: song.bitRate,
      artworkPath: artworkPath,
    );
  }
}
