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
- **Reminders & widget** — local notifications and a home-screen agenda widget
  on Android.
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
  Requires an OAuth client to be configured — see below.
- **Yandex (CalDAV) / Exchange (EWS)** — enter your e-mail and an **app
  password** (not your main password).

### OAuth client configuration

Google/Microsoft sign-in needs your own OAuth client id (the app ships without
one). Store the values in the keyring via the CLI:

```bash
# Google (OAuth client of type "Desktop")
tools/calenfi secret-set --key GOOGLE_OAUTH_CLIENT_ID     --value "…apps.googleusercontent.com"
tools/calenfi secret-set --key GOOGLE_OAUTH_CLIENT_SECRET --value "…"
# Microsoft (Azure app registration, platform "Mobile and desktop",
# redirect http://localhost)
tools/calenfi secret-set --key GRAPH_CLIENT_ID --value "…"
tools/calenfi secret-set --key GRAPH_TENANT    --value "common"
```

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
