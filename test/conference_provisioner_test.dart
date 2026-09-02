import 'package:calenfi/data/providers/conference/conference_provisioner.dart';
import 'package:calenfi/data/secure/credential_source.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/conference.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Развязка провижининга видеовстреч: маршрутизация «нативно vs отдельный API».
/// Сетевые пути (реальный Teams/Meet) здесь не дёргаем — только логику выбора.
void main() {
  const graph = Account(
      id: 'a-graph',
      provider: ProviderType.graph,
      displayName: 'O365',
      email: 'user@o365.com');
  const google = Account(
      id: 'a-google',
      provider: ProviderType.google,
      displayName: 'Google',
      email: 'user@gmail.com');
  const yandex = Account(
      id: 'a-yandex',
      provider: ProviderType.caldav,
      displayName: 'Yandex',
      email: 'user@yandex.ru');

  // Пустые креды — чтобы Zoom/Telemost детерминированно падали «не настроено»
  // (без чтения реального secrets.env и без сети).
  final prov = ConferenceProvisioner(credentials: CredentialSource.empty());
  final start = DateTime.utc(2026, 7, 10, 12);
  final end = DateTime.utc(2026, 7, 10, 13);

  Future<Conference> resolve(ConferenceType t, Account? target,
          List<Account> all) =>
      prov.resolve(t, target: target, allAccounts: all, start: start, end: end,
          subject: 'x');

  test('nativeCapable: Teams↔Graph, Meet↔Google, иначе нет', () {
    expect(ConferenceProvisioner.nativeCapable(ConferenceType.teams, graph), isTrue);
    expect(ConferenceProvisioner.nativeCapable(ConferenceType.meet, google), isTrue);
    expect(ConferenceProvisioner.nativeCapable(ConferenceType.teams, google), isFalse);
    expect(ConferenceProvisioner.nativeCapable(ConferenceType.meet, yandex), isFalse);
    expect(
        ConferenceProvisioner.nativeCapable(ConferenceType.telemost, yandex),
        isTrue);
    expect(ConferenceProvisioner.nativeCapable(ConferenceType.zoom, graph), isFalse);
  });

  test('тот же аккаунт умеет нативно → маркер (пустой joinUrl), без сети',
      () async {
    final teams = await resolve(ConferenceType.teams, graph, [graph, yandex]);
    expect(teams.type, ConferenceType.teams);
    expect(teams.isReady, isFalse); // «ожидающая» — заведёт провайдер календаря

    final meet = await resolve(ConferenceType.meet, google, [google, yandex]);
    expect(meet.isReady, isFalse);
  });

  test('Zoom без кредов → внятная ошибка', () async {
    expect(() => resolve(ConferenceType.zoom, yandex, [yandex]),
        throwsA(isA<ConferenceUnavailableException>()));
  });

  test('кросс-аккаунт Teams, но нет O365-аккаунта → ошибка', () async {
    expect(() => resolve(ConferenceType.teams, yandex, [yandex, google]),
        throwsA(isA<ConferenceUnavailableException>()));
  });

  test('descriptionWithConference встраивает ссылку только для готовой', () {
    expect(descriptionWithConference('заметка', null), 'заметка');
    expect(descriptionWithConference('заметка', Conference.pending(ConferenceType.teams)),
        'заметка');
    final ready = descriptionWithConference(
        'заметка', const Conference(type: ConferenceType.zoom, joinUrl: 'https://z/1'));
    expect(ready, contains('https://z/1'));
    expect(ready, contains('заметка'));
  });
}
