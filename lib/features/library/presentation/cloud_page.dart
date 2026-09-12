import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/cloud_providers.dart';
import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/core/util/natural_compare.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/cloud_directory.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/features/library/domain/browse_prefs.dart';
import 'package:whisplayer/features/library/presentation/cloud_cover.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/features/settings/presentation/webdav_scan_sheet.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

/// The cloud tab, backed by WebDAV.
///
/// Everything shown here comes from the local database, not the network: a
/// scan has already recorded every file path, so browsing is instant and works
/// with the share offline. The two modes therefore answer different questions
/// about the same rows — "which works do I have" (grouped by the top-level
/// directory the scan recorded as the album) and "what does the share actually
/// look like" (the real directory tree).
class CloudPage extends ConsumerStatefulWidget {
  const CloudPage({super.key});

  @override
  ConsumerState<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends ConsumerState<CloudPage> {
  BrowsePrefs _prefs = BrowsePrefs.defaults;
  final SearchController _searchController = SearchController();
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_restorePrefs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restorePrefs() async {
    try {
      final prefs = await ref.read(settingsRepositoryProvider).getBrowsePrefs();
      if (mounted) {
        setState(() => _prefs = prefs);
      }
    } on Exception {
      // Settings storage unavailable — keep the defaults.
    }
  }

  void _persistPrefs() {
    unawaited(ref.read(settingsRepositoryProvider).setBrowsePrefs(_prefs));
  }

  /// Resolves the stored server id against the live list, falling back to the
  /// first share so a deleted or never-chosen id cannot leave the tab blank.
  WebDavServer? _activeServer(List<WebDavServer> servers) {
    if (servers.isEmpty) {
      return null;
    }
    for (final server in servers) {
      if (server.id == _prefs.activeServerId) {
        return server;
      }
    }
    return servers.first;
  }

  Future<void> _switchServer(WebDavServer server) async {
    if (server.id == _prefs.activeServerId) {
      return;
    }
    setState(() => _prefs = _prefs.copyWith(activeServerId: server.id));
    _persistPrefs();
  }

  void _switchMode(CloudMode mode) {
    if (mode == _prefs.mode) {
      return;
    }
    setState(() => _prefs = _prefs.copyWith(mode: mode));
    _persistPrefs();
  }

  void _toggleView() {
    setState(() {
      _prefs = _prefs.mode == CloudMode.albums
          ? _prefs.copyWith(
              albumsView: _prefs.albumsView == CloudView.grid
                  ? CloudView.list
                  : CloudView.grid,
            )
          : _prefs.copyWith(
              foldersView: _prefs.foldersView == CloudView.grid
                  ? CloudView.list
                  : CloudView.grid,
            );
    });
    _persistPrefs();
  }

  Future<void> _scan(WebDavServer? server) async {
    if (server == null) {
      await context.push('/settings/webdav-servers');
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WebDavScanSheet(server: server),
    );
  }

  // --- sorting ----------------------------------------------------------

  List<Album> _sortedAlbums(List<Album> albums) {
    final sorted = [...albums];
    int byField(Album a, Album b) {
      switch (_prefs.albumSort) {
        case AlbumSort.artist:
          return (a.artistName ?? '')
              .toLowerCase()
              .compareTo((b.artistName ?? '').toLowerCase());
        case AlbumSort.recent:
          // Albums carry no timestamp; the auto-increment id is the insertion
          // order, so a higher id is a later scan.
          return b.id.compareTo(a.id);
        case AlbumSort.songs:
          return a.songCount.compareTo(b.songCount);
        case AlbumSort.name:
          return naturalCompare(a.title.toLowerCase(), b.title.toLowerCase());
      }
    }

    final direction = _prefs.albumDesc ? -1 : 1;
    sorted.sort((a, b) => direction * byField(a, b));
    return sorted;
  }

  List<CloudDirectory> _sortedDirectories(List<CloudDirectory> dirs) {
    final sorted = [...dirs];
    final direction = _prefs.folderDesc ? -1 : 1;
    sorted.sort((a, b) {
      final result = _prefs.folderSort == FolderSort.songs
          ? a.totalSongCount.compareTo(b.totalSongCount)
          : naturalCompare(a.name.toLowerCase(), b.name.toLowerCase());
      return direction * result;
    });
    return sorted;
  }

  // --- search -----------------------------------------------------------

  Future<List<Widget>> _albumSuggestions(
    BuildContext context,
    SearchController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final query = controller.text.trim();
    if (query.isEmpty) {
      return [_Hint(text: l10n.searchHintCloud)];
    }
    final token = ++_searchToken;
    final List<Song> songs;
    try {
      songs = await ref.read(cloudBrowseRepositoryProvider).searchSongs(query);
    } on Exception {
      return [_Hint(text: l10n.searchHintFailure)];
    }
    if (token != _searchToken) {
      return const <Widget>[];
    }
    if (songs.isEmpty) {
      return [_Hint(text: l10n.noCloudMatch)];
    }
    return [
      _SectionLabel(title: l10n.sectionSongs),
      for (var i = 0; i < songs.length; i++)
        ListTile(
          leading: const Icon(Icons.music_note_outlined),
          title: Text(songs[i].title),
          subtitle: Text(songs[i].albumTitle ?? ''),
          trailing: const Icon(Icons.play_arrow_rounded),
          onTap: () {
            controller.closeView(null);
            _playFromSearch(songs, i);
          },
        ),
    ];
  }

  Future<List<Widget>> _folderSuggestions(
    BuildContext context,
    SearchController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final needle = controller.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return [_Hint(text: l10n.searchHintFolders)];
    }
    final server = _activeServer(ref.read(webDavServersProvider).value ??
        const <WebDavServer>[]);
    if (server == null) {
      return [_Hint(text: l10n.noServer)];
    }
    final dirs = ref.read(cloudDirectoriesProvider(server.pathPrefix))
            .value ??
        const <CloudDirectory>[];
    final matches = [
      for (final dir in dirs)
        if (dir.name.toLowerCase().contains(needle)) dir,
    ];
    if (matches.isEmpty) {
      return [_Hint(text: l10n.folderNoMatch)];
    }
    return [
      for (final dir in matches)
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(dir.name),
          subtitle: Text(l10n.countSongs(dir.totalSongCount)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            controller.closeView(null);
            _openDirectory(dir.path);
          },
        ),
    ];
  }

  void _playFromSearch(List<Song> songs, int index) {
    unawaited(
      ref
          .read(playerControllerProvider.notifier)
          .playSongs(songs, startIndex: index),
    );
    unawaited(context.push('/player'));
  }

  void _openDirectory(String path) {
    unawaited(context.push('/cloud/dir?path=${Uri.encodeComponent(path)}'));
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
      } else ...<FolderSort, String>{
        FolderSort.name: l10n.sortTitle,
        FolderSort.songs: l10n.sortSongsCount,
      },
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in entries.entries)
              ListTile(
                title: Text(entry.value),
                trailing: _selectedMarker(entry.key),
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
              onChanged: (value) {
                Navigator.pop(sheetContext);
                setState(() {
                  _prefs = isAlbums
                      ? _prefs.copyWith(albumDesc: value)
                      : _prefs.copyWith(folderDesc: value);
                });
                _persistPrefs();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _selectedMarker(Object key) {
    final selected =
        key is AlbumSort ? key == _prefs.albumSort : key == _prefs.folderSort;
    return selected ? const Icon(Icons.check) : null;
  }

  // --- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final servers =
        ref.watch(webDavServersProvider).value ?? const <WebDavServer>[];
    final server = _activeServer(servers);

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(l10n, servers, server),
        actions: [
          SearchAnchor(
            searchController: _searchController,
            builder: (context, controller) => IconButton(
              tooltip: l10n.tooltipSearch,
              onPressed: controller.openView,
              icon: const Icon(Icons.search_rounded),
            ),
            suggestionsBuilder: _prefs.mode == CloudMode.albums
                ? _albumSuggestions
                : _folderSuggestions,
          ),
          IconButton(
            tooltip: l10n.tooltipSort,
            onPressed: _showSortSheet,
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: l10n.tooltipToggleView,
            onPressed: _toggleView,
            icon: Icon(
              (_prefs.mode == CloudMode.albums
                          ? _prefs.albumsView
                          : _prefs.foldersView) ==
                      CloudView.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            tooltip: l10n.tooltipRefresh,
            onPressed: () => unawaited(_scan(server)),
            icon: const Icon(Icons.refresh),
          ),
          // Settings stays the right-most action so it lands in the same
          // place on every tab.
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => unawaited(context.push('/settings')),
            icon: const Icon(Icons.settings_outlined),
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
              onSelectionChanged: (selection) => _switchMode(
                selection.first == 'folders'
                    ? CloudMode.folders
                    : CloudMode.albums,
              ),
            ),
          ),
          Expanded(child: _buildBody(l10n, server)),
        ],
      ),
    );
  }

  Widget _buildTitle(
    AppLocalizations l10n,
    List<WebDavServer> servers,
    WebDavServer? server,
  ) {
    if (server == null) {
      return Text(l10n.cloudFallback);
    }
    if (servers.length < 2) {
      return Text(server.name);
    }
    return PopupMenuButton<WebDavServer>(
      tooltip: l10n.tooltipSwitchServer,
      onSelected: (value) => unawaited(_switchServer(value)),
      itemBuilder: (context) => [
        for (final entry in servers)
          PopupMenuItem(value: entry, child: Text(entry.name)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(server.name, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, WebDavServer? server) {
    if (server == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.webdavNoServerYet,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  unawaited(context.push('/settings/webdav-servers')),
              child: Text(l10n.goAdd),
            ),
          ],
        ),
      );
    }
    return _prefs.mode == CloudMode.albums
        ? _buildAlbums(l10n)
        : _buildDirectories(l10n, server);
  }

  Widget _buildAlbums(AppLocalizations l10n) {
    final albums = ref.watch(cloudAlbumsProvider);
    final list = _sortedAlbums(albums.value ?? const <Album>[]);
    if (list.isEmpty) {
      return _EmptyHint(text: l10n.cloudLibraryEmpty);
    }
    if (_prefs.albumsView == CloudView.list) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 140),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final album = list[index];
          return ListTile(
            leading: CloudCover(
              artworkPath: album.artworkPath,
              size: 48,
              fallbackIconSize: 24,
            ),
            title: Text(album.title),
            subtitle: Text(
              l10n.countSongs(album.songCount),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(context.push('/library/album/${album.id}')),
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
        childAspectRatio: 0.78,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final album = list[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => unawaited(context.push('/library/album/${album.id}')),
          child: Column(
            // Stretch so the cover receives tight constraints and fills the
            // cell; with a loose cross axis it would size to the image and
            // spill past the grid row.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CloudCover(
                  artworkPath: album.artworkPath,
                  fallbackIconSize: 48,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                l10n.countSongs(album.songCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectories(AppLocalizations l10n, WebDavServer server) {
    final dirs =
        ref.watch(cloudDirectoriesProvider(server.pathPrefix)).value ??
            const <CloudDirectory>[];
    final list = _sortedDirectories(dirs);
    if (list.isEmpty) {
      return _EmptyHint(text: l10n.cloudLibraryEmpty);
    }
    if (_prefs.foldersView == CloudView.list) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 140),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final dir = list[index];
          return ListTile(
            leading: const Icon(Icons.folder_outlined, size: 36),
            title: Text(dir.name),
            subtitle: Text(_directorySubtitle(l10n, dir)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDirectory(dir.path),
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
        childAspectRatio: 0.9,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final dir = list[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDirectory(dir.path),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.folder_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dir.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                _directorySubtitle(l10n, dir),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Song total, plus a folder count when the directory nests further.
  ///
  /// The total rather than the direct count: a work directory often holds no
  /// audio of its own, so the direct figure would read as a misleading zero.
  String _directorySubtitle(AppLocalizations l10n, CloudDirectory dir) {
    final parts = <String>[l10n.countSongs(dir.totalSongCount)];
    if (dir.subDirectoryCount > 0) {
      parts.add(l10n.countSubfolders(dir.subDirectoryCount));
    }
    return parts.join(' · ');
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(text, textAlign: TextAlign.center),
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
