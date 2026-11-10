import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bulkhead/core/docker_socket_connection.dart';
import 'package:bulkhead/core/windows_pipe_socket.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(Process, StreamIterator<String>, String)> servePipe({
  bool stall = false,
}) async {
  final name = 'bulkhead-test-$pid-${DateTime.now().microsecondsSinceEpoch}';
  final response = stall
      ? 'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n'
      : 'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n3\r\nabc\r\n3\r\ndef\r\n0\r\n\r\n';
  final script =
      '''
\$ErrorActionPreference = 'Stop'
\$pipe = [IO.Pipes.NamedPipeServerStream]::new('$name', [IO.Pipes.PipeDirection]::InOut)
try {
  [Console]::WriteLine('READY')
  \$pipe.WaitForConnection()
  \$headers = ''
  while (-not \$headers.EndsWith("`r`n`r`n")) {
    \$byte = \$pipe.ReadByte()
    if (\$byte -eq -1) { throw 'Client closed before headers' }
    \$headers += [char]\$byte
  }
  \$response = [Convert]::FromBase64String('${base64Encode(utf8.encode(response))}')
  \$pipe.Write(\$response, 0, \$response.Length)
  \$pipe.Flush()
  ${stall ? '\$null = \$pipe.ReadByte()' : ''}
} finally { \$pipe.Dispose() }
[Console]::WriteLine('CLOSED')
''';
  final encoded = base64Encode([
    for (final unit in script.codeUnits) ...[unit & 255, unit >> 8],
  ]);
  final process = await Process.start('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-EncodedCommand',
    encoded,
  ]);
  final stderr = process.stderr.transform(utf8.decoder).join();
  final lines = StreamIterator(
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );
  addTearDown(() async {
    process.kill();
    await lines.cancel();
    await process.exitCode.timeout(const Duration(seconds: 5));
    await stderr;
  });
  expect(await lines.moveNext().timeout(const Duration(seconds: 10)), isTrue);
  expect(lines.current, 'READY');
  return (process, lines, r'\\.\pipe\' + name);
}

void main() {
  test('named pipe transport decodes real HTTP responses', () async {
    final (_, _, path) = await servePipe();
    final response = await DockerSocketConnection(
      socketPath: path,
    ).request(method: 'GET', path: '/_ping');
    expect(response.body, 'abcdef');
  }, skip: !Platform.isWindows);

  test('cancelling an idle pipe stream closes the server connection', () async {
    final (process, lines, path) = await servePipe(stall: true);
    final received = Completer<void>();
    final subscription = DockerSocketConnection(socketPath: path)
        .streamResponse(method: 'GET', path: '/events')
        .listen((data) {
          if (!received.isCompleted) received.complete();
        });
    await received.future.timeout(const Duration(seconds: 10));
    await subscription.cancel().timeout(const Duration(seconds: 5));
    expect(await lines.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(lines.current, 'CLOSED');
    expect(await process.exitCode, 0);
  }, skip: !Platform.isWindows);

  test(
    'missing pipe reports a socket error without falling back to TCP',
    () async {
      await expectLater(
        WindowsPipeSocket.connect(r'\\.\pipe\bulkhead-missing-pipe'),
        throwsA(isA<SocketException>()),
      );
    },
    skip: !Platform.isWindows,
  );
}
