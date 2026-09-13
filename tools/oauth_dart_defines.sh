#!/usr/bin/env bash
# Печатает аргументы --dart-define для OAuth-клиентов приложения, по одному на
# строку. Значения берутся из переменных окружения с теми же именами, что и ключи
# keyring (lib/data/secure/build_credentials.dart):
#
#   bash tools/oauth_dart_defines.sh --require > oauth-defines
#   defines=(); while IFS= read -r d; do defines+=("$d"); done < oauth-defines
#   flutter build apk --release "${defines[@]}"
#
# --require: ошибка, если нет клиентов Google или Microsoft. Без них скачанная
# сборка не может начать вход через браузер.
#
# В сборку попадают только идентификаторы OAuth-приложений. Пароли, токены
# пользователей и ключи Zoom сюда не добавлять.
set -euo pipefail

keys=(GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET GRAPH_CLIENT_ID GRAPH_TENANT YANDEX_OAUTH_CLIENT_ID YANDEX_OAUTH_CLIENT_SECRET)
required=(GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET GRAPH_CLIENT_ID)

require=0
if [[ "${1:-}" == --require ]]; then
  require=1
fi

missing=()
for key in "${required[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    missing+=("$key")
  fi
done
if (( require )) && (( ${#missing[@]} )); then
  echo "Не заданы OAuth-клиенты: ${missing[*]}. Задайте их переменными окружения сборки (приватная конфигурация, не публичный репозиторий)." >&2
  exit 1
fi

for key in "${keys[@]}"; do
  value="${!key:-}"
  if [[ -n "$value" ]]; then
    printf -- '--dart-define=%s=%s\n' "$key" "$value"
  fi
done
