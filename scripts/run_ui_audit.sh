#!/usr/bin/env bash
# UI-audit: скрины в artifacts/ui-audit/screenshots + screenflow.json
# По умолчанию: после логина импорт игр из TestData/ui_audit_import_games.txt (игрок «Ник»),
# затем обход экранов — чтобы вкладки были с данными, а не пустые.
# Быстрый прогон без импорта: UI_AUDIT_SKIP_IMPORT=1 ./scripts/run_ui_audit.sh
# Креды: экспортируй FC_TEST_EMAIL / FC_TEST_PASSWORD или положи файл `.env.ui-audit`
# в корень gamesCheck (см. пример ниже; файл в .gitignore).
# В схеме не используем $(FC_TEST_*): в UITest приходит буквальная строка — только export в shell.
# Обход xctrunner: -parallel-testing-enabled NO, явный destination.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export UITEST_REPO_ROOT="$ROOT"
if [[ -f "$ROOT/.env.ui-audit" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env.ui-audit"
  set +a
fi
export UI_AUDIT_ARTIFACTS_ROOT="${UI_AUDIT_ARTIFACTS_ROOT:-$ROOT/artifacts/ui-audit}"
mkdir -p "$UI_AUDIT_ARTIFACTS_ROOT/screenshots"

if [[ -z "${FC_TEST_EMAIL:-}" || "${FC_TEST_EMAIL}" == *'$('* ]]; then
  echo "Ошибка: FC_TEST_EMAIL пустой или не раскрыт (сейчас: ${FC_TEST_EMAIL:-<пусто>})."
  echo "В gamesCheck/.env.ui-audit должны быть реальные значения, например:"
  echo "  export FC_TEST_EMAIL=you@example.com"
  echo "  export FC_TEST_PASSWORD=yourpassword"
  echo "Запуск из Xcode: Product → Scheme → Test → добавь FC_TEST_* в Environment или экспортируй в shell перед xcodebuild."
  exit 1
fi
if [[ -z "${FC_TEST_PASSWORD:-}" || "${FC_TEST_PASSWORD}" == *'$('* ]]; then
  echo "Ошибка: FC_TEST_PASSWORD пустой или не раскрыт."
  exit 1
fi

DEST="${1:-platform=iOS Simulator,name=iPhone 17 Pro}"
UI_AUDIT_TEST_METHOD="${UI_AUDIT_TEST_METHOD:-testUIAuditScreenFlowWithImport}"
if [[ "${UI_AUDIT_SKIP_IMPORT:-}" == "1" ]]; then
  UI_AUDIT_TEST_METHOD="testUIAuditScreenFlow"
fi
echo "UI_AUDIT_ARTIFACTS_ROOT=$UI_AUDIT_ARTIFACTS_ROOT"
echo "UI-audit test: UIAuditUITests/${UI_AUDIT_TEST_METHOD}"

xcodebuild \
  -project FishAndChips.xcodeproj \
  -scheme FishAndChips \
  -destination "$DEST" \
  -parallel-testing-enabled NO \
  -only-testing:FishAndChipsUITests/UIAuditUITests/"${UI_AUDIT_TEST_METHOD}" \
  test

echo "Готово: $UI_AUDIT_ARTIFACTS_ROOT/screenflow.json"
echo "Подсказка: если в симуляторе не набирается текст — I/O → Keyboard → отключи «Connect Hardware Keyboard»."
