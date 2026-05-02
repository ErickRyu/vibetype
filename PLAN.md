# VibeType 실행 플랜 (요약)

> 전체 플랜은 `~/.claude/plans/expressive-sprouting-blanket.md`에 있습니다.
> 이 문서는 프로젝트 동봉용 요약본입니다.

## 결정 사항

| 항목 | 결정 |
|---|---|
| 범위 | Mac + iOS 동시 v0.1 |
| 단축키 (Mac) | ⌥Space (리매핑 가능) |
| 시작 모델 | Gemma 3 4B IT 4-bit (Gemma 4 출시 시 교체) |
| UI 언어 | 한국어 우선 + 영어 토글 |

## 단계

| Phase | 내용 | 상태 |
|---|---|---|
| 0 | 부트스트랩 (Package.swift, 디렉토리, README, git) | 진행 중 |
| 1 | Core 추론 (LLMEngine, ModelRegistry, PromptTemplate, CLI 검증) | 대기 |
| 2 | Mac 앱 스켈레톤 (메뉴바, 설정, 모델 다운로드) | 대기 |
| 3 | Mac 시스템 통합 (글로벌 단축키, Accessibility, Pasteboard 폴백) | 대기 |
| 4 | Mac Action Palette (HUD, 스트리밍 미리보기, 인라인 교체) | 대기 |
| 5 | iOS 컨테이너 앱 + 키보드 확장 (App Group + Darwin notify IPC) | 대기 |
| 6 | 폴리싱 (커스텀 프롬프트, 단축키 리매핑, idle 언로드) | 대기 |
| 7 | 배포 (Mac DMG + 노타라이즈, iOS TestFlight) | 대기 |

## 핵심 아키텍처

```
VibeTypeCore (SPM 라이브러리, 플랫폼 무관)
  ├─ LLMEngine (actor) — MLX Swift 래퍼
  ├─ ModelRegistry — Gemma 2/3/3n/4 메타
  ├─ ModelDownloader — HF Hub 다운로드
  └─ PromptTemplate / TextAction — 5개 기본 액션
        │
        ├──→ VibeTypeMac (메뉴바 앱 + Accessibility + 글로벌 단축키)
        └──→ VibeTypeIOS (컨테이너 앱 추론 + 키보드 확장 UI, Darwin notify IPC)
```

## v0.1 MVP 수용 기준

- Apple Silicon Mac에서 ⌥Space로 텍스트 인라인 교체
- iPhone 키보드에서 ✨ 탭 → 핸드오프 → 결과 인서션
- 5개 기본 액션 (Improve / FixGrammar / TranslateKo / TranslateEn / Summarize)
- Gemma 3 4B 4-bit 로컬 추론, 추론 중 네트워크 호출 0
- 한국어 입출력 정상, 시스템 프롬프트 한국어 최적화
