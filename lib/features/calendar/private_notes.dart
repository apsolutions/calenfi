import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/notes_repository.dart';
import '../../domain/models/merged_event.dart';
import '../../l10n/app_localizations.dart';

/// Поле «Мои заметки» в карточке встречи.
///
/// Сохраняется само через полсекунды после последнего изменения и при
/// закрытии карточки. Хранится только в Calenfi (см. `NotesRepository`).
class PrivateNotesField extends ConsumerStatefulWidget {
  const PrivateNotesField({super.key, required this.event});
  final MergedEvent event;

  @override
  ConsumerState<PrivateNotesField> createState() => _PrivateNotesFieldState();
}

class _PrivateNotesFieldState extends ConsumerState<PrivateNotesField> {
  final _controller = TextEditingController();
  // Берём один раз: в dispose обращаться к ref уже нельзя.
  late final NotesRepository _repo = ref.read(notesRepositoryProvider);
  Timer? _debounce;
  bool _loaded = false;
  String _saved = '';

  @override
  void initState() {
    super.initState();
    _repo.read(widget.event).then((text) {
      if (!mounted) return;
      _saved = text ?? '';
      _controller.text = _saved;
      setState(() => _loaded = true);
    });
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (!_loaded) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    final text = _controller.text;
    if (text == _saved) return;
    _saved = text;
    await _repo.write(widget.event, text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Закрыли карточку, не дождавшись паузы: дописываем сразу.
    final text = _controller.text;
    if (_loaded && text != _saved) _repo.write(widget.event, text);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(l10n.detNotes,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('private-notes'),
          controller: _controller,
          enabled: _loaded,
          minLines: 2,
          maxLines: 12,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.detNotesHint,
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.detNotesPrivate,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
