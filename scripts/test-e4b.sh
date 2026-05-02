#!/bin/bash
# Gemma 3n E4B 5개 액션 검증 스크립트
set +e
CLI=/Users/sungjin/MyDocument/Project/vibetype/.xcbuild/Build/Products/Debug/vibetype-cli
export VIBETYPE_MODEL=gemma-3n-e4b-it-lm-4bit

echo "=== Gemma 3n E4B 검증 시작 ==="
echo ""
echo "=== 1. IMPROVE ==="
$CLI improve "회의 좋았어" 2>&1
echo ""
echo "=== 2. FIX GRAMMAR ==="
$CLI fix "오늘 미팅 좀 길었어. 다음번엔 짭게 하자" 2>&1
echo ""
echo "=== 3. TRANSLATE → KO ==="
$CLI translate-ko "Hello, nice to meet you. Let's grab coffee tomorrow." 2>&1
echo ""
echo "=== 4. TRANSLATE → EN ==="
$CLI translate-en "안녕하세요, 만나서 반갑습니다" 2>&1
echo ""
echo "=== 5. SUMMARIZE ==="
$CLI summarize "오늘 회의에서 우리는 다음 분기 로드맵을 검토했고 마케팅 예산을 두 배로 늘리기로 했다. 또한 신제품 출시일을 6월에서 8월로 미루기로 합의했다." 2>&1
echo ""
echo "=== 검증 완료 ==="
