import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'windows_pipe_socket.dart';

class DockerPermissionDeniedException implements Exception {
  final String message;
  DockerPermissionDeniedException(this.message);
  @override
  String toString() => message;
}

class DockerSocketNotFoundException implements Exception {
  final String message;
  DockerSocketNotFoundException(this.message);
  @override
  String toString() => message;
}

class RawHttpResponse {
  final int statusCode;
  final String statusReason;
  final Map<String, String> headers;
  final String body;

  RawHttpResponse({
    required this.statusCode,
    required this.statusReason,
    required this.headers,
    required this.body,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class DockerSocketConnection {
  final String socketPath;

  static String get defaultSocketPath {
    if (Platform.isWindows) {
      return r'\\.\pipe\docker_engine';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      final userSock = '$home/.docker/run/docker.sock';
      if (File(userSock).existsSync()) return userSock;

      final orbstackSock = '$home/.orbstack/run/docker.sock';
      if (File(orbstackSock).existsSync()) return orbstackSock;

      final colimaSock = '$home/.colima/default/docker.sock';
      if (File(colimaSock).existsSync()) return colimaSock;

      return '/var/run/docker.sock';
    }
    return '/var/run/docker.sock';
  }

  DockerSocketConnection({String? socketPath})
    : socketPath = socketPath ?? defaultSocketPath;

  Future<Socket> _connectSocket() async {
    try {
      if (socketPath.startsWith('tcp://') || socketPath.startsWith('http://')) {
        final uri = Uri.parse(socketPath);
        return await Socket.connect(
          uri.host,
          uri.port != 0 ? uri.port : 2375,
          timeout: const Duration(seconds: 10),
        );
      }
      if (Platform.isWindows) {
        return await WindowsPipeSocket.connect(socketPath);
      }
      final address = InternetAddress(
        socketPath,
        type: InternetAddressType.unix,
      );
      return await Socket.connect(
        address,
        0,
        timeout: const Duration(seconds: 10),
      );
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 13 ||
          (Platform.isWindows && e.osError?.errorCode == 5) ||
          e.message.toLowerCase().contains('permission denied')) {
        throw DockerPermissionDeniedException(
          'Permission denied on $socketPath. Please ensure your user is added to the "docker" group.',
        );
      } else if (e.osError?.errorCode == 2 ||
          e.message.toLowerCase().contains('no such file')) {
        throw DockerSocketNotFoundException(
          'Docker socket not found at $socketPath. Please verify Docker daemon is running.',
        );
      }
      rethrow;
    }
  }

  // Let the standard HTTP client decode chunk boundaries and response lengths.
  HttpClient _httpClient() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      var cancelled = false;
      Socket? connected;
      final pending = _connectSocket().then((socket) {
        connected = socket;
        if (cancelled) {
          socket.destroy();
          throw const SocketException('Docker connection cancelled');
        }
        return socket;
      });
      return ConnectionTask.fromSocket(pending, () {
        cancelled = true;
        connected?.destroy();
      });
    };
    return client;
  }

  Future<HttpClientResponse> _open(
    HttpClient client,
    String method,
    String path,
    Map<String, String>? headers,
    String? body,
  ) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://localhost$path'),
    );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json, */*');
    headers?.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(body));
    }
    return request.close().timeout(const Duration(seconds: 30));
  }

  Future<RawHttpResponse> request({
    required String method,
    required String path,
    Map<String, String>? headers,
    String? body,
  }) async {
    final client = _httpClient();
    try {
      final response = await _open(client, method, path, headers, body);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      final responseHeaders = <String, String>{};
      response.headers.forEach(
        (key, values) => responseHeaders[key] = values.join(', '),
      );
      return RawHttpResponse(
        statusCode: response.statusCode,
        statusReason: response.reasonPhrase,
        headers: responseHeaders,
        body: text,
      );
    } finally {
      client.close(force: true);
    }
  }

  Stream<Uint8List> streamResponse({
    required String method,
    required String path,
    Map<String, String>? headers,
    String? body,
  }) async* {
    final client = _httpClient();
    try {
      final response = await _open(client, method, path, headers, body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 30));
        throw HttpException('Docker returned ${response.statusCode}: $message');
      }
      await for (final chunk in response) {
        yield Uint8List.fromList(chunk);
      }
    } finally {
      client.close(force: true);
    }
  }
}
