import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/remote/remote_library_service.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

const String _keyActiveServer = 'remote.active_server_id';
const String _keyBrowseMode = 'cloud.browse_mode';
const String _keyAlbumSort = 'cloud.album_sort';
const String _keyAlbumDesc = 'cloud.album_desc';
const String _keyAlbumsView = 'cloud.albums_view';
const String _keyFolderSort = 'cloud.folder_sort';
const String _keyFolderDesc = 'cloud.folder_desc';
const String _keyFoldersView = 'cloud.folders_view';

/// One page of getAlbumList2 is the protocol maximum; a full sweep needs at
/// most a couple of round trips for realistic libraries.
const int _albumPageSize = 500;

enum _CloudMode { albums, folders }

enum _AlbumSort { name, artist, recent, songs }

enum _FolderSort { name, songs }

enum _CloudView { list, grid }

class RemoteAlbumsPage extends ConsumerStatefulWidget {
  const RemoteAlbumsPage({super.key});

  @override
  ConsumerState<RemoteAlbumsPage> createState() => _RemoteAlbumsPageState();
}

class _RemoteAlbumsPageState extends ConsumerState<RemoteAlbumsPage> {
  List<RemoteServer> _servers = const <RemoteServer>[];
  RemoteServer? _server;
  List<SubsonicAlbum>? _albums;
  List<RemoteFolderSummary>? _folders;

  _CloudMode _mode = _CloudMode.albums;

  _AlbumSort _albumSort = _AlbumSort.name;
  bool _albumDesc = false;
  _CloudView _albumsView = _CloudView.grid;

  _FolderSort _folderSort = _FolderSort.name;
  bool _folderDesc = false;
  _CloudView _foldersView = _CloudView.list;

  bool _loading = false;
  bool _opening = false;
  String? _openingAlbumId;
  String? _error;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await _restorePrefs();
    await _load();
  }

  Future<void> _restorePrefs() async {
    final repo = ref.read(settingsRepositoryProvider);
    try {
      final mode = await repo.getString(_keyBrowseMode);
      if (mode == 'folders') {
        _mode = _CloudMode.folders;
      }
      final albumSort = await repo.getString(_keyAlbumSort);
      _albumSort = _parseAlbumSort(albumSort);
      _albumDesc = await repo.getString(_keyAlbumDesc) == 'true';
      final albumsView = await repo.getString(_keyAlbumsView);
      if (albumsView == 'list') {
        _albumsView = _CloudView.list;
      }
      final folderSort = await repo.getString(_keyFolderSort);
      _folderSort = _parseFolderSort(folderSort);
      _folderDesc = await repo.getString(_keyFolderDesc) == 'true';
      final foldersView = await repo.getString(_keyFoldersView);
      if (foldersView == 'grid') {
        _foldersView = _CloudView.grid;
      }
      if (mounted) {
        setState(() {});
      }
    } on Exception {
      // Settings storage unavailable (tests / first run) — keep defaults.
    }
  }

  _AlbumSort _parseAlbumSort(String? raw) {
    switch (raw) {
      case 'artist':
        return _AlbumSort.artist;
      case 'recent':
        return _AlbumSort.recent;
      case 'songs':
        return _AlbumSort.songs;
      default:
        return _AlbumSort.name;
    }
  }

  _FolderSort _parseFolderSort(String? raw) {
    return raw == 'songs' ? _FolderSort.songs : _FolderSort.name;
  }

  void _persist(String key, String value) {
    unawaited(
      ref.read(settingsRepositoryProvider).setString(key, value),
    );
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final servers =
          await ref.read(remoteServerRepositoryProvider).getServers();
      if (!mounted) {
        return;
      }
      if (servers.isEmpty) {
        setState(() {
          _error = AppLocalizations.of(context).noServer;
        });
        return;
      }
      final savedId = int.tryParse(
            await ref.read(settingsRepositoryProvider).getString(
                  _keyActiveServer,
                ) ??
                '',
          ) ??
          -1;
      var server = servers.first;
      for (final candidate in servers) {
        if (candidate.id == savedId) {
          server = candidate;
        }
      }
      if (_mode == _CloudMode.albums) {
        final albums = await _fetchAllAlbums(server.id, refresh: refresh);
        if (!mounted) {
          return;
        }
        setState(() {
          _servers = servers;
          _server = server;
          _albums = albums;
        });
      } else {
        final folders = await ref
            .read(remoteLibraryServiceProvider)
            .indexFolders(server.id, refresh: refresh);
        if (!mounted) {
          return;
        }
        setState(() {
          _servers = servers;
          _server = server;
          _folders = folders;
        });
      }
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() => _error = '${l10n.loadFailedPrefix}: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<SubsonicAlbum>> _fetchAllAlbums(
    int serverId, {
    required bool refresh,
  }) async {
    if (!refresh) {
      final cached = _albums;
      if (cached != null) {
        return cached;
      }
    }
    final all = <SubsonicAlbum>[];
    var offset = 0;
    while (true) {
      final page = await ref
          .read(remoteLibraryServiceProvider)
          .fetchAlbums(serverId, size: _albumPageSize, offset: offset);
      all.addAll(page);
      if (page.length < _albumPageSize || offset > 10000) {
        break;
      }
      offset += page.length;
    }
    return all;
  }

  void _switchMode(_CloudMode mode) {
    if (mode == _mode) {
      return;
    }
    setState(() => _mode = mode);
    _persist(_keyBrowseMode, mode == _CloudMode.folders ? 'folders' : 'albums');
    final hasData =
        mode == _CloudMode.folders ? _folders != null : _albums != null;
    if (!hasData) {
      unawaited(_load());
    }
  }

  List<SubsonicAlbum> get _sortedAlbums {
    final albums = _albums ?? const <SubsonicAlbum>[];
    final sorted = [...albums];

    // Each field defines its own natural direction; "recent added" naturally
    // shows newest first, everything else ascending. The descending switch
    // simply reverses whatever is on screen.
    int fieldCompare(SubsonicAlbum a, SubsonicAlbum b) {
      switch (_albumSort) {
        case _AlbumSort.artist:
          return (a.artist ?? '')
              .toLowerCase()
              .compareTo((b.artist ?? '').toLowerCase());
        case _AlbumSort.recent:
          return b.created.compareTo(a.created);
        case _AlbumSort.songs:
          return a.songCount.compareTo(b.songCount);
        case _AlbumSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    final direction = _albumDesc ? -1 : 1;
    int signed(SubsonicAlbum a, SubsonicAlbum b) =>
        direction * fieldCompare(a, b);
    sorted.sort(signed);
    return sorted;
  }

  List<RemoteFolderSummary> get _visibleFolders =>
      _sortFolders(_folders ?? const <RemoteFolderSummary>[]);

  List<RemoteFolderSummary> _sortFolders(
    List<RemoteFolderSummary> folders,
  ) {
    int comparator(RemoteFolderSummary a, RemoteFolderSummary b) =>
        _folderSort == _FolderSort.songs
            ? a.songCount.compareTo(b.songCount)
            : a.name.compareTo(b.name);
    final direction = _folderDesc ? -1 : 1;
    int signed(RemoteFolderSummary a, RemoteFolderSummary b) =>
        direction * comparator(a, b);
    final sorted = [...folders]..sort(signed);
    return sorted;
  }

  void _showSortSheet() {
    final l10n = AppLocalizations.of(context);
    final isAlbums = _mode == _CloudMode.albums;
    final entries = <Object, String>{
      if (isAlbums) ...<_AlbumSort, String>{
        _AlbumSort.name: l10n.sortTitle,
        _AlbumSort.artist: l10n.sortArtist,
        _AlbumSort.recent: l10n.sortAddedAt,
        _AlbumSort.songs: l10n.sortSongsCount,
      },
      if (!isAlbums) ...<_FolderSort, String>{
        _FolderSort.name: l10n.sortTitle,
        _FolderSort.songs: l10n.sortSongsCount,
      },
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing: _sortSelectionMarker(entry.key),
                  onTap: () {
                    setState(() {
                      if (entry.key is _AlbumSort) {
                        _albumSort = entry.key as _AlbumSort;
                        // Every field starts in its natural order.
                        _albumDesc = false;
                      } else {
                        _folderSort = entry.key as _FolderSort;
                        _folderDesc = false;
                      }
                    });
                    Navigator.pop(sheetContext);
                    _persistCurrentSort(entry.key);
                    _persist(
                      entry.key is _AlbumSort
                          ? _keyAlbumDesc
                          : _keyFolderDesc,
                      'false',
                    );
                  },
                ),
              SwitchListTile(
                title: Text(l10n.sortDescending),
                value: isAlbums ? _albumDesc : _folderDesc,
                onChanged: (v) {
                  setState(() {
                    if (isAlbums) {
                      _albumDesc = v;
                    } else {
                      _folderDesc = v;
                    }
                  });
                  Navigator.pop(sheetContext);
                  _persist(
                    isAlbums ? _keyAlbumDesc : _keyFolderDesc,
                    '$v',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _sortSelectionMarker(Object key) {
    final selected = key is _AlbumSort ? key == _albumSort : key == _folderSort;
    return selected ? const Icon(Icons.check) : null;
  }

  void _persistCurrentSort(Object key) {
    if (key is _AlbumSort) {
      _persist(_keyAlbumSort, key.name);
    } else if (key is _FolderSort) {
      _persist(_keyFolderSort, key.name);
    }
  }

  void _toggleView() {
    setState(() {
      if (_mode == _CloudMode.albums) {
        _albumsView =
            _albumsView == _CloudView.grid ? _CloudView.list : _CloudView.grid;
        _persist(_keyAlbumsView, _albumsView.name);
      } else {
        _foldersView =
            _foldersView == _CloudView.grid ? _CloudView.list : _CloudView.grid;
        _persist(_keyFoldersView, _foldersView.name);
      }
    });
  }

  Future<void> _switchServer(RemoteServer server) async {
    if (server.id == _server?.id) {
      return;
    }
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyActiveServer, '${server.id}');
    _albums = null;
    _folders = null;
    await _load(refresh: true);
  }

  Future<void> _openAlbum(SubsonicAlbum album) async {
    final server = _server;
    if (server == null || _opening) {
      return;
    }
    setState(() {
      _opening = true;
      _openingAlbumId = album.id;
    });
    try {
      final service = ref.read(remoteLibraryServiceProvider);
      final detail = await service.fetchAlbum(server.id, album.id);
      final localAlbumId = await service.syncAlbumToLibrary(
        server: server,
        detail: detail,
      );
      if (!mounted) {
        return;
      }
      if (localAlbumId == null) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.albumNoSongs)),
        );
        return;
      }
      unawaited(context.push('/library/album/$localAlbumId'));
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.openFailedPrefix}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _openingAlbumId = null;
        });
      }
    }
  }

  Future<List<Widget>> _buildSearchSuggestions(
    BuildContext context,
    SearchController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final query = controller.text.trim();
    final server = _server;
    if (query.isEmpty) {
      return [_Hint(text: l10n.searchHintCloud)];
    }
    if (server == null) {
      return [_Hint(text: l10n.noServer)];
    }
    final SubsonicSearchResult result;
    try {
      result = await ref
          .read(remoteLibraryServiceProvider)
          .search(server.id, query);
    } on Exception catch (e) {
      return [_Hint(text: '${l10n.searchFailedPrefix}: $e')];
    }
    if (result.albums.isEmpty && result.songs.isEmpty) {
      return [_Hint(text: l10n.noCloudMatch)];
    }
    return [
      if (result.albums.isNotEmpty)
        _SectionLabel(title: l10n.sectionAlbums),
      for (final album in result.albums)
        ListTile(
          leading: const Icon(Icons.album_outlined),
          title: Text(album.name),
          subtitle: Text(album.artist ?? ''),
          onTap: () {
            controller.closeView(null);
            unawaited(_openAlbum(album));
          },
        ),
      if (result.songs.isNotEmpty)
        _SectionLabel(title: l10n.sectionSongs),
      for (final song in result.songs)
        ListTile(
          leading: const Icon(Icons.music_note_outlined),
          title: Text(song.title),
          subtitle: Text(song.artist ?? ''),
          trailing: const Icon(Icons.play_arrow_rounded),
          onTap: () {
            controller.closeView(null);
            unawaited(_playSearchedSong(song));
          },
        ),
    ];
  }

  /// Folder-name fuzzy search over the in-memory index; tapping a result
  /// opens the work page directly.
  Future<List<Widget>> _buildFolderSuggestions(
    BuildContext context,
    SearchController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final needle = controller.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return [_Hint(text: l10n.searchHintFolders)];
    }
    if (_server == null) {
      return [_Hint(text: l10n.noServer)];
    }
    final matches = [
      for (final folder in (_folders ?? const <RemoteFolderSummary>[]))
        if (folder.name.toLowerCase().contains(needle)) folder,
    ];
    if (matches.isEmpty) {
      return [_Hint(text: l10n.folderNoMatch)];
    }
    return [
      for (final folder in matches)
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(folder.name),
          subtitle: Text(l10n.countSongs(folder.songCount)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            controller.closeView(null);
            _openFolder(folder);
          },
        ),
    ];
  }

  Future<void> _playSearchedSong(SubsonicSong remoteSong) async {
    final server = _server;
    if (server == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.syncingTo(remoteSong.title))),
      );
    try {
      final albumSongs = await ref
          .read(remoteLibraryServiceProvider)
          .syncAlbumSongs(server: server, remoteSong: remoteSong);
      if (!mounted || albumSongs.isEmpty) {
        return;
      }
      final targetPath = 'subsonic://${server.id}/${remoteSong.id}';
      var startIndex =
          albumSongs.indexWhere((s) => s.path == targetPath);
      if (startIndex < 0) {
        startIndex = 0;
      }
      await ref
          .read(playerControllerProvider.notifier)
          .playSongs(albumSongs, startIndex: startIndex);
      if (!mounted) {
        return;
      }
      unawaited(context.push('/player'));
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.playFailedPrefix}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(l10n),
        actions: [
          if (_mode == _CloudMode.albums)
            SearchAnchor(
              builder: (context, controller) => IconButton(
                tooltip: l10n.tooltipSearch,
                onPressed: controller.openView,
                icon: const Icon(Icons.search_rounded),
              ),
              suggestionsBuilder: _buildSearchSuggestions,
            )
          else
            SearchAnchor(
              builder: (context, controller) => IconButton(
                tooltip: l10n.tooltipSearch,
                onPressed: controller.openView,
                icon: const Icon(Icons.search_rounded),
              ),
              suggestionsBuilder: _buildFolderSuggestions,
            ),
          IconButton(
            tooltip: l10n.tooltipSort,
            onPressed: _showSortSheet,
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: l10n.tooltipToggleView,
            onPressed: _toggleView,
            icon: _viewToggleIcon(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.tooltipManageServers,
            onPressed: () async {
              await context.push('/settings/remote-servers');
              await _load(refresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.tooltipRefresh,
            onPressed: () => unawaited(_load(refresh: true)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'albums',
                  label: Text(l10n.cloudModeAlbums),
                ),
                ButtonSegment(
                  value: 'folders',
                  label: Text(l10n.cloudModeFolders),
                ),
              ],
              selected: {
                if (_mode == _CloudMode.albums) 'albums' else 'folders',
              },
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  _switchMode(selection.first == 'folders'
                      ? _CloudMode.folders
                      : _CloudMode.albums),
            ),
          ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _viewToggleIcon() {
    final current =
        _mode == _CloudMode.albums ? _albumsView : _foldersView;
    return Icon(
      current == _CloudView.grid
          ? Icons.view_list_rounded
          : Icons.grid_view_rounded,
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    if (_server == null || _servers.length < 2) {
      return Text(_server?.name ?? l10n.cloudFallback);
    }
    return PopupMenuButton<RemoteServer>(
      initialValue: _server,
      tooltip: l10n.tooltipSwitchServer,
      onSelected: (server) => unawaited(_switchServer(server)),
      itemBuilder: (context) => [
        for (final server in _servers)
          PopupMenuItem(value: server, child: Text(server.name)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _server!.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                if (_error == l10n.noServer) {
                  unawaited(context.push('/settings/remote-servers'));
                } else {
                  unawaited(_load(refresh: true));
                }
              },
              child: Text(_error == l10n.noServer ? l10n.goAdd : l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mode == _CloudMode.albums) {
      return _buildAlbumsBody(theme, l10n);
    }
    return _buildFoldersBody(theme, l10n);
  }

  Widget _buildAlbumsBody(ThemeData theme, AppLocalizations l10n) {
    final albums = _sortedAlbums;
    if (albums.isEmpty) {
      return Center(child: Text(l10n.serverNoAlbums));
    }
    if (_albumsView == _CloudView.list) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 140),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return ListTile(
            leading: _CoverThumb(server: _server, coverArtId: album.coverArt),
            title: Text(album.name),
            subtitle: Text(album.artist ?? ''),
            trailing: Text('${album.songCount}'),
            onTap: () => unawaited(_openAlbum(album)),
          );
        },
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => unawaited(_openAlbum(album)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CoverThumb(server: _server, coverArtId: album.coverArt),
                    if (_opening && _openingAlbumId == album.id)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                album.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoldersBody(ThemeData theme, AppLocalizations l10n) {
    final folders = _visibleFolders;
    if (folders.isEmpty) {
      return Center(child: Text(l10n.cloudFoldersEmpty));
    }
    if (_foldersView == _CloudView.list) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 140),
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final folder = folders[index];
          return ListTile(
            leading: _FolderThumb(server: _server, summary: folder, size: 48),
            title: Text(folder.name),
            subtitle: Text(l10n.countSongs(folder.songCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openFolder(folder),
          );
        },
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openFolder(folder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FolderThumb(
                  server: _server,
                  summary: folder,
                  size: null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                l10n.countSongs(folder.songCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFolder(RemoteFolderSummary folder) {
    final server = _server;
    if (server == null) {
      return;
    }
    unawaited(
      context.push(
        '/cloud/folder/${server.id}'
        '?name=${Uri.encodeComponent(folder.name)}',
        extra: server,
      ),
    );
  }
}

class _CoverThumb extends ConsumerWidget {
  const _CoverThumb({required this.server, required this.coverArtId});

  final RemoteServer? server;
  final String? coverArtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => Container(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.album_outlined,
            size: 48,
            color: scheme.onSecondaryContainer,
          ),
        );
    if (server == null || coverArtId == null || coverArtId!.isEmpty) {
      return fallback();
    }
    final future = ref
        .read(remoteLibraryServiceProvider)
        .cacheCover(server: server!, coverArtId: coverArtId!, size: 200);
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || !File(path).existsSync()) {
          return fallback();
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 200,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      },
    );
  }
}

class _FolderThumb extends ConsumerWidget {
  const _FolderThumb({
    required this.server,
    required this.summary,
    required this.size,
  });

  final RemoteServer? server;
  final RemoteFolderSummary summary;

  /// Fixed square edge for list rows; `null` expands to fill grid cells.
  final double? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() {
      final icon = Icon(
        Icons.folder_outlined,
        size: size == null ? 44 : 24,
        color: scheme.onSecondaryContainer,
      );
      if (size == null) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: icon,
        );
      }
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: icon,
      );
    }

    final donor = summary.coverSongId;
    if (server == null || donor == null) {
      return fallback();
    }
    final future = ref
        .read(remoteLibraryServiceProvider)
        .folderCover(server: server!, songId: donor, size: 200);
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || !File(path).existsSync()) {
          return fallback();
        }
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 200,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
        if (size == null) {
          return SizedBox.expand(child: image);
        }
        return SizedBox(width: size, height: size, child: image);
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
