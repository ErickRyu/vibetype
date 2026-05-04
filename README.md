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

### 사전 요구사항

Xcode 26+에서는 Metal Toolchain이 별도 다운로드입니다 (최초 1회):

```bash
xcodebuild -downloadComponent MetalToolchain
```

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

## 배포

### 1. 앱 아이콘 통합

1024×1024 PNG를 준비해 다음 명령으로 자동 생성:

```bash
make icon ICON=path/to/icon-1024.png
```

`apps/VibeTypeMac/VibeTypeMac/Assets.xcassets/AppIcon.appiconset/`에 모든 사이즈가 자동 생성됩니다.

### 2. Release 빌드

```bash
# 서명 없이 (개발/내부 테스트용)
make release

# Developer ID 서명 (배포 전 단계)
export DEVELOPER_ID_APP="Developer ID Application: 이름 (TEAM_ID)"
make release-sign

# 서명 + 노타라이즈 + DMG (배포용)
export DEVELOPER_ID_APP="Developer ID Application: 이름 (TEAM_ID)"
export APPLE_TEAM_ID="ABC1234567"
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # appleid.apple.com에서 발급
make release-notarize
```

산출물:
- `apps/VibeTypeMac/build/Build/Products/Release/VibeType.app`
- `dist/VibeType.dmg` (create-dmg 설치 시: `brew install create-dmg`)

### 3. 권한 요구사항 (사용자 안내)

- **Microphone** — 음성 받아쓰기
- **Accessibility** — 받아쓰기 결과를 다른 앱에 입력
- 두 권한 모두 System Settings → Privacy & Security에서 직접 grant 필요

> 💡 **DMG 설치 시 권장:** 다운로드한 `VibeType.app`을 `/Applications`로 옮긴 뒤 우클릭 → "열기"로 실행. 매번 다른 위치에서 실행하면 unsigned 빌드 특성상 macOS가 다른 앱으로 인식해 권한 다이얼로그를 다시 묻습니다.

#### 마이크 권한 다이얼로그가 반복되면

System Settings → Privacy & Security → Microphone에서 VibeType 토글을 확인:
- 토글이 **OFF**라면 ON으로 바꾸고 앱 재실행
- 토글이 **ON인데도** 매번 다이얼로그가 뜨면 unsigned 빌드의 TCC 일관성 한계입니다. 다음을 한 번 실행 후 앱 재실행:

```bash
tccutil reset Microphone com.vibetype.mac
```

근본 해결은 Developer ID 서명(향후 release).

## GitHub Releases 자동 배포

`v*.*.*` 형태의 태그를 push하면 GitHub Actions가 자동으로:
1. Release 빌드
2. Developer ID 서명
3. Apple 노타라이즈
4. DMG 생성
5. GitHub Release 게시 (CHANGELOG에서 해당 버전 섹션을 release notes로)

### 1회 셋업: GitHub repo Secrets 등록

Repo → Settings → Secrets and variables → Actions에 다음 6개 등록:

| Secret 이름 | 값 |
|---|---|
| `MACOS_CERTIFICATE_BASE64` | Developer ID Application `.p12`를 `base64 -i cert.p12 \| pbcopy`로 인코딩 |
| `MACOS_CERTIFICATE_PASSWORD` | `.p12` 비밀번호 |
| `DEVELOPER_ID_APP` | `Developer ID Application: 사용자이름 (TEAM_ID)` |
| `APPLE_TEAM_ID` | 10자리 팀 ID |
| `APPLE_ID` | Apple ID 이메일 |
| `APPLE_APP_PASSWORD` | App-specific password |

Secrets 미등록 시 Actions는 unsigned 빌드만 수행 (배포는 가능하나 Gatekeeper 경고).

### 새 버전 배포

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 인증서 추출 (1회)

```bash
# Keychain Access → "Developer ID Application" 인증서 우클릭 → 내보내기 → .p12
base64 -i path/to/cert.p12 | pbcopy
# 클립보드의 base64 문자열을 GitHub Secret 'MACOS_CERTIFICATE_BASE64'에 붙여넣기
```

## 라이선스

[MIT](./LICENSE)
