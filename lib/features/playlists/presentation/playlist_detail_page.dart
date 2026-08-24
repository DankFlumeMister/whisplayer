import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/playlist.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({
    required this.playlistId,
    required this.name,
    super.key,
  });

  final int playlistId;
  final String name;

  @override
  ConsumerState<PlaylistDetailPage> createState() =>
      _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  bool _editing = false;
  final Set<int> _selectedEntryIds = <int>{};
  List<PlaylistEntry> _latestEntries = const <PlaylistEntry>[];

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(playlistRepositoryProvider);
    return Scaffold(
      appBar: _editing ? _buildEditingAppBar() : _buildNormalAppBar(),
      bottomNavigationBar: _editing ? _buildEditBottomBar() : null,
      body: StreamBuilder<List<PlaylistEntry>>(
        stream: repo.watchEntries(widget.playlistId),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <PlaylistEntry>[];
          _latestEntries = entries;
          if (_editing) {
            _selectedEntryIds.removeWhere(
              (id) => !entries.any((e) => e.entryId == id),
            );
          }
          if (entries.isEmpty) {
            return Center(
              child: Text(_editing ? '列表为空' : '列表为空，点右上角添加歌曲'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 140),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final song = entry.song;
              final selected = _selectedEntryIds.contains(entry.entryId);
              return ListTile(
                leading: _editing
                    ? Checkbox(
                        value: selected,
                        onChanged: (_) => _toggle(entry.entryId),
                      )
                    : song.sourceType == SourceType.remote
                        ? const Icon(Icons.cloud_outlined)
                        : const Icon(Icons.music_note_outlined),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    song.artistName ?? '',
                    if (song.sourceType == SourceType.remote) '云端',
                  ]
                      .where((part) => part.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  if (_editing) {
                    _toggle(entry.entryId);
                    return;
                  }
                  unawaited(
                    ref
                        .read(playerControllerProvider.notifier)
                        .playSongs(
                          [for (final e in entries) e.song],
                          startIndex: index,
                        ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _toggle(int entryId) {
    setState(() {
      if (!_selectedEntryIds.add(entryId)) {
        _selectedEntryIds.remove(entryId);
      }
    });
  }

  void _exitEditing() {
    setState(() {
      _editing = false;
      _selectedEntryIds.clear();
    });
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '添加歌曲',
          onPressed: () => _showAddSheet(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: '编辑歌曲',
          onPressed: () => setState(() => _editing = true),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除播放列表',
          onPressed: () => _confirmDelete(context, ref),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildEditingAppBar() {
    final allSelected =
        _latestEntries.isNotEmpty &&
            _selectedEntryIds.length == _latestEntries.length;
    return AppBar(
      leading: BackButton(onPressed: _exitEditing),
      title: Text('已选 ${_selectedEntryIds.length} 首'),
      actions: [
        IconButton(
          tooltip: allSelected ? '取消全选' : '全选',
          onPressed: () {
            setState(() {
              if (allSelected) {
                _selectedEntryIds.clear();
              } else {
                _selectedEntryIds
                  ..clear()
                  ..addAll(_latestEntries.map((e) => e.entryId));
              }
            });
          },
          icon: Icon(
            allSelected
                ? Icons.deselect_rounded
                : Icons.select_all_rounded,
          ),
        ),
        IconButton(
          tooltip: '完成',
          onPressed: _exitEditing,
          icon: const Icon(Icons.check_rounded),
        ),
      ],
    );
  }

  Widget? _buildEditBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed:
              _selectedEntryIds.isEmpty ? null : _deleteSelected,
          icon: const Icon(Icons.delete_outline),
          label: Text('删除所选 (${_selectedEntryIds.length})'),
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedEntryIds.toList();
    await ref.read(playlistRepositoryProvider).removeEntries(ids);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已移除 ${ids.length} 首')));
    _exitEditing();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除播放列表？'),
        content: Text('「${widget.name}」将被删除，歌曲不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(playlistRepositoryProvider)
          .deletePlaylist(widget.playlistId);
      if (!context.mounted) {
        return;
      }
      context.pop();
    }
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    var mode = 0;
    final filterController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('本地歌曲')),
                    ButtonSegment(value: 1, label: Text('云端歌曲')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) =>
                      setState(() => mode = selection.first),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: filterController,
                    decoration: InputDecoration(
                      labelText:
                          mode == 0 ? '过滤本地歌曲' : '模糊搜索云端歌曲',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: mode == 1
                          ? IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              tooltip: '搜索',
                              onPressed: () => setState(() {}),
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: mode == 0
                      ? _LocalPicker(
                          playlistId: widget.playlistId,
                          filter: filterController.text,
                        )
                      : _CloudPicker(
                          playlistId: widget.playlistId,
                          query: filterController.text.trim(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalPicker extends ConsumerWidget {
  const _LocalPicker({required this.playlistId, required this.filter});

  final int playlistId;
  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryRepositoryProvider);
    return FutureBuilder(
      future: repo.getAllSongs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final needle = filter.toLowerCase();
        final songs = [
          for (final song in snapshot.data!)
            if (song.sourceType == SourceType.local)
              if (needle.isEmpty ||
                  song.title.toLowerCase().contains(needle) ||
                  (song.artistName ?? '')
                      .toLowerCase()
                      .contains(needle))
                song,
        ];
        if (songs.isEmpty) {
          return const Center(child: Text('没有匹配的本地歌曲'));
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: Text(song.title),
              subtitle: Text(song.artistName ?? ''),
              onTap: () => _add(
                context,
                ref,
                song.id,
                song.title,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    int songId,
    String title,
  ) async {
    await ref
        .read(playlistRepositoryProvider)
        .addSong(playlistId, songId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已加入「$title」')));
  }
}

class _CloudPicker extends ConsumerStatefulWidget {
  const _CloudPicker({required this.playlistId, required this.query});

  final int playlistId;
  final String query;

  @override
  ConsumerState<_CloudPicker> createState() => _CloudPickerState();
}

class _CloudPickerState extends ConsumerState<_CloudPicker> {
  List<SubsonicSong>? _results;
  String? _error;
  bool _searching = false;
  final Set<String> _added = <String>{};

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_search);
  }

  Future<void> _search() async {
    setState(() {
      _error = null;
      _results = null;
      _searching = true;
    });
    try {
      final servers =
          await ref.read(remoteServerRepositoryProvider).getServers();
      if (!mounted) {
        return;
      }
      if (servers.isEmpty) {
        setState(() => _error = '未连接到服务器');
        return;
      }
      if (widget.query.isEmpty) {
        setState(() => _error = '输入关键字后点搜索');
        return;
      }
      final result = await ref
          .read(remoteLibraryServiceProvider)
          .search(servers.first.id, widget.query);
      if (!mounted) {
        return;
      }
      setState(() => _results = result.songs);
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '搜索失败：$e');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _addRemote(SubsonicSong remoteSong) async {
    if (_added.contains(remoteSong.id)) {
      return;
    }
    setState(() => _added.add(remoteSong.id));
    try {
      final servers =
          await ref.read(remoteServerRepositoryProvider).getServers();
      if (servers.isEmpty || !mounted) {
        return;
      }
      final song = await ref
          .read(remoteLibraryServiceProvider)
          .ensureSongSynced(servers.first, remoteSong);
      if (song == null) {
        return;
      }
      await ref
          .read(playlistRepositoryProvider)
          .addSong(widget.playlistId, song.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('已加入「${song.title}」')));
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _added.remove(remoteSong.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _error == '未连接到服务器'
                  ? () => unawaited(
                        context.push('/settings/remote-servers'),
                      )
                  : _search,
              child: Text(_error == '未连接到服务器' ? '去连接' : '重试'),
            ),
          ],
        ),
      );
    }
    final results = _results;
    if (_searching || results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return const Center(child: Text('未找到匹配的歌曲'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final song = results[index];
        return ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: Text(song.title),
          subtitle: Text(song.artist ?? ''),
          trailing: _added.contains(song.id)
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline),
          onTap: () => unawaited(_addRemote(song)),
        );
      },
    );
  }
}
