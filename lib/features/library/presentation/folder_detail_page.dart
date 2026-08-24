import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/domain/entities/song.dart';
import 'package:whisplayer/features/library/presentation/widgets/song_list_view.dart';
import 'package:whisplayer/features/player/application/player_controller.dart';

class FolderDetailPage extends ConsumerStatefulWidget {
  const FolderDetailPage({required this.dirPath, super.key});

  final String dirPath;

  @override
  ConsumerState<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends ConsumerState<FolderDetailPage> {
  List<Song>? _songs;

  String _normalize(String path) => path.replaceAll(r'\', '/');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ref.read(libraryRepositoryProvider).getAllSongs();
    if (!mounted) {
      return;
    }
    final prefix = '${_normalize(widget.dirPath)}/';
    setState(() {
      _songs = [
        for (final song in all)
          if (_normalize(song.path).startsWith(prefix)) song,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    final notifier = ref.read(playerControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dirPath.split('/').last),
      ),
      body: songs == null
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
              ? const Center(child: Text('该文件夹暂无歌曲'))
              : SongListView(songs: songs),
      floatingActionButton: songs != null && songs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => notifier.playSongs(songs),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放'),
            )
          : null,
    );
  }
}
