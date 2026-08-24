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

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int _viewIndex = 0;
  SongSort _sort = SongSort.title;
  bool _descending = false;
  final SearchController _searchController = SearchController();
  int _searchToken = 0;

  static const _views = ['歌曲', '专辑', '艺术家', '文件夹'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(libraryRepositoryProvider);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            pinned: true,
            actions: [
              IconButton(
                tooltip: '最近播放',
                onPressed: () =>
                    unawaited(context.push('/library/recently-played')),
                icon: const Icon(Icons.history_rounded),
              ),
              if (_viewIndex == 0)
                SearchAnchor(
                  searchController: _searchController,
                  builder: (context, controller) => IconButton(
                    tooltip: '搜索',
                    onPressed: controller.openView,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  suggestionsBuilder: _buildSearchSuggestions,
                ),
              if (_viewIndex == 0)
                IconButton(
                  tooltip: '排序',
                  onPressed: _showSortMenu,
                  icon: const Icon(Icons.sort_rounded),
                ),
              IconButton(
                tooltip: '设置',
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
                  for (var i = 0; i < _views.length; i++)
                    ButtonSegment(value: i, label: Text(_views[i])),
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
                      return const _EmptyHint(text: '暂无歌曲，先去设置里扫描音乐吧');
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
    final query = controller.text.trim();
    if (query.isEmpty) {
      return const [_SearchHint(text: '输入关键字搜索歌曲')];
    }
    final token = ++_searchToken;
    final List<Song> songs;
    try {
      songs = await ref
          .read(libraryRepositoryProvider)
          .searchLocalSongs(query);
    } on Exception {
      if (token == _searchToken) {
        return const [_SearchHint(text: '搜索失败，请稍后重试')];
      }
      return const <Widget>[];
    }
    if (token != _searchToken) {
      return const <Widget>[];
    }
    if (songs.isEmpty) {
      return const [_SearchHint(text: '未找到匹配的歌曲')];
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
    final labels = {
      SongSort.title: '标题',
      SongSort.artist: '艺术家',
      SongSort.album: '专辑',
      SongSort.addedAt: '最近添加',
      SongSort.playCount: '播放次数',
      SongSort.duration: '时长',
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
                title: const Text('降序'),
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
