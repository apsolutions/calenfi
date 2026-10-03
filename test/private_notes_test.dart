// «Хочу поле с личными заметками, которое не будет отображаться другим
// участникам, а мне даст информацию о повестке встречи».

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/repositories/notes_repository.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NotesRepository notes;
  final t = DateTime.utc(2026, 10, 2, 14);

  CalendarEvent ev(String id, {DateTime? start, String title = 'Собеседование'}) {
    final s = start ?? t;
    return CalendarEvent(
      id: id,
      calendarId: 'c-$id',
      title: title,
      startUtc: s,
      endUtc: s.add(const Duration(hours: 1)),
      source: EventSource(accountId: id.split(':').first, calendarId: 'c-$id'),
    );
  }

  MergedEvent group(List<CalendarEvent> sources) =>
      MergedEvent(groupId: sources.first.id, primary: sources.first, sources: sources);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notes = NotesRepository(db);
  });
  tearDown(() => db.close());

  test('заметка читается с любой копии склейки и при смене основной', () async {
    await notes.write(group([ev('acc-a:1'), ev('acc-b:2')]), 'Повестка: опыт с LLM');

    expect(await notes.read(group([ev('acc-b:2'), ev('acc-a:1')])), 'Повестка: опыт с LLM');
    expect(await notes.read(group([ev('acc-b:2')])), 'Повестка: опыт с LLM');
  });

  test('переживает перенос встречи: копию узнаём по id', () async {
    await notes.write(group([ev('acc-a:1')]), 'Вопросы');
    final moved = ev('acc-a:1', start: t.add(const Duration(days: 1)));
    expect(await notes.read(group([moved])), 'Вопросы');
  });

  test('без общего id находим по названию и времени', () async {
    await notes.write(group([ev('acc-a:1')]), 'Подготовить демо');
    expect(await notes.read(group([ev('acc-z:9')])), 'Подготовить демо');
    expect(await notes.read(group([ev('acc-z:9', title: 'Другая встреча')])), isNull);
  });

  test('пустой текст удаляет заметку, значок пропадает', () async {
    final m = group([ev('acc-a:1')]);
    await notes.write(m, 'текст');
    expect(NotesRepository.hasNote(m, await notes.watchKeys().first), isTrue);
    await notes.write(m, '   ');
    expect(await notes.read(m), isNull);
    expect(NotesRepository.hasNote(m, await notes.watchKeys().first), isFalse);
  });

  test('заметка не входит в событие, которое уходит провайдеру', () {
    // Отдельная таблица, а не поле CalendarEvent: адаптеры провайдеров её не
    // видят, и pull её не перезаписывает.
    expect(kEventNotesDdl, contains('CREATE TABLE IF NOT EXISTS event_notes'));
  });
}
