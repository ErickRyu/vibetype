#!/bin/bash
# VibeType Mac 앱 릴리스 빌드 + (선택) 서명/노타라이즈/DMG.
#
# 사용법:
#   ./scripts/release.sh                   # 서명 없이 .app만 (개발/내부 테스트)
#   ./scripts/release.sh --sign            # Developer ID 서명
#   ./scripts/release.sh --sign --notarize # 서명 + 노타라이즈 + DMG (배포용)
#
# 환경 변수:
#   DEVELOPER_ID_APP   "Developer ID Application: 이름 (TEAM_ID)" (--sign 시 필수)
#   APPLE_TEAM_ID      Apple Developer Team ID (--sign 시 권장)
#   APPLE_ID           Apple ID 이메일 (--notarize 시 필수)
#   APPLE_APP_PASSWORD App-specific password (--notarize 시 필수)
set -e

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
MAC_DIR="$ROOT/apps/VibeTypeMac"
APP_PATH="$MAC_DIR/build/Build/Products/Release/VibeType.app"
DMG_DIR="$ROOT/dist"

DO_SIGN=0
DO_NOTARIZE=0
for arg in "$@"; do
    case "$arg" in
        --sign) DO_SIGN=1 ;;
        --notarize) DO_NOTARIZE=1; DO_SIGN=1 ;;
    esac
done

echo "→ Xcode 프로젝트 재생성"
cd "$MAC_DIR"
xcodegen generate > /dev/null

echo "→ Release 빌드"
declare -a XCB=(
    -scheme VibeTypeMac
    -destination 'platform=macOS'
    -configuration Release
    -derivedDataPath build
)
if [ $DO_SIGN -eq 1 ]; then
    [ -z "$DEVELOPER_ID_APP" ] && { echo "❌ DEVELOPER_ID_APP 미설정"; exit 1; }
    XCB+=("CODE_SIGN_IDENTITY=$DEVELOPER_ID_APP")
    XCB+=("CODE_SIGN_STYLE=Manual")
    if [ -n "$APPLE_TEAM_ID" ]; then
        XCB+=("DEVELOPMENT_TEAM=$APPLE_TEAM_ID")
    fi
    XCB+=("OTHER_CODE_SIGN_FLAGS=--timestamp")
else
    XCB+=("CODE_SIGNING_ALLOWED=NO")
fi
XCB+=(build)

if ! xcodebuild "${XCB[@]}" > /tmp/vibetype-release.log 2>&1; then
    echo "❌ 빌드 실패. 마지막 30줄:"
    tail -30 /tmp/vibetype-release.log
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ .app 산출물 없음: $APP_PATH"
    exit 1
fi
echo "✓ 빌드 완료: $APP_PATH"

cd "$ROOT"

if [ $DO_NOTARIZE -eq 1 ]; then
    [ -z "$APPLE_TEAM_ID" ] && { echo "❌ APPLE_TEAM_ID 미설정"; exit 1; }
    [ -z "$APPLE_ID" ] && { echo "❌ APPLE_ID 미설정"; exit 1; }
    [ -z "$APPLE_APP_PASSWORD" ] && { echo "❌ APPLE_APP_PASSWORD 미설정 (App-specific password)"; exit 1; }

    mkdir -p "$DMG_DIR"
    ZIP_PATH="$DMG_DIR/VibeType-notarize.zip"
    /usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    echo "→ 노타라이즈 제출 (5~15분 소요)"
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait

    echo "→ Stapler"
    xcrun stapler staple "$APP_PATH"
    rm -f "$ZIP_PATH"
fi

# DMG 생성
if command -v create-dmg >/dev/null 2>&1; then
    mkdir -p "$DMG_DIR"
    DMG_PATH="$DMG_DIR/VibeType.dmg"
    # 기존 임시 산출물 정리.
    rm -f "$DMG_PATH" "$DMG_DIR"/rw.*.VibeType.dmg
    # 마운트되어 있으면 강제 언마운트 (이전 실행에서 unmount 실패 잔재).
    for vol in /Volumes/VibeType*; do
        [ -d "$vol" ] && hdiutil detach "$vol" -force >/dev/null 2>&1 || true
    done

    echo "→ DMG 생성: $DMG_PATH"
    create-dmg \
        --volname "VibeType" \
        --window-size 540 380 \
        --icon-size 96 \
        --icon "VibeType.app" 140 180 \
        --app-drop-link 400 180 \
        --hide-extension "VibeType.app" \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_PATH" || true

    # create-dmg가 unmount 실패 시 rw.NNNN.VibeType.dmg로 남김. rename.
    if [ ! -f "$DMG_PATH" ]; then
        TMP_DMG=$(ls "$DMG_DIR"/rw.*.VibeType.dmg 2>/dev/null | head -1)
        if [ -n "$TMP_DMG" ]; then
            # 마운트되어 있으면 detach 후 rename.
            for vol in /Volumes/VibeType*; do
                [ -d "$vol" ] && hdiutil detach "$vol" -force >/dev/null 2>&1 || true
            done
            mv "$TMP_DMG" "$DMG_PATH"
        fi
    fi

    if [ $DO_SIGN -eq 1 ] && [ -f "$DMG_PATH" ]; then
        codesign --sign "$DEVELOPER_ID_APP" --timestamp "$DMG_PATH"
    fi

    if [ -f "$DMG_PATH" ]; then
        echo "✓ DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
    else
        echo "❌ DMG 생성 실패. .app은 사용 가능: $APP_PATH"
    fi
else
    echo "ℹ️  create-dmg 미설치. 'brew install create-dmg' 후 DMG 생성 가능."
    echo "✓ .app만 사용: $APP_PATH"
fi
