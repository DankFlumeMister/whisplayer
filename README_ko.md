# Whisplayer

[![CI](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml/badge.svg)](https://github.com/DankFlumeMister/whisplayer/actions/workflows/ci.yml)

[English](README_en.md) · [简体中文](README.md) · [繁體中文](README_zh_TW.md) · [日本語](README_ja.md) · **한국어**

로컬 & 셀프 호스팅 음악 플레이어.

## ✨ 기능

**셀프 호스팅 스트리밍 (Subsonic 프로토콜)**
- LAN을 통해 휴대폰에서 PC / NAS 음악 재생
- Navidrome 등 Subsonic / OpenSubsonic 서버 호환
- 앨범 그리드 브라우징(아트워크 캐시 + 무한 스크롤), 서버 측 퍼지 검색
- 스트리밍: 플레이어 배경 / 잠금 화면 아트워크, 서버 측 동기화 가사 자동 로드
- 멀티 서버 관리 및 빠른 전환; 자격 증명은 시스템 키스토어에 저장, 데이터베이스 미기록
- 재생목록에 로컬 곡과 클라우드 곡 모두 추가 가능

**로컬 재생**
- 무손실 / 유손실 형식 지원 (FLAC, WAV, ALAC, MP3, M4A 등)
- 곡 / 앨범 / 아티스트 / 폴더별 브라우징, 전문 검색 및 다축 정렬
- 대기열 관리: 다음에 재생, 추가, 제거, 전체 삭제, 일괄 편집
- 3가지 반복 모드 (한 곡 / 전체 / 끄기)
- 재생 위치·대기열·반복 모드 지속화——프로세스 종료 후 정확히 이어 재생
- 최근 재생 기록 및 재생 통계

**가사**
- 같은 폴더의 `.lrc` / `.vtt` / `.srt` 사이드카, 내장 가사, 데이터베이스 텍스트 자동 로드
- 동기화 스크롤, 글자 크기 / 정렬 / 오프셋 조절(지속화), 수동 가져오기
- 3가지 표시 모드: 커버 숨김 / 도크 패널 / 몰입 전체 화면(길게 눌러 잠금 해제)
- 데스크톱 가사 오버레이(드래그 가능, 글자 크기 조절 가능, 모든 앱 위에 표시)

**개인화**
- 24가지 강조 색상 즉시 전환, 라이트/다크 자동 대응
- 라이트 / 다크 테마 + 시스템 설정 따르기
- 앱 언어: 简体中文 / 繁體中文 / 日本語 / 한국어 / English
- 흐릿한 유리 배경, 커버 애니메이션 등 시각적 디테일

## 📸 스크린샷

> TODO: 릴리스 전 스크린샷 추가 예정

## ⬇️ 다운로드

[Releases](../../releases) 페이지에서 최신 APK를 다운로드하세요.

## 🔨 소스에서 빌드

```bash
git clone https://github.com/DankFlumeMister/whisplayer.git
cd whisplayer
flutter pub get
flutter build apk --release
# 출력: build/app/outputs/flutter-apk/app-release.apk
```

요구 사항:

- Flutter **3.27+** (개발 환경은 master 브랜치 `3.48.0-0.2.pre`, `Color.withValues` 등 신규 API 사용)
- Android SDK (프로젝트 compileSdk 37)

중국 대륙 네트워크에서는 미러 설정을 권장합니다:

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
```

## 🖥 Navidrome 연결

1. [Navidrome](https://www.navidrome.org)(또는 Subsonic 호환 서버)을 배포하고 실행
2. 앱 내: 설정 → 원격 음악 서버 → 서버 주소와 계정 추가
3. "연결 테스트"로 확인 후 저장; 하단의 "클라우드" 탭에서 브라우징·스트리밍 시작

## 🌐 언어

简体中文 · 繁體中文 · 日本語 · 한국어 · English

설정 → 언어 → 시스템 설정 따르기 또는 수동 선택.

## 🗺 로드맵

- [ ] WebDAV 소스
- [ ] 가사 편집 및 타이밍
- [ ] iOS 지원

## ⚠️ 면책 조항

이 프로젝트는 온라인 음악 소스나 콘텐츠 배포 기능을 제공하지 않습니다. 로컬 파일과 **직접 호스팅하는 서버** 전용 재생 클라이언트입니다. 이 프로젝트를 사용함으로써 재생하는 콘텐츠의 합법성을 보증한 것으로 간주됩니다.

## 📄 라이선스

[MIT](LICENSE) © 2026 DankFlumeMister
