import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:calenfi/data/providers/calendar/ews/ntlm_http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ServerSocket server;
  final peers = <Socket>[];
  late NtlmHttp client;
  late Uri url;
  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('https://127.0.0.1:${server.port}/ews');
    client = NtlmHttp(
      user: 'test',
      password: 'test',
      responseTimeout: const Duration(milliseconds: 500),
      connect: (uri, timeout) =>
          Socket.connect(uri.host, uri.port, timeout: timeout),
    );
  });
  tearDown(() async {
    for (final peer in peers) {
      peer.destroy();
    }
    peers.clear();
    await server.close();
  });
  void respond(void Function(Socket) handler) {
    server.listen((peer) {
      peers.add(peer);
      var called = false;
      peer.listen((_) {
        if (!called) {
          called = true;
          handler(peer);
        }
      }, onError: (_) {});
    });
  }

  test(
    'real TLS transport sends a large request and reads the response',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'calenfi-tls-test-',
      );
      SecureServerSocket? tlsServer;
      final tlsPeers = <SecureSocket>[];
      try {
        final generated = await Process.run('openssl', [
          'req',
          '-x509',
          '-newkey',
          'rsa:2048',
          '-nodes',
          '-keyout',
          '${directory.path}/key.pem',
          '-out',
          '${directory.path}/cert.pem',
          '-days',
          '1',
          '-subj',
          '/CN=localhost',
        ]);
        expect(generated.exitCode, 0);
        final context = SecurityContext()
          ..useCertificateChain('${directory.path}/cert.pem')
          ..usePrivateKey('${directory.path}/key.pem');
        tlsServer = await SecureServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
          context,
        );
        final body = 'query' * 200000;
        final received = Completer<String>();
        tlsServer.listen((peer) {
          tlsPeers.add(peer);
          final bytes = <int>[];
          peer.listen((data) {
            bytes.addAll(data);
            final text = utf8.decode(bytes, allowMalformed: true);
            final headerEnd = text.indexOf('\r\n\r\n');
            if (headerEnd >= 0 &&
                text.length >= headerEnd + 4 + body.length &&
                !received.isCompleted) {
              received.complete(text.substring(headerEnd + 4));
              peer.add(
                utf8.encode('HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok'),
              );
            }
          }, onError: (_) {});
        });
        final realClient = NtlmHttp(
          user: 'test',
          password: 'test',
          connectTimeout: const Duration(seconds: 5),
          responseTimeout: const Duration(seconds: 5),
        );
        final result = await realClient.post(
          Uri.parse('https://127.0.0.1:${tlsServer.port}/ews'),
          body: body,
        );
        expect(result.body, 'ok');
        expect(await received.future, body);
      } finally {
        for (final peer in tlsPeers) {
          peer.destroy();
        }
        await tlsServer?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('TLS handshake timeout releases a silent connection', () async {
    final disconnected = Completer<void>();
    server.listen((peer) {
      peers.add(peer);
      peer.listen(
        (_) {},
        onDone: () {
          if (!disconnected.isCompleted) disconnected.complete();
        },
        onError: (_) {},
      );
    });
    final tlsClient = NtlmHttp(
      user: 'test',
      password: 'test',
      connectTimeout: const Duration(milliseconds: 80),
    );
    await expectLater(
      tlsClient.post(url, body: 'query'),
      throwsA(isA<TimeoutException>()),
    );
    await disconnected.future.timeout(const Duration(seconds: 2));
  });

  test(
    'silent connection times out, is closed, and next request succeeds',
    () async {
      var calls = 0;
      final closed = Completer<void>();
      server.listen((peer) {
        peers.add(peer);
        final number = ++calls;
        var answered = false;
        peer.listen(
          (_) {
            if (number == 2 && !answered) {
              answered = true;
              peer.add(
                utf8.encode('HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok'),
              );
            }
          },
          onDone: () {
            if (number == 1 && !closed.isCompleted) closed.complete();
          },
        );
      });
      await expectLater(
        client.post(url, body: 'query'),
        throwsA(isA<TimeoutException>()),
      );
      await closed.future.timeout(const Duration(seconds: 2));
      expect((await client.post(url, body: 'query')).body, 'ok');
      expect(calls, 2);
    },
  );
  for (final partial in [
    '',
    'HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nx',
  ]) {
    test(
      'EOF completes request with an error (partial=${partial.isNotEmpty})',
      () async {
        respond((peer) async {
          peer.add(utf8.encode(partial));
          await peer.flush();
          await peer.close();
        });
        await expectLater(
          client.post(url, body: 'query'),
          throwsA(isA<SocketException>()),
        );
      },
    );
  }
  test(
    'chunk terminator split across packets waits for the final CRLF',
    () async {
      respond((peer) async {
        peer.add(
          utf8.encode(
            'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n0\r\n',
          ),
        );
        await peer.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        peer.add(utf8.encode('\r\n'));
      });
      expect((await client.post(url, body: 'query')).body, 'ok');
    },
  );
  test('chunk trailers are consumed before completing', () async {
    respond((peer) {
      peer.add(
        utf8.encode(
          'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n0\r\nX-Trailer: yes\r\n\r\n',
        ),
      );
    });
    expect((await client.post(url, body: 'query')).body, 'ok');
  });
  test('malformed chunk rejects the request instead of hanging', () async {
    respond((peer) {
      peer.add(
        utf8.encode(
          'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nxyz\r\n',
        ),
      );
    });
    await expectLater(
      client.post(url, body: 'query'),
      throwsA(isA<FormatException>()),
    );
  });
}
