import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import '../../../../domain/models/account.dart';
import '../../../../domain/models/calendar.dart';
import '../../../../domain/models/calendar_event.dart';
import '../../../../domain/models/enums.dart';
import '../../../../domain/providers/calendar_provider.dart';
import '../../../../domain/providers/provider_capabilities.dart';
import 'ntlm_http.dart';

/// Реальный адаптер Exchange (EWS/SOAP) для self-hosted (HSE).
///
/// NTLM/Autodiscover идут через НАТИВНЫЙ [NtlmHttp] (без подпроцесса curl) —
/// работает кроссплатформенно, включая Windows и мобилу.
class EwsProvider implements CalendarProvider {
  EwsProvider({
    required this.account,
    required this.password,
    this.user,
    this.ewsUrlOverride,
  });

  final Account account;
  final String password;
  final String? user; // если домен-логин отличается от email
  final String? ewsUrlOverride;
  String? _ewsUrl;

  String get _login => user ?? account.email;
  String get _domain => account.email.split('@').last;

  @override
  ProviderType get type => ProviderType.ews;
  @override
  ProviderCapabilities get caps => ProviderCapabilities.ews;

  @override
  Future<AuthResult> authenticate(AccountConfig cfg) async {
    try {
      await _resolveUrl();
      return AuthResult(success: true);
    } catch (e) {
      return AuthResult(success: false, error: '$e');
    }
  }

  @override
  Future<void> refreshAuth(Account acc) async {}

  // ───────── структура ─────────

  @override
  Future<List<Calendar>> listCalendars(Account acc) async {
    // MVP: основной календарь Exchange (дистингвиш-папка "calendar").
    return [
      Calendar(
        id: '${acc.id}|calendar',
        accountId: acc.id,
        name: 'Exchange',
        color: 0xFF0078D4,
        isPrimary: true,
      ),
    ];
  }

  // ───────── чтение ─────────

  @override
  Future<List<CalendarEvent>> fetchEvents(
      Account acc, Calendar cal, DateRange range) async {
    final body = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types" xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
<soap:Header><t:RequestServerVersion Version="Exchange2010_SP2"/></soap:Header>
<soap:Body><m:FindItem Traversal="Shallow"><m:ItemShape><t:BaseShape>IdOnly</t:BaseShape>
<t:AdditionalProperties>
<t:FieldURI FieldURI="item:Subject"/><t:FieldURI FieldURI="calendar:Start"/><t:FieldURI FieldURI="calendar:End"/>
<t:FieldURI FieldURI="calendar:Location"/><t:FieldURI FieldURI="calendar:IsAllDayEvent"/>
<t:FieldURI FieldURI="calendar:LegacyFreeBusyStatus"/><t:FieldURI FieldURI="calendar:MyResponseType"/>
<t:FieldURI FieldURI="item:Body"/><t:FieldURI FieldURI="calendar:UID"/>
</t:AdditionalProperties></m:ItemShape>
<m:CalendarView StartDate="${_z(range.startUtc)}" EndDate="${_z(range.endUtc)}" MaxEntriesReturned="500"/>
<m:ParentFolderIds><t:DistinguishedFolderId Id="calendar"/></m:ParentFolderIds></m:FindItem></soap:Body></soap:Envelope>''';

    final xml = await _soap(
        'http://schemas.microsoft.com/exchange/services/2006/messages/FindItem',
        body);
    final doc = XmlDocument.parse(xml);
    final out = <CalendarEvent>[];
    for (final it in doc.findAllElements('CalendarItem', namespace: _tns)) {
      final ev = _toEvent(acc, cal, it);
      if (ev != null) out.add(ev);
    }
    // FindItem НЕ возвращает Body (ограничение EWS) — дотягиваем тела (детали +
    // внешние ссылки) отдельным GetItem по ItemId.
    final bodies = await _fetchBodies(
        out.map((e) => e.source.providerEventId).whereType<String>().toList());
    if (bodies.isEmpty) return out;
    return [
      for (final e in out)
        (e.source.providerEventId != null &&
                bodies[e.source.providerEventId] != null)
            ? e.copyWith(description: bodies[e.source.providerEventId!])
            : e,
    ];
  }

  /// Тянет тела (Body) по ItemId батчами — FindItem их не отдаёт. Возвращает
  /// map itemId → очищенный от HTML текст. Порядок ответа = порядок запроса.
  Future<Map<String, String>> _fetchBodies(List<String> ids) async {
    final result = <String, String>{};
    const chunkSize = 50;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
      final idsXml =
          chunk.map((id) => '<t:ItemId Id="${_attr(id)}"/>').join();
      final req = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types" xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
<soap:Header><t:RequestServerVersion Version="Exchange2010_SP2"/></soap:Header>
<soap:Body><m:GetItem><m:ItemShape><t:BaseShape>IdOnly</t:BaseShape>
<t:AdditionalProperties><t:FieldURI FieldURI="item:Body"/></t:AdditionalProperties>
</m:ItemShape><m:ItemIds>$idsXml</m:ItemIds></m:GetItem></soap:Body></soap:Envelope>''';
      try {
        final xml = await _soap(
            'http://schemas.microsoft.com/exchange/services/2006/messages/GetItem',
            req);
        final doc = XmlDocument.parse(xml);
        var j = 0;
        for (final msg
            in doc.findAllElements('GetItemResponseMessage', namespace: _mns)) {
          if (j >= chunk.length) break;
          final b =
              msg.findAllElements('Body', namespace: _tns).firstOrNull?.innerText;
          if (b != null) {
            final t = _stripHtml(b);
            if (t.isNotEmpty) result[chunk[j]] = t;
          }
          j++;
        }
      } catch (_) {/* тела необязательны — без них просто нет описания */}
    }
    return result;
  }

  @override
  Future<SyncResult> incrementalSync(
      Account acc, Calendar cal, String? syncState) async {
    final now = DateTime.now().toUtc();
    final range = DateRange(
        now.subtract(const Duration(days: 14)), now.add(const Duration(days: 60)));
    final events = await fetchEvents(acc, cal, range);
    return SyncResult(
        upserts: events, deletedIds: const [], newSyncState: null, fullWindow: range);
  }

  // ───────── запись (EWS SOAP) ─────────

  @override
  Future<CalendarEvent> createEvent(Account a, Calendar c, CalendarEvent e) async {
    // Повторы в EWS требуют объёмного <t:Recurrence> — в MVP серии не создаём,
    // чтобы не «терять» правило молча: явная ошибка (её покажет слой синка).
    if (e.recurrenceRule != null && e.recurrenceId == null) {
      throw UnsupportedError(
          'Создание повторяющихся серий в Exchange пока не поддержано');
    }
    final attendees = e.attendees.where((x) => !x.isResource).toList();
    final sendMode =
        attendees.isEmpty ? 'SendToNone' : 'SendToAllAndSaveCopy';
    final body = '''${_envelopeOpen('CreateItem')}
<m:CreateItem SendMeetingInvitations="$sendMode">
<m:SavedItemFolderId><t:DistinguishedFolderId Id="calendar"/></m:SavedItemFolderId>
<m:Items><t:CalendarItem>
<t:Subject>${_esc(e.title)}</t:Subject>
${e.description == null ? '' : '<t:Body BodyType="Text">${_esc(e.description!)}</t:Body>'}
<t:ReminderIsSet>false</t:ReminderIsSet>
<t:Start>${_z(e.startUtc)}</t:Start>
<t:End>${_z(e.endUtc)}</t:End>
<t:IsAllDayEvent>${e.allDay}</t:IsAllDayEvent>
<t:LegacyFreeBusyStatus>${e.showAs == ShowAs.free ? 'Free' : 'Busy'}</t:LegacyFreeBusyStatus>
${e.location == null ? '' : '<t:Location>${_esc(e.location!)}</t:Location>'}
${_attendeesXml(attendees)}
</t:CalendarItem></m:Items></m:CreateItem>${_envelopeClose()}''';

    final doc = _checked(await _soap(_action('CreateItem'), body));
    final idEl = doc
        .findAllElements('CalendarItem', namespace: _tns)
        .firstOrNull
        ?.findElements('ItemId', namespace: _tns)
        .firstOrNull;
    final id = idEl?.getAttribute('Id');
    return id == null
        ? e
        : e.copyWith(
            source: e.source.copyWith(
                providerEventId: id, etag: idEl?.getAttribute('ChangeKey')));
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account a,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async {
    // Серии Exchange правятся вхождение за вхождением: fetchEvents отдаёт
    // occurrences без признака серии, поэтому мастера у нас нет и scope
    // применить не к чему (UI для таких событий выбор и не показывает).
    final id = e.source.providerEventId;
    if (id == null) throw StateError('EWS update: нет ItemId');
    // Периодичность здесь менять нечему: мастера серии у нас нет. Молча
    // проглотить правило нельзя — правка выглядела бы применённой.
    if (e.recurrenceRule != null) {
      throw UnsupportedError(
          'Exchange: смена периодичности серии из Calenfi не поддерживается');
    }
    String set(String field, String ns, String inner) =>
        '<t:SetItemField><t:FieldURI FieldURI="$field"/>'
        '<t:CalendarItem>$inner</t:CalendarItem></t:SetItemField>';
    final updates = <String>[
      set('item:Subject', 't', '<t:Subject>${_esc(e.title)}</t:Subject>'),
      set('calendar:Start', 't', '<t:Start>${_z(e.startUtc)}</t:Start>'),
      set('calendar:End', 't', '<t:End>${_z(e.endUtc)}</t:End>'),
      if (e.location != null)
        set('calendar:Location', 't', '<t:Location>${_esc(e.location!)}</t:Location>'),
      if (e.description != null)
        set('item:Body', 't', '<t:Body BodyType="Text">${_esc(e.description!)}</t:Body>'),
    ].join();
    final body = '''${_envelopeOpen('UpdateItem')}
<m:UpdateItem ConflictResolution="AutoResolve" SendMeetingInvitationsOrCancellations="SendToNone">
<m:ItemChanges><t:ItemChange>
<t:ItemId Id="${_attr(id)}"${e.source.etag == null ? '' : ' ChangeKey="${_attr(e.source.etag!)}"'}/>
<t:Updates>$updates</t:Updates>
</t:ItemChange></m:ItemChanges></m:UpdateItem>${_envelopeClose()}''';
    final doc = _checked(await _soap(_action('UpdateItem'), body));
    final idEl = doc.findAllElements('ItemId', namespace: _tns).firstOrNull;
    return idEl == null
        ? e
        : e.copyWith(
            source: e.source.copyWith(etag: idEl.getAttribute('ChangeKey')));
  }

  @override
  Future<void> deleteEvent(Account a, CalendarEvent e, RecurrenceScope s) async {
    final id = e.source.providerEventId;
    // Нет серверного ItemId (событие ещё не доехало до сервера) — удалять на
    // сервере нечего, считаем удалённым.
    if (id == null) return;
    final body = '''${_envelopeOpen('DeleteItem')}
<m:DeleteItem DeleteType="MoveToDeletedItems" SendMeetingCancellations="SendToNone">
<m:ItemIds><t:ItemId Id="${_attr(id)}"${e.source.etag == null ? '' : ' ChangeKey="${_attr(e.source.etag!)}"'}/></m:ItemIds>
</m:DeleteItem>${_envelopeClose()}''';
    // ErrorItemNotFound / ErrorCannotDeleteObject = событие уже удалено на
    // сервере → цель достигнута, НЕ ошибка (иначе задание застревает навсегда).
    _checked(await _soap(_action('DeleteItem'), body),
        okCodes: const {'ErrorItemNotFound', 'ErrorCannotDeleteObject'});
  }

  @override
  Future<void> respondToInvite(Account a, CalendarEvent e, ResponseStatus r) async {
    final id = e.source.providerEventId;
    if (id == null) throw StateError('EWS RSVP: нет ItemId');
    final verb = switch (r) {
      ResponseStatus.accepted => 'AcceptItem',
      ResponseStatus.declined => 'DeclineItem',
      ResponseStatus.tentative => 'TentativelyAcceptItem',
      _ => throw UnsupportedError('EWS RSVP: неподдерживаемый ответ $r'),
    };
    final body = '''${_envelopeOpen('CreateItem')}
<m:CreateItem MessageDisposition="SendAndSaveCopy">
<m:Items><t:$verb><t:ReferenceItemId Id="${_attr(id)}"${e.source.etag == null ? '' : ' ChangeKey="${_attr(e.source.etag!)}"'}/></t:$verb></m:Items>
</m:CreateItem>${_envelopeClose()}''';
    _checked(await _soap(_action('CreateItem'), body));
  }

  // ───────── helpers ─────────

  static const _tns = 'http://schemas.microsoft.com/exchange/services/2006/types';
  static const _mns =
      'http://schemas.microsoft.com/exchange/services/2006/messages';

  static String _action(String op) =>
      'http://schemas.microsoft.com/exchange/services/2006/messages/$op';

  static String _envelopeOpen(String op) => '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:t="$_tns" xmlns:m="$_mns">
<soap:Header><t:RequestServerVersion Version="Exchange2010_SP2"/></soap:Header>
<soap:Body>''';

  static String _envelopeClose() => '</soap:Body></soap:Envelope>';

  /// Экранирование текстового значения XML-элемента.
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _attendeesXml(List<dynamic> attendees) {
    if (attendees.isEmpty) return '';
    final rows = attendees
        .map((a) =>
            '<t:Attendee><t:Mailbox><t:EmailAddress>${_esc(a.email as String)}</t:EmailAddress></t:Mailbox></t:Attendee>')
        .join();
    return '<t:RequiredAttendees>$rows</t:RequiredAttendees>';
  }

  /// Разбирает ответ EWS и БРОСАЕТ, если ResponseCode != NoError (и не входит в
  /// [okCodes]) — иначе запись молча «терялась» бы (слой синка покажет ошибку).
  /// [okCodes] — коды, которые считаем успехом (напр. «уже удалено» для delete).
  XmlDocument _checked(String xml, {Set<String> okCodes = const {}}) {
    final doc = XmlDocument.parse(xml);
    for (final m in doc.findAllElements('ResponseCode', namespace: _mns)) {
      final code = m.innerText;
      if (code != 'NoError' && !okCodes.contains(code)) {
        final msg = m.parent
                ?.findElements('MessageText', namespace: _mns)
                .firstOrNull
                ?.innerText ??
            code;
        throw 'EWS $code: $msg';
      }
    }
    return doc;
  }

  /// Экранирование значения XML-атрибута (ItemId Id).
  static String _attr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Грубое HTML→текст для тела события: теги убираем, br/блоки → перенос,
  /// схлопываем пустые строки. Ссылки остаются текстом (кликабельны в карточке
  /// через LinkifiedText).
  static String _stripHtml(String html) {
    var s = html;
    s = s.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(
        RegExp(r'</\s*(p|div|tr|li|h[1-6]|table)\s*>', caseSensitive: false),
        '\n');
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'&[a-zA-Z#0-9]+;'), ' ');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n[ \t]+'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  CalendarEvent? _toEvent(Account acc, Calendar cal, XmlElement it) {
    String? text(String name) =>
        it.findElements(name, namespace: _tns).firstOrNull?.innerText;
    final start = DateTime.tryParse(text('Start') ?? '');
    final end = DateTime.tryParse(text('End') ?? '');
    if (start == null || end == null) return null;
    final uid = text('UID') ?? it.findElements('ItemId', namespace: _tns).firstOrNull?.getAttribute('Id') ?? '';
    final allDay = text('IsAllDayEvent') == 'true';
    final myResp = switch (text('MyResponseType')) {
      'Organizer' => ResponseStatus.organizer,
      'Accept' => ResponseStatus.accepted,
      'Decline' => ResponseStatus.declined,
      'Tentative' => ResponseStatus.tentative,
      _ => ResponseStatus.needsAction,
    };
    final showAs = (text('LegacyFreeBusyStatus') == 'Free') ? ShowAs.free : ShowAs.busy;
    final itemIdEl = it.findElements('ItemId', namespace: _tns).firstOrNull;
    final itemId = itemIdEl?.getAttribute('Id');
    // ChangeKey обязателен для UpdateItem и желателен для DeleteItem — храним
    // его в etag источника (иначе правки/удаление на EWS падают).
    final changeKey = itemIdEl?.getAttribute('ChangeKey');

    // occurrences повторяющейся серии в EWS имеют ОДИНАКОВЫЙ UID — поэтому
    // в локальный id добавляем время начала, иначе они схлопнутся при upsert.
    return CalendarEvent(
      id: '${acc.id}:$uid:${start.toUtc().millisecondsSinceEpoch}',
      calendarId: cal.id,
      title: text('Subject') ?? '(без названия)',
      startUtc: start.toUtc(),
      endUtc: end.toUtc(),
      allDay: allDay,
      location: text('Location'),
      description: text('Body'),
      myResponse: myResp,
      showAs: showAs,
      source: EventSource(
          accountId: acc.id,
          calendarId: cal.id,
          providerEventId: itemId,
          etag: changeKey),
    );
  }

  Future<String> _resolveUrl() async {
    if (_ewsUrl != null) return _ewsUrl!;
    if (ewsUrlOverride != null) return _ewsUrl = ewsUrlOverride!;
    // Autodiscover (curl) по доменным хостам.
    final adBody =
        '<Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/requestschema/2006"><Request><EMailAddress>${account.email}</EMailAddress><AcceptableResponseSchema>http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a</AcceptableResponseSchema></Request></Autodiscover>';
    for (final host in ['autodiscover.$_domain', 'mail.$_domain', _domain]) {
      try {
        final xml = await _post(
          'https://$host/autodiscover/autodiscover.xml',
          adBody,
          headers: const ['Content-Type: text/xml'],
        );
        final m = RegExp(r'<EwsUrl>([^<]+)</EwsUrl>').firstMatch(xml);
        if (m != null) return _ewsUrl = m.group(1)!;
      } catch (_) {/* следующий хост */}
    }
    throw 'EWS autodiscover не удался для $_domain';
  }

  Future<String> _soap(String soapAction, String body) async {
    final url = await _resolveUrl();
    return _post(url, body, headers: [
      'Content-Type: text/xml; charset=utf-8',
      'SOAPAction: "$soapAction"',
    ]);
  }

  /// POST с NTLM-аутентификацией — НАТИВНО (без подпроцесса curl), поэтому
  /// работает на всех платформах (Windows/мобила/десктоп). NTLM аутентифицирует
  /// соединение, [NtlmHttp] держит Type1/Type3 на одном сокете.
  Future<String> _post(String url, String body,
      {List<String> headers = const []}) async {
    final hmap = <String, String>{};
    for (final h in headers) {
      final i = h.indexOf(':');
      if (i > 0) hmap[h.substring(0, i).trim()] = h.substring(i + 1).trim();
    }
    final (u, dom) = _ntlmCreds();
    final resp = await NtlmHttp(user: u, password: password, domain: dom)
        .post(Uri.parse(url), body: body, headers: hmap);
    if (resp.statusCode >= 400) throw 'EWS HTTP ${resp.statusCode}';
    return resp.body;
  }

  /// Разбор логина на (user, domain) для NTLM: `DOMAIN\user` → домен отдельно;
  /// UPN/plain (`user@example.org`) → домен пустой (как в рабочем curl `--ntlm`).
  (String, String) _ntlmCreds() {
    final l = _login;
    final bs = l.indexOf('\\');
    if (bs > 0) return (l.substring(bs + 1), l.substring(0, bs));
    return (l, '');
  }

  static String _z(DateTime d) => '${d.toUtc().toIso8601String().split('.').first}Z';
}
