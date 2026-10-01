import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/version.dart';
import '../../app/locale_provider.dart';
import '../../app/providers.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/calendar.dart';
import '../../domain/models/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../services/maps_service.dart';
import '../accounts/accounts_screen.dart';
import '../calendar/calendar_state.dart';
import 'diag_log_screen.dart';

/// Экран всех настроек. Подмножество настроек Fantastical
/// (см. docs/fantastical-settings-reference.md), включая выбор активных
/// календарей («Calendars & Lists»).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).setTitle)),
        body: const SettingsPanel(),
      );
}

/// Тело настроек без Scaffold — переиспользуется как полный экран и как боковая
/// панель (endDrawer) на десктопе, чтобы не закрывать календарь целиком.
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final combine = ref.watch(combineProvider);
    final showCancelled = ref.watch(showCancelledProvider);
    final showMonth = ref.watch(showMonthViewProvider);
    final accounts = ref.watch(accountsStreamProvider).value ?? const <Account>[];
    final calendars =
        ref.watch(calendarsStreamProvider).value ?? const <Calendar>[];

    return ListView(
        children: [
          // ───────── Активные календари (Fantastical «Calendars & Lists») ──────
          _SectionHeader(l10n.setCalendars),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.setCalendarsSubtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          for (final acc in accounts)
            _AccountCalendars(
              account: acc,
              calendars: calendars.where((c) => c.accountId == acc.id).toList(),
            ),
          if (accounts.isEmpty)
            ListTile(dense: true, title: Text(l10n.setNoAccounts)),

          const Divider(),
          _SectionHeader(l10n.setView),
          SwitchListTile(
            title: Text(l10n.setShowMonth),
            subtitle: Text(l10n.setShowMonthSubtitle),
            value: showMonth,
            onChanged: (v) =>
                ref.read(showMonthViewProvider.notifier).state = v,
          ),
          const Divider(),
          _SectionHeader(l10n.setEvents),
          SwitchListTile(
            secondary:
                Icon(combine ? Icons.layers : Icons.layers_clear_outlined),
            title: Text(l10n.setCombine),
            subtitle: Text(l10n.setCombineSubtitle),
            value: combine,
            onChanged: (v) => ref.read(combineProvider.notifier).state = v,
          ),
          SwitchListTile(
            secondary: Icon(showCancelled
                ? Icons.event_busy
                : Icons.event_busy_outlined),
            title: Text(l10n.setShowCancelled),
            subtitle: Text(l10n.setShowCancelledSubtitle),
            value: showCancelled,
            onChanged: (v) =>
                ref.read(showCancelledProvider.notifier).state = v,
          ),
          ListTile(
            title: Text(l10n.setCommitDelay),
            subtitle: Text(l10n.setCommitDelaySubtitle),
            trailing: DropdownButton<int>(
              value: ref.watch(commitDelayProvider).inMinutes,
              onChanged: (m) => ref.read(commitDelayProvider.notifier).state =
                  Duration(minutes: m ?? 0),
              items: [
                DropdownMenuItem(value: 0, child: Text(l10n.setDelayImmediate)),
                DropdownMenuItem(value: 1, child: Text(l10n.setDelayMinutes(1))),
                DropdownMenuItem(value: 2, child: Text(l10n.setDelayMinutes(2))),
                DropdownMenuItem(value: 5, child: Text(l10n.setDelayMinutes(5))),
              ],
            ),
          ),

          const Divider(),
          _SectionHeader(l10n.setMaps),
          ListTile(
            title: Text(l10n.setOpenPlacesIn),
            subtitle: Text(l10n.setMapsSubtitle),
            trailing: const _MapsDropdown(),
          ),

          const Divider(),
          _SectionHeader(l10n.setAccounts),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l10n.setAccountsAndConnections),
            subtitle: Text(l10n.setAccountsConnected(accounts.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),

          const Divider(),
          _SectionHeader(l10n.setDiagnostics),
          ListTile(
            key: const ValueKey('settings-diag-log'),
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(l10n.setDiagLog),
            subtitle: Text(l10n.setDiagLogSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiagLogScreen())),
          ),

          const Divider(),
          _SectionHeader(l10n.setLanguage),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.setLanguage),
            trailing: DropdownButton<String?>(
              value: ref.watch(localeProvider)?.languageCode,
              onChanged: (v) => ref
                  .read(localeProvider.notifier)
                  .set(v == null ? null : Locale(v)),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(l10n.setLanguageSystem)),
                for (final code in LocaleNotifier.supported)
                  DropdownMenuItem(
                      value: code, child: Text(languageName(code))),
              ],
            ),
          ),

          const Divider(),
          _SectionHeader(l10n.setAbout),
          ListTile(
            title: const Text('Calenfi $kAppVersion'),
            subtitle: Text(l10n.setAboutSubtitle),
          ),
        ],
      );
  }
}

/// Группа «аккаунт + его календари» с чекбоксами видимости и «выбрать все».
class _AccountCalendars extends ConsumerWidget {
  const _AccountCalendars({required this.account, required this.calendars});
  final Account account;
  final List<Calendar> calendars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final repo = ref.read(accountRepositoryProvider);
    final visibleCount = calendars.where((c) => c.visible).length;
    final bool? groupValue = calendars.isEmpty
        ? false
        : visibleCount == calendars.length
            ? true
            : visibleCount == 0
                ? false
                : null;

    Future<void> setAll(bool v) async {
      for (final c in calendars) {
        await repo.setCalendarVisible(c.id, v);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // заголовок аккаунта + tristate «выбрать все»
        InkWell(
          onTap: calendars.isEmpty ? null : () => setAll(!(groupValue ?? false)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Checkbox(
                  tristate: true,
                  value: groupValue,
                  onChanged: calendars.isEmpty
                      ? null
                      : (_) => setAll(!(groupValue ?? false)),
                ),
                Icon(_providerIcon(account.provider),
                    size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(account.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
        for (final c in calendars)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: 24, right: 8),
            value: c.visible,
            onChanged: (v) => repo.setCalendarVisible(c.id, v ?? false),
            secondary: TextButton.icon(
              onPressed: () => _pickReminder(context, repo, c),
              icon: Icon(
                  c.defaultReminderMinutes == null
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                  size: 16),
              label: Text(_reminderLabel(context, c.defaultReminderMinutes),
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6)),
            ),
            title: Row(
              children: [
                _ColorSwatch(
                  color: Color(c.effectiveColor),
                  custom: c.colorOverride != null,
                  onTap: () => _pickColor(context, repo, c),
                ),
                const SizedBox(width: 10),
                // тап по имени → переименовать
                Flexible(
                  child: InkWell(
                    onTap: () => _pickName(context, repo, c),
                    child: Text(c.effectiveName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontStyle: c.nameOverride != null
                                ? FontStyle.italic
                                : null)),
                  ),
                ),
                if (c.nameOverride != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.edit, size: 11, color: Colors.grey),
                  ),
                if (c.readOnly)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child:
                        Icon(Icons.lock_outline, size: 13, color: Colors.grey),
                  ),
              ],
            ),
          ),
        if (calendars.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 16, 8),
            child: Text(l10n.setNoCalendars,
                style: const TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }
}

class _MapsDropdown extends StatefulWidget {
  const _MapsDropdown();
  @override
  State<_MapsDropdown> createState() => _MapsDropdownState();
}

class _MapsDropdownState extends State<_MapsDropdown> {
  @override
  Widget build(BuildContext context) => DropdownButton<MapProvider>(
        value: MapsService.provider,
        onChanged: (v) => setState(() => MapsService.provider = v!),
        items: const [
          DropdownMenuItem(value: MapProvider.yandex, child: Text('Yandex Maps')),
          DropdownMenuItem(value: MapProvider.google, child: Text('Google Maps')),
          DropdownMenuItem(value: MapProvider.apple, child: Text('Apple Maps')),
        ],
      );
}

/// Кружок-цвет календаря; обводка, если цвет переопределён пользователем.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch(
      {required this.color, required this.custom, required this.onTap});
  final Color color;
  final bool custom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: custom
                ? Border.all(color: Colors.white70, width: 2)
                : Border.all(color: Colors.white24, width: 1),
          ),
        ),
      );
}

/// Палитра выбора цвета календаря + сброс к цвету источника.
const _palette = <int>[
  0xFFE53935, 0xFFD81B60, 0xFF8E24AA, 0xFF5E35B1, 0xFF3949AB,
  0xFF1E88E5, 0xFF039BE5, 0xFF00ACC1, 0xFF00897B, 0xFF43A047,
  0xFF7CB342, 0xFFC0CA33, 0xFFFDD835, 0xFFFFB300, 0xFFFB8C00,
  0xFFF4511E, 0xFF6D4C41, 0xFF757575, 0xFF546E7A, 0xFF7719AA,
];

Future<void> _pickName(
    BuildContext context, AccountRepository repo, Calendar c) async {
  final l10n = L10n.of(context);
  final ctrl = TextEditingController(text: c.effectiveName);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.setRenameCalendar),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.setCalendarNameHint),
            onSubmitted: (v) {
              repo.setCalendarName(c.id, v);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 6),
          Text(l10n.setFromSource(c.name),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      actions: [
        if (c.nameOverride != null)
          TextButton(
            onPressed: () {
              repo.setCalendarName(c.id, null); // сброс к имени источника
              Navigator.pop(ctx);
            },
            child: Text(l10n.setReset),
          ),
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(l10n.setCancel)),
        FilledButton(
          onPressed: () {
            repo.setCalendarName(c.id, ctrl.text);
            Navigator.pop(ctx);
          },
          child: Text(l10n.setSave),
        ),
      ],
    ),
  );
}

Future<void> _pickColor(
    BuildContext context, AccountRepository repo, Calendar c) async {
  final l10n = L10n.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.setColorTitle(c.effectiveName)),
      content: SizedBox(
        width: 320,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final argb in _palette)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  repo.setCalendarColor(c.id, argb);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(argb),
                    shape: BoxShape.circle,
                    border: c.effectiveColor == argb
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (c.colorOverride != null)
          TextButton(
            onPressed: () {
              repo.setCalendarColor(c.id, null);
              Navigator.pop(ctx);
            },
            child: Text(l10n.setResetColor),
          ),
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(l10n.setCancel)),
      ],
    ),
  );
}

// ───────── напоминания по умолчанию ─────────

/// Варианты дефолтного напоминания календаря: null = нет, 0 = в момент начала.
const _reminderOptions = <int?>[null, 0, 5, 10, 15, 30, 60];

String _reminderLabel(BuildContext context, int? minutes) {
  final l10n = L10n.of(context);
  if (minutes == null) return l10n.setReminderNone;
  if (minutes == 0) return l10n.setReminderAtStart;
  if (minutes % 60 == 0) return l10n.setReminderHours(minutes ~/ 60);
  return l10n.setReminderMinutes(minutes);
}

Future<void> _pickReminder(
    BuildContext context, AccountRepository repo, Calendar c) async {
  final l10n = L10n.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.setReminderTitle(c.effectiveName)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(l10n.setReminderSubtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        RadioGroup<int?>(
          groupValue: c.defaultReminderMinutes,
          onChanged: (v) {
            repo.setCalendarDefaultReminder(c.id, v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opt in _reminderOptions)
                RadioListTile<int?>(
                  dense: true,
                  value: opt,
                  title: Text(opt == null
                      ? l10n.setReminderNoneFull
                      : opt == 0
                          ? l10n.setReminderAtStartFull
                          : _reminderLabel(context, opt)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

IconData _providerIcon(ProviderType p) => switch (p) {
      ProviderType.google => Icons.event,
      ProviderType.graph => Icons.business,
      ProviderType.caldav => Icons.cloud_outlined,
      ProviderType.ews => Icons.dns_outlined,
    };

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}
