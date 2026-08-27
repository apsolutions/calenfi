#!/usr/bin/env bash
#
# setup_macos.sh — одноразовая подготовка платформы macOS для Calenfi.
#
# ВАЖНО: запускать НА Mac. Flutter не умеет генерировать папку macos/ на Linux
# (desktop macOS поддерживается только на самом Mac + Xcode). Поэтому в репозитории
# папки macos/ нет — она создаётся этим скриптом на целевой машине.
#
# Что делает:
#   1. Генерирует macos/ (валидный Xcode-проект) через `flutter create`.
#   2. Патчит entitlements: исходящая сеть (календарные API) + Keychain
#      (нужно для flutter_secure_storage под app-sandbox).
#   3. Ставит зависимости.
#
# После этого:  flutter run -d macos
#
set -euo pipefail

cd "$(dirname "$0")/.."   # корень проекта
ORG="ru.apsolutions"
BUNDLE_ID="ru.apsolutions.calenfi"   # совпадает с PRODUCT_BUNDLE_IDENTIFIER, который ставит flutter create

# --- 0. Проверки окружения ---------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ОШИБКА: этот скрипт нужно запускать на macOS (сборка macOS-приложения возможна только на Mac)." >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "ОШИБКА: flutter не найден в PATH. Установите Flutter и Xcode." >&2
  exit 1
fi

# --- 1. Генерация платформы macos -------------------------------------------
if [[ -d macos ]]; then
  echo "==> macos/ уже существует — пропускаю flutter create."
else
  echo "==> Генерирую папку macos/ ..."
  flutter create --platforms=macos --org "$ORG" .
fi

# --- 2. Патч entitlements -----------------------------------------------------
PB=/usr/libexec/PlistBuddy
patch_entitlements () {
  local f="$1"
  [[ -f "$f" ]] || { echo "   пропуск (нет файла): $f"; return; }
  echo "==> Патчу $f"

  # Исходящие сетевые запросы (Google/Graph/CalDAV/EWS).
  "$PB" -c "Delete :com.apple.security.network.client" "$f" 2>/dev/null || true
  "$PB" -c "Add :com.apple.security.network.client bool true" "$f"

  # Доступ к Keychain для flutter_secure_storage под app-sandbox.
  "$PB" -c "Delete :keychain-access-groups" "$f" 2>/dev/null || true
  "$PB" -c "Add :keychain-access-groups array" "$f"
  "$PB" -c "Add :keychain-access-groups:0 string \$(AppIdentifierPrefix)${BUNDLE_ID}" "$f"
}
patch_entitlements macos/Runner/DebugProfile.entitlements
patch_entitlements macos/Runner/Release.entitlements

# --- 2b. Иконка приложения ---------------------------------------------------
# flutter create кладёт дефолтную иконку — подменяем нашей (tools/icon/macos).
ICONSET="tools/icon/macos_appicon/AppIcon.appiconset"
DEST="macos/Runner/Assets.xcassets/AppIcon.appiconset"
if [[ -d "$ICONSET" && -d "$(dirname "$DEST")" ]]; then
  echo "==> Ставлю иконку приложения (macOS)"
  rm -f "$DEST"/*.png
  cp "$ICONSET"/*.png "$ICONSET"/Contents.json "$DEST"/
fi

# --- 3. Зависимости + кодоген -------------------------------------------------
echo "==> flutter pub get"
flutter pub get
echo "==> кодоген Drift/Riverpod"
dart run build_runner build --delete-conflicting-outputs

cat <<'DONE'

✅ Готово. Платформа macOS подготовлена.

Запуск:
    flutter run -d macos

Если используешь реальные провайдеры (OAuth) — положи tools/google_client_secret.json
и проверь redirect-URI для desktop-приложения.
DONE
