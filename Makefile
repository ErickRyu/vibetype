.PHONY: help test build run clean models metaltools mac mac-run mac-gen icon release release-sign release-notarize

CLI := .xcbuild/Build/Products/Debug/vibetype-cli
DERIVED := .xcbuild
SCHEME := vibetype-cli
DEST := platform=macOS
MAC_DIR := apps/VibeTypeMac
MAC_APP := $(MAC_DIR)/build/Build/Products/Debug/VibeType.app

help:
	@echo "VibeType — 로컬 Gemma 키보드 컴패니언"
	@echo ""
	@echo "사용 가능한 타겟:"
	@echo "  make test          단위 테스트 (SPM, 추론 없음)"
	@echo "  make build         CLI 빌드 (xcodebuild, metallib 포함)"
	@echo "  make run ARGS=...  CLI 실행 — 예: make run ARGS='improve \"회의 좋았어\"'"
	@echo "  make models        지원 모델 목록"
	@echo "  make mac-gen       Mac 앱 Xcode 프로젝트 재생성 (xcodegen)"
	@echo "  make mac           Mac 메뉴바 앱 빌드"
	@echo "  make mac-run       Mac 메뉴바 앱 빌드 + 실행"
	@echo "  make icon ICON=path/to/1024.png  AppIcon 자동 생성"
	@echo "  make release       Release 빌드 (서명 없음)"
	@echo "  make release-sign  Release 빌드 + 서명 (DEVELOPER_ID_APP 필요)"
	@echo "  make release-notarize  서명 + 노타라이즈 + DMG (배포용)"
	@echo "  make clean         빌드 산출물 정리"
	@echo "  make metaltools    Metal Toolchain 다운로드 (Xcode 26+, 최초 1회)"

test:
	swift test

build:
	xcodebuild -scheme $(SCHEME) -destination '$(DEST)' \
		-configuration Debug -derivedDataPath $(DERIVED) build

run: build
	$(CLI) $(ARGS)

models: build
	$(CLI) models

mac-gen:
	cd $(MAC_DIR) && xcodegen generate

mac: mac-gen
	cd $(MAC_DIR) && xcodebuild -scheme VibeTypeMac \
		-destination 'platform=macOS' -configuration Debug \
		-derivedDataPath build CODE_SIGNING_ALLOWED=NO build

mac-run: mac
	open $(MAC_APP)

icon:
	@test -n "$(ICON)" || (echo "사용법: make icon ICON=path/to/1024x1024.png"; exit 1)
	./scripts/make-icon.sh "$(ICON)"

release:
	./scripts/release.sh

release-sign:
	./scripts/release.sh --sign

release-notarize:
	./scripts/release.sh --sign --notarize

clean:
	rm -rf .build $(DERIVED) $(MAC_DIR)/build $(MAC_DIR)/VibeTypeMac.xcodeproj dist

metaltools:
	xcodebuild -downloadComponent MetalToolchain
