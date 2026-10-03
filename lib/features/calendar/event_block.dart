import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/notes_repository.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/merged_event.dart';
import 'event_details_sheet.dart';

/// Блок одного (возможно склеенного) события в сетке.
///
/// Визуальные состояния (FR-V9):
///  • accepted/organizer → заливка;
///  • needsAction («направлено, ожидает ответа») → контур;
///  • cancelled/удалено (FR-V12) → приглушённо + зачёркнуто.
class EventBlock extends ConsumerWidget {
  const EventBlock({super.key, required this.event, required this.color});

  final MergedEvent event;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event.primary;
    final noteKeys = ref.watch(noteKeysProvider).value ?? const <String>{};
    final hasNote = NotesRepository.hasNote(event, noteKeys);
    final pending = e.myResponse == ResponseStatus.needsAction;
    final cancelled = e.isCancelled;
    final start = e.startUtc.toLocal();
    final timeLabel =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    final fill = pending
        ? color.withValues(alpha: 0.12)
        : color.withValues(alpha: cancelled ? 0.10 : 0.32);
    final border = pending
        ? BorderSide(color: color, width: 1.2)
        : BorderSide(color: color.withValues(alpha: 0.6), width: 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => showEventDetails(context, event),
          child: Opacity(
            opacity: cancelled ? 0.55 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(5),
                border: Border.fromBorderSide(border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FittedBox: в узких колонках (неделя) строка масштабируется,
                  // а не вылезает «полосатым» оверфлоу.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(timeLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                              fontSize: 10,
                              color: color.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600)),
                      if (e.conference != null)
                        Icon(Icons.videocam,
                            size: 11, color: color.withValues(alpha: 0.9)),
                      if (hasNote)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(Icons.sticky_note_2_outlined,
                              size: 11, color: color.withValues(alpha: 0.9)),
                        ),
                      if (event.isMerged)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text('×${event.sources.length}',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: color.withValues(alpha: 0.9))),
                        ),
                    ]),
                  ),
                  Flexible(
                    child: Text(
                      e.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        decoration:
                            cancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
