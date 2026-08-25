// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get localTab => '本地';

  @override
  String get cloudTab => '云端';

  @override
  String get playlistTab => '播放列表';

  @override
  String get settingsTitle => '设置';

  @override
  String get appearanceEntry => '外观';

  @override
  String get appearanceSubtitle => '主题模式与主题色';

  @override
  String get scanEntry => '扫描音乐';

  @override
  String get scanSubtitle => '导入本地音频文件';

  @override
  String get statsEntry => '播放统计';

  @override
  String get statsSubtitle => '最常播放与累计时长';

  @override
  String get remoteServersEntry => '远程音乐服务器';

  @override
  String get remoteServersSubtitle => 'Navidrome / Subsonic 自建服务';

  @override
  String get languageEntry => '语言';

  @override
  String get languageFollowSystem => '跟随系统';

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
  String get appearanceTitle => '外观';

  @override
  String get themeModeLabel => '主题模式';

  @override
  String get themeModeFollowSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get themeColorLabel => '主题色';

  @override
  String get themeColorHint => '点击即时生效，自动适配深浅模式';

  @override
  String get desktopLyricsEntry => '桌面歌词';

  @override
  String get desktopLyricsOn => '已开启，可在其他应用上方显示';

  @override
  String get desktopLyricsOff => '在其他应用上方显示当前歌词行';

  @override
  String get desktopLyricsPermission => '需要“显示在应用上层”权限才能开启桌面歌词';

  @override
  String get colorSakura => '樱粉';

  @override
  String get colorMagenta => '品红';

  @override
  String get colorWisteria => '紫藤';

  @override
  String get colorDeepPurple => '深紫';

  @override
  String get colorLavender => '雾紫';

  @override
  String get colorIris => '鸢尾';

  @override
  String get colorNavy => '藏青';

  @override
  String get colorSky => '晴空';

  @override
  String get colorLake => '湖水';

  @override
  String get colorCeladon => '青瓷';

  @override
  String get colorMint => '亮绿';

  @override
  String get colorMatcha => '抹茶';

  @override
  String get colorLime => '青柠';

  @override
  String get colorOlive => '橄榄';

  @override
  String get colorLemon => '柠黄';

  @override
  String get colorBrown => '棕咖';

  @override
  String get colorOrange => '橙';

  @override
  String get colorCoral => '珊瑚';

  @override
  String get colorPeach => '蜜桃';

  @override
  String get colorRed => '正红';

  @override
  String get colorWine => '酒红';

  @override
  String get colorRoseGold => '玫瑰金';

  @override
  String get colorBlueGrey => '蓝灰';

  @override
  String get colorGrey => '灰';

  @override
  String get songsTab => '歌曲';

  @override
  String get albumsTab => '专辑';

  @override
  String get artistsTab => '艺术家';

  @override
  String get foldersTab => '文件夹';

  @override
  String get libraryEmpty => '暂无歌曲，先去设置里扫描音乐吧';

  @override
  String get noAlbums => '暂无专辑';

  @override
  String get noArtists => '暂无艺术家';

  @override
  String get noFolders => '暂无文件夹';

  @override
  String get unknownArtist => '未知艺术家';

  @override
  String countSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(n, locale: localeName, other: '$n 首');
    return '$_temp0';
  }

  @override
  String countAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 张专辑',
    );
    return '$_temp0';
  }

  @override
  String get playAll => '播放全部';

  @override
  String get albumFallback => '专辑';

  @override
  String get artistFallback => '艺术家';

  @override
  String get play => '播放';

  @override
  String get tooltipRecent => '最近播放';

  @override
  String get tooltipSearch => '搜索';

  @override
  String get tooltipSort => '排序';

  @override
  String get sortTitle => '标题';

  @override
  String get sortArtist => '艺术家';

  @override
  String get sortAlbum => '专辑';

  @override
  String get sortAddedAt => '最近添加';

  @override
  String get sortPlayCount => '播放次数';

  @override
  String get sortDuration => '时长';

  @override
  String get sortDescending => '降序';

  @override
  String get searchHintInput => '输入关键字搜索歌曲';

  @override
  String get searchHintFailure => '搜索失败，请稍后重试';

  @override
  String get searchHintNoMatch => '未找到匹配的歌曲';

  @override
  String get songsPageTitle => '歌曲';

  @override
  String get songsPageEmpty => '还没有歌曲，先去设置里扫描音乐吧';

  @override
  String get folderDetailEmpty => '该文件夹暂无歌曲';

  @override
  String get recentTitle => '最近播放';

  @override
  String get recentEmpty => '还没有播放记录';

  @override
  String statsHeader(int plays, int completed, int minutes) {
    return '共播放 $plays 次 · 完播 $completed 次 · 累计约 $minutes 分钟';
  }

  @override
  String get relJust => '刚刚';

  @override
  String relMinutesAgo(int n) {
    return '$n分钟前';
  }

  @override
  String relHoursAgo(int n) {
    return '$n小时前';
  }

  @override
  String relDaysAgo(int n) {
    return '$n天前';
  }

  @override
  String get statsTitle => '播放统计';

  @override
  String get statsEmpty => '还没有统计数据，先去听几首歌吧';

  @override
  String get topPlayed => '最常播放';

  @override
  String playCountLabel(int n) {
    return '播放 $n 次';
  }

  @override
  String totalDurMinutes(int n) {
    return '约 $n 分钟';
  }

  @override
  String totalDurHours(int n) {
    return '约 $n 小时';
  }

  @override
  String totalDurHoursMinutes(int h, int m) {
    return '$h 小时 $m 分钟';
  }

  @override
  String get cloudTitle => '云端音乐';

  @override
  String get noServer => '尚未添加服务器';

  @override
  String get goAdd => '去添加';

  @override
  String get retry => '重试';

  @override
  String get loadFailedPrefix => '加载失败';

  @override
  String get albumNoSongs => '该专辑没有歌曲';

  @override
  String get openFailedPrefix => '打开失败';

  @override
  String syncingTo(String title) {
    return '正在同步「$title」…';
  }

  @override
  String get playFailedPrefix => '播放失败';

  @override
  String get searchHintCloud => '输入关键字模糊搜索云端歌曲与专辑';

  @override
  String get sectionAlbums => '专辑';

  @override
  String get sectionSongs => '歌曲';

  @override
  String get tooltipManageServers => '管理服务器';

  @override
  String get tooltipRefresh => '刷新';

  @override
  String get tooltipSwitchServer => '切换服务器';

  @override
  String get serverNoAlbums => '服务器上没有专辑';

  @override
  String get cloudFallback => '云端音乐';

  @override
  String get noServerYet => '还没有服务器，点右下角添加';

  @override
  String get tooltipDelete => '删除';

  @override
  String deleteServerTitle(String name) {
    return '删除 $name？';
  }

  @override
  String get deleteServerBody => '将同时删除已保存的密码。';

  @override
  String get cancelAction => '取消';

  @override
  String get deleteAction => '删除';

  @override
  String get addServerTitle => '添加服务器';

  @override
  String get fieldName => '名称';

  @override
  String get fieldAddress => '服务器地址';

  @override
  String get fieldAddressHint => '例：192.168.XX.XX:4533';

  @override
  String get fieldUsername => '用户名';

  @override
  String get fieldPassword => '密码';

  @override
  String get testConnection => '测试连接';

  @override
  String get saveAction => '保存';

  @override
  String get fillAllFields => '请填写全部字段';

  @override
  String get loopbackSnackBar => '注意：127.0.0.1 指向手机自身，通常应填写电脑的局域网 IP';

  @override
  String get fillAllFieldsFull => '请填写地址、用户名和密码';

  @override
  String get loopbackTest =>
      '127.0.0.1 / localhost 指向手机自身，无法访问电脑上的服务器；请填写电脑的局域网 IP（ipconfig 查看）';

  @override
  String testOk(String url) {
    return '连接成功 ✓ 将使用 $url';
  }

  @override
  String serverErrorMsg(String msg) {
    return '服务器响应错误：$msg';
  }

  @override
  String cannotConnectMsg(String url) {
    return '无法连接到 $url（请检查地址与手机网络）';
  }

  @override
  String get loopbackHint => '127.0.0.1 指向手机自身，无法访问电脑上的服务器；请填写电脑的局域网 IP';

  @override
  String get scanTitle => '扫描音乐';

  @override
  String get needAudioPermission => '需要音频文件访问权限';

  @override
  String get allFilesDenied => '未授予“所有文件访问”，歌词旁注文件（.lrc 等）将无法读取';

  @override
  String get stopAction => '停止';

  @override
  String get startScanAction => '开始扫描';

  @override
  String get notScannedYet => '尚未扫描';

  @override
  String get ready => '准备就绪';

  @override
  String scanDone(int added, int updated, int removed) {
    return '完成：新增 $added · 更新 $updated · 移除 $removed';
  }

  @override
  String get scanError => '扫描出错';

  @override
  String get walking => '正在遍历目录…';

  @override
  String get parsing => '正在解析…';

  @override
  String get addDirectory => '添加目录';

  @override
  String get createPlaylistTooltip => '新建播放列表';

  @override
  String get createPlaylistTitle => '新建播放列表';

  @override
  String get nameLabel => '名称';

  @override
  String get createAction => '创建';

  @override
  String get noPlaylists => '还没有播放列表';

  @override
  String get playlistsHint => '本地歌曲和云端歌曲都可以加入';

  @override
  String get detailEmpty => '列表为空，点右上角添加歌曲';

  @override
  String get detailEmptyEditing => '列表为空';

  @override
  String get cloudTag => '云端';

  @override
  String get addSongsTooltip => '添加歌曲';

  @override
  String get editTooltip => '编辑歌曲';

  @override
  String get deletePlaylistTooltip => '删除播放列表';

  @override
  String selectedCount(int n) {
    return '已选 $n 首';
  }

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String get doneAction => '完成';

  @override
  String deleteSelected(int n) {
    return '删除所选 ($n)';
  }

  @override
  String removedCount(int n) {
    return '已移除 $n 首';
  }

  @override
  String get deletePlaylistTitle => '删除播放列表？';

  @override
  String deletePlaylistBody(String name) {
    return '「$name」将被删除，歌曲不受影响。';
  }

  @override
  String get localSongs => '本地歌曲';

  @override
  String get cloudSongs => '云端歌曲';

  @override
  String get filterLocal => '过滤本地歌曲';

  @override
  String get searchCloud => '模糊搜索云端歌曲';

  @override
  String get noLocalMatch => '没有匹配的本地歌曲';

  @override
  String addedTo(String title) {
    return '已加入「$title」';
  }

  @override
  String get notConnected => '未连接到服务器';

  @override
  String get goConnect => '去连接';

  @override
  String get typeToSearchCloud => '输入关键字后点搜索';

  @override
  String get searchFailedPrefix => '搜索失败';

  @override
  String get addFailedPrefix => '添加失败';

  @override
  String get noCloudMatch => '未找到匹配的歌曲';

  @override
  String get queueEmpty => '队列为空';

  @override
  String get tooltipLoopMode => '循环模式';

  @override
  String get tooltipQueue => '播放队列';

  @override
  String get tooltipBackToCover => '返回封面';

  @override
  String get tooltipFontSmaller => '缩小字体';

  @override
  String get tooltipFontBigger => '放大字体';

  @override
  String get tooltipManualAlign => '手动对齐';

  @override
  String get tooltipAlign => '文字对齐';

  @override
  String get unsyncedBanner => '未检测到时间轴，仅显示文本';

  @override
  String get importLyricsFile => '导入歌词文件';

  @override
  String get noLyrics => '暂无歌词';

  @override
  String get unlock => '解锁';

  @override
  String get tooltipOverlayOn => '关闭桌面歌词';

  @override
  String get tooltipOverlayOff => '开启桌面歌词';

  @override
  String get overlayTitle => 'Whisplayer 桌面歌词';

  @override
  String get overlayContent => '正在显示桌面歌词';

  @override
  String get overlayWaiting => '等待播放…';

  @override
  String get overlayUnsynced => '（纯文本歌词，暂不支持同步滚动）';

  @override
  String get playlistDetailTitleFallback => '播放列表';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get localTab => '本地';

  @override
  String get cloudTab => '雲端';

  @override
  String get playlistTab => '播放清單';

  @override
  String get settingsTitle => '設定';

  @override
  String get appearanceEntry => '外觀';

  @override
  String get appearanceSubtitle => '主題模式與主題色';

  @override
  String get scanEntry => '掃描音樂';

  @override
  String get scanSubtitle => '匯入本機音訊檔案';

  @override
  String get statsEntry => '播放統計';

  @override
  String get statsSubtitle => '最常播放與累計時長';

  @override
  String get remoteServersEntry => '遠端音樂伺服器';

  @override
  String get remoteServersSubtitle => 'Navidrome / Subsonic 自架服務';

  @override
  String get languageEntry => '語言';

  @override
  String get languageFollowSystem => '跟隨系統';

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
  String get appearanceTitle => '外觀';

  @override
  String get themeModeLabel => '主題模式';

  @override
  String get themeModeFollowSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色';

  @override
  String get themeModeDark => '深色';

  @override
  String get themeColorLabel => '主題色';

  @override
  String get themeColorHint => '點選即時生效，自動適配深淺模式';

  @override
  String get desktopLyricsEntry => '桌面歌詞';

  @override
  String get desktopLyricsOn => '已開啟，可在其他應用上方顯示';

  @override
  String get desktopLyricsOff => '在其他應用上方顯示當前歌詞行';

  @override
  String get desktopLyricsPermission => '需要「顯示在其他應用程式上層」權限才能開啟桌面歌詞';

  @override
  String get colorSakura => '櫻粉';

  @override
  String get colorMagenta => '桃紅';

  @override
  String get colorWisteria => '紫藤';

  @override
  String get colorDeepPurple => '深紫';

  @override
  String get colorLavender => '霧紫';

  @override
  String get colorIris => '鳶尾';

  @override
  String get colorNavy => '藏青';

  @override
  String get colorSky => '晴空';

  @override
  String get colorLake => '湖水';

  @override
  String get colorCeladon => '青瓷';

  @override
  String get colorMint => '薄荷綠';

  @override
  String get colorMatcha => '抹茶';

  @override
  String get colorLime => '萊姆';

  @override
  String get colorOlive => '橄欖';

  @override
  String get colorLemon => '檸黃';

  @override
  String get colorBrown => '咖啡';

  @override
  String get colorOrange => '橘';

  @override
  String get colorCoral => '珊瑚';

  @override
  String get colorPeach => '蜜桃';

  @override
  String get colorRed => '正紅';

  @override
  String get colorWine => '酒紅';

  @override
  String get colorRoseGold => '玫瑰金';

  @override
  String get colorBlueGrey => '藍灰';

  @override
  String get colorGrey => '灰';

  @override
  String get songsTab => '歌曲';

  @override
  String get albumsTab => '專輯';

  @override
  String get artistsTab => '藝人';

  @override
  String get foldersTab => '資料夾';

  @override
  String get libraryEmpty => '還沒有歌曲，先去設定裡掃描音樂吧';

  @override
  String get noAlbums => '尚無專輯';

  @override
  String get noArtists => '尚無藝人';

  @override
  String get noFolders => '尚無資料夾';

  @override
  String get unknownArtist => '未知藝人';

  @override
  String countSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(n, locale: localeName, other: '$n 首');
    return '$_temp0';
  }

  @override
  String countAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 張專輯',
    );
    return '$_temp0';
  }

  @override
  String get playAll => '全部播放';

  @override
  String get albumFallback => '專輯';

  @override
  String get artistFallback => '藝人';

  @override
  String get play => '播放';

  @override
  String get tooltipRecent => '最近播放';

  @override
  String get tooltipSearch => '搜尋';

  @override
  String get tooltipSort => '排序';

  @override
  String get sortTitle => '標題';

  @override
  String get sortArtist => '藝人';

  @override
  String get sortAlbum => '專輯';

  @override
  String get sortAddedAt => '最近加入';

  @override
  String get sortPlayCount => '播放次數';

  @override
  String get sortDuration => '時長';

  @override
  String get sortDescending => '降冪';

  @override
  String get searchHintInput => '輸入關鍵字搜尋歌曲';

  @override
  String get searchHintFailure => '搜尋失敗，請稍後再試';

  @override
  String get searchHintNoMatch => '找不到符合的歌曲';

  @override
  String get songsPageTitle => '歌曲';

  @override
  String get songsPageEmpty => '還沒有歌曲，先去設定裡掃描音樂吧';

  @override
  String get recentTitle => '最近播放';

  @override
  String get recentEmpty => '還沒有播放紀錄';

  @override
  String statsHeader(int plays, int completed, int minutes) {
    return '共播放 $plays 次 · 完播 $completed 次 · 累計約 $minutes 分鐘';
  }

  @override
  String get relJust => '剛剛';

  @override
  String relMinutesAgo(int n) {
    return '$n分鐘前';
  }

  @override
  String relHoursAgo(int n) {
    return '$n小時前';
  }

  @override
  String relDaysAgo(int n) {
    return '$n天前';
  }

  @override
  String get statsTitle => '播放統計';

  @override
  String get statsEmpty => '還沒有統計數據，先去聽幾首歌吧';

  @override
  String get topPlayed => '最常播放';

  @override
  String playCountLabel(int n) {
    return '播放 $n 次';
  }

  @override
  String totalDurMinutes(int n) {
    return '約 $n 分鐘';
  }

  @override
  String totalDurHours(int n) {
    return '約 $n 小時';
  }

  @override
  String totalDurHoursMinutes(int h, int m) {
    return '$h 小時 $m 分鐘';
  }

  @override
  String get cloudTitle => '雲端音樂';

  @override
  String get noServer => '尚未新增伺服器';

  @override
  String get goAdd => '去新增';

  @override
  String get retry => '重試';

  @override
  String get loadFailedPrefix => '載入失敗';

  @override
  String get albumNoSongs => '此專輯沒有歌曲';

  @override
  String get openFailedPrefix => '開啟失敗';

  @override
  String syncingTo(String title) {
    return '正在同步「$title」…';
  }

  @override
  String get playFailedPrefix => '播放失敗';

  @override
  String get searchHintCloud => '輸入關鍵字模糊搜尋雲端歌曲與專輯';

  @override
  String get sectionAlbums => '專輯';

  @override
  String get sectionSongs => '歌曲';

  @override
  String get tooltipManageServers => '管理伺服器';

  @override
  String get tooltipRefresh => '重新整理';

  @override
  String get tooltipSwitchServer => '切換伺服器';

  @override
  String get serverNoAlbums => '伺服器上沒有專輯';

  @override
  String get cloudFallback => '雲端音樂';

  @override
  String get noServerYet => '還沒有伺服器，點右下角新增';

  @override
  String get tooltipDelete => '刪除';

  @override
  String deleteServerTitle(String name) {
    return '刪除 $name？';
  }

  @override
  String get deleteServerBody => '將同時刪除已儲存的密碼。';

  @override
  String get cancelAction => '取消';

  @override
  String get deleteAction => '刪除';

  @override
  String get addServerTitle => '新增伺服器';

  @override
  String get fieldName => '名稱';

  @override
  String get fieldAddress => '伺服器位址';

  @override
  String get fieldAddressHint => '例：192.168.XX.XX:4533';

  @override
  String get fieldUsername => '使用者名稱';

  @override
  String get fieldPassword => '密碼';

  @override
  String get testConnection => '測試連線';

  @override
  String get saveAction => '儲存';

  @override
  String get fillAllFields => '請填寫全部欄位';

  @override
  String get loopbackSnackBar => '注意：127.0.0.1 指向手機本身，通常應填寫電腦的區域網路 IP';

  @override
  String get fillAllFieldsFull => '請填寫位址、使用者名稱和密碼';

  @override
  String get loopbackTest =>
      '127.0.0.1 / localhost 指向手機本身，無法存取電腦上的伺服器；請填寫電腦的區域網路 IP（ipconfig 查看）';

  @override
  String testOk(String url) {
    return '連線成功 ✓ 將使用 $url';
  }

  @override
  String serverErrorMsg(String msg) {
    return '伺服器回應錯誤：$msg';
  }

  @override
  String cannotConnectMsg(String url) {
    return '無法連線到 $url（請檢查位址與手機網路）';
  }

  @override
  String get loopbackHint => '127.0.0.1 指向手機本身，無法存取電腦上的伺服器；請填寫電腦的區域網路 IP';

  @override
  String get scanTitle => '掃描音樂';

  @override
  String get needAudioPermission => '需要音訊檔案存取權限';

  @override
  String get allFilesDenied => '未授予「所有檔案存取」，歌詞旁註檔案（.lrc 等）將無法讀取';

  @override
  String get stopAction => '停止';

  @override
  String get startScanAction => '開始掃描';

  @override
  String get notScannedYet => '尚未掃描';

  @override
  String get ready => '準備就緒';

  @override
  String scanDone(int added, int updated, int removed) {
    return '完成：新增 $added · 更新 $updated · 移除 $removed';
  }

  @override
  String get scanError => '掃描出錯';

  @override
  String get walking => '正在走訪目錄…';

  @override
  String get parsing => '正在解析…';

  @override
  String get addDirectory => '新增資料夾';

  @override
  String get createPlaylistTooltip => '新增播放清單';

  @override
  String get createPlaylistTitle => '新增播放清單';

  @override
  String get nameLabel => '名稱';

  @override
  String get createAction => '建立';

  @override
  String get noPlaylists => '還沒有播放清單';

  @override
  String get playlistsHint => '本機歌曲和雲端歌曲都可以加入';

  @override
  String get detailEmpty => '清單為空，點右上角加入歌曲';

  @override
  String get detailEmptyEditing => '清單為空';

  @override
  String get cloudTag => '雲端';

  @override
  String get addSongsTooltip => '加入歌曲';

  @override
  String get editTooltip => '編輯歌曲';

  @override
  String get deletePlaylistTooltip => '刪除播放清單';

  @override
  String selectedCount(int n) {
    return '已選 $n 首';
  }

  @override
  String get selectAll => '全選';

  @override
  String get deselectAll => '取消全選';

  @override
  String get doneAction => '完成';

  @override
  String deleteSelected(int n) {
    return '刪除所選 ($n)';
  }

  @override
  String removedCount(int n) {
    return '已移除 $n 首';
  }

  @override
  String get deletePlaylistTitle => '刪除播放清單？';

  @override
  String deletePlaylistBody(String name) {
    return '「$name」將被刪除，歌曲不受影響。';
  }

  @override
  String get localSongs => '本機歌曲';

  @override
  String get cloudSongs => '雲端歌曲';

  @override
  String get filterLocal => '篩選本機歌曲';

  @override
  String get searchCloud => '模糊搜尋雲端歌曲';

  @override
  String get noLocalMatch => '沒有符合的本機歌曲';

  @override
  String addedTo(String title) {
    return '已加入「$title」';
  }

  @override
  String get notConnected => '未連線到伺服器';

  @override
  String get goConnect => '去連線';

  @override
  String get typeToSearchCloud => '輸入關鍵字後點搜尋';

  @override
  String get searchFailedPrefix => '搜尋失敗';

  @override
  String get addFailedPrefix => '加入失敗';

  @override
  String get noCloudMatch => '找不到符合的歌曲';

  @override
  String get queueEmpty => '佇列為空';

  @override
  String get tooltipLoopMode => '循環模式';

  @override
  String get tooltipQueue => '播放佇列';

  @override
  String get tooltipBackToCover => '返回封面';

  @override
  String get tooltipFontSmaller => '縮小字體';

  @override
  String get tooltipFontBigger => '放大字體';

  @override
  String get tooltipManualAlign => '手動對齊';

  @override
  String get tooltipAlign => '文字對齊';

  @override
  String get unsyncedBanner => '未偵測到時間軸，僅顯示文字';

  @override
  String get importLyricsFile => '匯入歌詞檔案';

  @override
  String get noLyrics => '暫無歌詞';

  @override
  String get unlock => '解鎖';

  @override
  String get tooltipOverlayOn => '關閉桌面歌詞';

  @override
  String get tooltipOverlayOff => '開啟桌面歌詞';

  @override
  String get overlayTitle => 'Whisplayer 桌面歌詞';

  @override
  String get overlayContent => '正在顯示桌面歌詞';

  @override
  String get overlayWaiting => '等待播放…';

  @override
  String get overlayUnsynced => '（純文字歌詞，暫不支援同步捲動）';

  @override
  String get playlistDetailTitleFallback => '播放清單';
}
