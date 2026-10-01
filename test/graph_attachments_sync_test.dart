// Жалоба: «календари опять не синкаются». С появлением вложений каждый проход
// синхронизации Office 365 запрашивал список файлов отдельным запросом для
// КАЖДОГО вхождения с флагом hasAttachments. Серия с файлом, развёрнутая на
// год вперёд, давала сотни запросов; проход не укладывался в лимит времени.

import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/graph/graph_provider.dart';
import 'package:calenfi/data/providers/calendar/graph/graph_token.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Graph в миниатюре: одна страница calendarView и списки вложений.
class _FakeGraph implements HttpClientAdapter {
  List<Map<String, dynamic>> events = [];
  final attachmentRequests = <String>[];
  int inFlight = 0;
  int maxInFlight = 0;

  /// Событие, у которого список вложений «не отдаётся» (403).
  String? forbidden;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    if (path.endsWith('/attachments')) {
      final id = path.split('/')[path.split('/').length - 2];
      attachmentRequests.add(id);
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inFlight--;
      if (id == forbidden) return _json({'error': 'denied'}, 403);
      return _json({
        'value': [
          {'name': 'План-$id.pdf', 'contentType': 'application/pdf', 'size': 1024},
        ],
      });
    }
    return _json({'value': events});
  }

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _event(
  String id, {
  required int day,
  bool files = false,
  String type = 'singleInstance',
  String? master,
  String changeKey = 'v1',
}) =>
    {
      'id': id,
      'subject': 'Событие $id',
      'start': {'dateTime': '2026-10-${day.toString().padLeft(2, '0')}T10:00:00.0000000'},
      'end': {'dateTime': '2026-10-${day.toString().padLeft(2, '0')}T11:00:00.0000000'},
      'webLink': 'https://outlook.office.com/calendar/item/$id',
      'type': type,
      'seriesMasterId': master,
      'hasAttachments': files,
      'changeKey': changeKey,
    };

void main() {
  const acc = Account(
    id: 'acc-work',
    provider: ProviderType.graph,
    displayName: 'Work',
    email: 'user@example.test',
  );
  const cal = Calendar(
      id: 'acc-work|cal-1', accountId: 'acc-work', name: 'Calendar', color: 0xFF336699);
  final range = DateRange(DateTime.utc(2026, 10, 1), DateTime.utc(2026, 11, 1));

  late _FakeGraph graph;
  late GraphProvider provider;

  setUp(() {
    graph = _FakeGraph();
    final dio = Dio()..httpClientAdapter = graph;
    provider = GraphProvider(
      account: acc,
      token: GraphToken(
        clientId: 'client',
        tenant: 'organizations',
        refreshToken: 'refresh',
        accessToken: 'access',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      ),
      dio: dio,
    );
  });

  test('серия с файлом: один запрос на серию, а не на каждое вхождение',
      () async {
    graph.events = [
      for (var d = 1; d <= 25; d++)
        _event('occ-$d', day: d, files: true, type: 'occurrence', master: 'series-1'),
      _event('single', day: 3, files: true),
      _event('plain', day: 4),
    ];

    final events = await provider.fetchEvents(acc, cal, range);

    expect(graph.attachmentRequests.toSet(), {'series-1', 'single'});
    expect(graph.attachmentRequests, hasLength(2));
    // Файл виден у каждого вхождения, и ссылка ведёт на само вхождение.
    final occurrences = events.where((e) => e.id.contains('occ-')).toList();
    expect(occurrences, hasLength(25));
    for (final e in occurrences) {
      expect(e.attachments.single.fileName, 'План-series-1.pdf');
      expect(e.attachments.single.uri, e.webUrl);
    }
    expect(events.firstWhere((e) => e.id.endsWith(':plain')).attachments, isEmpty);
  });

  test('повторный проход не запрашивает вложения, пока событие не изменилось',
      () async {
    graph.events = [
      for (var d = 1; d <= 10; d++)
        _event('occ-$d', day: d, files: true, type: 'occurrence', master: 'series-1'),
      _event('single', day: 3, files: true),
    ];
    await provider.fetchEvents(acc, cal, range);
    graph.attachmentRequests.clear();

    final again = await provider.fetchEvents(acc, cal, range);
    expect(graph.attachmentRequests, isEmpty);
    expect(again.every((e) => e.attachments.length == 1), isTrue);

    // У одного события сменилась версия — перечитываем только его.
    graph.events = [
      for (var d = 1; d <= 10; d++)
        _event('occ-$d', day: d, files: true, type: 'occurrence', master: 'series-1'),
      _event('single', day: 3, files: true, changeKey: 'v2'),
    ];
    await provider.fetchEvents(acc, cal, range);
    expect(graph.attachmentRequests, ['single']);
  });

  test('исключение из серии спрашивает свой список, запросы идут пачками',
      () async {
    graph.events = [
      for (var s = 1; s <= 9; s++)
        _event('occ-$s', day: s, files: true, type: 'occurrence', master: 'series-$s'),
      _event('exc', day: 12, files: true, type: 'exception', master: 'series-1'),
    ];

    await provider.fetchEvents(acc, cal, range);

    expect(graph.attachmentRequests.toSet(),
        {for (var s = 1; s <= 9; s++) 'series-$s', 'exc'});
    expect(graph.maxInFlight, greaterThan(1));
    expect(graph.maxInFlight, lessThanOrEqualTo(4));
  });

  test('отказ в списке вложений не роняет синк и не запоминается', () async {
    graph.events = [_event('secret', day: 5, files: true)];
    graph.forbidden = 'secret';

    final first = await provider.fetchEvents(acc, cal, range);
    expect(first.single.attachments, isEmpty);

    graph.forbidden = null;
    final second = await provider.fetchEvents(acc, cal, range);
    expect(second.single.attachments.single.fileName, 'План-secret.pdf');
    expect(graph.attachmentRequests, ['secret', 'secret']);
  });
}
