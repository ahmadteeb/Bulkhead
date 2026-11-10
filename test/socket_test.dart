import 'dart:convert';
import 'dart:io';

import 'package:bulkhead/core/docker_socket_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(DockerSocketConnection, ServerSocket)> serve(String response) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      var sent = false;
      socket.listen((_) async {
        if (sent) return;
        sent = true;
        // Fragment across HTTP headers, chunks and Unicode boundaries.
        for (final byte in utf8.encode(response)) {
          socket.add([byte]);
          await socket.flush();
        }
        await socket.close();
      });
    });
    return (
      DockerSocketConnection(socketPath: 'tcp://127.0.0.1:${server.port}'),
      server,
    );
  }

  test('transport decodes HTTP chunking before consumers see bytes', () async {
    final (connection, server) = await serve(
      'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n'
      '3\r\nabc\r\n3\r\ndef\r\n0\r\n\r\n',
    );
    addTearDown(server.close);
    final bytes = await connection
        .streamResponse(method: 'GET', path: '/events')
        .expand((bytes) => bytes)
        .toList();
    expect(utf8.decode(bytes), 'abcdef');
  });

  test('transport surfaces HTTP errors on streaming endpoints', () async {
    final (connection, server) = await serve(
      'HTTP/1.1 404 Not Found\r\nContent-Length: 7\r\nConnection: close\r\n\r\nmissing',
    );
    addTearDown(server.close);
    await expectLater(
      connection.streamResponse(method: 'GET', path: '/events').toList(),
      throwsA(isA<HttpException>()),
    );
  });

  test('request body decoder preserves Unicode split over HTTP chunks', () async {
    final (connection, server) = await serve(
      'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n'
      '5\r\ncafé\r\n0\r\n\r\n',
    );
    addTearDown(server.close);
    final response = await connection.request(method: 'GET', path: '/_ping');
    expect(response.body, 'café');
  });
}
