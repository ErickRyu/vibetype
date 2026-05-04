# Changelog

All notable changes to VibeType will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] — 2026-05-04

### Fixed
- **Fn 한 번에 권한 다이얼로그 다중 표시(9회)**: 두 곳의 race condition 차단.
  - `FnKeyMonitor`: `addGlobalMonitor` + `addLocalMonitor`가 같은 `flagsChanged`를 양쪽에서 emit하거나 macOS가 한 번 누름에 multiple emit하는 케이스에서, dedup이 `Task @MainActor` 안에서 일어나 경합. NSLock 기반 sync dedup으로 콜백 도달 직후 차단.
  - `DictationCoordinator.startRecording`: `permissionRequestInFlight=true`가 `Task` 내부에서 set되어, sync 다중 호출이 모두 첫 가드를 통과해 N개의 권한 요청 Task를 생성. flag를 sync set으로 옮겨 첫 호출만 통과.

## [0.1.2] — 2026-05-04

### Fixed
- **마이크 권한 다이얼로그 매 Fn마다 반복**: ad-hoc 서명 환경에서 macOS가 grant 후에도 `.notDetermined`를 매번 리포트하는 케이스 우회. `DictationCoordinator`가 세션 내 권한 요청 1회 캐시(`hasRequestedPermissionThisSession`). 두 번째 Fn부터는 다이얼로그 없이 `recorder.start()` 직접 시도.
- **AudioRecorder.start 권한 가드 완화**: `.denied`/`.restricted`만 명시 throw, `.notDetermined`은 `engine.start()`로 위임. ad-hoc 서명에서의 status 부정확성 우회.
- **트러블슈팅 안내 추가**: 그래도 권한 다이얼로그가 반복되면 `tccutil reset Microphone com.vibetype.mac` 후 앱 재실행.

## [0.1.1] — 2026-05-04

### Fixed
- **마이크 / Documents 권한 다이얼로그 반복**: WhisperKit 모델 캐시 위치를 `~/Documents/huggingface/...`에서 `~/Library/Application Support/VibeType/whisperkit/`로 이동. macOS Sonoma+의 Documents TCC 다이얼로그가 매 실행마다 뜨던 문제 해소.
- **v0.1.0 사용자 자동 마이그레이션**: 기존 ~/Documents 캐시가 있으면 silent move (권한 거부되면 새 위치에서 재다운로드).
- **Chrome / Safari 등 브라우저 입력창 붙여넣기 실패**: Pasteboard ⌘V 폴백이 changeCount 변화를 감지 못 하면 명시적 throw하여 AX 폴백을 자동 시도. 클립보드 복원 대기 시간 100ms → 250ms (브라우저의 비동기 paste 처리 대응). deadline 400ms → 700ms.

## [0.1.0] — 2026-05-03

첫 공개 릴리스. 100% 로컬 음성 받아쓰기 키보드.

### Added
- **Push-to-talk 받아쓰기**: Fn(또는 🌐 Globe) 키를 누르고 있는 동안 녹음, 떼면 즉시 변환되어 포커스된 앱에 입력.
- **WhisperKit large-v3-turbo**: Apple Silicon CoreML 최적, 한국어 우수.
- **Wispr Flow 스타일 floating HUD**: 화면 하단 중앙 알약 모양, 녹음 중 빨간 펄스 + 파형 + 타이머, transcribing 진행률 바, 단계별 시각 피드백.
- **메뉴바 인디케이터**: idle/recording/transcribing/postProcessing/typing 상태별 SF Symbol 변경.
- **한글 IME 안전 입력**: Pasteboard ⌘V 우선 + AX 폴백, CGEvent 키 입력 사용 안 함.
- **Gemma 후처리 옵션**: 디폴트 OFF(Whisper 단독), Settings에서 토글로 켤 수 있음.
- **모델 6종 선택**: large-v3-turbo / large-v3 / full / small / base / tiny.
- **단축키 리매핑**: 받아쓰기 + 보너스 텍스트 액션(Improve/FixGrammar/Translate/Summarize) 설정 가능.
- **백그라운드 프리로드**: 앱 시작 시 모델 캐시가 있으면 자동 로드해 첫 받아쓰기 콜드 스타트 제거.
- **idle 자동 언로드**: 15분 비활성 시 Whisper 모델을 메모리에서 자동 해제 (~1GB 회수).

### 시스템 요구사항
- macOS 14+ (Apple Silicon)
- 약 950MB Whisper 모델 + (옵션) Gemma 모델
- Microphone + Accessibility 권한
