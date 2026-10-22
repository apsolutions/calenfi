import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'ntlm.dart';

class NtlmResponse {
  NtlmResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

/// HTTP-клиент с NTLM поверх **сырого** SecureSocket. NTLM аутентифицирует
/// соединение, поэтому Type1 и Type3 идут по одному и тому же сокету —
/// `dart:io HttpClient` этого не гарантирует, отсюда ручная реализация.
class NtlmHttp {
  NtlmHttp({
    required this.user,
    required this.password,
    this.domain = '',
    this.workstation = '',
    this.connectTimeout = const Duration(seconds: 20),
    this.responseTimeout = const Duration(seconds: 60),
    this.connect,
  });

  final String user;
  final String password;
  final String domain;
  final String workstation;
  final Duration connectTimeout;
  final Duration responseTimeout;

  /// Optional transport for local socket tests. Production always uses TLS.
  final Future<Socket> Function(Uri url, Duration timeout)? connect;

  Future<NtlmResponse> post(
    Uri url, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    final socket = connect == null
        ? await _Connection.tls(url, connectTimeout)
        : _Connection.fromSocket(await connect!(url, connectTimeout));
    final reader = _ResponseReader(socket.stream);
    try {
      // Шаг 1: Type1.
      var raw = await _send(
        reader,
        socket,
        url,
        headers,
        body,
        'NTLM ${createType1()}',
      );
      if (raw.status == 401) {
        final t2 = _extractNtlm(raw.headers['www-authenticate']);
        if (t2 == null) return NtlmResponse(401, raw.body);
        final type3 = createType3(
          user: user,
          password: password,
          domain: domain,
          workstation: workstation,
          type2: parseType2(t2),
        );
        // Шаг 2: Type3 по тому же сокету.
        raw = await _send(reader, socket, url, headers, body, 'NTLM $type3');
      }
      return NtlmResponse(raw.status, raw.body);
    } finally {
      // A timeout must close the actual connection, not just abandon its Future.
      // Otherwise the account remains in flight forever after sleep/network loss.
      socket.destroy();
      await reader.close();
    }
  }

  Future<_Raw> _send(
    _ResponseReader reader,
    _Connection socket,
    Uri url,
    Map<String, String> headers,
    String body,
    String auth,
  ) {
    final bodyBytes = utf8.encode(body);
    final path = url.hasQuery ? '${url.path}?${url.query}' : url.path;
    final sb = StringBuffer()
      ..write('POST $path HTTP/1.1\r\n')
      ..write('Host: ${url.host}\r\n')
      ..write('Authorization: $auth\r\n')
      ..write('Content-Length: ${bodyBytes.length}\r\n')
      ..write('Connection: keep-alive\r\n');
    headers.forEach((k, v) => sb.write('$k: $v\r\n'));
    sb.write('\r\n');
    final out = <int>[...utf8.encode(sb.toString()), ...bodyBytes];
    final fut = reader.next();
    socket.add(out);
    return fut.timeout(responseTimeout);
  }

  static String? _extractNtlm(List<String>? values) {
    if (values == null) return null;
    for (final v in values) {
      final t = v.trim();
      if (t.length > 5 && t.toUpperCase().startsWith('NTLM ')) {
        return t.substring(5).trim();
      }
    }
    return null;
  }
}

/// Keep the raw TCP connection while TLS negotiates: SecureSocket.connect's
/// timeout only bounds TCP, and a timed-out TLS Future cannot close itself.
class _Connection {
  _Connection(this.stream, this.add, this.destroy);
  factory _Connection.fromSocket(Socket socket) =>
      _Connection(socket, socket.add, socket.destroy);
  final Stream<List<int>> stream;
  final void Function(List<int>) add;
  final void Function() destroy;

  static Future<_Connection> tls(Uri url, Duration timeout) async {
    final tcp = await RawSocket.connect(url.host, url.port, timeout: timeout);
    RawSecureSocket secure;
    try {
      secure =
          await RawSecureSocket.secure(
            tcp,
            host: url.host,
            onBadCertificate: (_) => true,
          ).timeout(
            timeout,
            onTimeout: () async {
              await tcp.close();
              throw TimeoutException('EWS TLS handshake timed out', timeout);
            },
          );
    } catch (_) {
      await tcp.close();
      rethrow;
    }
    final incoming = StreamController<List<int>>();
    var pending = <int>[];
    var offset = 0;
    var closed = false;
    void flush() {
      if (closed) return;
      try {
        if (offset < pending.length) {
          offset += secure.write(pending, offset, pending.length - offset);
        }
        if (offset == pending.length) {
          pending = <int>[];
          offset = 0;
        }
        secure.writeEventsEnabled = pending.isNotEmpty;
      } catch (e, st) {
        incoming.addError(e, st);
      }
    }

    late StreamSubscription<RawSocketEvent> subscription;
    void finish() {
      if (closed) return;
      closed = true;
      secure.close();
      incoming.close();
    }

    subscription = secure.listen(
      (event) {
        if (closed) return;
        switch (event) {
          case RawSocketEvent.read:
            final bytes = secure.read();
            if (bytes != null) incoming.add(bytes);
          case RawSocketEvent.write:
            flush();
          case RawSocketEvent.readClosed:
          case RawSocketEvent.closed:
            finish();
        }
      },
      onError: (Object e, StackTrace st) {
        incoming.addError(e, st);
        finish();
      },
      onDone: finish,
    );
    incoming.onCancel = subscription.cancel;
    return _Connection(incoming.stream, (bytes) {
      pending.addAll(bytes);
      flush();
    }, finish);
  }
}

class _Raw {
  _Raw(this.status, this.headers, this.body);
  final int status;
  final Map<String, List<String>> headers;
  final String body;
}

/// Читает HTTP/1.1-ответы из потока сокета (Content-Length и chunked).
class _ResponseReader {
  _ResponseReader(Stream<List<int>> socket) {
    _sub = socket.listen(
      (d) {
        _buf.addAll(d);
        _parseSafely();
      },
      onError: (Object e) {
        _fail(e);
      },
      onDone: () {
        _fail(
          const SocketException(
            'EWS connection closed before response completed',
          ),
        );
      },
    );
  }

  late final StreamSubscription<List<int>> _sub;
  final List<int> _buf = [];
  Completer<_Raw>? _completer;
  Object? _terminalError;

  void _fail(Object error) {
    _terminalError = error;
    final pending = _completer;
    _completer = null;
    if (pending != null && !pending.isCompleted) pending.completeError(error);
  }

  void _parseSafely() {
    try {
      _tryParse();
    } catch (e) {
      _fail(e);
    }
  }

  Future<_Raw> next() {
    if (_terminalError case final error?) return Future.error(error);
    final c = Completer<_Raw>();
    _completer = c;
    _parseSafely();
    return c.future;
  }

  void _tryParse() {
    final c = _completer;
    if (c == null) return;
    final headerEnd = _indexOf(_buf, const [13, 10, 13, 10]);
    if (headerEnd < 0) return;
    final headerText = utf8.decode(
      _buf.sublist(0, headerEnd),
      allowMalformed: true,
    );
    final lines = headerText.split('\r\n');
    final status =
        int.tryParse(lines.first.split(' ').elementAtOrNull(1) ?? '') ?? 0;
    final headers = <String, List<String>>{};
    for (final l in lines.skip(1)) {
      final i = l.indexOf(':');
      if (i <= 0) continue;
      headers
          .putIfAbsent(l.substring(0, i).trim().toLowerCase(), () => [])
          .add(l.substring(i + 1).trim());
    }
    final bodyStart = headerEnd + 4;
    final chunked = (headers['transfer-encoding'] ?? []).any(
      (v) => v.toLowerCase().contains('chunked'),
    );

    if (chunked) {
      final body = _readChunked(_buf, bodyStart);
      if (body == null) return; // ждём ещё байты
      _consume(body.end);
      _complete(
        c,
        _Raw(status, headers, utf8.decode(body.bytes, allowMalformed: true)),
      );
    } else {
      final len = int.tryParse((headers['content-length'] ?? ['0']).first) ?? 0;
      if (_buf.length < bodyStart + len) return; // ждём тело
      final bodyBytes = _buf.sublist(bodyStart, bodyStart + len);
      _consume(bodyStart + len);
      _complete(
        c,
        _Raw(status, headers, utf8.decode(bodyBytes, allowMalformed: true)),
      );
    }
  }

  void _complete(Completer<_Raw> c, _Raw r) {
    _completer = null;
    if (!c.isCompleted) c.complete(r);
  }

  void _consume(int n) => _buf.removeRange(0, n);

  static int _indexOf(List<int> buf, List<int> pat) =>
      _indexOfFrom(buf, pat, 0);

  /// Поиск [pat] в [buf] начиная с [from] — БЕЗ копирования (иначе O(n²) на
  /// больших ответах: chunked-тела EWS в мегабайты деградировали до минут).
  static int _indexOfFrom(List<int> buf, List<int> pat, int from) {
    final n = buf.length, m = pat.length;
    for (var i = from; i + m <= n; i++) {
      var ok = true;
      for (var j = 0; j < m; j++) {
        if (buf[i + j] != pat[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  /// Декодирует chunked-тело начиная с [start]; null если данных ещё мало.
  static ({Uint8List bytes, int end})? _readChunked(List<int> buf, int start) {
    final out = <int>[];
    var pos = start;
    while (true) {
      final lineEnd = _indexOfFrom(buf, const [13, 10], pos);
      if (lineEnd < 0) return null;
      final sizeStr = utf8.decode(buf.sublist(pos, lineEnd));
      final size = int.tryParse(sizeStr.split(';').first.trim(), radix: 16);
      if (size == null || size < 0) {
        throw const FormatException('Invalid HTTP chunk size');
      }
      pos = lineEnd + 2;
      if (size == 0) {
        // The final CRLF (and optional trailers) can arrive in another packet.
        while (true) {
          final trailerEnd = _indexOfFrom(buf, const [13, 10], pos);
          if (trailerEnd < 0) return null;
          if (trailerEnd == pos) {
            return (bytes: Uint8List.fromList(out), end: pos + 2);
          }
          pos = trailerEnd + 2;
        }
      }
      if (buf.length < pos + size + 2) return null;
      out.addAll(buf.getRange(pos, pos + size));
      pos += size + 2;
    }
  }

  Future<void> close() => _sub.cancel();
}

extension<T> on List<T> {
  T? elementAtOrNull(int i) => (i >= 0 && i < length) ? this[i] : null;
}
