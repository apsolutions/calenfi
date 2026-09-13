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
#   2. Патчит entitlements: исходящая сеть (календарные API).
#   3. Добавляет таргет WidgetKit-виджетов (macos_widget/).
#   4. Ставит зависимости.
#
# После этого:  flutter run -d macos
#
set -euo pipefail

cd "$(dirname "$0")/.."   # корень проекта
ORG="ru.apsolutions"
BUNDLE_ID="ru.apsolutions.calenfi"

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

# `flutter create --org` задаёт id только при первичной генерации. Закрепляем
# его и для уже существующего Xcode-проекта, чтобы старый bundle id не мог
# пережить перенос репозитория.
APP_INFO="macos/Runner/Configs/AppInfo.xcconfig"
[[ -f "$APP_INFO" ]] || {
  echo "ОШИБКА: не найден $APP_INFO" >&2
  exit 1
}
APP_INFO_TMP="$(mktemp "${TMPDIR:-/tmp}/calenfi-app-info.XXXXXX")"
trap 'rm -f -- "$APP_INFO_TMP"' EXIT
awk -v identity="PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID" '
  BEGIN { found = 0 }
  /^PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=/ {
    if (!found) print identity
    found = 1
    next
  }
  { print }
  END { if (!found) print identity }
' "$APP_INFO" >"$APP_INFO_TMP"
chmod 644 "$APP_INFO_TMP"
mv -f "$APP_INFO_TMP" "$APP_INFO"
trap - EXIT
grep -Fqx "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID" "$APP_INFO"

# --- 2. Патч entitlements -----------------------------------------------------
PB=/usr/libexec/PlistBuddy
patch_entitlements () {
  local f="$1"
  [[ -f "$f" ]] || { echo "   пропуск (нет файла): $f"; return; }
  echo "==> Патчу $f"

  # Исходящие сетевые запросы (Google/Graph/CalDAV/EWS).
  "$PB" -c "Delete :com.apple.security.network.client" "$f" 2>/dev/null || true
  "$PB" -c "Add :com.apple.security.network.client bool true" "$f"

  # App Sandbox у САМОГО приложения выключен намеренно. В песочнице HOME
  # подменяется контейнером: приложение перестаёт видеть ~/Library/Application
  # Support/calenfi (accounts.json, secrets.env, снимок для виджетов), а
  # SecretStore не может запустить утилиту `security` для Keychain. Шаблон
  # flutter create ставит sandbox = true, поэтому гасим его явно — иначе после
  # пересоздания macos/ приложение молча теряет все учётные записи.
  # Расширение виджетов, наоборот, ОБЯЗАНО быть в песочнице (иначе macOS его
  # не регистрирует) — у него свой CalenfiWidgets.entitlements.
  "$PB" -c "Delete :com.apple.security.app-sandbox" "$f" 2>/dev/null || true
  "$PB" -c "Add :com.apple.security.app-sandbox bool false" "$f"

  # keychain-access-groups намеренно НЕ добавляем: Xcode 26 отказывается
  # подписывать такой бандл ad-hoc («requires signing with a development
  # certificate»), а на macOS секреты и так идут через утилиту `security`
  # (MacKeychainBackend), а не через flutter_secure_storage.
  "$PB" -c "Delete :keychain-access-groups" "$f" 2>/dev/null || true
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

# --- 2c. WidgetKit-расширение (виджеты «сегодня» и мини-календарь) -----------
# Таргет расширения нельзя закоммитить вместе с macos/ (её тут нет), поэтому он
# добавляется в сгенерированный Xcode-проект скриптом. Исходники — macos_widget/.
echo "==> Добавляю таргет виджетов CalenfiWidgets"
if ! ruby -e "require 'xcodeproj'" >/dev/null 2>&1; then
  echo "   ставлю гем xcodeproj"
  gem install xcodeproj --no-document >/dev/null 2>&1 ||
    sudo gem install xcodeproj --no-document
fi
ruby tools/macos_add_widget_target.rb

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
