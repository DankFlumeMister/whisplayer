// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get localTab => 'ライブラリ';

  @override
  String get cloudTab => 'クラウド';

  @override
  String get playlistTab => 'プレイリスト';

  @override
  String get settingsTitle => '設定';

  @override
  String get appearanceEntry => '外観';

  @override
  String get appearanceSubtitle => 'テーマモードとアクセントカラー';

  @override
  String get scanEntry => '音楽をスキャン';

  @override
  String get scanSubtitle => 'ローカル音声ファイルを読み込む';

  @override
  String get statsEntry => '再生統計';

  @override
  String get statsSubtitle => 'よく再生する曲と累計時間';

  @override
  String get remoteServersEntry => 'リモート音楽サーバー';

  @override
  String get remoteServersSubtitle => 'Navidrome / Subsonic 自前サーバー';

  @override
  String get languageEntry => '言語';

  @override
  String get languageFollowSystem => 'システムに従う';

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
  String get appearanceTitle => '外観';

  @override
  String get themeModeLabel => 'テーマモード';

  @override
  String get themeModeFollowSystem => 'システムに従う';

  @override
  String get themeModeLight => 'ライト';

  @override
  String get themeModeDark => 'ダーク';

  @override
  String get themeColorLabel => 'アクセントカラー';

  @override
  String get themeColorHint => 'タップですぐ反映。ライト/ダーク両方に対応';

  @override
  String get desktopLyricsEntry => 'デスクトップ歌詞';

  @override
  String get desktopLyricsOn => 'オン — 他のアプリの上に表示中';

  @override
  String get desktopLyricsOff => '他のアプリの上に現在の歌詞行を表示';

  @override
  String get desktopLyricsPermission => '「他のアプリの上に重ねて表示」権限が必要です';

  @override
  String get colorSakura => '桜色';

  @override
  String get colorMagenta => 'マゼンタ';

  @override
  String get colorWisteria => 'フジ';

  @override
  String get colorDeepPurple => '濃紫';

  @override
  String get colorLavender => 'ラベンダー';

  @override
  String get colorIris => 'アイリス';

  @override
  String get colorNavy => 'ネイビー';

  @override
  String get colorSky => '空色';

  @override
  String get colorLake => 'コバルト';

  @override
  String get colorCeladon => '青磁';

  @override
  String get colorMint => 'ミント';

  @override
  String get colorMatcha => '抹茶';

  @override
  String get colorLime => 'ライム';

  @override
  String get colorOlive => 'オリーブ';

  @override
  String get colorLemon => 'レモン';

  @override
  String get colorBrown => 'ブラウン';

  @override
  String get colorOrange => 'オレンジ';

  @override
  String get colorCoral => 'コーラル';

  @override
  String get colorPeach => 'ピーチ';

  @override
  String get colorRed => 'レッド';

  @override
  String get colorWine => 'ワイン';

  @override
  String get colorRoseGold => 'ローズゴールド';

  @override
  String get colorBlueGrey => 'ブルーグレー';

  @override
  String get colorGrey => 'グレー';

  @override
  String get songsTab => '曲';

  @override
  String get albumsTab => 'アルバム';

  @override
  String get artistsTab => 'アーティスト';

  @override
  String get foldersTab => 'フォルダ';

  @override
  String get libraryEmpty => '曲がありません。設定から音楽をスキャンしてください';

  @override
  String get noAlbums => 'アルバムがありません';

  @override
  String get noArtists => 'アーティストがいません';

  @override
  String get noFolders => 'フォルダがありません';

  @override
  String get unknownArtist => '不明なアーティスト';

  @override
  String countSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(n, locale: localeName, other: '$n 曲');
    return '$_temp0';
  }

  @override
  String countAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 枚のアルバム',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'すべて再生';

  @override
  String get albumFallback => 'アルバム';

  @override
  String get artistFallback => 'アーティスト';

  @override
  String get play => '再生';

  @override
  String get tooltipRecent => '最近再生した曲';

  @override
  String get tooltipSearch => '検索';

  @override
  String get tooltipSort => '並べ替え';

  @override
  String get sortTitle => 'タイトル';

  @override
  String get sortArtist => 'アーティスト';

  @override
  String get sortAlbum => 'アルバム';

  @override
  String get sortAddedAt => '追加日';

  @override
  String get sortPlayCount => '再生回数';

  @override
  String get sortDuration => '長さ';

  @override
  String get sortDescending => '降順';

  @override
  String get searchHintInput => 'キーワードで曲を検索';

  @override
  String get searchHintFailure => '検索に失敗しました。後でお試しください';

  @override
  String get searchHintNoMatch => '一致する曲が見つかりません';

  @override
  String get songsPageTitle => '曲';

  @override
  String get songsPageEmpty => '曲がありません。設定から音楽をスキャンしてください';

  @override
  String get folderDetailEmpty => '该文件夹暂无歌曲';

  @override
  String get recentTitle => '最近再生した曲';

  @override
  String get recentEmpty => '再生履歴はまだありません';

  @override
  String statsHeader(int plays, int completed, int minutes) {
    return '再生 $plays 回 · 完聴 $completed 回 · 累計約 $minutes 分';
  }

  @override
  String get relJust => 'たった今';

  @override
  String relMinutesAgo(int n) {
    return '$n分前';
  }

  @override
  String relHoursAgo(int n) {
    return '$n時間前';
  }

  @override
  String relDaysAgo(int n) {
    return '$n日前';
  }

  @override
  String get statsTitle => '再生統計';

  @override
  String get statsEmpty => '統計データはまだありません。曲を再生してみましょう';

  @override
  String get topPlayed => 'よく再生される曲';

  @override
  String playCountLabel(int n) {
    return '再生 $n 回';
  }

  @override
  String totalDurMinutes(int n) {
    return '約 $n 分';
  }

  @override
  String totalDurHours(int n) {
    return '約 $n 時間';
  }

  @override
  String totalDurHoursMinutes(int h, int m) {
    return '$h 時間 $m 分';
  }

  @override
  String get cloudTitle => 'クラウド音楽';

  @override
  String get noServer => 'サーバーが追加されていません';

  @override
  String get goAdd => '追加する';

  @override
  String get retry => '再試行';

  @override
  String get loadFailedPrefix => '読み込み失敗';

  @override
  String get albumNoSongs => 'このアルバムには曲がありません';

  @override
  String get openFailedPrefix => '開けませんでした';

  @override
  String syncingTo(String title) {
    return '「$title」を同期中…';
  }

  @override
  String get playFailedPrefix => '再生に失敗しました';

  @override
  String get searchHintCloud => 'キーワードでクラウドの曲とアルバムを検索';

  @override
  String get sectionAlbums => 'アルバム';

  @override
  String get sectionSongs => '曲';

  @override
  String get tooltipManageServers => 'サーバー管理';

  @override
  String get tooltipRefresh => '更新';

  @override
  String get tooltipSwitchServer => 'サーバー切替';

  @override
  String get serverNoAlbums => 'サーバーにアルバムがありません';

  @override
  String get cloudFallback => 'クラウド音楽';

  @override
  String get noServerYet => 'サーバーがありません。右下のボタンで追加してください';

  @override
  String get tooltipDelete => '削除';

  @override
  String deleteServerTitle(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get deleteServerBody => '保存されたパスワードも削除されます。';

  @override
  String get cancelAction => 'キャンセル';

  @override
  String get deleteAction => '削除';

  @override
  String get addServerTitle => 'サーバーを追加';

  @override
  String get fieldName => '名前';

  @override
  String get fieldAddress => 'サーバーアドレス';

  @override
  String get fieldAddressHint => '例：192.168.XX.XX:4533';

  @override
  String get fieldUsername => 'ユーザー名';

  @override
  String get fieldPassword => 'パスワード';

  @override
  String get testConnection => '接続テスト';

  @override
  String get saveAction => '保存';

  @override
  String get fillAllFields => 'すべての項目を入力してください';

  @override
  String get loopbackSnackBar =>
      '注意：127.0.0.1 はスマホ自身を指します。PC のローカル IP を入力してください';

  @override
  String get fillAllFieldsFull => 'アドレス・ユーザー名・パスワードを入力してください';

  @override
  String get loopbackTest =>
      '127.0.0.1 / localhost はスマホ自身を指し、PC のサーバーには届きません。PC のローカル IP を入力してください（ipconfig で確認）';

  @override
  String testOk(String url) {
    return '接続成功 ✓ $url を使用します';
  }

  @override
  String serverErrorMsg(String msg) {
    return 'サーバーエラー：$msg';
  }

  @override
  String cannotConnectMsg(String url) {
    return '$url に接続できません（アドレスと回線を確認）';
  }

  @override
  String get loopbackHint => '127.0.0.1 はスマホ自身を指します。PC のローカル IP を入力してください';

  @override
  String get scanTitle => '音楽をスキャン';

  @override
  String get needAudioPermission => '音声ファイルへのアクセス権限が必要です';

  @override
  String get allFilesDenied =>
      '「すべてのファイルへのアクセス」が許可されていないため、歌詞ファイル（.lrc など）を読み込めません';

  @override
  String get stopAction => '停止';

  @override
  String get startScanAction => 'スキャン開始';

  @override
  String get notScannedYet => '未スキャン';

  @override
  String get ready => '準備完了';

  @override
  String scanDone(int added, int updated, int removed) {
    return '完了：追加 $added · 更新 $updated · 削除 $removed';
  }

  @override
  String get scanError => 'スキャンエラー';

  @override
  String get walking => 'ディレクトリを走査中…';

  @override
  String get parsing => '解析中…';

  @override
  String get addDirectory => 'フォルダを追加';

  @override
  String get createPlaylistTooltip => 'プレイリストを作成';

  @override
  String get createPlaylistTitle => '新しいプレイリスト';

  @override
  String get nameLabel => '名前';

  @override
  String get createAction => '作成';

  @override
  String get noPlaylists => 'プレイリストはまだありません';

  @override
  String get playlistsHint => 'ローカル曲もクラウド曲も追加できます';

  @override
  String get detailEmpty => '空です。右上から曲を追加してください';

  @override
  String get detailEmptyEditing => '空です';

  @override
  String get cloudTag => 'クラウド';

  @override
  String get addSongsTooltip => '曲を追加';

  @override
  String get editTooltip => '曲を編集';

  @override
  String get deletePlaylistTooltip => 'プレイリストを削除';

  @override
  String selectedCount(int n) {
    return '$n 件選択中';
  }

  @override
  String get selectAll => 'すべて選択';

  @override
  String get deselectAll => '選択解除';

  @override
  String get doneAction => '完了';

  @override
  String deleteSelected(int n) {
    return '選択した曲を削除 ($n)';
  }

  @override
  String removedCount(int n) {
    return '$n 件削除しました';
  }

  @override
  String get deletePlaylistTitle => 'プレイリストを削除しますか？';

  @override
  String deletePlaylistBody(String name) {
    return '「$name」を削除します。曲自体は影響を受けません。';
  }

  @override
  String get localSongs => 'ローカルの曲';

  @override
  String get cloudSongs => 'クラウドの曲';

  @override
  String get filterLocal => 'ローカルの曲を絞り込み';

  @override
  String get searchCloud => 'クラウドの曲をあいまい検索';

  @override
  String get noLocalMatch => '一致するローカルの曲がありません';

  @override
  String addedTo(String title) {
    return '「$title」を追加しました';
  }

  @override
  String get notConnected => 'サーバーに接続していません';

  @override
  String get goConnect => '接続する';

  @override
  String get typeToSearchCloud => 'キーワードを入力して検索をタップ';

  @override
  String get searchFailedPrefix => '検索に失敗しました';

  @override
  String get addFailedPrefix => '追加に失敗しました';

  @override
  String get noCloudMatch => '一致する曲が見つかりません';

  @override
  String get queueEmpty => 'キューは空です';

  @override
  String get tooltipLoopMode => 'ループモード';

  @override
  String get tooltipQueue => '再生キュー';

  @override
  String get tooltipBackToCover => 'カバーに戻る';

  @override
  String get tooltipFontSmaller => '文字を小さく';

  @override
  String get tooltipFontBigger => '文字を大きく';

  @override
  String get tooltipManualAlign => '手動合わせ';

  @override
  String get tooltipAlign => 'テキスト配置';

  @override
  String get unsyncedBanner => 'タイミングが検出されないため、テキストのみ表示';

  @override
  String get importLyricsFile => '歌詞ファイルを読み込む';

  @override
  String get noLyrics => '歌詞がありません';

  @override
  String get unlock => 'ロック解除';

  @override
  String get tooltipOverlayOn => 'デスクトップ歌詞を閉じる';

  @override
  String get tooltipOverlayOff => 'デスクトップ歌詞を表示';

  @override
  String get overlayTitle => 'Whisplayer デスクトップ歌詞';

  @override
  String get overlayContent => 'デスクトップ歌詞を表示中';

  @override
  String get overlayWaiting => '再生を待機中…';

  @override
  String get overlayUnsynced => '（テキスト歌詞のためスクロール同期は非対応）';

  @override
  String get playlistDetailTitleFallback => 'プレイリスト';
}
