#!/usr/bin/env bash
# Запуск UI-теста скриншотов для Figma. Из каталога gamesCheck:
#   export FC_TEST_EMAIL=...
#   export FC_TEST_PASSWORD=...
#   export FIGMA_SCREENSHOT_DIR="$PWD/docs/figma-screenshots"
#   ./scripts/run_figma_screenshots.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="${FIGMA_SCREENSHOT_DIR:-$ROOT/docs/figma-screenshots}"
mkdir -p "$OUT"
export FIGMA_SCREENSHOT_DIR="$OUT"

DEST="${1:-platform=iOS Simulator,name=iPhone 17 Pro}"

echo "FIGMA_SCREENSHOT_DIR=$OUT"
xcodebuild \
  -project FishAndChips.xcodeproj \
  -scheme FishAndChips \
  -destination "$DEST" \
  -only-testing:FishAndChipsUITests/FigmaScreenshotsUITests/testCaptureFigmaScreenshots \
  test

echo "PNG сохранены в: $OUT"
