// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get localTab => 'Local';

  @override
  String get cloudTab => 'Cloud';

  @override
  String get playlistTab => 'Playlists';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearanceEntry => 'Appearance';

  @override
  String get appearanceSubtitle => 'Theme mode & accent color';

  @override
  String get scanEntry => 'Scan music';

  @override
  String get scanSubtitle => 'Import local audio files';

  @override
  String get statsEntry => 'Playback stats';

  @override
  String get statsSubtitle => 'Top played & total listening time';

  @override
  String get remoteServersEntry => 'Remote music servers';

  @override
  String get remoteServersSubtitle => 'Navidrome / Subsonic self-hosted';

  @override
  String get languageEntry => 'Language';

  @override
  String get languageFollowSystem => 'Follow system';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageJa => '日本語';

  @override
  String get languageKo => '한국어';

  @override
  String get languageEn => 'English';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeModeLabel => 'Theme mode';

  @override
  String get themeModeFollowSystem => 'Follow system';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeColorLabel => 'Accent color';

  @override
  String get themeColorHint => 'Applies instantly; adapts to light & dark';

  @override
  String get desktopLyricsEntry => 'Desktop lyrics';

  @override
  String get desktopLyricsOn => 'On — shown over other apps';

  @override
  String get desktopLyricsOff => 'Show the current lyric line over other apps';

  @override
  String get desktopLyricsPermission =>
      '\"Display over other apps\" permission is required';

  @override
  String get colorSakura => 'Sakura';

  @override
  String get colorMagenta => 'Magenta';

  @override
  String get colorWisteria => 'Wisteria';

  @override
  String get colorDeepPurple => 'Deep Purple';

  @override
  String get colorLavender => 'Lavender';

  @override
  String get colorIris => 'Iris';

  @override
  String get colorNavy => 'Navy';

  @override
  String get colorSky => 'Sky';

  @override
  String get colorLake => 'Lake';

  @override
  String get colorCeladon => 'Celadon';

  @override
  String get colorMint => 'Mint';

  @override
  String get colorMatcha => 'Matcha';

  @override
  String get colorLime => 'Lime';

  @override
  String get colorOlive => 'Olive';

  @override
  String get colorLemon => 'Lemon';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorPeach => 'Peach';

  @override
  String get colorRed => 'Red';

  @override
  String get colorWine => 'Wine';

  @override
  String get colorRoseGold => 'Rose Gold';

  @override
  String get colorBlueGrey => 'Blue Grey';

  @override
  String get colorGrey => 'Grey';

  @override
  String get songsTab => 'Songs';

  @override
  String get albumsTab => 'Albums';

  @override
  String get artistsTab => 'Artists';

  @override
  String get foldersTab => 'Folders';

  @override
  String get libraryEmpty => 'No songs yet — scan music in Settings first';

  @override
  String get noAlbums => 'No albums';

  @override
  String get noArtists => 'No artists';

  @override
  String get noFolders => 'No folders';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String countSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String countAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'Play all';

  @override
  String get albumFallback => 'Album';

  @override
  String get artistFallback => 'Artist';

  @override
  String get play => 'Play';

  @override
  String get tooltipRecent => 'Recently played';

  @override
  String get tooltipSearch => 'Search';

  @override
  String get startupPage => 'Startup page';

  @override
  String get tooltipShuffle => 'Shuffle';

  @override
  String get tooltipSort => 'Sort';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortAddedAt => 'Recently added';

  @override
  String get sortPlayCount => 'Play count';

  @override
  String get sortDuration => 'Duration';

  @override
  String get sortDescending => 'Descending';

  @override
  String get searchHintInput => 'Search songs by keyword';

  @override
  String get searchHintFailure => 'Search failed, please try again later';

  @override
  String get searchHintNoMatch => 'No matching songs';

  @override
  String get songsPageTitle => 'Songs';

  @override
  String get songsPageEmpty => 'No songs yet — scan music in Settings first';

  @override
  String get folderDetailEmpty => '该文件夹暂无歌曲';

  @override
  String get recentTitle => 'Recently played';

  @override
  String get recentEmpty => 'No play history yet';

  @override
  String statsHeader(int plays, int completed, int minutes) {
    return '$plays plays · $completed completed · ~$minutes min total';
  }

  @override
  String get relJust => 'Just now';

  @override
  String relMinutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String relHoursAgo(int n) {
    return '$n hr ago';
  }

  @override
  String relDaysAgo(int n) {
    return '$n days ago';
  }

  @override
  String get statsTitle => 'Playback stats';

  @override
  String get statsEmpty => 'No stats yet — play a few songs first';

  @override
  String get topPlayed => 'Top played';

  @override
  String playCountLabel(int n) {
    return 'Played $n times';
  }

  @override
  String totalDurMinutes(int n) {
    return '~$n min';
  }

  @override
  String totalDurHours(int n) {
    return '~$n h';
  }

  @override
  String totalDurHoursMinutes(int h, int m) {
    return '$h h $m min';
  }

  @override
  String get cloudTitle => 'Cloud music';

  @override
  String get noServer => 'No server added yet';

  @override
  String get goAdd => 'Add';

  @override
  String get retry => 'Retry';

  @override
  String get loadFailedPrefix => 'Load failed';

  @override
  String get albumNoSongs => 'This album has no songs';

  @override
  String get openFailedPrefix => 'Open failed';

  @override
  String syncingTo(String title) {
    return 'Syncing “$title”…';
  }

  @override
  String get playFailedPrefix => 'Playback failed';

  @override
  String get cloudModeAlbums => 'Albums';

  @override
  String get cloudModeFolders => 'Folders';

  @override
  String get cloudFoldersEmpty => 'No folders yet';

  @override
  String get sortSongsCount => 'Song count';

  @override
  String get tooltipToggleView => 'Toggle view';

  @override
  String get searchHintFolders => 'Search folder names';

  @override
  String get folderNoSongs => 'No audio files in this folder';

  @override
  String get folderNoMatch => 'No matching folders';

  @override
  String get searchHintCloud => 'Fuzzy-search cloud songs & albums';

  @override
  String get sectionAlbums => 'Albums';

  @override
  String get sectionSongs => 'Songs';

  @override
  String get tooltipManageServers => 'Manage servers';

  @override
  String get tooltipRefresh => 'Refresh';

  @override
  String get tooltipSwitchServer => 'Switch server';

  @override
  String get serverNoAlbums => 'No albums on this server';

  @override
  String get cloudFallback => 'Cloud music';

  @override
  String get noServerYet => 'No servers yet — tap the button below to add one';

  @override
  String get tooltipDelete => 'Delete';

  @override
  String deleteServerTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteServerBody => 'The saved password will be removed as well.';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get deleteAction => 'Delete';

  @override
  String get addServerTitle => 'Add server';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldAddress => 'Server address';

  @override
  String get fieldAddressHint => 'e.g. 192.168.XX.XX:4533';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get testConnection => 'Test connection';

  @override
  String get saveAction => 'Save';

  @override
  String get fillAllFields => 'Please fill in all fields';

  @override
  String get loopbackSnackBar =>
      'Note: 127.0.0.1 points to the phone itself — use the PC\'s LAN IP instead';

  @override
  String get fillAllFieldsFull =>
      'Please fill in address, username and password';

  @override
  String get loopbackTest =>
      '127.0.0.1 / localhost points to the phone itself and cannot reach the PC; use the PC\'s LAN IP (see ipconfig)';

  @override
  String testOk(String url) {
    return 'Connected ✓ using $url';
  }

  @override
  String serverErrorMsg(String msg) {
    return 'Server error: $msg';
  }

  @override
  String cannotConnectMsg(String url) {
    return 'Cannot reach $url (check the address and phone network)';
  }

  @override
  String get loopbackHint =>
      '127.0.0.1 points to the phone itself; use the PC\'s LAN IP';

  @override
  String get scanTitle => 'Scan music';

  @override
  String get needAudioPermission => 'Audio file access permission required';

  @override
  String get allFilesDenied =>
      '\"All files access\" was not granted; lyric sidecar files (.lrc etc.) cannot be read';

  @override
  String get stopAction => 'Stop';

  @override
  String get startScanAction => 'Start scan';

  @override
  String get notScannedYet => 'Not scanned yet';

  @override
  String get ready => 'Ready';

  @override
  String scanDone(int added, int updated, int removed) {
    return 'Done: added $added · updated $updated · removed $removed';
  }

  @override
  String get scanError => 'Scan error';

  @override
  String get walking => 'Walking directories…';

  @override
  String get parsing => 'Parsing…';

  @override
  String get addDirectory => 'Add folder';

  @override
  String get createPlaylistTooltip => 'New playlist';

  @override
  String get createPlaylistTitle => 'New playlist';

  @override
  String get nameLabel => 'Name';

  @override
  String get createAction => 'Create';

  @override
  String get noPlaylists => 'No playlists yet';

  @override
  String get playlistsHint => 'Both local and cloud songs can be added';

  @override
  String get detailEmpty => 'Empty — tap top-right to add songs';

  @override
  String get detailEmptyEditing => 'Empty';

  @override
  String get cloudTag => 'Cloud';

  @override
  String get addSongsTooltip => 'Add songs';

  @override
  String get editTooltip => 'Edit songs';

  @override
  String get deletePlaylistTooltip => 'Delete playlist';

  @override
  String selectedCount(int n) {
    return '$n selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get doneAction => 'Done';

  @override
  String deleteSelected(int n) {
    return 'Delete selected ($n)';
  }

  @override
  String removedCount(int n) {
    return 'Removed $n';
  }

  @override
  String get deletePlaylistTitle => 'Delete playlist?';

  @override
  String deletePlaylistBody(String name) {
    return '“$name” will be deleted; the songs are not affected.';
  }

  @override
  String get localSongs => 'Local songs';

  @override
  String get cloudSongs => 'Cloud songs';

  @override
  String get filterLocal => 'Filter local songs';

  @override
  String get searchCloud => 'Fuzzy-search cloud songs';

  @override
  String get noLocalMatch => 'No matching local songs';

  @override
  String addedTo(String title) {
    return 'Added “$title”';
  }

  @override
  String get notConnected => 'Not connected to a server';

  @override
  String get goConnect => 'Connect';

  @override
  String get typeToSearchCloud => 'Type a keyword, then tap search';

  @override
  String get searchFailedPrefix => 'Search failed';

  @override
  String get addFailedPrefix => 'Add failed';

  @override
  String get noCloudMatch => 'No matching songs';

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get tooltipLoopMode => 'Loop mode';

  @override
  String get tooltipQueue => 'Play queue';

  @override
  String get tooltipBackToCover => 'Back to cover';

  @override
  String get tooltipFontSmaller => 'Smaller font';

  @override
  String get tooltipFontBigger => 'Larger font';

  @override
  String get tooltipManualAlign => 'Manual align';

  @override
  String get tooltipAlign => 'Text alignment';

  @override
  String get unsyncedBanner => 'No timing detected — showing text only';

  @override
  String get importLyricsFile => 'Import lyrics file';

  @override
  String get noLyrics => 'No lyrics';

  @override
  String get unlock => 'Unlock';

  @override
  String get tooltipOverlayOn => 'Hide desktop lyrics';

  @override
  String get tooltipOverlayOff => 'Show desktop lyrics';

  @override
  String get overlayTitle => 'Whisplayer Desktop Lyrics';

  @override
  String get overlayContent => 'Showing desktop lyrics';

  @override
  String get overlayWaiting => 'Waiting for playback…';

  @override
  String get overlayUnsynced =>
      '(Plain-text lyrics — sync scrolling not supported)';

  @override
  String get playlistDetailTitleFallback => 'Playlist';
}
