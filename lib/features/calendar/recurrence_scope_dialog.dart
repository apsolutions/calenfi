import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/enums.dart';
import '../../l10n/app_localizations.dart';

/// Спрашивает, куда применить правку повторяющегося события: в одно вхождение
/// или во всю серию. `null` — пользователь передумал, правку отправлять нельзя.
///
/// Отдельный шаг нужен потому, что у Google/Graph/CalDAV это РАЗНЫЕ операции с
/// разными адресатами (экземпляр или мастер серии), и молчаливый выбор за
/// пользователя рассылает участникам приглашения не на то, что он правил.
/// «Это и последующие» здесь нет намеренно: у всех трёх провайдеров такая
/// правка расщепляет серию на новую, то есть заново приглашает участников.
Future<RecurrenceScope?> askRecurrenceEditScope(BuildContext context) {
  final l10n = L10n.of(context);
  return showModalBottomSheet<RecurrenceScope?>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(ctx),
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.detRecurringWhatEdit,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: Text(l10n.detThisEventOnly),
                onTap: () => Navigator.pop(ctx, RecurrenceScope.thisOnly),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(l10n.detEditWholeSeries),
                onTap: () => Navigator.pop(ctx, RecurrenceScope.all),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(l10n.detCancel),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
