import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bulkhead/core/docker_api_client.dart';
import 'package:bulkhead/core/docker_socket_connection.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSocket extends DockerSocketConnection {
  final bool tty;
  final int exitCode;
  final List<int> bytes;
  final List<String> paths = [];
  final Map<String, int> statuses;
  String? execBody;

  FakeSocket({
    this.tty = false,
    this.exitCode = 0,
    this.bytes = const [],
    this.statuses = const {},
  });

  @override
  Future<RawHttpResponse> request({
    required String method,
    required String path,
    Map<String, String>? headers,
    String? body,
  }) async {
    paths.add(path);
    if (path.endsWith('/exec')) execBody = body;
    return RawHttpResponse(
      statusCode: statuses[path] ?? 200,
      statusReason: '',
      headers: {},
      body: path.endsWith('/json')
          ? jsonEncode({
              'Config': {'Tty': tty},
              'ExitCode': exitCode,
            })
          : path.endsWith('/exec')
          ? '{"Id":"exec1"}'
          : '{}',
    );
  }

  @override
  Stream<Uint8List> streamResponse({
    required String method,
    required String path,
    Map<String, String>? headers,
    String? body,
  }) async* {
    paths.add(path);
    // Every byte gets its own network packet, including UTF-8 and frame headers.
    for (final byte in bytes) {
      yield Uint8List.fromList([byte]);
    }
  }
}

List<int> frame(String text, {int stream = 1}) {
  final data = utf8.encode(text);
  return [stream, 0, 0, 0, 0, 0, data.length >> 8, data.length & 255, ...data];
}

void main() {
  test(
    'demultiplexes fragmented log frames without losing Unicode or final lines',
    () async {
      final socket = FakeSocket(
        bytes: [
          ...frame('café\n'),
          ...frame('deadbeef\n  indented\nlast', stream: 2),
        ],
      );
      final lines = await DockerApiClient(
        socket: socket,
      ).streamContainerLogs('test').toList();
      expect(lines, ['café', 'deadbeef', '  indented', 'last']);
    },
  );

  test('TTY output preserves hex lines and split Unicode', () async {
    final socket = FakeSocket(
      tty: true,
      bytes: utf8.encode('42\nمرحبا\nfinal'),
    );
    expect(
      await DockerApiClient(
        socket: socket,
      ).streamContainerLogs('test').toList(),
      ['42', 'مرحبا', 'final'],
    );
  });

  test('truncated Docker log frames report an error', () async {
    final socket = FakeSocket(bytes: frame('missing').sublist(0, 10));
    await expectLater(
      DockerApiClient(socket: socket).streamContainerLogs('test').toList(),
      throwsFormatException,
    );
  });

  test('pull keeps registry ports, tags, and digests intact', () async {
    for (final reference in [
      'localhost:5000/team/app:1.2',
      'alpine@sha256:abcdef',
      'alpine',
    ]) {
      final socket = FakeSocket();
      await DockerApiClient(socket: socket).pullImage(reference).drain<void>();
      expect(
        Uri.parse(socket.paths.single).queryParameters['fromImage'],
        reference,
      );
    }
  });

  test('Docker pull error objects fail the operation', () async {
    final socket = FakeSocket(
      bytes: utf8.encode('{"error":"access denied"}\n'),
    );
    await expectLater(
      DockerApiClient(socket: socket).pullImage('private').toList(),
      throwsStateError,
    );
  });

  test(
    'prune stops and reports failure instead of returning false success',
    () async {
      final socket = FakeSocket(statuses: {'/images/prune': 500});
      await expectLater(
        DockerApiClient(socket: socket).systemPruneAll(),
        throwsException,
      );
      expect(socket.paths, ['/containers/prune', '/images/prune']);
    },
  );

  test('file browser quotes shell metacharacters as a literal path', () async {
    const path = "/tmp/a'\$(touch /tmp/unwanted)";
    final socket = FakeSocket();
    await DockerApiClient(socket: socket).listContainerFiles('test', path);
    final command = (jsonDecode(socket.execBody!)['Cmd'] as List).last;
    expect(
      command,
      startsWith('directory=\'/tmp/a\'"\'"\'\$(touch /tmp/unwanted)\'\n'),
    );
  });
  test(
    'JSON streams retain Unicode and a final record without a newline',
    () async {
      final socket = FakeSocket(bytes: utf8.encode('{"status":"café"}'));
      expect(
        await DockerApiClient(socket: socket).pullImage('alpine').toList(),
        [
          {'status': 'café'},
        ],
      );
    },
  );

  test('a final pull error without a newline is still reported', () async {
    final socket = FakeSocket(bytes: utf8.encode('{"error":"denied"}'));
    await expectLater(
      DockerApiClient(socket: socket).pullImage('private').toList(),
      throwsStateError,
    );
  });
  test('container removal preserves attached anonymous volumes', () async {
    final socket = FakeSocket();
    await DockerApiClient(
      socket: socket,
    ).removeContainer('database', force: true);
    expect(socket.paths.single, '/containers/database?v=0&force=1');
  });
  test(
    'nonzero exec status reports directory errors instead of an empty folder',
    () async {
      final socket = FakeSocket(
        exitCode: 1,
        bytes: frame('Permission denied\n', stream: 2),
      );
      await expectLater(
        DockerApiClient(socket: socket).listContainerFiles('test', '/denied'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Permission denied'),
          ),
        ),
      );
    },
  );

  test(
    'directory records preserve repeated spaces, newlines, Unicode and shell characters',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        "bulkhead-a'quote-",
      );
      addTearDown(() => directory.delete(recursive: true));
      final names = [
        'two  spaces',
        'line\nbreak',
        'café',
        '\$(touch sentinel)',
        '.hidden',
      ];
      for (final name in names) {
        await File('${directory.path}/$name').writeAsString('data');
      }
      final capture = FakeSocket();
      await DockerApiClient(
        socket: capture,
      ).listContainerFiles('test', directory.path);
      final command =
          (jsonDecode(capture.execBody!)['Cmd'] as List).last as String;
      final local = await Process.run('sh', [
        '-c',
        command,
      ], workingDirectory: directory.path);
      expect(local.exitCode, 0, reason: local.stderr.toString());
      expect(await File('${directory.path}/sentinel').exists(), isFalse);
      final socket = FakeSocket(bytes: frame(local.stdout as String));
      final files = await DockerApiClient(
        socket: socket,
      ).listContainerFiles('test', directory.path);
      expect(files.map((file) => file['name']), unorderedEquals(names));
    },
    skip: !Platform.isLinux,
  );
}
