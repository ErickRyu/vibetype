#!/bin/bash
# 1024x1024 PNG → AppIcon.appiconset 모든 사이즈 자동 생성.
# 사용법: ./scripts/make-icon.sh path/to/icon-1024.png
set -e

if [ $# -lt 1 ]; then
    echo "사용법: $0 <path-to-1024x1024.png>"
    exit 1
fi

SOURCE="$1"
if [ ! -f "$SOURCE" ]; then
    echo "❌ 파일 없음: $SOURCE"
    exit 1
fi

# 1024x1024 검증
DIMENSIONS=$(sips -g pixelWidth -g pixelHeight "$SOURCE" 2>/dev/null | awk '/pixel(Width|Height)/ {print $2}' | tr '\n' 'x' | sed 's/x$//')
if [ "$DIMENSIONS" != "1024x1024" ]; then
    echo "⚠️  추천: 1024x1024 PNG. 현재: $DIMENSIONS. 진행 계속? (Ctrl-C 취소)"
    sleep 2
fi

DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/apps/VibeTypeMac/VibeTypeMac/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$DEST_DIR"

echo "→ AppIcon 사이즈 생성 중…"
sips -z 16 16     "$SOURCE" --out "$DEST_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32     "$SOURCE" --out "$DEST_DIR/icon_16x16@2x.png"   > /dev/null
sips -z 32 32     "$SOURCE" --out "$DEST_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64     "$SOURCE" --out "$DEST_DIR/icon_32x32@2x.png"   > /dev/null
sips -z 128 128   "$SOURCE" --out "$DEST_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256   "$SOURCE" --out "$DEST_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SOURCE" --out "$DEST_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512   "$SOURCE" --out "$DEST_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SOURCE" --out "$DEST_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$SOURCE" --out "$DEST_DIR/icon_512x512@2x.png" > /dev/null

echo "✓ AppIcon 생성 완료: $DEST_DIR"
echo "  다음: 'make mac' 빌드 → 메뉴바·Dock 아이콘 확인"
