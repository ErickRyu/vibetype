# Changelog

All notable changes to VibeType will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### 시스템 요구사항
- macOS 14+ (Apple Silicon)
- 약 950MB Whisper 모델 + (옵션) Gemma 모델
- Microphone + Accessibility 권한
