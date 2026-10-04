# Changelog

All notable changes to Calenfi are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.21] — 2026-10-04

### Fixed
- Exchange (EWS) meetings came without attendees. FindItem does not return
  them, and the follow-up GetItem asked only for the body, so a meeting with
  invitations that had actually been sent looked as if nobody was invited.
  GetItem now also asks for the organizer, required and optional attendees and
  resources, with each person's response; legacy Exchange addresses without
  an SMTP form are skipped.

## [0.3.20] — 2026-10-03

### Changed
- One notes field instead of two. The editor's **Notes** field is now the
  private meeting note (it used to edit the event description, which goes to
  attendees), and the separate "My notes" field in the event card is gone:
  the card shows the note read-only and it is edited in the event editor. The
  editor no longer edits the provider's description and keeps it unchanged
  when saving.

## [0.3.19] — 2026-10-03

### Added
- Meeting notes sync between devices through Google Tasks. Each note becomes
  a task in a private list "Calenfi · заметки к встречам" of the user's
  Google account: the meeting title and time as the task title, the note as
  its text, and a service line with the keys that let Calenfi on another
  device recognise the meeting. Google Tasks are private, so attendees still
  never see the notes. Sync runs at start, a few seconds after an edit, every
  five minutes, on return to the screen and in the Android background job;
  the latest edit wins, and a note edited directly in Google Tasks comes back
  to Calenfi. Settings show which account carries the notes.
- Signing in to Google now also asks for access to Google Tasks. An account
  connected earlier keeps working; reconnect it once on each device to turn
  notes sync on. A token with Tasks access stored under the Tasks key of the
  tt app is picked up as well.
- CLI: `notes-sync`; `note` pulls before reading and pushes after writing.

### Changed
- Notes are stored one row per note with sync metadata. Notes written with
  0.3.18 move over on first start and are uploaded on the first sync.

## [0.3.18] — 2026-10-03

### Added
- Private notes for a meeting. The event card has a **My notes** field for the
  agenda, questions and things to prepare. The note stays in Calenfi's local
  database: it is never written to the provider's event and attendees never
  see it. It is saved as you type, follows the meeting across all merged
  copies and survives a reschedule, and a small note icon marks such meetings
  in the grid. The agent CLI reads and writes notes with
  `calenfi note --id ID [--set TEXT | --clear]`, and `agenda` includes them.
  Notes are not synced between devices yet.

### Changed
- The copy shown on top of a merged meeting is now the one from the calendar
  my account was invited to. Before, the first copy by id won, so an interview
  with a booked room showed up as "Room booking calendar" and an invitation
  could appear under a read-only subscription. The account's own main
  calendar ranks first, then a calendar whose account is among the attendees
  or organizes the meeting; read-only calendars and declined copies rank last.

### Fixed
- After the computer woke from sleep the desktop app showed "not updated: no
  network" for half a minute: the first sync ran before Wi-Fi reconnected. A
  late timer tick now marks a wake-up, and network failures in the following
  two minutes are retried silently instead of being shown.

## [0.3.17] — 2026-10-01

### Added
- Background sync on Android. Android freezes an app about a minute after it
  leaves the screen and cuts its network, so the in-app timer never ran in the
  background: meetings were only as fresh as the last time Calenfi was open,
  and the home-screen widget and reminders went stale with them. A system job
  (WorkManager) now wakes the app every 15 minutes when there is a network,
  syncs the accounts whose interval has passed, redraws the widget and
  reschedules reminders. It is scheduled on launch, after an update and after
  a reboot.

### Fixed
- Opening the app after a pause showed "not updated: no network" although the
  account and the network were fine: a sync attempted while the app was frozen
  in the background failed on DNS and was recorded as the account's status. A
  "host not found" failure while the app is off screen no longer changes the
  account status.
- While a sync is running and no account has failed, the status in the top bar
  shows the sync icon without the red "!" instead of "3/5 !".

## [0.3.16] — 2026-10-01

### Fixed
- An Office 365 account kept failing with "sync exceeded the time limit" and
  showed stale meetings. Since attachments arrived in 0.3.11, every sync pass
  asked Graph for the file list of each occurrence flagged `hasAttachments`,
  one request at a time. A weekly series with a file, expanded a year ahead,
  alone costs dozens of requests; a work calendar with about 190 such
  occurrences needed 155 seconds per pass against a 150-second limit. A pass
  now asks once per series (an exception still has its own list), runs a few
  requests at a time and reuses the answer until the event changes. The same
  account now syncs in about a minute, and later passes make no attachment
  requests at all.
- Sync passes piled up. The 150-second limit released the per-account guard
  while the pass itself kept running, so the one-minute timer started another
  pass on top of it, and another, each slowing the rest down. A pass now
  holds the guard until it really ends: callers stop waiting after 150
  seconds, the account is marked as failed only after 15 minutes, and the
  sync indicator stays on while work is still going.
- The diagnostics log no longer goes to the CLI's stdout, where it broke the
  JSON answer of `calenfi sync`.

## [0.3.15] — 2026-10-01

### Added
- A diagnostics log. Settings → Diagnostics → Event and error log shows what
  the app did and where it failed: every sync attempt with the full error text
  and the top of the stack, token refreshes rejected by Google or Microsoft
  with the provider's own explanation, each step of a browser sign-in, app
  lifecycle changes and unhandled errors. The log is kept in `calenfi.log`
  next to the app data, can be copied in one tap, and never contains tokens,
  codes or passwords. Until now a failed account left 200 characters of error
  text and nothing else.
- The page the browser shows after a sign-in has a **Back to Calenfi** button
  on Android and tries to return to the app by itself.
- The app version is shown in Settings → About.

### Changed
- The row of days above the week and day grids is one line now: "MON 28"
  instead of the weekday stacked over the number. It takes 30 points instead
  of 56, and the weekday follows the app language in the week view too.

### Fixed
- An account dropped back to "reconnect" a few minutes after a successful
  sign-in and stayed that way until the app was restarted. Reconnecting
  rebuilds the sync engine, but the background sync kept the engine it was
  created with, together with the old (missing or revoked) credentials, and
  overwrote the fresh status on its next run. Background sync now takes the
  current engine every time.
- Signing in on Android hung on the provider's last page ("Are you trying to
  sign in to Calenfi?") when typing the password took more than about a
  minute. The browser's answer is received by a local server inside the app,
  and Android freezes an app that sits behind the browser. The app now holds a
  foreground service for the duration of a sign-in, which keeps it running.

## [0.3.14] — 2026-10-01

### Added
- Foldable phones. A Galaxy Z Fold 7 gives one app two screens: a 411-point
  cover screen and a 750-point inner screen. The inner screen now has its own
  top bar: arrows, a "today" button and the period title on the left, search
  behind a magnifier button that turns the whole row into the search field,
  then the view switcher, sync status and settings.
- Each screen remembers its own view. Unfolding the phone switches to the week
  (or to whatever was last used on the inner screen), folding it back returns
  to the day. Desktop windows are left alone when resized.

### Fixed
- On the inner screen of a foldable the desktop top bar did not fit: the search
  field shrank to nothing and the settings button slid off the right edge, so
  accounts could not be reached at all. With unsent edits and a failed account
  the row was 240 points too wide.
- Unsent edits were shown inside the top bar from a width of 720 points, where
  there is no room for them. They now move into the bar only from 1200 points
  and stay on their own strip below that.
- The home-screen widget could not be stretched beyond 360 points, half the
  width of a foldable's inner home screen. The limit is gone.
- The event editor opened as a 660-point-tall window on a screen 411 points
  tall (the cover screen held sideways). Low screens get the full-screen editor.
- In a window narrower than 360 points (pop-up view) the "today" button slid
  under the view switcher and the unsent-edits counter wrapped into a column
  three letters wide.

## [0.3.13] — 2026-09-30

### Fixed
- The home-screen widget dropped occurrences of repeating meetings from
  today's agenda. Duplicate detection treated a shared iCalendar UID as proof
  of one meeting, but every occurrence of a series carries the same UID; over
  the widget's year-long range a whole series collapsed into one group whose
  representative fell on another day, so today's occurrence vanished. A shared
  UID now joins copies only when their starts are less than 12 hours apart, so
  the week and month views also keep each day of a daily series.
- Opening the app after a while left accounts on "offline" with stale meetings
  for up to a minute. Android battery saver cuts network access for apps in
  the background, so background syncs fail; the app now syncs every overdue
  account as soon as it returns to the screen instead of waiting for the
  next one-minute tick.

## [0.3.12] — 2026-09-21

### Fixed
- An Office 365 account stopped syncing with `invalid_grant` about a day after
  every sign-in. Entra issues a fresh refresh token on every refresh and
  retires the previous one roughly 24 hours later; Calenfi kept using the one
  it was first given and never stored the new one. A rotated refresh token is
  now accepted and written back to the keyring, for Microsoft and for Google
  alike.

## [0.3.11] — 2026-09-21

### Added
- Attachments. An event now carries the files a provider attached to it, and
  the details card lists them under **Attachments**: an icon by file type, the
  file name, its size when known, and a tap that opens the file in the cloud.
  Sources: `ATTACH` in CalDAV (`FMTTYPE`, `FILENAME`/`X-FILENAME`, `SIZE`),
  `attachments` in Google Calendar, and the attachment list of an Office 365
  event, fetched only for events whose `hasAttachments` is set. Inline
  (`VALUE=BINARY`) attachments are skipped on purpose: the file would bloat the
  local database and there is nothing to open.
- Database schema 9: the new `attachments_json` column on events.

## [0.3.10] — 2026-09-20

### Fixed
- The recurrence of a repeating event could not be changed at all. Opening an
  occurrence — which is what the calendar shows — greyed out the **Repeat**
  row, and editing the whole series deliberately dropped the rule before
  sending it, so the only way to change "every week" into "every two weeks"
  was to delete the series and create it again. The row now opens from an
  occurrence too, and a changed rule goes to the series master: Google gets a
  new `RRULE`, Office 365 a new `patternedRecurrence`, CalDAV a rewritten
  `RRULE` in the master `VEVENT`. Exchange has no master to edit, so it now
  refuses with a clear message instead of silently ignoring the change.
- The recurrence dialog did not fit a phone screen: a fixed width of 380
  points and non-wrapping rows pushed it off the right edge.

## [0.3.9] — 2026-09-20

### Changed
- Phone layout of the date header. The day view spent a whole 57-pixel row on a
  weekday and a day number ("MON 21") while the top bar showed the same date
  clipped to "MON, 2…". The row is gone; a single full-width line under the top
  bar now carries weekday, day, month and year, and the top bar keeps a
  "today" button in its place.
- That line is also a control: tapping the day part opens the week, tapping the
  month part opens the month.
- Tapping a day in the month grid opens the day view on a phone, where a cell
  shows only a couple of events. On a wide screen the month view stays and only
  the focused day changes.

## [0.3.8] — 2026-09-18

### Fixed
- Connecting or reconnecting an Office 365 account failed right after the
  browser said "Done": Calenfi looked up the mailbox address with Graph `/me`,
  which needs the `User.Read` permission Calenfi does not request, so Graph
  answered 403 and the new token was never saved. The address now comes from
  the `id_token` returned with the sign-in (`email`, else
  `preferred_username`), with `/me` kept only as a fallback.
- Matching a reconnected mailbox to the existing account ignores letter case,
  so a differently capitalised address no longer creates a second account.

## [0.3.7] — 2026-09-17

### Added
- **Reconnect** for an account whose sign-in a provider has revoked
  (`invalid_grant`): in the account menu and right next to the error. It runs
  the browser sign-in for the same mailbox and replaces the token, keeping the
  account, its calendars and its settings. Signing in with a different mailbox
  is refused instead of quietly adding a second account. Until now the only way
  back was **Add account**, which reads as adding a new one.

## [0.3.6] — 2026-09-15

### Fixed
- Typing in the search box no longer triggers keyboard shortcuts. Shortcuts
  without modifiers (R — sync, H, 1/2/3, arrows, N, T) used to fire while a text
  field had focus, so typing "r" started a sync; they now stay off whenever a
  text field is focused.
- A queued delete without an explicit scope removed only one occurrence of a
  recurring event instead of the whole series: the payload parser turned a
  missing `scope` into `thisOnly`.
- Agent CLI (`tools/calenfi`): `delete` and `update` accept
  `--scope this|following|all`; deleting an occurrence of a recurring event now
  requires it. The CLI used to delete the whole series when it pushed the job
  itself, while the app deleted one occurrence.
- Agent CLI: a write command pushes only the job it has just queued and reports
  the result in `pushed`. It used to retry the whole Outbox on every run and
  count each failure, so after five runs without keyring access the app's
  background sync skipped those jobs.

## [0.3.5] — 2026-09-13

### Added
- A build without an OAuth client now says so on **Add account** and lets you
  enter your own client, which is stored in the device keyring. Public GitHub
  releases ship without OAuth clients on purpose: anything embedded in a binary
  can be extracted from the download.
- Private builds can embed OAuth clients at build time from environment
  variables (`tools/oauth_dart_defines.sh` → `--dart-define`); a client stored
  in the keyring still wins over the embedded one.

- macOS gets two WidgetKit widgets embedded in the app bundle: **Calenfi —
  сегодня** (agenda for the current day) and **Calenfi — календарь** (a
  translucent month grid that pages through months inside the widget itself,
  with a dot on every day that has events). The app writes a snapshot to
  `widget_snapshot.json` in the config directory; the extension reads it, so the
  widgets work offline and without network access of their own.

- Editing an occurrence of a recurring event now asks what to change — this
  occurrence or the whole series — for drag, resize and the editor alike. The
  choice travels to the provider: Google/Graph patch either the occurrence or
  the series master, CalDAV rewrites either the RECURRENCE-ID exception or the
  master. A series is shifted by the same delta as the occurrence, so moving one
  meeting 15 minutes later no longer moves the series onto that date.

### Fixed
- Creating a recurring series no longer leaves a ghost event. Providers answer
  `create` with the series master while reading returns expanded occurrences, so
  the master used to stay behind as a second meeting next to the first
  occurrence — and dragging it silently rescheduled every occurrence. Existing
  ghosts are removed on the next sync.
- The Android APK from GitHub could not add a Google or Microsoft account: it
  showed "complete sign-in in the browser that opened…", but no browser opened
  because the release carried no OAuth client, and the error was hidden. Sign-in
  now asks for a client up front; results and errors
  appear immediately instead of queueing behind that ten-second hint, a second
  sign-in cannot start while one is waiting for the browser, and the Android
  manifest declares visibility of https browsers for Android 11+.

## [0.3.4] — 2026-09-03

### Added
- A selected Yandex Calendar account can now create a Telemost meeting
  natively through Yandex's CalDAV extension. This includes Yandex 360
  organisation addresses on custom domains and does not require a separate
  Telemost OAuth connection.

### Fixed
- CI and release builds now fail before publication unless every native runner
  uses the canonical `ru.apsolutions.calenfi` identity; Android APK manifests
  are verified again after compilation.
- Linux and Windows now discover healthy databases and account state in
  retired application/vendor support directories without relying on embedded
  historical identifiers. Discovery is limited to the known support-directory
  depth, and canonical data remains authoritative.
- The Calendar and Video meeting rows no longer collapse or wrap one letter
  per line in the mobile event editor. Long calendar/account names are
  ellipsized, while the desktop dialog keeps its horizontal layout.
- The selected conference host account now survives a local database
  round-trip, so a deferred sync provisions the meeting with the intended
  account.
- An edited event keeps its original calendar while calendar data is still
  loading instead of silently falling back to the first calendar.
- Existing Yandex Telemost URLs are recognised from CalDAV and are not
  duplicated in the description during later edits.
- An external Telemost link in an event description is no longer mistaken for
  a request to create a new native Yandex meeting.
- Standalone Telemost creation uses Yandex's current documented API endpoint.

## [0.3.3] — 2026-09-02

### Fixed
- Android release builds now declare the `INTERNET` permission in the main
  manifest. This restores Office 365 and all other network calendar sync in
  GitHub-built APKs; debug/profile builds were not affected.
- Connection timeouts, server refusals, and TLS failures are no longer
  mislabeled as a device-wide lack of network. The Accounts screen now shows
  the stored error detail for an unhealthy account.

## [0.3.2] — 2026-09-02

### Added
- Day view columns now show the localized weekday and calendar date above the
  timeline.

### Fixed
- Linux, Android and Windows now consistently display **Calenfi** and use the
  canonical `ru.apsolutions.calenfi` desktop/application identity.
- On Linux, a database from a supported legacy application id is migrated with
  SQLite's online backup on
  first launch. The source database is retained as a rollback copy, and both
  the GUI and agent CLI resolve the same canonical path.
- An incomplete system-keyring record is now repaired once from the retained
  fallback store, restoring Exchange settings such as a known EWS endpoint
  without allowing deleted secrets to reappear or copying keyring-only secrets
  back to plaintext.
- The calendar header no longer presents the oldest failed account timestamp as
  if every account stopped syncing; partial health is shown as a fresh-account
  count while the existing health banner identifies the failing account.
- CalDAV always performs a full REPORT even when a server's collection tag is
  unchanged, so deletions made by another client are reconciled locally.
- CalDAV writes preserve the server resource href, send the original RFC UID
  instead of a Calenfi-scoped local id, and require successful per-resource
  multistatus responses. This stops repeated account/calendar prefixes from
  growing when an event is moved repeatedly between Windows and Calenfi.
- CalDAV create/update/delete operations use HTTP preconditions, and outbox
  entries are retargeted atomically when a legacy local id is canonicalized.
  Existing duplicate server resources are collapsed deterministically for the
  local view but are not mutated automatically during a normal sync.
- Explicit deletion now removes every server resource in a canonical legacy
  UID family, so an older prefixed copy cannot reappear after the winner is
  deleted. Retried creates recover idempotently when the original successful
  response was lost and the server answers `412 Precondition Failed`.
- Recurring CalDAV edits merge only the selected master or `RECURRENCE-ID`
  exception into the existing resource, preserving sibling exceptions,
  `EXDATE`/`RDATE`, alarms and vendor fields; pull no longer duplicates moved
  occurrences.
- A failed or conflicting outbound edit is protected from the following pull,
  tombstone and full-window reconciliation. Remote ETag/resource metadata is
  still refreshed, allowing a later retry to apply the local edit without
  silently replacing it with the server's older payload.
- App-id migration now validates complete Windows state profiles and selects
  SQLite sources using application timestamps plus DB/WAL/SHM freshness,
  avoiding stale databases and newer-but-corrupt credential files.
- Meeting links now have a permanently visible 48 dp copy action on mobile,
  where the desktop hover-only control was unreachable, without overflowing on
  narrow phone screens.
- The Android agenda widget keeps a rolling event snapshot and schedules a
  refresh just after local midnight, so it advances to the new day even while
  Calenfi is closed and continues to handle time-zone and clock changes.
- The red current-time line uses one lifecycle-aware, wall-clock-aligned timer:
  it refreshes immediately after sleep or resume instead of remaining behind
  real time, and follows midnight without moving a deliberately browsed date.

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

[Unreleased]: https://github.com/apsolutions/calenfi/compare/v0.3.4...HEAD
[0.3.4]: https://github.com/apsolutions/calenfi/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/apsolutions/calenfi/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/apsolutions/calenfi/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/apsolutions/calenfi/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/apsolutions/calenfi/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/apsolutions/calenfi/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/apsolutions/calenfi/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/apsolutions/calenfi/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/apsolutions/calenfi/releases/tag/v0.1.0
