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
