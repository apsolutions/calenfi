import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../data/local/db/database.dart' show ContactRow;
import '../../domain/models/attendee.dart';
import '../../domain/models/calendar.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/account.dart';
import '../../domain/models/conference.dart';
import '../../domain/models/enums.dart';
import '../../data/secure/credential_source.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/add_account_sheet.dart';
import '../calendar/calendar_state.dart';
import '../calendar/pending_edits.dart';
import 'conference_options.dart';
import 'recurrence_editor.dart';

/// Открытие редактора события как **диалога** (не на весь экран).
class EventEditor {
  static Future<void> open(
    BuildContext context, {
    CalendarEvent? existing,
    DateTime? initialDay,
    DateTime? initialStart,
    DateTime? initialEnd,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final narrow = MediaQuery.of(ctx).size.width < 520;
        final content = EventEditorScreen(
          existing: existing,
          initialDay: initialDay,
          initialStart: initialStart,
          initialEnd: initialEnd,
        );
        final body = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(ctx).pop(),
          },
          child: Focus(autofocus: true, child: content),
        );
        // На телефоне — полноэкранный диалог (надёжный layout); на десктопе —
        // компактное окно фиксированного размера.
        if (narrow) return Dialog.fullscreen(child: body);
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: 480, height: 660, child: body),
        );
      },
    );
  }
}

/// Содержимое редактора создания/редактирования события (FR-E1–E4, FR-E9),
/// поля по `docs/images/image.png`.
class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({
    super.key,
    this.existing,
    this.initialDay,
    this.initialStart,
    this.initialEnd,
  });

  final CalendarEvent? existing;
  final DateTime? initialDay;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;

  late bool _allDay;
  late DateTime _start;
  late DateTime _end;
  String? _calendarId;
  late ShowAs _showAs;
  late EventVisibility _visibility;
  ConferenceType? _conference;
  String? _conferenceAccountId; // УЗ-хост встречи
  late List<Attendee> _attendees;

  /// Правило повторения (RRULE без префикса, FR-E6). null — не повторять.
  String? _recurrenceRule;

  /// Контроллер поля ввода участника (из Autocomplete.fieldViewBuilder) —
  /// нужен, чтобы очистить строку после выбора из выпадающего списка.
  TextEditingController? _inviteeCtl;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _notes = TextEditingController(text: e?.description ?? '');
    _allDay = e?.allDay ?? false;
    final base = widget.initialDay ?? DateTime.now();
    _start =
        e?.startUtc.toLocal() ??
        widget.initialStart ??
        DateTime(base.year, base.month, base.day, 12, 0);
    _end =
        e?.endUtc.toLocal() ??
        widget.initialEnd ??
        _start.add(const Duration(hours: 1));
    _calendarId = e?.calendarId;
    _showAs = e?.showAs ?? ShowAs.busy;
    _visibility = e?.visibility ?? EventVisibility.defaultVis;
    _conference = e?.conference?.type;
    _conferenceAccountId = e?.conference?.accountId;
    _recurrenceRule = e?.recurrenceRule;
    // Переговорка (ресурс) — отдельная категория; из общего списка исключаем.
    _attendees = List.of(e?.people ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final calendarsValue = ref.watch(calendarsListProvider);
    final all = calendarsValue.value ?? const <Calendar>[];
    // Только видимые и доступные для записи календари: в скрытый или read-only
    // календарь событие создать нельзя (FR-A8).
    var cals = all.where((c) => c.visible && !c.readOnly).toList();
    if (cals.isEmpty) cals = all.where((c) => c.visible).toList();
    if (cals.isEmpty) cals = all;
    // A StreamProvider is initially AsyncLoading. Do not erase an existing
    // calendar selection during that frame: when several calendars arrive,
    // falling back to the first one would silently move the edited event.
    if (calendarsValue.hasValue &&
        (_calendarId == null || cals.every((c) => c.id != _calendarId))) {
      _applyCalendarSelection(cals.isNotEmpty ? cals.first.id : null, cals);
    }

    return Column(
      children: [
        // шапка диалога
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isNew ? l10n.edNewEvent : l10n.edEditEvent,
                  key: const ValueKey('event-editor-header-title'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              FilledButton(
                onPressed: cals.isEmpty ? null : () => _save(cals),
                child: Text(l10n.edDone),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              TextField(
                controller: _title,
                autofocus: _isNew,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitByEnter(cals),
                decoration: InputDecoration(hintText: l10n.edTitleHint),
                style: const TextStyle(fontSize: 18),
              ),
              TextField(
                controller: _location,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitByEnter(cals),
                decoration: InputDecoration(
                  hintText: l10n.edLocationHint,
                  icon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.edAllDay),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              _dateTimeRow(
                l10n.edStart,
                _start,
                (d) => setState(() {
                  _start = d;
                  if (_end.isBefore(_start)) {
                    _end = _start.add(const Duration(hours: 1));
                  }
                }),
              ),
              _dateTimeRow(l10n.edEnd, _end, (d) => setState(() => _end = d)),
              _recurrenceRow(),
              const Divider(height: 24),
              _calendarPicker(cals),
              _showAsRow(),
              _visibilityRow(),
              _conferenceRow(),
              const Divider(height: 24),
              _inviteesSection(),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.edNotesHint,
                  icon: const Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- invitees (FR-E9, FR-K3) ---
  Widget _inviteesSection() {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(l10n.edAttendees),
          ],
        ),
        const SizedBox(height: 6),
        if (_attendees.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final a in _attendees)
                InputChip(
                  label: Text(
                    a.displayName ?? a.email,
                    style: const TextStyle(fontSize: 12),
                  ),
                  avatar: _responseAvatar(a.response),
                  onDeleted: () => setState(() => _attendees.remove(a)),
                ),
            ],
          ),
        // автодополнение из справочника (FR-K3) + ручной ввод email
        Autocomplete<ContactRow>(
          optionsBuilder: (value) => _matchingContacts(value.text),
          displayStringForOption: (c) => '${c.displayName} <${c.email}>',
          onSelected: (c) {
            _addInviteeEmail(c.email, c.displayName);
            // Autocomplete проставляет в поле displayString ПОСЛЕ onSelected —
            // поэтому чистим на следующем кадре, иначе строка не очищается.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _inviteeCtl?.clear();
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            _inviteeCtl = controller;
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: l10n.edInviteeHint,
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      // Есть подсказки → Enter выбирает выделенную (onSubmit →
                      // onSelected добавит участника), затем чистим поле. Иначе,
                      // если введён «сырой» email — добавляем его вручную.
                      if (_matchingContacts(v).isNotEmpty) {
                        onSubmit();
                        controller.clear();
                      } else if (v.trim().contains('@')) {
                        _addInviteeEmail(v.trim(), null);
                        controller.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (controller.text.trim().contains('@')) {
                      _addInviteeEmail(controller.text.trim(), null);
                      controller.clear();
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Контакты справочника, подходящие под запрос (по имени или почте).
  /// Общий источник для подсказок Autocomplete и для выбора по Enter.
  /// Сортировка: по умолчанию по ЧАСТОТЕ использования (useCount ↓), при равной
  /// частоте — по алфавиту (имя ↑).
  Iterable<ContactRow> _matchingContacts(String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) return const <ContactRow>[];
    final contacts = ref.read(contactsStreamProvider).value ?? const [];
    final matched =
        contacts
            .where(
              (c) =>
                  c.displayName.toLowerCase().contains(q) ||
                  c.email.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            final byUse = b.useCount.compareTo(a.useCount);
            return byUse != 0
                ? byUse
                : a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  );
          });
    return matched;
  }

  void _addInviteeEmail(String email, String? name) {
    if (email.isEmpty || !email.contains('@')) return;
    if (_attendees.any((a) => a.email == email)) return;
    setState(() => _attendees.add(Attendee(email: email, displayName: name)));
    // Отметить частоту — в следующий раз этот контакт будет выше в подсказках.
    ref
        .read(contactRepositoryProvider)
        .bumpUse(email: email, displayName: name);
  }

  Widget? _responseAvatar(ResponseStatus r) {
    final (icon, color) = switch (r) {
      ResponseStatus.accepted => (Icons.check, Colors.green),
      ResponseStatus.declined => (Icons.close, Colors.red),
      ResponseStatus.tentative => (Icons.help_outline, Colors.orange),
      _ => (Icons.schedule, Colors.grey),
    };
    return CircleAvatar(
      backgroundColor: Colors.transparent,
      child: Icon(icon, size: 14, color: color),
    );
  }

  /// Повторение (FR-E6): диалог в стиле Outlook (см. recurrence_editor.dart).
  /// У экземпляра серии правило меняется только у мастера — строка заблокирована.
  Widget _recurrenceRow() {
    final l10n = L10n.of(context);
    final isInstance = widget.existing?.recurrenceId != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.repeat),
      title: Text(l10n.edRepeat),
      subtitle: Text(
        isInstance
            ? l10n.edSeriesInstance
            : describeRecurrence(context, _recurrenceRule),
      ),
      enabled: !isInstance,
      onTap: isInstance
          ? null
          : () async {
              final r = await showRecurrenceDialog(
                context,
                initial: _recurrenceRule,
                start: _start,
              );
              if (r == null) return; // отмена
              setState(() => _recurrenceRule = r.isEmpty ? null : r);
            },
    );
  }

  Widget _showAsRow() {
    final l10n = L10n.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.work_outline),
      title: Text(l10n.edShowAs),
      trailing: SegmentedButton<ShowAs>(
        segments: [
          ButtonSegment(value: ShowAs.busy, label: Text(l10n.edBusy)),
          ButtonSegment(value: ShowAs.free, label: Text(l10n.edFree)),
        ],
        selected: {_showAs},
        onSelectionChanged: (s) => setState(() => _showAs = s.first),
      ),
    );
  }

  Widget _visibilityRow() {
    final l10n = L10n.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.visibility_outlined),
      title: Text(l10n.edVisibility),
      trailing: DropdownButton<EventVisibility>(
        value: _visibility,
        onChanged: (v) => setState(() => _visibility = v!),
        items: [
          DropdownMenuItem(
            value: EventVisibility.defaultVis,
            child: Text(l10n.edVisDefault),
          ),
          DropdownMenuItem(
            value: EventVisibility.private,
            child: Text(l10n.edVisPrivate),
          ),
          DropdownMenuItem(
            value: EventVisibility.public,
            child: Text(l10n.edVisPublic),
          ),
        ],
      ),
    );
  }

  /// Опции видеовстречи: каждая привязанная УЗ, умеющая хостить встречу, +
  /// сервисы по токену. Telemost для Yandex CalDAV заводится
  /// самим календарём, поэтому показываем его для выбранной Yandex-УЗ
  /// даже без отдельного OAuth-токена.
  List<_ConfOption> _confOptions() {
    final accts = ref.watch(accountsStreamProvider).value ?? const <Account>[];
    final calendars =
        ref.watch(calendarsListProvider).value ?? const <Calendar>[];
    final creds = CredentialSource.load();
    final out = <_ConfOption>[];
    for (final a in accts) {
      if (a.provider == ProviderType.graph) {
        out.add(_ConfOption(ConferenceType.teams, a.id, a.email, 'Teams'));
      } else if (a.provider == ProviderType.google) {
        out.add(_ConfOption(ConferenceType.meet, a.id, a.email, 'Meet'));
      }
    }
    final nativeTelemostAccount = yandexTelemostAccountForCalendar(
      calendarId: _calendarId,
      calendars: calendars,
      accounts: accts,
    );
    if (nativeTelemostAccount != null) {
      out.add(
        _ConfOption(
          ConferenceType.telemost,
          nativeTelemostAccount.id,
          nativeTelemostAccount.email,
          'Telemost',
        ),
      );
    }
    if (creds.zoomClientId != null) {
      out.add(_ConfOption(ConferenceType.zoom, null, 'Zoom', 'Zoom'));
    }
    if (nativeTelemostAccount == null && creds.telemostToken != null) {
      out.add(
        _ConfOption(ConferenceType.telemost, null, 'Telemost', 'Telemost'),
      );
    }
    final existingConference = widget.existing?.conference;
    if (existingConference != null &&
        existingConference.isReady &&
        _conference == existingConference.type &&
        _conferenceAccountId == existingConference.accountId &&
        out.every(
          (option) =>
              option.type != existingConference.type ||
              option.accountId != existingConference.accountId,
        )) {
      // Keep an already attached/detected link visible even when its original
      // host account is unavailable. This is informational and does not turn
      // an external link into a request for a native meeting.
      out.add(
        _ConfOption(
          existingConference.type,
          existingConference.accountId,
          conferenceLabel(existingConference.type),
          '',
        ),
      );
    }
    return out;
  }

  Widget _conferenceRow() {
    final l10n = L10n.of(context);
    final opts = _confOptions();
    var selectedKey = _conference == null
        ? null
        : '${_conference!.name}|${_conferenceAccountId ?? ''}';
    // A detected/external meeting can have no corresponding configured host.
    // Show no selected option instead of silently treating it as a request for
    // a new native meeting in the currently selected Yandex calendar.
    if (selectedKey != null &&
        opts.every((option) => option.key != selectedKey)) {
      selectedKey = null;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // В desktop-диалоге доступно 448 dp после padding. На телефоне
        // dropdown переносим под заголовок, чтобы он не сжимал
        // «Видеовстреча» до одной буквы в строке.
        final compact = constraints.maxWidth < 420;
        final dropdown = DropdownButton<String?>(
          key: const ValueKey('event-editor-conference-dropdown'),
          isExpanded: true,
          value: selectedKey,
          hint: Text(l10n.edNone),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.edNone)),
            for (final o in opts)
              DropdownMenuItem(
                value: o.key,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (o.service.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${o.service}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (key) => setState(() {
            if (key == null) {
              _conference = null;
              _conferenceAccountId = null;
            } else {
              final o = opts.firstWhere((x) => x.key == key);
              _conference = o.type;
              _conferenceAccountId = o.accountId;
            }
          }),
        );
        final addButton = IconButton(
          tooltip: l10n.edConnectAccount,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => openAddAccount(context),
        );
        final label = Text(
          l10n.edConference,
          key: const ValueKey('event-editor-conference-label'),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );

        if (!compact) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.videocam_outlined),
            title: label,
            trailing: SizedBox(
              width: constraints.maxWidth * 0.5,
              child: Row(
                children: [
                  Expanded(child: dropdown),
                  addButton,
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.videocam_outlined),
                    ),
                  ),
                  Expanded(child: label),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Row(
                  children: [
                    Expanded(child: dropdown),
                    addButton,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _calendarPicker(List<Calendar> cals) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      final dropdown = DropdownButton<String>(
        key: const ValueKey('event-editor-calendar-dropdown'),
        isExpanded: true,
        value: cals.any((calendar) => calendar.id == _calendarId)
            ? _calendarId
            : null,
        onChanged: (v) =>
            setState(() => _applyCalendarSelection(v, cals)),
        items: [
          for (final c in cals)
            DropdownMenuItem(
              value: c.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(c.effectiveColor),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.effectiveName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
      final label = Text(
        L10n.of(context).edCalendar,
        key: const ValueKey('event-editor-calendar-label'),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      );

      if (!compact) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: label,
          trailing: SizedBox(
            width: constraints.maxWidth * 0.5,
            child: dropdown,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 40,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                Expanded(child: label),
              ],
            ),
            const SizedBox(height: 2),
            Padding(padding: const EdgeInsets.only(left: 40), child: dropdown),
          ],
        ),
      );
    },
  );

  void _applyCalendarSelection(String? calendarId, List<Calendar> calendars) {
    // Native Telemost belongs to the selected Yandex account. If the event is
    // moved to another provider/account, clear that choice rather than falling
    // through to the standalone API or sending a marker for the wrong account.
    if (_conference == ConferenceType.telemost &&
        _conferenceAccountId != null &&
        calendars
            .where((calendar) => calendar.id == calendarId)
            .every(
              (calendar) => calendar.accountId != _conferenceAccountId,
            )) {
      _conference = null;
      _conferenceAccountId = null;
    }
    _calendarId = calendarId;
  }

  Widget _dateTimeRow(
    String label,
    DateTime value,
    ValueChanged<DateTime> onChange,
  ) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null) {
                onChange(
                  DateTime(d.year, d.month, d.day, value.hour, value.minute),
                );
              }
            },
            child: Text('${two(value.day)}.${two(value.month)}.${value.year}'),
          ),
          if (!_allDay)
            TextButton(
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: value.hour,
                    minute: value.minute,
                  ),
                );
                if (t != null) {
                  onChange(
                    DateTime(
                      value.year,
                      value.month,
                      value.day,
                      t.hour,
                      t.minute,
                    ),
                  );
                }
              },
              child: Text('${two(value.hour)}:${two(value.minute)}'),
            ),
        ],
      ),
    );
  }

  /// Enter в однострочном поле → создать/применить (как кнопка «Готово»).
  /// В многострочных «Заметках» и поле участников Enter не сюда — там свой смысл.
  void _submitByEnter(List<Calendar> cals) {
    if (cals.isNotEmpty) _save(cals);
  }

  Future<void> _save(List<Calendar> cals) async {
    final cal = cals.firstWhere(
      (c) => c.id == _calendarId,
      orElse: () => cals.first,
    );
    final existing = widget.existing;

    Conference? conf = existing?.conference;
    if (_conference == null) {
      conf = null;
    } else if (conf?.type != _conference ||
        conf?.accountId != _conferenceAccountId) {
      // «Ожидающая» — реальную встречу заведёт ConferenceProvisioner при пуше
      // Outbox от выбранной УЗ (_conferenceAccountId): Teams/Meet/Zoom/Telemost.
      conf = Conference.pending(_conference!, accountId: _conferenceAccountId);
    }

    // Переговорка (если задана) — ресурс-участник, добавляем к людям.
    final attendees = List.of(_attendees);

    final event = CalendarEvent(
      id: existing?.id ?? '',
      calendarId: cal.id,
      title: _title.text.trim().isEmpty
          ? L10n.of(context).edUntitled
          : _title.text.trim(),
      startUtc: _start.toUtc(),
      endUtc: _end.toUtc(),
      timeZoneId: existing?.timeZoneId ?? 'Europe/Moscow',
      allDay: _allDay,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      description: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      attendees: attendees,
      recurrenceRule: _recurrenceRule,
      recurrenceId: existing?.recurrenceId,
      myResponse: existing?.myResponse ?? ResponseStatus.organizer,
      showAs: _showAs,
      visibility: _visibility,
      reminders: existing?.reminders ?? const [],
      conference: conf,
      source: EventSource(
        accountId: cal.accountId,
        calendarId: cal.id,
        providerEventId: existing?.source.providerEventId,
        etag: existing?.source.etag,
      ),
    );

    // Как перенос/ресайз — через отложенную отправку: правка видна сразу, в
    // облако уходит по таймеру (commitDelay) или по кнопке «В облако» сверху;
    // «Отменить» вернёт исходное (для нового — удалит).
    final delay = ref.read(commitDelayProvider);
    final pending = ref.read(pendingEditsProvider.notifier);
    if (_isNew) {
      await pending.stage(event.withId(const Uuid().v4()), delay, op: 'create');
    } else {
      await pending.stage(event, delay, op: 'update', original: existing);
    }
    if (mounted) Navigator.pop(context);
  }
}

/// Опция поля «Видеовстреча»: сервис + УЗ-хост или сам standalone-сервис.
/// [account] — что показываем крупно (адрес УЗ или имя сервиса).
class _ConfOption {
  const _ConfOption(this.type, this.accountId, this.account, this.service);
  final ConferenceType type;
  final String? accountId;
  final String account;
  final String service;
  String get key => '${type.name}|${accountId ?? ''}';
}
