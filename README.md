# VibeType

> 로컬 Gemma 기반 Mac & iOS 키보드 컴패니언. 클라우드 없이 Apple Silicon 기기에서 직접 추론합니다.

## 무엇인가요

선택한 텍스트를 단축키 한 번으로 AI가 다듬어 주는 도구입니다. Typeless의 인라인 글쓰기 경험을 **완전 로컬**로 구현합니다.

- 어떤 Mac 앱에서든 ⌥Space → 액션 선택 → 그 자리에 텍스트 교체
- iPhone 키보드 위 ✨ 버튼 → 컨테이너 앱이 추론 → 결과 인서션
- 추론은 모두 사용자 기기의 GPU/ANE에서. 네트워크 호출 0, 텔레메트리 0.

## 기본 액션

- **Improve** — 자연스럽게 다듬기
- **Fix Grammar** — 맞춤법/문법 교정
- **Translate → KO** — 한국어로 번역
- **Translate → EN** — 영어로 번역
- **Summarize** — 요약

사용자 정의 프롬프트 추가 가능 (Phase 6).

## 시스템 요구사항

- Apple Silicon Mac (M1/M2/M3/M4) — Intel 미지원
- macOS 14+ (권장 26+)
- 16GB RAM 권장 (8GB는 Gemma 2B 4-bit로 자동 폴백)
- iPhone (iOS 17+) — iOS 클라이언트 사용 시

## 시작 모델

`mlx-community/gemma-3-4b-it-4bit` (~2.5GB). Gemma 4 출시 시 `ModelRegistry`에서 ID만 교체합니다.

## 개발 상태

- [x] Phase 0 — 부트스트랩
- [ ] Phase 1 — Core 추론 검증
- [ ] Phase 2 — Mac 앱 스켈레톤
- [ ] Phase 3 — Mac 시스템 통합
- [ ] Phase 4 — Mac Action Palette
- [ ] Phase 5 — iOS 컨테이너 + 키보드 확장
- [ ] Phase 6 — 폴리싱
- [ ] Phase 7 — 배포

전체 플랜은 [`PLAN.md`](./PLAN.md) 참조.

## 빌드

> **중요:** MLX Swift의 Metal 셰이더는 SPM CLI(`swift build`)로 컴파일되지 않습니다.
> 실제 추론 실행 가능한 빌드는 **`xcodebuild`** 또는 Xcode를 통해야 합니다.
> `swift build`는 코드 컴파일 검증과 단위 테스트(추론 미포함)에만 사용하세요.

### 단위 테스트 (SPM CLI, 추론 없음)

```bash
swift build
swift test
```

### CLI 실행 (xcodebuild 필요, 실제 Gemma 추론)

```bash
# 빌드
xcodebuild -scheme vibetype-cli -destination 'platform=macOS' \
  -derivedDataPath .xcbuild build

# 실행
.xcbuild/Build/Products/Debug/vibetype-cli improve "회의 좋았어"

# 모델 목록
.xcbuild/Build/Products/Debug/vibetype-cli models
```

첫 실행 시 Hugging Face에서 모델을 다운로드합니다 (캐시: `~/.cache/huggingface/hub/`).

### 모델 선택

```bash
VIBETYPE_MODEL=gemma-3-1b-it-qat-4bit \
  .xcbuild/Build/Products/Debug/vibetype-cli improve "샘플"
```

| Model ID | Size | RAM | iOS |
|---|---|---|---|
| `gemma-3n-e4b-it-lm-4bit` (기본) | 2.4GB | 12GB+ | ✓ |
| `gemma-3n-e2b-it-lm-4bit` | 1.5GB | 8GB+ | ✓ |
| `gemma-2-2b-it-4bit` | 1.5GB | 8GB+ | ✓ |
| `gemma-2-9b-it-4bit` | 5.5GB | 24GB+ | ✗ |
| `gemma-3-1b-it-qat-4bit` | 0.8GB | 6GB+ | ✓ |

## 라이선스

(추후 결정)
