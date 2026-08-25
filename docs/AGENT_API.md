# Calenfi Agent API (CLI)

JSON-интерфейс над локальным календарём Calenfi для LLM-агентов. **Только Linux/Arch.**
Работает с той же локальной БД, что и приложение (`~/.local/share/io.github.karpovilia.calenfi/calenfi.sqlite`).

## Запуск

```bash
tools/calenfi <command> [--flags]        # обёртка: чистый JSON в stdout
# или напрямую:
dart run calenfi:calenfi <command> [--flags]   # из корня проекта
```

Всё печатает JSON: `{"ok": true, ...}` или `{"ok": false, "error": "..."}`.
Время — ISO 8601 (`2026-06-12T15:00:00`); на выходе всегда UTC (`...Z`).

## Чтение

| Команда | Назначение | Флаги |
|---|---|---|
| `agenda` | список встреч (со склейкой дублей) | `--from ISO --to ISO [--include-cancelled]` |
| `busy` | интервалы занятости (free/busy), объединённые | `--from ISO --to ISO` |
| `freeslots` | свободные слоты в рабочих часах | `--from ISO --to ISO --duration MIN [--day-start 10 --day-end 20]` |
| `accounts` | учётные записи | — |
| `calendars` | календари | — |

`agenda` для каждого события отдаёт: `id, title, start, end, allDay, status`
(`confirmed`/`cancelled`), `response` (`organizer`/`accepted`/`tentative`/`declined`/`needsAction` —
так отличаются **подтверждённые** от **планируемых**), `showAs`, `calendarId`, `accountId`,
`location`, `description`, `conference{type,url}`, `attendees[]`, и при склейке —
`merged`/`sourceCount`/`sources[]`.

`busy` исключает отменённые, `showAs=free` и отклонённые (`declined`) — то есть реальная занятость.

## Запись

Пишется оптимистично в локальную БД + очередь Outbox; в источники уезжает при ближайшей
синхронизации (`"note": "queued; syncs when app runs"`). Чтобы протолкнуть немедленно —
вызови `sync` (см. ниже): CLI пушит Outbox и подтягивает изменения сам, без запущенного приложения.

| Команда | Флаги |
|---|---|
| `create` | `--title T --start ISO --end ISO` + `--all-day` (тогда `--start`/`--end` — даты `2026-09-22`, время отбрасывается, `--end` необязателен = один день) + опц. `--calendar ID` \| `--account EMAIL`, `--location`, `--description`, `--attendees a@x,b@y`, `--conference meet\|teams\|zoom\|telemost`, `--rrule "FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20270101T000000Z"` (повторение, RFC 5545) |
| `update` | `--id ID` + любые из `--title --start --end --location --description`, `--all-day true|false` (переключает режим; при `true` даты обрезаются до полуночи) |
| `delete` | `--id ID` |
| `rsvp` | `--id ID --response accepted\|declined\|tentative` |

Если не указать `--calendar`/`--account`, событие создаётся в основном (primary) календаре.
При `--account EMAIL` выбирается **основной** календарь этого аккаунта (primary, иначе тот, чей
id/имя совпадает с почтой) — раньше брался первый попавшийся, и событие молча уезжало в чужой
подписной календарь того же аккаунта. Надёжнее всего указывать `--calendar` явно: id виден
в выводе `calendars`. Календари только для чтения отвергаются с ошибкой.

**Событие на весь день.** `--all-day --start 2026-09-22` → локальная полночь 22.09 …
эксклюзивная полночь 23.09, `allDay=true`. В выводе это UTC-момент со сдвигом на пояс
(в GMT+3 — `2026-09-21T21:00:00Z`), так и должно быть: приложение и провайдеры
(Google `date`, EWS `IsAllDayEvent`) читают это как «весь день 22 сентября».

## Синхронизация

| Команда | Назначение | Флаги |
|---|---|---|
| `sync` | pull из источников + push Outbox через тот же движок, что и приложение | `[--account acc-<id>]` — все аккаунты или один |
| `contacts` | список контактов | — |
| `contact-add` | добавить контакт | `--name N --email E` |
| `secret-set` | положить секрет в хранилище (напр. ключи Zoom) | `--key ZOOM_CLIENT_ID --value …` |

Полный проход `sync` занимает ~70 c (медленнее всего EWS/HSE). Приложение для этого запускать не нужно.

## Примеры (для агента)

```bash
# Что у меня запланировано на неделю?
tools/calenfi agenda --from 2026-06-12T00:00:00 --to 2026-06-19T00:00:00

# Когда я свободен завтра на час?
tools/calenfi freeslots --from 2026-06-13T00:00:00 --to 2026-06-13T23:59:00 --duration 60

# Поставь встречу с боссом
# Еженедельная серия (зал по средам до августа 2027)
tools/calenfi create --title "Зал" --start 2026-07-29T22:00:00 --end 2026-07-30T00:00:00 \
  --rrule "FREQ=WEEKLY;BYDAY=WE;UNTIL=20270731T235959Z"

tools/calenfi create --title "1:1 with boss" \
  --start 2026-06-13T15:00:00 --end 2026-06-13T15:30:00 \
  --account me@gmail.com --attendees boss@example.com --conference meet

# Перенеси её на час позже
tools/calenfi update --id <ID> --start 2026-06-13T16:00:00 --end 2026-06-13T16:30:00

# Прими приглашение
tools/calenfi rsvp --id <ID> --response accepted
```

## Заметки для агента

- Для отделения «подтверждённых» от «планируемых» смотри поле `response`:
  `organizer`/`accepted` — подтверждено; `needsAction`/`tentative` — планируется/под вопросом.
- `busy`/`freeslots` уже учитывают `showAs` и `declined` — отдают реальную занятость.
- Записи не уходят в Google/Yandex/Exchange мгновенно — они в Outbox до ближайшего синка;
  чтобы протолкнуть сразу, вызови `sync` (можно `--account acc-<id>` для одного источника).
- Реализация: `bin/calenfi.dart`; переопределить путь к БД — `--db PATH` или `CALENFI_DB`.
