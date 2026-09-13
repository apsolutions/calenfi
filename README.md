# Calenfi

[![CI](https://github.com/apsolutions/calenfi/actions/workflows/ci.yml/badge.svg)](https://github.com/apsolutions/calenfi/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/apsolutions/calenfi?sort=semver)](https://github.com/apsolutions/calenfi/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Calenfi** is a local-first calendar aggregator for **macOS, Linux, Windows and
Android**. It merges Google, Microsoft 365, Yandex (CalDAV) and self-hosted
Exchange (EWS) into a single reactive grid — your schedule in one place, cached
on-device, editable offline.

> Built with Flutter · Riverpod · Drift.

## Features

- **One grid, many sources** — Google Calendar, Microsoft 365 (Graph), Yandex
  (CalDAV) and Exchange (EWS) side by side.
- **Local-first** — everything is cached in a local SQLite (Drift) database; the
  UI is instant and works offline, changes sync in the background.
- **Smart deduplication** — identical events shared across calendars collapse
  into one, with a toggle to keep every copy separate.
- **Move & resize** — drag to reschedule, drag edges to change duration on
  desktop; long-press-to-move on touch and trackpad.
- **Conferences** — attach real Teams / Meet / Zoom / Telemost meetings,
  independent of which calendar hosts the event.
- **Per-calendar overrides** — visibility, colour and default reminders.
- **Reminders & widgets** — local notifications, a home-screen agenda widget on
  Android, and two WidgetKit widgets on macOS: today's agenda and a translucent
  mini month calendar you can page through right in the widget.
- **Agent CLI** — a JSON interface (`tools/calenfi`) to read and edit your
  schedule from scripts or LLM agents (see [docs/AGENT_API.md](docs/AGENT_API.md)).

## Downloads

Prebuilt binaries for every platform are attached to each
[GitHub Release](https://github.com/apsolutions/calenfi/releases).

| Platform | Artifact |
|----------|----------|
| Linux    | `calenfi-<version>-linux-x64.tar.gz` |
| Windows  | `calenfi-<version>-windows-x64.zip` |
| macOS    | `calenfi-<version>-macos.zip` (ad-hoc signed — see note below) |
| Android  | `calenfi-<version>-<abi>.apk` |

> **macOS:** the app is ad-hoc signed (no Apple Developer notarization), so on
> first launch macOS blocks it. Right-click the app → **Open** → **Open**, once.
>
> **Android:** the APK is signed with a debug key for now — Android will warn on
> install. A release-signed build is planned.

## Connecting accounts

Open **Accounts → Add account** and pick a provider:

- **Google / Microsoft 365** — sign in through your browser (OAuth 2.0
  authorization-code + PKCE, loopback redirect; works on desktop and mobile).
  GitHub releases ship without an OAuth client and ask you for one — see below.
- **Yandex (CalDAV) / Exchange (EWS)** — enter your e-mail and an **app
  password** (not your main password).

### OAuth client configuration

Google/Microsoft sign-in needs an OAuth client. GitHub releases do not include
one: on **Add account** the app opens a dialog where you enter your own client,
and it is saved to the keyring of that device. Private builds can embed a client
(see [Build from source](#build-from-source)); a client in the keyring always
wins over the embedded one. You can also store the values via the CLI:

```bash
# Google (OAuth client of type "Desktop")
tools/calenfi secret-set --key GOOGLE_OAUTH_CLIENT_ID     --value "…apps.googleusercontent.com"
tools/calenfi secret-set --key GOOGLE_OAUTH_CLIENT_SECRET --value "…"
# Microsoft (Azure app registration, platform "Mobile and desktop",
# redirect http://localhost)
tools/calenfi secret-set --key GRAPH_CLIENT_ID --value "…"
tools/calenfi secret-set --key GRAPH_TENANT    --value "common"
```

On a machine without the CLI (for example a plain macOS release, which ships no
Dart toolchain) drop the same `KEY=value` pairs into `secrets.env` inside the
config directory instead — `~/Library/Application Support/calenfi` on macOS,
`~/.config/calenfi` on Linux, `%APPDATA%\calenfi` on Windows. The app imports the
file into the OS keyring on the next start.

### macOS widgets

The release `.app` embeds `CalenfiWidgets.appex`: **Calenfi — сегодня** (agenda
for the current day) and **Calenfi — календарь** (month grid with `‹` / `›`
paging; tapping the month name jumps back to today). Add them the usual way —
right-click the desktop → Edit Widgets → Calenfi — after launching the app once
from `/Applications` so the system registers the extension.

The widgets never talk to the network: the app writes a snapshot to
`~/Library/Application Support/calenfi/widget_snapshot.json` whenever the local
database changes, and the extension renders it. Keep the app running (or open it
periodically) for the snapshot to stay fresh.

### Video conferences (optional)

Attaching a meeting link works out of the box for **Teams** (via a connected
Microsoft 365 account), **Google Meet** (via a connected Google account), and
**Yandex Telemost** when the event belongs to a connected Yandex CalDAV
calendar. Native Telemost creation uses the existing Yandex app password and
does not need a separate OAuth connection. **Zoom**, and Telemost attached to a
non-Yandex calendar, need additional credentials:

```bash
# Zoom — Server-to-Server OAuth app (scope meeting:write)
tools/calenfi secret-set --key ZOOM_ACCOUNT_ID    --value "…"
tools/calenfi secret-set --key ZOOM_CLIENT_ID     --value "…"
tools/calenfi secret-set --key ZOOM_CLIENT_SECRET --value "…"
# Standalone Telemost — connect in Accounts → Add → Telemost (needs a Yandex
# OAuth app with "Telemost API" access, redirect http://localhost):
tools/calenfi secret-set --key YANDEX_OAUTH_CLIENT_ID     --value "…"
tools/calenfi secret-set --key YANDEX_OAUTH_CLIENT_SECRET --value "…"
```

## Credentials & privacy

Calenfi is local-first and stores nothing on any server of its own. Your
passwords and OAuth tokens live in the **operating-system keyring**:

- **Linux** — libsecret (`secret-tool`; GNOME Keyring, KWallet, KeePassXC…)
- **macOS** — Keychain (`security`)
- **Windows** — DPAPI (per-user, per-machine)
- **Android / iOS** — `flutter_secure_storage` (Keychain / EncryptedSharedPrefs)

If no system keyring is available, secrets fall back to a `0600` file in the
per-user config directory (`$XDG_CONFIG_HOME/calenfi`, `~/Library/Application
Support/calenfi`, or `%APPDATA%\calenfi`) — never inside the project tree, never
in git. Accounts are described by `accounts.json` in that same directory (see
[docs/accounts.example.json](docs/accounts.example.json)); there are no
hard-coded addresses in the source.

## Build from source

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel, Dart ≥ 3.12).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift codegen
flutter run -d linux        # or: -d macos / -d windows / <android-device-id>
```

`macos/` and `ios/` are generated on the build host (Flutter cannot create the
macOS platform on Linux). On a Mac, run `tools/setup_macos.sh` once, then
`flutter build macos`.

To embed OAuth clients into a build, export them under the same names as the
keyring keys (`GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`,
`GRAPH_CLIENT_ID`, `GRAPH_TENANT`, `YANDEX_OAUTH_CLIENT_ID`,
`YANDEX_OAUTH_CLIENT_SECRET`) and pass them through `tools/oauth_dart_defines.sh`:

```bash
bash tools/oauth_dart_defines.sh --require > oauth-defines
defines=(); while IFS= read -r d; do defines+=("$d"); done < oauth-defines
flutter build apk --release --split-per-abi "${defines[@]}"
```

Only OAuth application identifiers go into the binary: a Google "Desktop" client
secret is not confidential by Google's definition, and a Microsoft public client
has no secret. User passwords, refresh tokens and Zoom keys are never embedded.
Anything embedded can still be extracted from the binary, so GitHub releases are
built without these variables.

## Project layout

```
lib/
  app/        app wiring, providers, keymap, account config
  domain/     models and provider interfaces
  data/       Drift cache, provider adapters, secure storage
  features/   UI (calendar grid, editor, settings, accounts, widget)
  services/   dedup, conference parsing, notifications
  sync/       sync engine (pull + outbox push)
bin/          agent CLI + provider probes
tools/        auth helpers, contacts export, setup scripts
```

## License

[MIT](LICENSE) © 2026 Ilia Karpov
