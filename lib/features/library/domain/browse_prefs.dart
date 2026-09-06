/// Strongly-typed, serializable browse preferences for the cloud library
/// screen.
///
/// This is the single value object that crosses the settings-repository seam:
/// the page reads/writes the whole struct, and the repository owns the raw
/// key names plus the string-to-enum conversion via fromMap and toMap.
enum CloudMode { albums, folders }

enum AlbumSort { name, artist, recent, songs }

enum FolderSort { name, songs }

enum CloudView { list, grid }

class BrowsePrefs {
  const BrowsePrefs({
    this.activeServerId = -1,
    this.mode = CloudMode.albums,
    this.albumSort = AlbumSort.name,
    this.albumDesc = false,
    this.albumsView = CloudView.grid,
    this.folderSort = FolderSort.name,
    this.folderDesc = false,
    this.foldersView = CloudView.list,
  });

  factory BrowsePrefs.fromMap(Map<String, String> map) {
    var mode = CloudMode.albums;
    if (map[kMode] == 'folders') {
      mode = CloudMode.folders;
    }

    var albumSort = AlbumSort.name;
    switch (map[kAlbumSort]) {
      case 'artist':
        albumSort = AlbumSort.artist;
      case 'recent':
        albumSort = AlbumSort.recent;
      case 'songs':
        albumSort = AlbumSort.songs;
      case 'name':
      default:
        albumSort = AlbumSort.name;
    }

    var albumsView = CloudView.grid;
    if (map[kAlbumsView] == 'list') {
      albumsView = CloudView.list;
    }

    var folderSort = FolderSort.name;
    if (map[kFolderSort] == 'songs') {
      folderSort = FolderSort.songs;
    }

    var foldersView = CloudView.list;
    if (map[kFoldersView] == 'grid') {
      foldersView = CloudView.grid;
    }

    final activeServerId = int.tryParse(map[kActiveServer] ?? '') ?? -1;
    return BrowsePrefs(
      activeServerId: activeServerId,
      mode: mode,
      albumSort: albumSort,
      albumDesc: map[kAlbumDesc] == 'true',
      albumsView: albumsView,
      folderSort: folderSort,
      folderDesc: map[kFolderDesc] == 'true',
      foldersView: foldersView,
    );
  }

  /// Storage keys owned by this value object. Kept here so the page never has
  /// to know the raw strings.
  static const String kActiveServer = 'remote.active_server_id';
  static const String kMode = 'cloud.browse_mode';
  static const String kAlbumSort = 'cloud.album_sort';
  static const String kAlbumDesc = 'cloud.album_desc';
  static const String kAlbumsView = 'cloud.albums_view';
  static const String kFolderSort = 'cloud.folder_sort';
  static const String kFolderDesc = 'cloud.folder_desc';
  static const String kFoldersView = 'cloud.folders_view';

  static const BrowsePrefs defaults = BrowsePrefs();

  final int activeServerId;
  final CloudMode mode;
  final AlbumSort albumSort;
  final bool albumDesc;
  final CloudView albumsView;
  final FolderSort folderSort;
  final bool folderDesc;
  final CloudView foldersView;

  BrowsePrefs copyWith({
    int? activeServerId,
    CloudMode? mode,
    AlbumSort? albumSort,
    bool? albumDesc,
    CloudView? albumsView,
    FolderSort? folderSort,
    bool? folderDesc,
    CloudView? foldersView,
  }) {
    return BrowsePrefs(
      activeServerId: activeServerId ?? this.activeServerId,
      mode: mode ?? this.mode,
      albumSort: albumSort ?? this.albumSort,
      albumDesc: albumDesc ?? this.albumDesc,
      albumsView: albumsView ?? this.albumsView,
      folderSort: folderSort ?? this.folderSort,
      folderDesc: folderDesc ?? this.folderDesc,
      foldersView: foldersView ?? this.foldersView,
    );
  }

  Map<String, String> toMap() {
    return <String, String>{
      kActiveServer: '$activeServerId',
      kMode: mode == CloudMode.folders ? 'folders' : 'albums',
      kAlbumSort: albumSort.name,
      kAlbumDesc: '$albumDesc',
      kAlbumsView: albumsView.name,
      kFolderSort: folderSort.name,
      kFolderDesc: '$folderDesc',
      kFoldersView: foldersView.name,
    };
  }
}
