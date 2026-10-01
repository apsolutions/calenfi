import 'dart:async';
import 'dart:io';

/// Журнал диагностики: что делало приложение и на чём споткнулось.
///
/// Релизная сборка на телефоне ничего не пишет туда, где это можно прочитать:
/// когда синхронизация отваливалась или вход зависал, от ошибки оставались
/// 200 символов в карточке аккаунта. Журнал хранит последние события в памяти
/// и в файле `calenfi.log` рядом с данными приложения, его видно в настройках,
/// и его можно скопировать целиком.
///
/// Чистый Dart без Flutter: пишут сюда и движок синхронизации, и OAuth, и CLI.
/// Секреты в журнал не попадают: [scrub] вырезает токены, коды и пароли.
class DiagLog {
  DiagLog._();

  static final DiagLog instance = DiagLog._();

  /// Сколько строк держим в памяти (и показываем на экране журнала).
  static const maxLines = 1500;

  /// Размер файла, после которого он уезжает в `calenfi.log.1`.
  static const maxFileBytes = 512 * 1024;

  final List<String> _lines = [];
  final _changes = StreamController<void>.broadcast();
  File? _file;

  /// Печатать ли строки ещё и в stdout (на Android это logcat, тег flutter).
  /// По умолчанию выключено: агентский CLI отдаёт в stdout JSON, и строки
  /// журнала от движка синхронизации ломали бы его разбор. Включает приложение.
  bool echo = false;

  /// Срабатывает на каждую новую строку и на очистку.
  Stream<void> get changes => _changes.stream;

  /// Строки от старых к новым.
  List<String> get lines => List.unmodifiable(_lines);

  String? get filePath => _file?.path;

  /// Подключить файл журнала. До вызова журнал живёт только в памяти.
  /// Ошибки файла журнал не роняют: диагностика не должна ломать приложение.
  void attachFile(String path) {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      if (file.existsSync() && file.lengthSync() > maxFileBytes) {
        final old = File('$path.1');
        if (old.existsSync()) old.deleteSync();
        file.renameSync(old.path);
      }
      _file = File(path);
      if (_file!.existsSync() && _lines.isEmpty) {
        final previous = _file!.readAsLinesSync();
        _lines.addAll(previous.length > maxLines
            ? previous.sublist(previous.length - maxLines)
            : previous);
      }
    } on Object {
      _file = null;
    }
  }

  /// Записать событие. [tag] — короткая область: sync, login, token, app.
  void add(String tag, String message) {
    final line = '${_stamp(DateTime.now())} [$tag] ${scrub(message)}';
    _lines.add(line);
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
    if (echo) {
      // ignore: avoid_print
      print('calenfi $line');
    }
    try {
      _file?.writeAsStringSync('$line\n', mode: FileMode.append);
    } on Object {
      // Диск полон или файл недоступен — журнал остаётся в памяти.
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Записать ошибку: тип, полный текст и начало стека.
  void error(String tag, String message, Object error, [StackTrace? stack]) {
    final buffer = StringBuffer('$message: ${error.runtimeType}: $error');
    if (stack != null) {
      final frames = stack
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(8);
      for (final frame in frames) {
        buffer.write('\n    $frame');
      }
    }
    add(tag, buffer.toString());
  }

  /// Очистить журнал в памяти и в файле.
  void clear() {
    _lines.clear();
    try {
      _file?.writeAsStringSync('');
    } on Object {
      // см. add
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Весь журнал одним текстом — для копирования.
  String dump() => _lines.join('\n');

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.$ms';
  }

  // Явные имена полей с секретом — и в запросе (`=`), и в JSON (`:`).
  static final _secretField = RegExp(
    r'''(access_token|refresh_token|id_token|client_secret|code_verifier|client_assertion)(["']?\s*[=:]\s*["']?)[^\s&"',}]+''',
    caseSensitive: false,
  );
  // Короткие имена — только как параметр запроса: «code: 500» в тексте
  // ошибки секретом не является.
  static final _secretParam = RegExp(
    r'''\b(code|token|secret|password|passwd)(=)[^\s&"',}]+''',
    caseSensitive: false,
  );
  static final _jwt = RegExp(r'eyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]*');
  static final _bearer = RegExp(r'(Bearer|Basic)\s+[\w.~+/=-]{8,}');
  // Длинная непрозрачная строка без точек и слэшей: пути к файлам и кадры
  // стека (`package:calenfi/data/…/graph_provider.dart`) должны оставаться.
  static final _longOpaque = RegExp(r'(?<![\w/.])[A-Za-z0-9_~+=-]{48,}(?![\w/.])');

  /// Убирает из текста всё, что похоже на секрет: параметры с токенами и
  /// кодами, JWT, заголовки авторизации и длинные непрозрачные строки.
  static String scrub(String text) => text
      .replaceAllMapped(_secretField, (m) => '${m[1]}${m[2]}<скрыто>')
      .replaceAllMapped(_secretParam, (m) => '${m[1]}${m[2]}<скрыто>')
      .replaceAll(_jwt, '<jwt>')
      .replaceAllMapped(_bearer, (m) => '${m[1]} <скрыто>')
      .replaceAll(_longOpaque, '<скрыто>');
}
