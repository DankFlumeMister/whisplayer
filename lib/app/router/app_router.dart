import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:whisplayer/core/providers/startup_tab_provider.dart';
import 'package:whisplayer/domain/entities/album.dart';
import 'package:whisplayer/domain/entities/artist.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/features/library/presentation/album_detail_page.dart';
import 'package:whisplayer/features/library/presentation/artist_detail_page.dart';
import 'package:whisplayer/features/library/presentation/folder_detail_page.dart';
import 'package:whisplayer/features/library/presentation/library_page.dart';
import 'package:whisplayer/features/library/presentation/recently_played_page.dart';
import 'package:whisplayer/features/library/presentation/remote_albums_page.dart';
import 'package:whisplayer/features/library/presentation/remote_folder_page.dart';
import 'package:whisplayer/features/library/presentation/songs_page.dart';
import 'package:whisplayer/features/library/presentation/stats_page.dart';
import 'package:whisplayer/features/player/presentation/player_page.dart';
import 'package:whisplayer/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:whisplayer/features/playlists/presentation/playlist_detail_page.dart';
import 'package:whisplayer/features/playlists/presentation/playlists_page.dart';
import 'package:whisplayer/features/settings/presentation/appearance_page.dart';
import 'package:whisplayer/features/settings/presentation/remote_servers_page.dart';
import 'package:whisplayer/features/settings/presentation/scan_page.dart';
import 'package:whisplayer/features/settings/presentation/settings_page.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Read (not watch): changing the preference applies next launch.
  final startOnCloud = ref.read(startupTabProvider) == 'cloud';
  return GoRouter(
    initialLocation: startOnCloud ? '/cloud' : '/library',
    routes: [
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PlayerPage(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'scan',
            builder: (_, __) => const ScanPage(),
          ),
          GoRoute(
            path: 'appearance',
            builder: (_, __) => const AppearancePage(),
          ),
          GoRoute(
            path: 'remote-servers',
            builder: (_, __) => const RemoteServersPage(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, __) => const LibraryPage(),
                routes: [
                  GoRoute(
                    path: 'songs',
                    builder: (_, __) => const SongsPage(),
                  ),
                  GoRoute(
                    path: 'recently-played',
                    builder: (_, __) => const RecentlyPlayedPage(),
                  ),
                  GoRoute(
                    path: 'stats',
                    builder: (_, __) => const StatsPage(),
                  ),
                  GoRoute(
                    path: 'album/:id',
                    builder: (context, state) => AlbumDetailPage(
                      albumId:
                          int.parse(state.pathParameters['id']!),
                      album: state.extra as Album?,
                    ),
                  ),
                  GoRoute(
                    path: 'artist/:id',
                    builder: (context, state) => ArtistDetailPage(
                      artistId:
                          int.parse(state.pathParameters['id']!),
                      artist: state.extra as Artist?,
                    ),
                  ),
                  GoRoute(
                    path: 'folder',
                    builder: (_, state) => FolderDetailPage(
                      dirPath: state.extra as String? ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cloud',
                builder: (_, __) => const RemoteAlbumsPage(),
                routes: [
                  GoRoute(
                    path: 'folder/:serverId',
                    builder: (context, state) {
                      final server = state.extra as RemoteServer?;
                      if (server == null) {
                        return const Scaffold(
                          body: Center(child: Text('missing server')),
                        );
                      }
                      return RemoteFolderPage(
                        server: server,
                        folderName:
                            state.uri.queryParameters['name'] ?? '',
                        subPath: state.uri.queryParameters['sub'],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playlists',
                builder: (_, __) => const PlaylistsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PlaylistDetailPage(
                      playlistId: int.parse(state.pathParameters['id']!),
                      name: state.uri.queryParameters['name'] ??
                          AppLocalizations.of(context).playlistTab,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  );
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved),
    child: FadeTransition(opacity: curved, child: child),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.library_music_outlined),
                selectedIcon: const Icon(Icons.library_music),
                label: l10n.localTab,
              ),
              NavigationDestination(
                icon: const Icon(Icons.cloud_outlined),
                selectedIcon: const Icon(Icons.cloud),
                label: l10n.cloudTab,
              ),
              NavigationDestination(
                icon: const Icon(Icons.format_list_bulleted_outlined),
                selectedIcon: const Icon(Icons.format_list_bulleted),
                label: l10n.playlistTab,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
