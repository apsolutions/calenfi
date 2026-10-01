import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../services/diag_log.dart';

/// Журнал диагностики: свежие события сверху, весь текст копируется одной
/// кнопкой — чтобы причину сбоя можно было прочитать и переслать, не подключая
/// телефон к компьютеру.
class DiagLogScreen extends StatelessWidget {
  const DiagLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final log = DiagLog.instance;
    return StreamBuilder<void>(
      stream: log.changes,
      builder: (context, _) {
        final lines = log.lines.reversed.toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.setDiagLog),
            actions: [
              IconButton(
                key: const ValueKey('diag-copy'),
                tooltip: l10n.diagCopy,
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: lines.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: log.dump()));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.diagCopied)));
                        }
                      },
              ),
              IconButton(
                key: const ValueKey('diag-clear'),
                tooltip: l10n.diagClear,
                icon: const Icon(Icons.delete_outline),
                onPressed: lines.isEmpty ? null : log.clear,
              ),
            ],
          ),
          body: lines.isEmpty
              ? Center(child: Text(l10n.diagEmpty))
              : SelectionArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: lines.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        lines[i],
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11, height: 1.3),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
