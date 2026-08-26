import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/library/presentation/albums_tab.dart';
import 'package:whisplayer/features/library/presentation/artists_tab.dart';
import 'package:whisplayer/features/library/presentation/folders_tab.dart';
import 'package:whisplayer/features/library/presentation/widgets/song_list_view.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

const String _keySongsView = 'library.songs_view';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int _viewIndex = 0;
  SongSort _sort = SongSort.title;
  bool _descending = false;
  bool _songsGrid = false;
  final SearchController _searchController = SearchController();
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_restoreSongsView);
  }

  Future<void> _restoreSongsView() async {
    try {
      final value =
          await ref.read(settingsRepositoryProvider).getString(_keySongsView);
      if (!mounted) {
        return;
      }
      setState(() => _songsGrid = value == 'grid');
    } on Exception {
      // Settings storage unavailable — keep the list default.
    }
  }

  void _toggleSongsView() {
    setState(() => _songsGrid = !_songsGrid);
    unawaited(
      ref
          .read(settingsRepositoryProvider)
          .setString(_keySongsView, _songsGrid ? 'grid' : 'list'),
    );
  }

  static List<String> _viewLabels(AppLocalizations l10n) => [
        l10n.songsTab,
        l10n.albumsTab,
        l10n.artistsTab,
        l10n.foldersTab,
      ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(libraryRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            pinned: true,
            actions: [
              IconButton(
                tooltip: l10n.tooltipRecent,
                onPressed: () =>
                    unawaited(context.push('/library/recently-played')),
                icon: const Icon(Icons.history_rounded),
              ),
              if (_viewIndex == 0)
                SearchAnchor(
                  searchController: _searchController,
                  builder: (context, controller) => IconButton(
                    tooltip: l10n.tooltipSearch,
                    onPressed: controller.openView,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  suggestionsBuilder: _buildSearchSuggestions,
                ),
              if (_viewIndex == 0)
                IconButton(
                  tooltip: l10n.tooltipSort,
                  onPressed: _showSortMenu,
                  icon: const Icon(Icons.sort_rounded),
                ),
              if (_viewIndex == 0)
                IconButton(
                  tooltip: l10n.tooltipToggleView,
                  onPressed: _toggleSongsView,
                  icon: Icon(
                    _songsGrid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                  ),
                ),
              IconButton(
                tooltip: l10n.settingsTitle,
                onPressed: () => unawaited(context.push('/settings')),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < _viewLabels(l10n).length; i++)
                    ButtonSegment(value: i, label: Text(_viewLabels(l10n)[i])),
                ],
                selected: {_viewIndex},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _viewIndex = selection.first),
              ),
            ),
          ),
        ],
        body: Builder(
          builder: (context) {
            switch (_viewIndex) {
              case 0:
                return StreamBuilder<List<Song>>(
                  stream: repo.watchLocalSongs(
                    sort: _sort,
                    descending: _descending,
                  ),
                  builder: (context, snapshot) {
                    final songs = snapshot.data ?? const <Song>[];
                    if (songs.isEmpty) {
                      return _EmptyHint(text: l10n.libraryEmpty);
                    }
                    if (_songsGrid) {
                      return SongGridView(songs: songs);
                    }
                    return RefreshIndicator(
                      onRefresh: () async {},
                      child: Scrollbar(
                        child: SongListView(songs: songs),
                      ),
                    );
                  },
                );
              case 1:
                return const AlbumsTab();
              case 2:
                return const ArtistsTab();
              default:
                return const FoldersTab();
            }
          },
        ),
      ),
    );
  }

  Future<List<Widget>> _buildSearchSuggestions(
    BuildContext context,
    SearchController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final query = controller.text.trim();
    if (query.isEmpty) {
      return [_SearchHint(text: l10n.searchHintInput)];
    }
    final token = ++_searchToken;
    final List<Song> songs;
    try {
      songs = await ref
          .read(libraryRepositoryProvider)
          .searchLocalSongs(query);
    } on Exception {
      if (token == _searchToken) {
        return [_SearchHint(text: l10n.searchHintFailure)];
      }
      return const <Widget>[];
    }
    if (token != _searchToken) {
      return const <Widget>[];
    }
    if (songs.isEmpty) {
      return [_SearchHint(text: l10n.searchHintNoMatch)];
    }
    return [
      for (var i = 0; i < songs.length; i++)
        SongRow(
          key: ValueKey(songs[i].id),
          song: songs[i],
          songs: songs,
          index: i,
          onTap: () => _playFromSearch(controller, songs, i),
        ),
    ];
  }

  void _playFromSearch(
    SearchController controller,
    List<Song> songs,
    int index,
  ) {
    controller.closeView(null);
    unawaited(
      ref
          .read(playerControllerProvider.notifier)
          .playSongs(songs, startIndex: index),
    );
    unawaited(context.push('/player'));
  }

  void _showSortMenu() {
    final l10n = AppLocalizations.of(context);
    final labels = {
      SongSort.title: l10n.sortTitle,
      SongSort.artist: l10n.sortArtist,
      SongSort.album: l10n.sortAlbum,
      SongSort.addedAt: l10n.sortAddedAt,
      SongSort.playCount: l10n.sortPlayCount,
      SongSort.duration: l10n.sortDuration,
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in labels.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing:
                      _sort == entry.key ? const Icon(Icons.check) : null,
                  onTap: () {
                    setState(() => _sort = entry.key);
                    Navigator.pop(sheetContext);
                  },
                ),
              SwitchListTile(
                title: Text(l10n.sortDescending),
                value: _descending,
                onChanged: (v) {
                  setState(() => _descending = v);
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text));
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
