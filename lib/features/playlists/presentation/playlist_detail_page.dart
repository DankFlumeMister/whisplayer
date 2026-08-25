import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/playlist.dart';
import 'package:whisplayer/domain/entities/source_type.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(playlistRepositoryProvider);
    return Scaffold(
      appBar: _editing ? _buildEditingAppBar(l10n) : _buildNormalAppBar(l10n),
      bottomNavigationBar: _editing ? _buildEditBottomBar(l10n) : null,
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
              child: Text(
                _editing ? l10n.detailEmptyEditing : l10n.detailEmpty,
              ),
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
                    if (song.sourceType == SourceType.remote)
                      l10n.cloudTag,
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

  PreferredSizeWidget _buildNormalAppBar(AppLocalizations l10n) {
    return AppBar(
      title: Text(widget.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.addSongsTooltip,
          onPressed: () => _showAddSheet(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.editTooltip,
          onPressed: () => setState(() => _editing = true),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.deletePlaylistTooltip,
          onPressed: () => _confirmDelete(context, ref),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildEditingAppBar(AppLocalizations l10n) {
    final allSelected =
        _latestEntries.isNotEmpty &&
            _selectedEntryIds.length == _latestEntries.length;
    return AppBar(
      leading: BackButton(onPressed: _exitEditing),
      title: Text(l10n.selectedCount(_selectedEntryIds.length)),
      actions: [
        IconButton(
          tooltip: allSelected ? l10n.deselectAll : l10n.selectAll,
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
          tooltip: l10n.doneAction,
          onPressed: _exitEditing,
          icon: const Icon(Icons.check_rounded),
        ),
      ],
    );
  }

  Widget? _buildEditBottomBar(AppLocalizations l10n) {
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
          label: Text(l10n.deleteSelected(_selectedEntryIds.length)),
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context);
    final ids = _selectedEntryIds.toList();
    await ref.read(playlistRepositoryProvider).removeEntries(ids);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.removedCount(ids.length))));
    _exitEditing();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deletePlaylistTitle),
        content: Text(l10n.deletePlaylistBody(widget.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteAction),
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
    final l10n = AppLocalizations.of(context);
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
                  segments: [
                    ButtonSegment(value: 0, label: Text(l10n.localSongs)),
                    ButtonSegment(value: 1, label: Text(l10n.cloudSongs)),
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
                      labelText: mode == 0
                          ? l10n.filterLocal
                          : l10n.searchCloud,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: mode == 1
                          ? IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              tooltip: l10n.tooltipSearch,
                              onPressed: () => setState(() {}),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
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
    final l10n = AppLocalizations.of(context);
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
          return Center(child: Text(l10n.noLocalMatch));
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
    final l10n = AppLocalizations.of(context);
    await ref
        .read(playlistRepositoryProvider)
        .addSong(playlistId, songId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.addedTo(title))));
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
    final l10n = AppLocalizations.of(context);
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
        setState(() => _error = l10n.notConnected);
        return;
      }
      if (widget.query.isEmpty) {
        setState(() => _error = l10n.typeToSearchCloud);
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
      setState(() => _error = '${l10n.searchFailedPrefix}: $e');
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
    final l10n = AppLocalizations.of(context);
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
        ..showSnackBar(SnackBar(content: Text(l10n.addedTo(song.title))));
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.addFailedPrefix}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _added.remove(remoteSong.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _error == l10n.notConnected
                  ? () => unawaited(
                        context.push('/settings/remote-servers'),
                      )
                  : _search,
              child: Text(
                _error == l10n.notConnected
                    ? l10n.goConnect
                    : l10n.retry,
              ),
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
      return Center(child: Text(l10n.noCloudMatch));
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
