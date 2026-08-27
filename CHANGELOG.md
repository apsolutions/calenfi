# Changelog

All notable changes to Calenfi are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] — 2026-08-27

### Changed
- **Application identifier unified to `ru.apsolutions.calenfi`** across all
  platforms — Android `applicationId`/namespace, Linux `APPLICATION_ID`, macOS
  bundle id and Windows `CompanyName` (`apsolutions`). This relocates the
  per-user data directory accordingly (e.g. `~/.local/share/ru.apsolutions.calenfi`
  on Linux); a build with the previous id will not upgrade over this one.

### Fixed
- Windows/desktop app icon now ships the current **Vitruvian 'C'** artwork in
  released builds (the new icon landed after v0.3.0 and had never been packaged).

### Added
- Agent CLI: `--all-day` for `create`/`update`, primary-calendar targeting for
  `--account`, and lazy keyring access (secrets read only by commands that need
  them).

## [0.3.0] — 2026-07-25

### Added
- **Interface localization** in six languages — English, Russian, Spanish,
  German, Chinese, French — with a **Settings → Language** switcher (system
  default + the six languages, persisted per device). ~230 strings across the
  calendar, settings, accounts, event editor, event details, recurrence and
  status screens. Dates (period title, event schedule) are now formatted per
  locale via `intl`.
- **Zoom (Server-to-Server OAuth)** video conferences: choose Zoom in an event
  to create a real meeting; deleting the event also deletes the Zoom meeting
  (when the delete scope is granted).

### Changed
- Video-conference field lists the host **account** (email) + service with a
  (+) to connect one; the meeting is created from the chosen account.
- Attendee suggestions sort by usage frequency, then alphabetically.
- Removed the separate meeting-room field.

### Fixed
- Exchange (EWS) delete tolerates "already deleted" so it can't stick forever;
  a **manual sync resets outbox retry counters**, so edits that failed under a
  since-fixed credential re-push instead of staying stuck.

## [0.2.1] — 2026-07-25

### Added
- **Yandex Telemost** video conferences: create a real meeting link via the
  Telemost API. Connect once in Accounts → Add → Telemost (Yandex OAuth); needs
  a Yandex app with "Telemost API" access.

### Changed
- **Add-account is now a full screen**, not a cramped bottom sheet. Password
  providers (Yandex / Exchange) get a proper form screen with a busy indicator,
  and the account is saved immediately while the first sync runs in the
  background — so connecting no longer looks like "nothing happened".
- **Real app icon** on every platform (Android adaptive icon, macOS app icon,
  Windows `.ico`, Linux hicolor icon + `.desktop`) instead of the default
  Flutter logo.

## [0.2.0] — 2026-07-25

### Added
- **In-app account connection** (no more manual config files): a real "Add
  account" flow — Google and Microsoft 365 sign in through the browser
  (OAuth 2.0 authorization-code + PKCE via a loopback redirect, works on
  desktop and mobile), Yandex (CalDAV) and Exchange (EWS) use an app-password
  form. Accounts persist to `accounts.json`, credentials to the OS keyring;
  removing an account cleans both.
- **Exchange (EWS) write support**: create / update / delete events and RSVP
  (Accept / Decline / Tentative) via EWS SOAP — previously read-only.

### Fixed
- **No more silently lost edits.** Failed outbox pushes used to retry forever
  with no user feedback (`retryCount` was written but never read). Now a
  permanent error (unsupported op) or an exhausted retry budget marks the
  account with a sync error instead of pretending the change was saved.
- **Provider capabilities are enforced in the UI.** RSVP controls no longer
  appear for providers that don't support them (e.g. CalDAV), so a tap can't
  fail silently.

### Tests
- Loopback OAuth flow (PKCE params, code exchange, CSRF/state check), outbox
  failure surfacing, and provider-capability gating.

## [0.1.1] — 2026-07-23

### Added
- **Recurring events**: Outlook-style recurrence editor (daily/weekly/monthly/
  yearly, every-N interval, weekday picks, Nth-weekday-of-month, end:
  never / after N occurrences / by date). Providers now send recurrence on
  create/update — Google and CalDAV as RRULE, Microsoft Graph via a
  patternedRecurrence converter.
- CLI: `--rrule` on `create`, new `secret-set` command for storing provider
  credentials (e.g. Zoom Server-to-Server OAuth keys) in the OS keyring.

### Fixed
- CalDAV: event ids are now calendar-scoped. Servers like Yandex place one
  invitation (one UID) into several collections; the copies used to collide on
  one row and an event could vanish from the grid when a hidden calendar's
  copy overwrote the visible one.
- Desktop gestures: trackpad two-finger scroll no longer accidentally moves,
  resizes or draws events (trackpad uses long-press-to-drag); mouse click-drag
  works as before.
- The sync button now flushes **all** pending edits to the outbox before a
  single sync pass — previously only the first moved event was pushed.
- Cross-account create guard hardened (engine and CLI): an event queued for
  one account can neither be created in another account's calendar nor be
  silently dropped from the outbox by another account's sync pass.

### Tests
- Regression suite covering each of the above (77 tests), including widget
  tests pinning the trackpad-vs-mouse gesture contract; grid tests made
  independent of timezone and time of day.

## [0.1.0] — 2026-07-22

First public release.

### Added
- Local-first calendar aggregator for **macOS, Linux, Windows and Android**.
- Providers: **Google Calendar**, **Microsoft 365 (Graph)**, **Yandex (CalDAV)**
  and self-hosted **Exchange (EWS)** — merged into one reactive grid.
- Day / week / month views with drag-to-move and edge-resize (desktop),
  long-press-to-move (touch and trackpad).
- Deduplication of identical events across calendars, with a toggle to keep
  each copy separate.
- Conference provisioning (Teams / Meet / Zoom / Telemost) decoupled from the
  host calendar.
- Per-calendar visibility, colour and default reminder overrides.
- Local reminders and a home-screen agenda widget (Android).
- Agent-facing JSON CLI (`tools/calenfi`) for reading/creating/updating events.
- Secrets (app passwords, OAuth tokens) stored in the **OS keyring**
  (libsecret / Keychain / DPAPI), with an encrypted-at-rest file fallback and
  `flutter_secure_storage` on mobile.

[Unreleased]: https://github.com/karpovilia/calenfi/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/karpovilia/calenfi/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/karpovilia/calenfi/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/karpovilia/calenfi/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/karpovilia/calenfi/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/karpovilia/calenfi/releases/tag/v0.1.0
