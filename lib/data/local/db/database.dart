import 'package:drift/drift.dart';

import '../../../domain/models/enums.dart';

part 'database.g.dart';

/// Учётные записи (секреты — НЕ здесь, в SecureStore).
@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  IntColumn get provider => intEnum<ProviderType>()();
  TextColumn get displayName => text()();
  TextColumn get email => text()();
  IntColumn get status => intEnum<AccountStatus>()
      .withDefault(const Constant(0))();

  /// Сериализованный AccountConfig (JSON).
  TextColumn get configJson => text().withDefault(const Constant('{}'))();

  /// Политика обновления (JSON).
  TextColumn get refreshJson => text().withDefault(const Constant('{}'))();

  /// Время последнего УСПЕШНОГО синка и текст последней ошибки (для плашки).
  DateTimeColumn get lastSyncUtc => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Календари внутри учётных записей (FR-A8).
@DataClassName('CalendarRow')
class Calendars extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get name => text()();

  /// Пользовательское имя (переименование). Синк не трогает; null → берём [name].
  TextColumn get nameOverride => text().nullable()();

  /// Цвет из источника (перезаписывается синком).
  IntColumn get color => integer()();

  /// Пользовательский цвет (FR-A9). Синк его не трогает; null → берём [color].
  IntColumn get colorOverride => integer().nullable()();

  /// Дефолтное напоминание календаря (минут до начала; 0 = в момент начала;
  /// null = без напоминания). Пользовательская настройка, синк не трогает (FR-N).
  IntColumn get defaultReminderMinutes => integer().nullable()();

  BoolColumn get visible => boolean().withDefault(const Constant(true))();
  TextColumn get syncState => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get readOnly => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Локальный кэш событий (FR-C2). Время — в UTC.
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get calendarId => text().references(Calendars, #id)();
  TextColumn get accountId => text()();

  /// Id события в источнике (для CRUD и как сигнал дедупа — UID).
  TextColumn get providerEventId => text().nullable()();
  TextColumn get etag => text().nullable()();

  TextColumn get title => text()();
  DateTimeColumn get startUtc => dateTime()();
  DateTimeColumn get endUtc => dateTime()();
  TextColumn get timeZoneId => text().withDefault(const Constant('UTC'))();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get recurrenceRule => text().nullable()();
  TextColumn get recurrenceId => text().nullable()();

  IntColumn get myResponse => intEnum<ResponseStatus>()
      .withDefault(const Constant(4))(); // organizer
  IntColumn get showAs => intEnum<ShowAs>().withDefault(const Constant(0))();
  IntColumn get visibility =>
      intEnum<EventVisibility>().withDefault(const Constant(0))();
  IntColumn get status =>
      intEnum<EventStatus>().withDefault(const Constant(0))(); // confirmed
  BoolColumn get deletedRemotely =>
      boolean().withDefault(const Constant(false))();

  IntColumn get colorOverride => integer().nullable()();
  TextColumn get mergedGroupId => text().nullable()();

  /// Готовая web-ссылка на событие в облаке (для карточки).
  TextColumn get webUrl => text().nullable()();

  /// Видеоконференция (JSON) и участники (JSON) — денормализованно для MVP.
  TextColumn get conferenceJson => text().nullable()();
  TextColumn get attendeesJson => text().nullable()();
  TextColumn get remindersJson => text().nullable()();

  /// Вложения события (ATTACH / attachments) — JSON-список ссылок с подписями.
  TextColumn get attachmentsJson => text().nullable()();

  /// Признак «есть несинхронизированные локальные правки» (для Outbox-логики).
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Исходящая очередь изменений (Outbox, FR-S6).
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get op => text()(); // create | update | delete | rsvp
  TextColumn get eventId => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Справочник контактов (автодополнение участников, FR-K).
@DataClassName('ContactRow')
class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get email => text()();
  TextColumn get source => text().withDefault(const Constant('manual'))();

  /// Сколько раз контакт добавляли участником — для сортировки подсказок по
  /// частоте (FR-K).
  IntColumn get useCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Accounts, Calendars, Events, Outbox, Contacts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(accounts, accounts.lastSyncUtc);
            await m.addColumn(accounts, accounts.lastError);
          }
          if (from < 3) {
            await m.addColumn(calendars, calendars.colorOverride);
          }
          if (from < 4) {
            await m.addColumn(calendars, calendars.defaultReminderMinutes);
          }
          if (from < 5) {
            await m.createTable(contacts);
          }
          if (from < 6) {
            await m.addColumn(events, events.webUrl);
          }
          if (from < 7) {
            await m.addColumn(calendars, calendars.nameOverride);
          }
          if (from < 8) {
            await m.addColumn(contacts, contacts.useCount);
          }
          if (from < 9) {
            await m.addColumn(events, events.attachmentsJson);
          }
        },
      );

  /// Реактивный поток событий в диапазоне для видимых календарей (FR-V4).
  ///
  /// Возвращает confirmed + (опционально) отменённые/удалённые (FR-V12).
  Stream<List<Event>> watchEventsInRange(
    DateTime startUtc,
    DateTime endUtc, {
    bool includeCancelled = false,
  }) {
    final query = select(events).join([
      innerJoin(calendars, calendars.id.equalsExp(events.calendarId)),
    ])
      ..where(calendars.visible.equals(true))
      ..where(events.startUtc.isSmallerThanValue(endUtc))
      ..where(events.endUtc.isBiggerThanValue(startUtc));

    if (!includeCancelled) {
      query
        ..where(events.deletedRemotely.equals(false))
        ..where(events.status.isNotIn([EventStatus.cancelled.index]));
    }

    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(events)).toList(),
        );
  }
}
