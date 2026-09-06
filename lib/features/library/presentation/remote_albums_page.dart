import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/remote/remote_library_service.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/features/library/domain/browse_prefs.dart';
import 'package:whisplayer/features/library/presentation/remote_cover.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

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

  BrowsePrefs _prefs = BrowsePrefs.defaults;

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
      final prefs = await repo.getBrowsePrefs();
      if (mounted) {
        setState(() => _prefs = prefs);
      }
    } on Exception {
      // Settings storage unavailable (tests / first run) — keep defaults.
    }
  }

  void _persistPrefs() {
    unawaited(
      ref.read(settingsRepositoryProvider).setBrowsePrefs(_prefs),
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
      final savedId = _prefs.activeServerId;
      var server = servers.first;
      for (final candidate in servers) {
        if (candidate.id == savedId) {
          server = candidate;
        }
      }
      if (_prefs.mode == CloudMode.albums) {
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
    return ref
        .read(remoteLibraryServiceProvider)
        .fetchAllAlbums(serverId);
  }

  void _switchMode(CloudMode mode) {
    if (mode == _prefs.mode) {
      return;
    }
    setState(() => _prefs = _prefs.copyWith(mode: mode));
    _persistPrefs();
    final hasData =
        mode == CloudMode.folders ? _folders != null : _albums != null;
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
      switch (_prefs.albumSort) {
        case AlbumSort.artist:
          return (a.artist ?? '')
              .toLowerCase()
              .compareTo((b.artist ?? '').toLowerCase());
        case AlbumSort.recent:
          return b.created.compareTo(a.created);
        case AlbumSort.songs:
          return a.songCount.compareTo(b.songCount);
        case AlbumSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    final direction = _prefs.albumDesc ? -1 : 1;
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
        _prefs.folderSort == FolderSort.songs
            ? a.songCount.compareTo(b.songCount)
            : a.name.compareTo(b.name);
    final direction = _prefs.folderDesc ? -1 : 1;
    int signed(RemoteFolderSummary a, RemoteFolderSummary b) =>
        direction * comparator(a, b);
    final sorted = [...folders]..sort(signed);
    return sorted;
  }

  void _showSortSheet() {
    final l10n = AppLocalizations.of(context);
    final isAlbums = _prefs.mode == CloudMode.albums;
    final entries = <Object, String>{
      if (isAlbums) ...<AlbumSort, String>{
        AlbumSort.name: l10n.sortTitle,
        AlbumSort.artist: l10n.sortArtist,
        AlbumSort.recent: l10n.sortAddedAt,
        AlbumSort.songs: l10n.sortSongsCount,
      },
      if (!isAlbums) ...<FolderSort, String>{
        FolderSort.name: l10n.sortTitle,
        FolderSort.songs: l10n.sortSongsCount,
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
                    Navigator.pop(sheetContext);
                    setState(() {
                      if (entry.key is AlbumSort) {
                        _prefs = _prefs.copyWith(
                          albumSort: entry.key as AlbumSort,
                          // Every field starts in its natural order.
                          albumDesc: false,
                        );
                      } else {
                        _prefs = _prefs.copyWith(
                          folderSort: entry.key as FolderSort,
                          folderDesc: false,
                        );
                      }
                    });
                    _persistPrefs();
                  },
                ),
              SwitchListTile(
                title: Text(l10n.sortDescending),
                value: isAlbums ? _prefs.albumDesc : _prefs.folderDesc,
                onChanged: (v) {
                  Navigator.pop(sheetContext);
                  setState(() {
                    if (isAlbums) {
                      _prefs = _prefs.copyWith(albumDesc: v);
                    } else {
                      _prefs = _prefs.copyWith(folderDesc: v);
                    }
                  });
                  _persistPrefs();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _sortSelectionMarker(Object key) {
    final selected =
        key is AlbumSort ? key == _prefs.albumSort : key == _prefs.folderSort;
    return selected ? const Icon(Icons.check) : null;
  }

  void _toggleView() {
    setState(() {
      if (_prefs.mode == CloudMode.albums) {
        _prefs = _prefs.copyWith(
          albumsView: _prefs.albumsView == CloudView.grid
              ? CloudView.list
              : CloudView.grid,
        );
      } else {
        _prefs = _prefs.copyWith(
          foldersView: _prefs.foldersView == CloudView.grid
              ? CloudView.list
              : CloudView.grid,
        );
      }
    });
    _persistPrefs();
  }

  Future<void> _switchServer(RemoteServer server) async {
    if (server.id == _server?.id) {
      return;
    }
    setState(() => _prefs = _prefs.copyWith(activeServerId: server.id));
    await ref.read(settingsRepositoryProvider).setBrowsePrefs(_prefs);
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
      final targetPath = encodeSubsonicPath(server.id, remoteSong.id);
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
          if (_prefs.mode == CloudMode.albums)
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
                if (_prefs.mode == CloudMode.albums) 'albums' else 'folders',
              },
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  _switchMode(selection.first == 'folders'
                      ? CloudMode.folders
                      : CloudMode.albums),
            ),
          ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _viewToggleIcon() {
    final current = _prefs.mode == CloudMode.albums
        ? _prefs.albumsView
        : _prefs.foldersView;
    return Icon(
      current == CloudView.grid
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
    if (_prefs.mode == CloudMode.albums) {
      return _buildAlbumsBody(theme, l10n);
    }
    return _buildFoldersBody(theme, l10n);
  }

  Widget _buildAlbumsBody(ThemeData theme, AppLocalizations l10n) {
    final albums = _sortedAlbums;
    if (albums.isEmpty) {
      return Center(child: Text(l10n.serverNoAlbums));
    }
    if (_prefs.albumsView == CloudView.list) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 140),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return ListTile(
            leading: RemoteCover(
              server: _server,
              coverArtId: album.coverArt,
              fallbackIconSize: 48,
            ),
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
                    RemoteCover(
                      server: _server,
                      coverArtId: album.coverArt,
                      fallbackIconSize: 48,
                    ),
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
    if (_prefs.foldersView == CloudView.list) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 140),
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final folder = folders[index];
          return ListTile(
            leading: RemoteCover(
              server: _server,
              songId: folder.coverSongId,
              coverAlbumId: folder.coverAlbumId,
              folderName: folder.name,
              size: 48,
              radius: 10,
              fallbackIcon: Icons.folder_outlined,
              fallbackIconSize: 24,
            ),
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
                // Keep the cover square: with a loose cross-axis constraint
                // the fallback Container would otherwise stretch to the
                // full cell height and render as a tall rectangle.
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: RemoteCover(
                      server: _server,
                      songId: folder.coverSongId,
                      coverAlbumId: folder.coverAlbumId,
                      folderName: folder.name,
                      fallbackIcon: Icons.folder_outlined,
                      fallbackIconSize: 44,
                    ),
                  ),
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
