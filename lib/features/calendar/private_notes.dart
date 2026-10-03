import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/merged_event.dart';
import 'linkified_text.dart';

/// Личная заметка к встрече в карточке — только чтение. Правится в
/// редакторе встречи, в поле «Заметки»: поле одно, в двух местах его нет.
class PrivateNoteView extends ConsumerWidget {
  const PrivateNoteView({super.key, required this.event});
  final MergedEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Перечитываем при любом изменении заметок (правка в редакторе,
    // синхронизация с другого устройства).
    ref.watch(noteKeysProvider);
    return FutureBuilder<String?>(
      future: ref.read(notesRepositoryProvider).read(event),
      builder: (context, snap) {
        final text = snap.data;
        if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            key: const ValueKey('private-note-view'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(child: LinkifiedText(text)),
            ],
          ),
        );
      },
    );
  }
}
