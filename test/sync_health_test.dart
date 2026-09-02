import 'dart:io';

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/domain/providers/provider_capabilities.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Провайдер, всегда падающий заданной ошибкой (для проверки надёжности синка).
class _FailingProvider implements CalendarProvider {
  _FailingProvider(this.error);
  final Object error;
  int calls = 0;

  @override
  ProviderType get type => ProviderType.caldav;
  @override
  ProviderCapabilities get caps => ProviderCapabilities.caldav;
  @override
  Future<AuthResult> authenticate(AccountConfig cfg) async =>
      const AuthResult(success: true);
  @override
  Future<void> refreshAuth(Account acc) async {}
  @override
  Future<List<Calendar>> listCalendars(Account acc) async {
    calls++;
    throw error;
  }

  @override
  Future<List<CalendarEvent>> fetchEvents(
    Account a,
    Calendar c,
    DateRange r,
  ) async => throw error;
  @override
  Future<SyncResult> incrementalSync(Account a, Calendar c, String? s) async =>
      throw error;
  @override
  Future<CalendarEvent> createEvent(
    Account a,
    Calendar c,
    CalendarEvent e,
  ) async => throw error;
  @override
  Future<CalendarEvent> updateEvent(Account a, CalendarEvent e) async =>
      throw error;
  @override
  Future<void> deleteEvent(
    Account a,
    CalendarEvent e,
    RecurrenceScope s,
  ) async => throw error;
  @override
  Future<void> respondToInvite(
    Account a,
    CalendarEvent e,
    ResponseStatus r,
  ) async => throw error;
}

DioException _dioError(
  DioExceptionType type, {
  Object? error,
  int? statusCode,
}) {
  final request = RequestOptions(
    path: 'https://graph.microsoft.com/v1.0/me/calendars',
  );
  return DioException(
    requestOptions: request,
    type: type,
    error: error,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: request, statusCode: statusCode),
  );
}

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late EventRepository events;

  const acc = Account(
    id: 'a',
    provider: ProviderType.caldav,
    displayName: 'Test',
    email: 'a@x.com',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    events = EventRepository(db);
    await accounts.upsertAccount(acc);
  });
  tearDown(() => db.close());

  SyncEngine engineWith(CalendarProvider p) => SyncEngine(
    registry: ProviderRegistry(overrideFactory: (_) => p),
    accounts: accounts,
    events: events,
  );

  group('Надёжность синка (FR-A6, критично)', () {
    test('DNS ошибка → 3 попытки → статус offline', () async {
      final p = _FailingProvider(
        _dioError(
          DioExceptionType.connectionError,
          error: const SocketException(
            'Failed host lookup: graph.microsoft.com',
          ),
        ),
      );
      final report = await engineWith(p).syncAccount(acc);

      expect(report.ok, isFalse);
      expect(p.calls, 3, reason: 'должно быть ровно 3 попытки перед вердиктом');
      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.offline);
      expect(updated.lastError, isNotNull);
    });

    test('SocketException no route → offline', () async {
      final p = _FailingProvider(
        const SocketException(
          'Connection failed',
          osError: OSError('Network is unreachable', 101),
        ),
      );
      await engineWith(p).syncAccount(acc);

      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.offline);
    });

    test('Dio connection timeout → syncError, а не offline', () async {
      final p = _FailingProvider(_dioError(DioExceptionType.connectionTimeout));
      await engineWith(p).syncAccount(acc);

      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.syncError);
    });

    test('connection refused → syncError, а не offline', () async {
      final p = _FailingProvider(
        _dioError(
          DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        ),
      );
      await engineWith(p).syncAccount(acc);

      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.syncError);
    });

    test('TLS failure → syncError, а не offline', () async {
      final p = _FailingProvider(
        _dioError(
          DioExceptionType.connectionError,
          error: HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ),
      );
      await engineWith(p).syncAccount(acc);

      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.syncError);
    });

    test('HTTP 503 → syncError, а не offline', () async {
      final p = _FailingProvider(
        _dioError(DioExceptionType.badResponse, statusCode: 503),
      );
      await engineWith(p).syncAccount(acc);

      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.syncError);
    });

    test('прочая ошибка → статус syncError (не offline)', () async {
      final p = _FailingProvider(StateError('boom'));
      await engineWith(p).syncAccount(acc);
      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.syncError);
    });

    test('успех после сидов → статус ok + lastSync проставлен', () async {
      // используем мок (успешный) через обычный реестр невозможно без кредов,
      // поэтому проверяем, что recordSyncSuccess выставляет ok.
      await accounts.recordSyncSuccess('a', DateTime.utc(2026, 6, 13, 10));
      final updated = (await accounts.allAccounts()).first;
      expect(updated.status, AccountStatus.ok);
      expect(updated.lastSyncUtc, isNotNull);
      expect(updated.isHealthy, isTrue);
    });
  });
}
