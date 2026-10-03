import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/notifications/notification_sync.dart';
import '../features/widget/agenda_widget_service.dart';
import 'bootstrap.dart';
import 'locale_provider.dart';
import 'providers.dart';
import 'theme.dart';

class CalenfiApp extends ConsumerWidget {
  const CalenfiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(agendaWidgetSyncProvider); // держим домашний виджет в синхроне
    ref.watch(notificationSyncProvider); // напоминания о начале встреч (FR-N)
    ref.watch(periodicSyncProvider); // регулярная автосинхронизация (FR-S2)
    ref.watch(notesSyncLoopProvider); // личные заметки между устройствами
    return MaterialApp(
      title: 'Calenfi',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      locale: ref.watch(localeProvider),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: const _Bootstrap(child: CalendarScreen()),
    );
  }
}

/// Одноразовая инициализация (сид аккаунтов + первичный синк) перед показом UI.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap({required this.child});
  final Widget child;
  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = bootstrap(ref);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
              body: Center(child: Text('Ошибка инициализации: ${snap.error}')));
        }
        return widget.child;
      },
    );
  }
}
