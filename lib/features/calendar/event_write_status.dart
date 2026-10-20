import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

final eventWriteStateProvider = StreamProvider.autoDispose
    .family<({bool dirty, bool failed})?, String>(
      (ref, id) => ref.watch(eventRepositoryProvider).watchWriteState(id),
    );

/// The global spinner includes unrelated downloads; this row describes only
/// the event currently open, and remains visible after a failed write.
class EventWriteStatus extends ConsumerWidget {
  const EventWriteStatus({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventWriteStateProvider(eventId)).valueOrNull;
    if (state == null) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final failed = state.dirty && state.failed;
    final color = failed ? Theme.of(context).colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            failed
                ? Icons.sync_problem
                : state.dirty
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              failed
                  ? l10n.detWriteFailed
                  : state.dirty
                  ? l10n.detWritePending
                  : l10n.detWriteConfirmed,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
