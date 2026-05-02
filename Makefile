.PHONY: help test build run clean models metaltools

CLI := .xcbuild/Build/Products/Debug/vibetype-cli
DERIVED := .xcbuild
SCHEME := vibetype-cli
DEST := platform=macOS

help:
	@echo "VibeType — 로컬 Gemma 키보드 컴패니언"
	@echo ""
	@echo "사용 가능한 타겟:"
	@echo "  make test          단위 테스트 (SPM, 추론 없음)"
	@echo "  make build         CLI 빌드 (xcodebuild, metallib 포함)"
	@echo "  make run ARGS=...  CLI 실행 — 예: make run ARGS='improve \"회의 좋았어\"'"
	@echo "  make models        지원 모델 목록"
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

clean:
	rm -rf .build $(DERIVED)

metaltools:
	xcodebuild -downloadComponent MetalToolchain
