#!/usr/bin/env bash
# Сборка релиза + транзакционная установка приложения, иконки и .desktop.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/development/flutter/bin:$PATH"

first_five_cpus() {
  local cpu_list="$1" part start end cpu
  local count=0
  local -a selected=()
  local -a parts=()
  IFS=',' read -r -a parts <<< "$cpu_list"
  for part in "${parts[@]}"; do
    if [[ "$part" == *-* ]]; then
      start="${part%-*}"
      end="${part#*-}"
    else
      start="$part"
      end="$part"
    fi
    [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]] || continue
    for ((cpu = start; cpu <= end; cpu += 1)); do
      selected+=("$cpu")
      count=$((count + 1))
      ((count >= 5)) && break 2
    done
  done
  local joined
  IFS=','
  joined="${selected[*]}"
  printf '%s\n' "$joined"
}

if command -v taskset >/dev/null 2>&1; then
  allowed_cpus="$(taskset -pc "$$" 2>/dev/null | sed -E 's/.*:[[:space:]]*//')"
  build_cpus="$(first_five_cpus "$allowed_cpus")"
else
  build_cpus=""
fi

if [[ -n "$build_cpus" ]]; then
  echo "==> Сборка Calenfi на CPU $build_cpus"
  taskset -c "$build_cpus" flutter build linux --release
else
  echo "==> Сборка Calenfi (taskset недоступен)"
  flutter build linux --release
fi

bundle="build/linux/x64/release/bundle"
if [[ ! -x "$bundle/calenfi" ]]; then
  echo "ОШИБКА: release bundle не содержит исполняемый calenfi" >&2
  exit 1
fi

# Не даём старому process/application-id продолжать писать legacy DB после
# создания canonical-копии. Проверка выполняется непосредственно перед swap.
if command -v pgrep >/dev/null 2>&1 &&
   pgrep -u "$(id -u)" -x calenfi >/dev/null 2>&1; then
  echo "ОШИБКА: Calenfi запущен. Закройте приложение и повторите установку." >&2
  exit 1
fi

install_parent="$HOME/.local/opt"
install_target="$install_parent/calenfi"
mkdir -p "$install_parent"
install_stage="$(mktemp -d "$install_parent/.calenfi.install.XXXXXX")"
install_backup=""
desktop_stage=""

cleanup() {
  if [[ -n "$install_backup" &&
        ( -e "$install_backup" || -L "$install_backup" ) &&
        ! -e "$install_target" && ! -L "$install_target" ]]; then
    mv -- "$install_backup" "$install_target" || true
  fi
  if [[ -n "$desktop_stage" && -e "$desktop_stage" ]]; then
    rm -f -- "$desktop_stage"
  fi
  if [[ -n "$install_stage" && -d "$install_stage" ]]; then
    rm -rf -- "$install_stage"
  fi
}
trap cleanup EXIT

cp -a "$bundle/." "$install_stage/"
chmod 755 "$install_stage"
if [[ ! -x "$install_stage/calenfi" ]]; then
  echo "ОШИБКА: staged bundle повреждён" >&2
  exit 1
fi

if [[ -e "$install_target" || -L "$install_target" ]]; then
  install_backup="$install_parent/.calenfi.rollback.$$.${RANDOM}"
  if [[ -e "$install_backup" || -L "$install_backup" ]]; then
    echo "ОШИБКА: collision rollback path: $install_backup" >&2
    exit 1
  fi
  mv -- "$install_target" "$install_backup"
fi

if mv -- "$install_stage" "$install_target"; then
  install_stage=""
else
  if [[ -n "$install_backup" && ! -e "$install_target" ]]; then
    mv -- "$install_backup" "$install_target"
  fi
  echo "ОШИБКА: не удалось активировать staged bundle" >&2
  exit 1
fi

if [[ -n "$install_backup" ]]; then
  rm -rf -- "$install_backup"
  install_backup=""
fi

mkdir -p "$HOME/.local/bin"
ln -sfn "$install_target/calenfi" "$HOME/.local/bin/calenfi"

# --- иконки (hicolor), каждая заменяется атомарным rename ---
for size in 64 128 256 512; do
  icon_dir="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$icon_dir"
  if [[ -f "tools/icon/linux_${size}.png" ]]; then
    icon_stage="$icon_dir/.ru.apsolutions.calenfi.png.$$"
    cp "tools/icon/linux_${size}.png" "$icon_stage"
    mv -f -- "$icon_stage" "$icon_dir/ru.apsolutions.calenfi.png"
  fi
done
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

# --- .desktop: validate/stage first, then replace atomically ---
applications_dir="$HOME/.local/share/applications"
mkdir -p "$applications_dir"
desktop_target="$applications_dir/ru.apsolutions.calenfi.desktop"
desktop_stage="$(mktemp --suffix=.desktop \
  "$applications_dir/.ru.apsolutions.calenfi.XXXXXX")"
cat > "$desktop_stage" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Calenfi
GenericName=Calendar
Comment=Local-first calendar aggregator
Exec="$HOME/.local/opt/calenfi/calenfi"
Icon=ru.apsolutions.calenfi
Terminal=false
Categories=Office;Calendar;
Keywords=calendar;agenda;meetings;
StartupWMClass=ru.apsolutions.calenfi
StartupNotify=true
DESKTOP
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop_stage"
fi
chmod 644 "$desktop_stage"
mv -f -- "$desktop_stage" "$desktop_target"
desktop_stage=""
rm -f -- "$applications_dir/calenfi.desktop"
update-desktop-database "$applications_dir" 2>/dev/null || true

echo "✓ Calenfi установлен → $install_target/calenfi"
echo "  запуск: Win+r → calenfi  (или из меню приложений)"
