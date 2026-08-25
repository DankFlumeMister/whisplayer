import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

const String _keyActiveServer = 'remote.active_server_id';
const int _pageSize = 60;

class RemoteAlbumsPage extends ConsumerStatefulWidget {
  const RemoteAlbumsPage({super.key});

  @override
  ConsumerState<RemoteAlbumsPage> createState() => _RemoteAlbumsPageState();
}

class _RemoteAlbumsPageState extends ConsumerState<RemoteAlbumsPage> {
  final _scrollController = ScrollController();
  List<RemoteServer> _servers = const <RemoteServer>[];
  RemoteServer? _server;
  List<SubsonicAlbum>? _albums;
  String? _error;
  bool _opening = false;
  String? _openingAlbumId;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    scheduleMicrotask(_load);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore ||
        _loadingMore ||
        !_scrollController.hasClients ||
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 600) {
      return;
    }
    unawaited(_loadMore());
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _albums = null;
      _hasMore = true;
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
      final savedId =
          int.tryParse(await ref
                  .read(settingsRepositoryProvider)
                  .getString(_keyActiveServer) ??
              '') ;
      var server = servers.first;
      for (final candidate in servers) {
        if (candidate.id == savedId) {
          server = candidate;
        }
      }
      final albums = await ref
          .read(remoteLibraryServiceProvider)
          .fetchAlbums(server.id, size: _pageSize);
      if (!mounted) {
        return;
      }
      setState(() {
        _servers = servers;
        _server = server;
        _albums = albums;
        _hasMore = albums.length >= _pageSize;
      });
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() => _error = '${l10n.loadFailedPrefix}: $e');
    }
  }

  Future<void> _loadMore() async {
    final server = _server;
    final albums = _albums;
    if (server == null || albums == null || !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final more = await ref
          .read(remoteLibraryServiceProvider)
          .fetchAlbums(server.id, size: _pageSize, offset: albums.length);
      if (!mounted) {
        return;
      }
      setState(() {
        _albums = [...albums, ...more];
        _hasMore = more.length >= _pageSize;
      });
    } on Exception catch (_) {
      // Keep showing what we already have; scrolling will retry.
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _switchServer(RemoteServer server) async {
    if (server.id == _server?.id) {
      return;
    }
    await ref
        .read(settingsRepositoryProvider)
        .setString(_keyActiveServer, '${server.id}');
    await _load();
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
      final song = await ref
          .read(remoteLibraryServiceProvider)
          .ensureSongSynced(server, remoteSong);
      if (!mounted || song == null) {
        return;
      }
      await ref
          .read(playerControllerProvider.notifier)
          .playSongs([song]);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _server == null || _servers.length < 2
            ? Text(_server?.name ?? l10n.cloudFallback)
            : PopupMenuButton<RemoteServer>(
                initialValue: _server,
                tooltip: l10n.tooltipSwitchServer,
                onSelected: (server) =>
                    unawaited(_switchServer(server)),
                itemBuilder: (context) => [
                  for (final server in _servers)
                    PopupMenuItem(
                      value: server,
                      child: Text(server.name),
                    ),
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
              ),
        actions: [
          SearchAnchor(
            builder: (context, controller) => IconButton(
              tooltip: l10n.tooltipSearch,
              onPressed: controller.openView,
              icon: const Icon(Icons.search_rounded),
            ),
            suggestionsBuilder: _buildSearchSuggestions,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.tooltipManageServers,
            onPressed: () async {
              await context.push('/settings/remote-servers');
              await _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.tooltipRefresh,
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(theme),
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
                  unawaited(
                    context.push('/settings/remote-servers'),
                  );
                } else {
                  unawaited(_load());
                }
              },
              child: Text(
                _error == l10n.noServer ? l10n.goAdd : l10n.retry,
              ),
            ),
          ],
        ),
      );
    }
    final albums = _albums;
    if (albums == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (albums.isEmpty) {
      return Center(child: Text(l10n.serverNoAlbums));
    }
    final itemCount = albums.length + (_hasMore ? 1 : 0);
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= albums.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
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
                    _CoverThumb(
                      server: _server,
                      coverArtId: album.coverArt,
                    ),
                    if (_opening && _openingAlbumId == album.id)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
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
    final future = ref.read(remoteLibraryServiceProvider).cacheCover(
          server: server!,
          coverArtId: coverArtId!,
          size: 200,
        );
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
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
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
