import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @localTab.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get localTab;

  /// No description provided for @cloudTab.
  ///
  /// In zh, this message translates to:
  /// **'云端'**
  String get cloudTab;

  /// No description provided for @playlistTab.
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get playlistTab;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @appearanceEntry.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceEntry;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'主题模式与主题色'**
  String get appearanceSubtitle;

  /// No description provided for @scanEntry.
  ///
  /// In zh, this message translates to:
  /// **'扫描音乐'**
  String get scanEntry;

  /// No description provided for @scanSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导入本地音频文件'**
  String get scanSubtitle;

  /// No description provided for @statsEntry.
  ///
  /// In zh, this message translates to:
  /// **'播放统计'**
  String get statsEntry;

  /// No description provided for @statsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'最常播放与累计时长'**
  String get statsSubtitle;

  /// No description provided for @remoteServersEntry.
  ///
  /// In zh, this message translates to:
  /// **'远程音乐服务器'**
  String get remoteServersEntry;

  /// No description provided for @remoteServersSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Navidrome / Subsonic 自建服务'**
  String get remoteServersSubtitle;

  /// No description provided for @languageEntry.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get languageEntry;

  /// No description provided for @languageFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageFollowSystem;

  /// No description provided for @languageZhHans.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageZhHans;

  /// No description provided for @languageZhHant.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get languageZhHant;

  /// No description provided for @languageJa.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get languageJa;

  /// No description provided for @languageKo.
  ///
  /// In zh, this message translates to:
  /// **'한국어'**
  String get languageKo;

  /// No description provided for @languageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceTitle;

  /// No description provided for @themeModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeModeLabel;

  /// No description provided for @themeModeFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeFollowSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @themeColorLabel.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get themeColorLabel;

  /// No description provided for @themeColorHint.
  ///
  /// In zh, this message translates to:
  /// **'点击即时生效，自动适配深浅模式'**
  String get themeColorHint;

  /// No description provided for @desktopLyricsEntry.
  ///
  /// In zh, this message translates to:
  /// **'桌面歌词'**
  String get desktopLyricsEntry;

  /// No description provided for @desktopLyricsOn.
  ///
  /// In zh, this message translates to:
  /// **'已开启，可在其他应用上方显示'**
  String get desktopLyricsOn;

  /// No description provided for @desktopLyricsOff.
  ///
  /// In zh, this message translates to:
  /// **'在其他应用上方显示当前歌词行'**
  String get desktopLyricsOff;

  /// No description provided for @desktopLyricsPermission.
  ///
  /// In zh, this message translates to:
  /// **'需要“显示在应用上层”权限才能开启桌面歌词'**
  String get desktopLyricsPermission;

  /// No description provided for @colorSakura.
  ///
  /// In zh, this message translates to:
  /// **'樱粉'**
  String get colorSakura;

  /// No description provided for @colorMagenta.
  ///
  /// In zh, this message translates to:
  /// **'品红'**
  String get colorMagenta;

  /// No description provided for @colorWisteria.
  ///
  /// In zh, this message translates to:
  /// **'紫藤'**
  String get colorWisteria;

  /// No description provided for @colorDeepPurple.
  ///
  /// In zh, this message translates to:
  /// **'深紫'**
  String get colorDeepPurple;

  /// No description provided for @colorLavender.
  ///
  /// In zh, this message translates to:
  /// **'雾紫'**
  String get colorLavender;

  /// No description provided for @colorIris.
  ///
  /// In zh, this message translates to:
  /// **'鸢尾'**
  String get colorIris;

  /// No description provided for @colorNavy.
  ///
  /// In zh, this message translates to:
  /// **'藏青'**
  String get colorNavy;

  /// No description provided for @colorSky.
  ///
  /// In zh, this message translates to:
  /// **'晴空'**
  String get colorSky;

  /// No description provided for @colorLake.
  ///
  /// In zh, this message translates to:
  /// **'湖水'**
  String get colorLake;

  /// No description provided for @colorCeladon.
  ///
  /// In zh, this message translates to:
  /// **'青瓷'**
  String get colorCeladon;

  /// No description provided for @colorMint.
  ///
  /// In zh, this message translates to:
  /// **'亮绿'**
  String get colorMint;

  /// No description provided for @colorMatcha.
  ///
  /// In zh, this message translates to:
  /// **'抹茶'**
  String get colorMatcha;

  /// No description provided for @colorLime.
  ///
  /// In zh, this message translates to:
  /// **'青柠'**
  String get colorLime;

  /// No description provided for @colorOlive.
  ///
  /// In zh, this message translates to:
  /// **'橄榄'**
  String get colorOlive;

  /// No description provided for @colorLemon.
  ///
  /// In zh, this message translates to:
  /// **'柠黄'**
  String get colorLemon;

  /// No description provided for @colorBrown.
  ///
  /// In zh, this message translates to:
  /// **'棕咖'**
  String get colorBrown;

  /// No description provided for @colorOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙'**
  String get colorOrange;

  /// No description provided for @colorCoral.
  ///
  /// In zh, this message translates to:
  /// **'珊瑚'**
  String get colorCoral;

  /// No description provided for @colorPeach.
  ///
  /// In zh, this message translates to:
  /// **'蜜桃'**
  String get colorPeach;

  /// No description provided for @colorRed.
  ///
  /// In zh, this message translates to:
  /// **'正红'**
  String get colorRed;

  /// No description provided for @colorWine.
  ///
  /// In zh, this message translates to:
  /// **'酒红'**
  String get colorWine;

  /// No description provided for @colorRoseGold.
  ///
  /// In zh, this message translates to:
  /// **'玫瑰金'**
  String get colorRoseGold;

  /// No description provided for @colorBlueGrey.
  ///
  /// In zh, this message translates to:
  /// **'蓝灰'**
  String get colorBlueGrey;

  /// No description provided for @colorGrey.
  ///
  /// In zh, this message translates to:
  /// **'灰'**
  String get colorGrey;

  /// No description provided for @songsTab.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get songsTab;

  /// No description provided for @albumsTab.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get albumsTab;

  /// No description provided for @artistsTab.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get artistsTab;

  /// No description provided for @foldersTab.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get foldersTab;

  /// No description provided for @libraryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌曲，先去设置里扫描音乐吧'**
  String get libraryEmpty;

  /// No description provided for @noAlbums.
  ///
  /// In zh, this message translates to:
  /// **'暂无专辑'**
  String get noAlbums;

  /// No description provided for @noArtists.
  ///
  /// In zh, this message translates to:
  /// **'暂无艺术家'**
  String get noArtists;

  /// No description provided for @noFolders.
  ///
  /// In zh, this message translates to:
  /// **'暂无文件夹'**
  String get noFolders;

  /// No description provided for @unknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知艺术家'**
  String get unknownArtist;

  /// No description provided for @countSongs.
  ///
  /// In zh, this message translates to:
  /// **'{n,plural,other{{n} 首}}'**
  String countSongs(int n);

  /// No description provided for @countAlbums.
  ///
  /// In zh, this message translates to:
  /// **'{n,plural,other{{n} 张专辑}}'**
  String countAlbums(int n);

  /// No description provided for @playAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get playAll;

  /// No description provided for @albumFallback.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get albumFallback;

  /// No description provided for @artistFallback.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get artistFallback;

  /// No description provided for @play.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// No description provided for @tooltipRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get tooltipRecent;

  /// No description provided for @tooltipSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get tooltipSearch;

  /// No description provided for @tooltipSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get tooltipSort;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get sortArtist;

  /// No description provided for @sortAlbum.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get sortAlbum;

  /// No description provided for @sortAddedAt.
  ///
  /// In zh, this message translates to:
  /// **'最近添加'**
  String get sortAddedAt;

  /// No description provided for @sortPlayCount.
  ///
  /// In zh, this message translates to:
  /// **'播放次数'**
  String get sortPlayCount;

  /// No description provided for @sortDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get sortDuration;

  /// No description provided for @sortDescending.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get sortDescending;

  /// No description provided for @searchHintInput.
  ///
  /// In zh, this message translates to:
  /// **'输入关键字搜索歌曲'**
  String get searchHintInput;

  /// No description provided for @searchHintFailure.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败，请稍后重试'**
  String get searchHintFailure;

  /// No description provided for @searchHintNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的歌曲'**
  String get searchHintNoMatch;

  /// No description provided for @songsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get songsPageTitle;

  /// No description provided for @songsPageEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有歌曲，先去设置里扫描音乐吧'**
  String get songsPageEmpty;

  /// No description provided for @folderDetailEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该文件夹暂无歌曲'**
  String get folderDetailEmpty;

  /// No description provided for @recentTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get recentTitle;

  /// No description provided for @recentEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有播放记录'**
  String get recentEmpty;

  /// No description provided for @statsHeader.
  ///
  /// In zh, this message translates to:
  /// **'共播放 {plays} 次 · 完播 {completed} 次 · 累计约 {minutes} 分钟'**
  String statsHeader(int plays, int completed, int minutes);

  /// No description provided for @relJust.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get relJust;

  /// No description provided for @relMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{n}分钟前'**
  String relMinutesAgo(int n);

  /// No description provided for @relHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{n}小时前'**
  String relHoursAgo(int n);

  /// No description provided for @relDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{n}天前'**
  String relDaysAgo(int n);

  /// No description provided for @statsTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放统计'**
  String get statsTitle;

  /// No description provided for @statsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有统计数据，先去听几首歌吧'**
  String get statsEmpty;

  /// No description provided for @topPlayed.
  ///
  /// In zh, this message translates to:
  /// **'最常播放'**
  String get topPlayed;

  /// No description provided for @playCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'播放 {n} 次'**
  String playCountLabel(int n);

  /// No description provided for @totalDurMinutes.
  ///
  /// In zh, this message translates to:
  /// **'约 {n} 分钟'**
  String totalDurMinutes(int n);

  /// No description provided for @totalDurHours.
  ///
  /// In zh, this message translates to:
  /// **'约 {n} 小时'**
  String totalDurHours(int n);

  /// No description provided for @totalDurHoursMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{h} 小时 {m} 分钟'**
  String totalDurHoursMinutes(int h, int m);

  /// No description provided for @cloudTitle.
  ///
  /// In zh, this message translates to:
  /// **'云端音乐'**
  String get cloudTitle;

  /// No description provided for @noServer.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加服务器'**
  String get noServer;

  /// No description provided for @goAdd.
  ///
  /// In zh, this message translates to:
  /// **'去添加'**
  String get goAdd;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @loadFailedPrefix.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailedPrefix;

  /// No description provided for @albumNoSongs.
  ///
  /// In zh, this message translates to:
  /// **'该专辑没有歌曲'**
  String get albumNoSongs;

  /// No description provided for @openFailedPrefix.
  ///
  /// In zh, this message translates to:
  /// **'打开失败'**
  String get openFailedPrefix;

  /// No description provided for @syncingTo.
  ///
  /// In zh, this message translates to:
  /// **'正在同步「{title}」…'**
  String syncingTo(String title);

  /// No description provided for @playFailedPrefix.
  ///
  /// In zh, this message translates to:
  /// **'播放失败'**
  String get playFailedPrefix;

  /// No description provided for @searchHintCloud.
  ///
  /// In zh, this message translates to:
  /// **'输入关键字模糊搜索云端歌曲与专辑'**
  String get searchHintCloud;

  /// No description provided for @sectionAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get sectionAlbums;

  /// No description provided for @sectionSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get sectionSongs;

  /// No description provided for @tooltipManageServers.
  ///
  /// In zh, this message translates to:
  /// **'管理服务器'**
  String get tooltipManageServers;

  /// No description provided for @tooltipRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get tooltipRefresh;

  /// No description provided for @tooltipSwitchServer.
  ///
  /// In zh, this message translates to:
  /// **'切换服务器'**
  String get tooltipSwitchServer;

  /// No description provided for @serverNoAlbums.
  ///
  /// In zh, this message translates to:
  /// **'服务器上没有专辑'**
  String get serverNoAlbums;

  /// No description provided for @cloudFallback.
  ///
  /// In zh, this message translates to:
  /// **'云端音乐'**
  String get cloudFallback;

  /// No description provided for @noServerYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有服务器，点右下角添加'**
  String get noServerYet;

  /// No description provided for @tooltipDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get tooltipDelete;

  /// No description provided for @deleteServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除 {name}？'**
  String deleteServerTitle(String name);

  /// No description provided for @deleteServerBody.
  ///
  /// In zh, this message translates to:
  /// **'将同时删除已保存的密码。'**
  String get deleteServerBody;

  /// No description provided for @cancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancelAction;

  /// No description provided for @deleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteAction;

  /// No description provided for @addServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get addServerTitle;

  /// No description provided for @fieldName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get fieldName;

  /// No description provided for @fieldAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get fieldAddress;

  /// No description provided for @fieldAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'例：192.168.XX.XX:4533'**
  String get fieldAddressHint;

  /// No description provided for @fieldUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get fieldPassword;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @saveAction.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveAction;

  /// No description provided for @fillAllFields.
  ///
  /// In zh, this message translates to:
  /// **'请填写全部字段'**
  String get fillAllFields;

  /// No description provided for @loopbackSnackBar.
  ///
  /// In zh, this message translates to:
  /// **'注意：127.0.0.1 指向手机自身，通常应填写电脑的局域网 IP'**
  String get loopbackSnackBar;

  /// No description provided for @fillAllFieldsFull.
  ///
  /// In zh, this message translates to:
  /// **'请填写地址、用户名和密码'**
  String get fillAllFieldsFull;

  /// No description provided for @loopbackTest.
  ///
  /// In zh, this message translates to:
  /// **'127.0.0.1 / localhost 指向手机自身，无法访问电脑上的服务器；请填写电脑的局域网 IP（ipconfig 查看）'**
  String get loopbackTest;

  /// No description provided for @testOk.
  ///
  /// In zh, this message translates to:
  /// **'连接成功 ✓ 将使用 {url}'**
  String testOk(String url);

  /// No description provided for @serverErrorMsg.
  ///
  /// In zh, this message translates to:
  /// **'服务器响应错误：{msg}'**
  String serverErrorMsg(String msg);

  /// No description provided for @cannotConnectMsg.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到 {url}（请检查地址与手机网络）'**
  String cannotConnectMsg(String url);

  /// No description provided for @loopbackHint.
  ///
  /// In zh, this message translates to:
  /// **'127.0.0.1 指向手机自身，无法访问电脑上的服务器；请填写电脑的局域网 IP'**
  String get loopbackHint;

  /// No description provided for @scanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描音乐'**
  String get scanTitle;

  /// No description provided for @needAudioPermission.
  ///
  /// In zh, this message translates to:
  /// **'需要音频文件访问权限'**
  String get needAudioPermission;

  /// No description provided for @allFilesDenied.
  ///
  /// In zh, this message translates to:
  /// **'未授予“所有文件访问”，歌词旁注文件（.lrc 等）将无法读取'**
  String get allFilesDenied;

  /// No description provided for @stopAction.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stopAction;

  /// No description provided for @startScanAction.
  ///
  /// In zh, this message translates to:
  /// **'开始扫描'**
  String get startScanAction;

  /// No description provided for @notScannedYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未扫描'**
  String get notScannedYet;

  /// No description provided for @ready.
  ///
  /// In zh, this message translates to:
  /// **'准备就绪'**
  String get ready;

  /// No description provided for @scanDone.
  ///
  /// In zh, this message translates to:
  /// **'完成：新增 {added} · 更新 {updated} · 移除 {removed}'**
  String scanDone(int added, int updated, int removed);

  /// No description provided for @scanError.
  ///
  /// In zh, this message translates to:
  /// **'扫描出错'**
  String get scanError;

  /// No description provided for @walking.
  ///
  /// In zh, this message translates to:
  /// **'正在遍历目录…'**
  String get walking;

  /// No description provided for @parsing.
  ///
  /// In zh, this message translates to:
  /// **'正在解析…'**
  String get parsing;

  /// No description provided for @addDirectory.
  ///
  /// In zh, this message translates to:
  /// **'添加目录'**
  String get addDirectory;

  /// No description provided for @createPlaylistTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建播放列表'**
  String get createPlaylistTooltip;

  /// No description provided for @createPlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建播放列表'**
  String get createPlaylistTitle;

  /// No description provided for @nameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get nameLabel;

  /// No description provided for @createAction.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createAction;

  /// No description provided for @noPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'还没有播放列表'**
  String get noPlaylists;

  /// No description provided for @playlistsHint.
  ///
  /// In zh, this message translates to:
  /// **'本地歌曲和云端歌曲都可以加入'**
  String get playlistsHint;

  /// No description provided for @detailEmpty.
  ///
  /// In zh, this message translates to:
  /// **'列表为空，点右上角添加歌曲'**
  String get detailEmpty;

  /// No description provided for @detailEmptyEditing.
  ///
  /// In zh, this message translates to:
  /// **'列表为空'**
  String get detailEmptyEditing;

  /// No description provided for @cloudTag.
  ///
  /// In zh, this message translates to:
  /// **'云端'**
  String get cloudTag;

  /// No description provided for @addSongsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'添加歌曲'**
  String get addSongsTooltip;

  /// No description provided for @editTooltip.
  ///
  /// In zh, this message translates to:
  /// **'编辑歌曲'**
  String get editTooltip;

  /// No description provided for @deletePlaylistTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除播放列表'**
  String get deletePlaylistTooltip;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {n} 首'**
  String selectedCount(int n);

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get deselectAll;

  /// No description provided for @doneAction.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get doneAction;

  /// No description provided for @deleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除所选 ({n})'**
  String deleteSelected(int n);

  /// No description provided for @removedCount.
  ///
  /// In zh, this message translates to:
  /// **'已移除 {n} 首'**
  String removedCount(int n);

  /// No description provided for @deletePlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除播放列表？'**
  String get deletePlaylistTitle;

  /// No description provided for @deletePlaylistBody.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」将被删除，歌曲不受影响。'**
  String deletePlaylistBody(String name);

  /// No description provided for @localSongs.
  ///
  /// In zh, this message translates to:
  /// **'本地歌曲'**
  String get localSongs;

  /// No description provided for @cloudSongs.
  ///
  /// In zh, this message translates to:
  /// **'云端歌曲'**
  String get cloudSongs;

  /// No description provided for @filterLocal.
  ///
  /// In zh, this message translates to:
  /// **'过滤本地歌曲'**
  String get filterLocal;

  /// No description provided for @searchCloud.
  ///
  /// In zh, this message translates to:
  /// **'模糊搜索云端歌曲'**
  String get searchCloud;

  /// No description provided for @noLocalMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的本地歌曲'**
  String get noLocalMatch;

  /// No description provided for @addedTo.
  ///
  /// In zh, this message translates to:
  /// **'已加入「{title}」'**
  String addedTo(String title);

  /// No description provided for @notConnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接到服务器'**
  String get notConnected;

  /// No description provided for @goConnect.
  ///
  /// In zh, this message translates to:
  /// **'去连接'**
  String get goConnect;

  /// No description provided for @typeToSearchCloud.
  ///
  /// In zh, this message translates to:
  /// **'输入关键字后点搜索'**
  String get typeToSearchCloud;

  /// No description provided for @searchFailedPrefix.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败'**
  String get searchFailedPrefix;

  /// No description provided for @addFailedPrefix.
  ///
  /// In zh, this message translates to:
  /// **'添加失败'**
  String get addFailedPrefix;

  /// No description provided for @noCloudMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的歌曲'**
  String get noCloudMatch;

  /// No description provided for @queueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'队列为空'**
  String get queueEmpty;

  /// No description provided for @tooltipLoopMode.
  ///
  /// In zh, this message translates to:
  /// **'循环模式'**
  String get tooltipLoopMode;

  /// No description provided for @tooltipQueue.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get tooltipQueue;

  /// No description provided for @tooltipBackToCover.
  ///
  /// In zh, this message translates to:
  /// **'返回封面'**
  String get tooltipBackToCover;

  /// No description provided for @tooltipFontSmaller.
  ///
  /// In zh, this message translates to:
  /// **'缩小字体'**
  String get tooltipFontSmaller;

  /// No description provided for @tooltipFontBigger.
  ///
  /// In zh, this message translates to:
  /// **'放大字体'**
  String get tooltipFontBigger;

  /// No description provided for @tooltipManualAlign.
  ///
  /// In zh, this message translates to:
  /// **'手动对齐'**
  String get tooltipManualAlign;

  /// No description provided for @tooltipAlign.
  ///
  /// In zh, this message translates to:
  /// **'文字对齐'**
  String get tooltipAlign;

  /// No description provided for @unsyncedBanner.
  ///
  /// In zh, this message translates to:
  /// **'未检测到时间轴，仅显示文本'**
  String get unsyncedBanner;

  /// No description provided for @importLyricsFile.
  ///
  /// In zh, this message translates to:
  /// **'导入歌词文件'**
  String get importLyricsFile;

  /// No description provided for @noLyrics.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌词'**
  String get noLyrics;

  /// No description provided for @unlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get unlock;

  /// No description provided for @tooltipOverlayOn.
  ///
  /// In zh, this message translates to:
  /// **'关闭桌面歌词'**
  String get tooltipOverlayOn;

  /// No description provided for @tooltipOverlayOff.
  ///
  /// In zh, this message translates to:
  /// **'开启桌面歌词'**
  String get tooltipOverlayOff;

  /// No description provided for @overlayTitle.
  ///
  /// In zh, this message translates to:
  /// **'Whisplayer 桌面歌词'**
  String get overlayTitle;

  /// No description provided for @overlayContent.
  ///
  /// In zh, this message translates to:
  /// **'正在显示桌面歌词'**
  String get overlayContent;

  /// No description provided for @overlayWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待播放…'**
  String get overlayWaiting;

  /// No description provided for @overlayUnsynced.
  ///
  /// In zh, this message translates to:
  /// **'（纯文本歌词，暂不支持同步滚动）'**
  String get overlayUnsynced;

  /// No description provided for @playlistDetailTitleFallback.
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get playlistDetailTitleFallback;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
