#!/usr/bin/env bash
# Снимок текущего экрана загруженного симулятора (для выгрузки в Figma вручную).
# Использование: ./scripts/capture_simulator_screenshot.sh [имя_файла.png]
set -euo pipefail
OUT="${1:-$HOME/Desktop/fishchips_sim_screenshot.png}"
UDID="$(xcrun simctl list devices | awk -F'[()]' '/Booted/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
if [[ -z "${UDID}" ]]; then
  echo "Нет Booted-симулятора. Запусти Simulator и приложение, затем снова запусти скрипт." >&2
  exit 1
fi
xcrun simctl io "${UDID}" screenshot "${OUT}"
echo "OK: ${OUT}"
