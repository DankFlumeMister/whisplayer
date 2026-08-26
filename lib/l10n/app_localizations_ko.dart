// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get localTab => '로컬';

  @override
  String get cloudTab => '클라우드';

  @override
  String get playlistTab => '재생목록';

  @override
  String get settingsTitle => '설정';

  @override
  String get appearanceEntry => '화면 테마';

  @override
  String get appearanceSubtitle => '테마 모드와 강조 색상';

  @override
  String get scanEntry => '음악 스캔';

  @override
  String get scanSubtitle => '로컬 오디오 파일 가져오기';

  @override
  String get statsEntry => '재생 통계';

  @override
  String get statsSubtitle => '자주 재생한 곡과 총 청취 시간';

  @override
  String get remoteServersEntry => '원격 음악 서버';

  @override
  String get remoteServersSubtitle => 'Navidrome / Subsonic 자체 서버';

  @override
  String get languageEntry => '언어';

  @override
  String get languageFollowSystem => '시스템 설정 따르기';

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
  String get appearanceTitle => '화면 테마';

  @override
  String get themeModeLabel => '테마 모드';

  @override
  String get themeModeFollowSystem => '시스템 설정 따르기';

  @override
  String get themeModeLight => '라이트';

  @override
  String get themeModeDark => '다크';

  @override
  String get themeColorLabel => '강조 색상';

  @override
  String get themeColorHint => '탭하면 즉시 적용되며 라이트/다크에 자동 대응';

  @override
  String get desktopLyricsEntry => '데스크톱 가사';

  @override
  String get desktopLyricsOn => '켬 — 다른 앱 위에 표시 중';

  @override
  String get desktopLyricsOff => '다른 앱 위에 현재 가사 표시';

  @override
  String get desktopLyricsPermission => '\"다른 앱 위에 표시\" 권한이 필요합니다';

  @override
  String get colorSakura => '벚꽃';

  @override
  String get colorMagenta => '마젠타';

  @override
  String get colorWisteria => '등나무';

  @override
  String get colorDeepPurple => '진한 보라';

  @override
  String get colorLavender => '라벤더';

  @override
  String get colorIris => '아이리스';

  @override
  String get colorNavy => '네이비';

  @override
  String get colorSky => '하늘색';

  @override
  String get colorLake => '코발트';

  @override
  String get colorCeladon => '청자';

  @override
  String get colorMint => '민트';

  @override
  String get colorMatcha => '말차';

  @override
  String get colorLime => '라임';

  @override
  String get colorOlive => '올리브';

  @override
  String get colorLemon => '레몬';

  @override
  String get colorBrown => '브라운';

  @override
  String get colorOrange => '오렌지';

  @override
  String get colorCoral => '코랄';

  @override
  String get colorPeach => '피치';

  @override
  String get colorRed => '레드';

  @override
  String get colorWine => '와인';

  @override
  String get colorRoseGold => '로즈골드';

  @override
  String get colorBlueGrey => '블루 그레이';

  @override
  String get colorGrey => '회색';

  @override
  String get songsTab => '곡';

  @override
  String get albumsTab => '앨범';

  @override
  String get artistsTab => '아티스트';

  @override
  String get foldersTab => '폴더';

  @override
  String get libraryEmpty => '곡이 없습니다. 설정에서 음악을 스캔해 주세요';

  @override
  String get noAlbums => '앨범이 없습니다';

  @override
  String get noArtists => '아티스트가 없습니다';

  @override
  String get noFolders => '폴더가 없습니다';

  @override
  String get unknownArtist => '알 수 없는 아티스트';

  @override
  String countSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(n, locale: localeName, other: '$n곡');
    return '$_temp0';
  }

  @override
  String countAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n장의 앨범',
    );
    return '$_temp0';
  }

  @override
  String get playAll => '전체 재생';

  @override
  String get albumFallback => '앨범';

  @override
  String get artistFallback => '아티스트';

  @override
  String get play => '재생';

  @override
  String get tooltipRecent => '최근 재생';

  @override
  String get tooltipSearch => '검색';

  @override
  String get startupPage => '시작 페이지';

  @override
  String get tooltipShuffle => '셔플';

  @override
  String get tooltipSort => '정렬';

  @override
  String get sortTitle => '제목';

  @override
  String get sortArtist => '아티스트';

  @override
  String get sortAlbum => '앨범';

  @override
  String get sortAddedAt => '최근 추가';

  @override
  String get sortPlayCount => '재생 횟수';

  @override
  String get sortDuration => '길이';

  @override
  String get sortDescending => '내림차순';

  @override
  String get searchHintInput => '키워드로 곡 검색';

  @override
  String get searchHintFailure => '검색에 실패했습니다. 잠시 후 다시 시도하세요';

  @override
  String get searchHintNoMatch => '일치하는 곡이 없습니다';

  @override
  String get songsPageTitle => '곡';

  @override
  String get songsPageEmpty => '곡이 없습니다. 설정에서 음악을 스캔해 주세요';

  @override
  String get folderDetailEmpty => '该文件夹暂无歌曲';

  @override
  String get recentTitle => '최근 재생';

  @override
  String get recentEmpty => '재생 기록이 아직 없습니다';

  @override
  String statsHeader(int plays, int completed, int minutes) {
    return '재생 $plays회 · 완료 $completed회 · 총 약 $minutes분';
  }

  @override
  String get relJust => '방금 전';

  @override
  String relMinutesAgo(int n) {
    return '$n분 전';
  }

  @override
  String relHoursAgo(int n) {
    return '$n시간 전';
  }

  @override
  String relDaysAgo(int n) {
    return '$n일 전';
  }

  @override
  String get statsTitle => '재생 통계';

  @override
  String get statsEmpty => '통계 데이터가 없습니다. 곡을 재생해 보세요';

  @override
  String get topPlayed => '가장 많이 재생';

  @override
  String playCountLabel(int n) {
    return '$n회 재생';
  }

  @override
  String totalDurMinutes(int n) {
    return '약 $n분';
  }

  @override
  String totalDurHours(int n) {
    return '약 $n시간';
  }

  @override
  String totalDurHoursMinutes(int h, int m) {
    return '$h시간 $m분';
  }

  @override
  String get cloudTitle => '클라우드 음악';

  @override
  String get noServer => '서버가 아직 추가되지 않았습니다';

  @override
  String get goAdd => '추가하기';

  @override
  String get retry => '다시 시도';

  @override
  String get loadFailedPrefix => '불러오기 실패';

  @override
  String get albumNoSongs => '이 앨범에는 곡이 없습니다';

  @override
  String get openFailedPrefix => '열기 실패';

  @override
  String syncingTo(String title) {
    return '「$title」동기화 중…';
  }

  @override
  String get playFailedPrefix => '재생 실패';

  @override
  String get cloudModeAlbums => '앨범';

  @override
  String get cloudModeFolders => '폴더';

  @override
  String get cloudFoldersEmpty => '폴더가 없습니다';

  @override
  String get sortSongsCount => '곡 수';

  @override
  String get tooltipToggleView => '보기 전환';

  @override
  String get searchHintFolders => '폴더 이름 검색';

  @override
  String get folderNoSongs => '이 폴더에 오디오 파일이 없습니다';

  @override
  String get folderNoMatch => '일치하는 폴더가 없습니다';

  @override
  String get searchHintCloud => '키워드로 클라우드 곡과 앨범 검색';

  @override
  String get sectionAlbums => '앨범';

  @override
  String get sectionSongs => '곡';

  @override
  String get tooltipManageServers => '서버 관리';

  @override
  String get tooltipRefresh => '새로 고침';

  @override
  String get tooltipSwitchServer => '서버 전환';

  @override
  String get serverNoAlbums => '서버에 앨범이 없습니다';

  @override
  String get cloudFallback => '클라우드 음악';

  @override
  String get noServerYet => '서버가 없습니다. 오른쪽 아래 버튼으로 추가하세요';

  @override
  String get tooltipDelete => '삭제';

  @override
  String deleteServerTitle(String name) {
    return '$name을(를) 삭제할까요?';
  }

  @override
  String get deleteServerBody => '저장된 비밀번호도 함께 삭제됩니다.';

  @override
  String get cancelAction => '취소';

  @override
  String get deleteAction => '삭제';

  @override
  String get addServerTitle => '서버 추가';

  @override
  String get fieldName => '이름';

  @override
  String get fieldAddress => '서버 주소';

  @override
  String get fieldAddressHint => '예: 192.168.XX.XX:4533';

  @override
  String get fieldUsername => '사용자 이름';

  @override
  String get fieldPassword => '비밀번호';

  @override
  String get testConnection => '연결 테스트';

  @override
  String get saveAction => '저장';

  @override
  String get fillAllFields => '모든 항목을 입력해 주세요';

  @override
  String get loopbackSnackBar =>
      '참고: 127.0.0.1은 휴대폰 자신을 가리킵니다. PC의 내부 IP를 입력하세요';

  @override
  String get fillAllFieldsFull => '주소, 사용자 이름, 비밀번호를 입력해 주세요';

  @override
  String get loopbackTest =>
      '127.0.0.1 / localhost는 휴대폰 자신을 가리켜 PC의 서버에 접근할 수 없습니다. PC의 내부 IP를 입력하세요(ipconfig 확인)';

  @override
  String testOk(String url) {
    return '연결 성공 ✓ $url 사용';
  }

  @override
  String serverErrorMsg(String msg) {
    return '서버 오류: $msg';
  }

  @override
  String cannotConnectMsg(String url) {
    return '$url에 연결할 수 없습니다(주소와 네트워크 확인)';
  }

  @override
  String get loopbackHint => '127.0.0.1은 휴대폰 자신을 가리킵니다. PC의 내부 IP를 입력하세요';

  @override
  String get scanTitle => '음악 스캔';

  @override
  String get needAudioPermission => '오디오 파일 접근 권한이 필요합니다';

  @override
  String get allFilesDenied => '\"모든 파일 접근\"이 허용되지 않아 가사 파일(.lrc 등)을 읽을 수 없습니다';

  @override
  String get stopAction => '중지';

  @override
  String get startScanAction => '스캔 시작';

  @override
  String get notScannedYet => '아직 스캔하지 않았습니다';

  @override
  String get ready => '준비됨';

  @override
  String scanDone(int added, int updated, int removed) {
    return '완료: 추가 $added · 업데이트 $updated · 삭제 $removed';
  }

  @override
  String get scanError => '스캔 오류';

  @override
  String get walking => '디렉터리 탐색 중…';

  @override
  String get parsing => '분석 중…';

  @override
  String get addDirectory => '폴더 추가';

  @override
  String get createPlaylistTooltip => '재생목록 만들기';

  @override
  String get createPlaylistTitle => '새 재생목록';

  @override
  String get nameLabel => '이름';

  @override
  String get createAction => '만들기';

  @override
  String get noPlaylists => '재생목록이 아직 없습니다';

  @override
  String get playlistsHint => '로컬 곡과 클라우드 곡 모두 추가할 수 있습니다';

  @override
  String get detailEmpty => '비어 있습니다. 오른쪽 위에서 곡을 추가하세요';

  @override
  String get detailEmptyEditing => '비어 있습니다';

  @override
  String get cloudTag => '클라우드';

  @override
  String get addSongsTooltip => '곡 추가';

  @override
  String get editTooltip => '곡 편집';

  @override
  String get deletePlaylistTooltip => '재생목록 삭제';

  @override
  String selectedCount(int n) {
    return '$n곡 선택됨';
  }

  @override
  String get selectAll => '전체 선택';

  @override
  String get deselectAll => '선택 해제';

  @override
  String get doneAction => '완료';

  @override
  String deleteSelected(int n) {
    return '선택 항목 삭제 ($n)';
  }

  @override
  String removedCount(int n) {
    return '$n곡 제거됨';
  }

  @override
  String get deletePlaylistTitle => '재생목록을 삭제할까요?';

  @override
  String deletePlaylistBody(String name) {
    return '「$name」이(가) 삭제되며 곡은 영향을 받지 않습니다.';
  }

  @override
  String get localSongs => '로컬 곡';

  @override
  String get cloudSongs => '클라우드 곡';

  @override
  String get filterLocal => '로컬 곡 필터';

  @override
  String get searchCloud => '클라우드 곡 검색';

  @override
  String get noLocalMatch => '일치하는 로컬 곡이 없습니다';

  @override
  String addedTo(String title) {
    return '「$title」 추가됨';
  }

  @override
  String get notConnected => '서버에 연결되어 있지 않습니다';

  @override
  String get goConnect => '연결하기';

  @override
  String get typeToSearchCloud => '키워드 입력 후 검색을 탭하세요';

  @override
  String get searchFailedPrefix => '검색 실패';

  @override
  String get addFailedPrefix => '추가 실패';

  @override
  String get noCloudMatch => '일치하는 곡이 없습니다';

  @override
  String get queueEmpty => '대기열이 비어 있습니다';

  @override
  String get tooltipLoopMode => '반복 모드';

  @override
  String get tooltipQueue => '재생 대기열';

  @override
  String get tooltipBackToCover => '커버로 돌아가기';

  @override
  String get tooltipFontSmaller => '글자 작게';

  @override
  String get tooltipFontBigger => '글자 크게';

  @override
  String get tooltipManualAlign => '수동 맞춤';

  @override
  String get tooltipAlign => '텍스트 정렬';

  @override
  String get unsyncedBanner => '타이밍이 감지되지 않아 텍스트만 표시합니다';

  @override
  String get importLyricsFile => '가사 파일 가져오기';

  @override
  String get noLyrics => '가사 없음';

  @override
  String get unlock => '잠금 해제';

  @override
  String get tooltipOverlayOn => '데스크톱 가사 끄기';

  @override
  String get tooltipOverlayOff => '데스크톱 가사 켜기';

  @override
  String get overlayTitle => 'Whisplayer 데스크톱 가사';

  @override
  String get overlayContent => '데스크톱 가사 표시 중';

  @override
  String get overlayWaiting => '재생 대기 중…';

  @override
  String get overlayUnsynced => '(텍스트 가사 — 동기화 미지원)';

  @override
  String get playlistDetailTitleFallback => '재생목록';
}
