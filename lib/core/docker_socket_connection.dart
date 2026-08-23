import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  DockerSocketConnection({this.socketPath = '/var/run/docker.sock'});

  Future<Socket> _connectSocket() async {
    try {
      final address = InternetAddress(socketPath, type: InternetAddressType.unix);
      return await Socket.connect(address, 0);
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 13 || e.message.toLowerCase().contains('permission denied')) {
        throw DockerPermissionDeniedException(
          'Permission denied on $socketPath. Please ensure your user is added to the "docker" group.',
        );
      } else if (e.osError?.errorCode == 2 || e.message.toLowerCase().contains('no such file')) {
        throw DockerSocketNotFoundException(
          'Docker socket not found at $socketPath. Please verify Docker daemon is running.',
        );
      }
      rethrow;
    }
  }

  /// Sends a single HTTP request over Unix socket and returns response
  Future<RawHttpResponse> request({
    required String method,
    required String path,
    Map<String, String>? headers,
    String? body,
  }) async {
    final socket = await _connectSocket();

    final reqHeaders = <String, String>{
      'Host': 'localhost',
      'User-Agent': 'Bulkhead-Flutter/1.0',
      'Accept': 'application/json, */*',
      'Connection': 'close',
      if (body != null) 'Content-Type': 'application/json',
      if (body != null) 'Content-Length': utf8.encode(body).length.toString(),
      ...?headers,
    };

    final headerBuffer = StringBuffer();
    headerBuffer.write('$method $path HTTP/1.1\r\n');
    reqHeaders.forEach((key, value) {
      headerBuffer.write('$key: $value\r\n');
    });
    headerBuffer.write('\r\n');

    socket.write(headerBuffer.toString());
    if (body != null) {
      socket.write(body);
    }
    await socket.flush();

    final completer = Completer<RawHttpResponse>();
    final bytesBuilder = BytesBuilder();

    socket.listen(
      (data) {
        bytesBuilder.add(data);
      },
      onDone: () {
        final allBytes = bytesBuilder.takeBytes();
        completer.complete(_parseRawHttpResponse(allBytes));
      },
      onError: (err) {
        if (!completer.isCompleted) completer.completeError(err);
      },
    );

    return completer.future.whenComplete(() {
      socket.destroy();
    });
  }

  /// Streams raw bytes after HTTP response headers over Unix socket
  Stream<Uint8List> streamResponse({
    required String method,
    required String path,
    Map<String, String>? headers,
    String? body,
  }) async* {
    final socket = await _connectSocket();

    final reqHeaders = <String, String>{
      'Host': 'localhost',
      'User-Agent': 'Bulkhead-Flutter/1.0',
      'Accept': '*/*',
      if (body != null) 'Content-Type': 'application/json',
      if (body != null) 'Content-Length': utf8.encode(body).length.toString(),
      ...?headers,
    };

    final headerBuffer = StringBuffer();
    headerBuffer.write('$method $path HTTP/1.1\r\n');
    reqHeaders.forEach((key, value) {
      headerBuffer.write('$key: $value\r\n');
    });
    headerBuffer.write('\r\n');

    socket.write(headerBuffer.toString());
    if (body != null) {
      socket.write(body);
    }
    await socket.flush();

    bool headersParsed = false;
    final headerBufferBytes = BytesBuilder();

    try {
      await for (final chunk in socket) {
        if (!headersParsed) {
          headerBufferBytes.add(chunk);
          final bytes = headerBufferBytes.toBytes();

          // Find \r\n\r\n (13, 10, 13, 10)
          int headerEnd = -1;
          for (int i = 0; i <= bytes.length - 4; i++) {
            if (bytes[i] == 13 && bytes[i + 1] == 10 && bytes[i + 2] == 13 && bytes[i + 3] == 10) {
              headerEnd = i + 4;
              break;
            }
          }

          if (headerEnd != -1) {
            headersParsed = true;
            if (headerEnd < bytes.length) {
              yield Uint8List.fromList(bytes.sublist(headerEnd));
            }
          }
        } else {
          yield Uint8List.fromList(chunk);
        }
      }
    } finally {
      socket.destroy();
    }
  }

  RawHttpResponse _parseRawHttpResponse(Uint8List allBytes) {
    int headerEnd = -1;
    for (int i = 0; i <= allBytes.length - 4; i++) {
      if (allBytes[i] == 13 && allBytes[i + 1] == 10 && allBytes[i + 2] == 13 && allBytes[i + 3] == 10) {
        headerEnd = i + 4;
        break;
      }
    }

    if (headerEnd == -1) {
      // Full body without proper HTTP header or empty response
      return RawHttpResponse(
        statusCode: 500,
        statusReason: 'Invalid HTTP response format',
        headers: {},
        body: utf8.decode(allBytes, allowMalformed: true),
      );
    }

    final headerString = utf8.decode(allBytes.sublist(0, headerEnd - 4), allowMalformed: true);
    final rawBodyBytes = allBytes.sublist(headerEnd);

    final lines = headerString.split('\r\n');
    final statusLine = lines.isNotEmpty ? lines[0] : '';
    final statusParts = statusLine.split(' ');
    
    int statusCode = 200;
    String statusReason = 'OK';
    if (statusParts.length >= 2) {
      statusCode = int.tryParse(statusParts[1]) ?? 200;
    }
    if (statusParts.length >= 3) {
      statusReason = statusParts.sublist(2).join(' ');
    }

    final responseHeaders = <String, String>{};
    for (int i = 1; i < lines.length; i++) {
      final idx = lines[i].indexOf(':');
      if (idx != -1) {
        final k = lines[i].substring(0, idx).trim().toLowerCase();
        final v = lines[i].substring(idx + 1).trim();
        responseHeaders[k] = v;
      }
    }

    String decodedBody;
    final isChunked = responseHeaders['transfer-encoding']?.contains('chunked') ?? false;
    if (isChunked) {
      decodedBody = _decodeChunkedBody(rawBodyBytes);
    } else {
      decodedBody = utf8.decode(rawBodyBytes, allowMalformed: true);
    }

    return RawHttpResponse(
      statusCode: statusCode,
      statusReason: statusReason,
      headers: responseHeaders,
      body: decodedBody,
    );
  }

  String _decodeChunkedBody(Uint8List bytes) {
    final buffer = StringBuffer();
    int offset = 0;

    while (offset < bytes.length) {
      // Find \r\n after hex chunk size
      int lineEnd = -1;
      for (int i = offset; i < bytes.length - 1; i++) {
        if (bytes[i] == 13 && bytes[i + 1] == 10) {
          lineEnd = i;
          break;
        }
      }
      if (lineEnd == -1) break;

      final hexStr = utf8.decode(bytes.sublist(offset, lineEnd)).trim().split(';')[0];
      final chunkSize = int.tryParse(hexStr, radix: 16) ?? 0;

      if (chunkSize == 0) break;

      final dataStart = lineEnd + 2;
      final dataEnd = dataStart + chunkSize;
      if (dataEnd > bytes.length) {
        buffer.write(utf8.decode(bytes.sublist(dataStart), allowMalformed: true));
        break;
      }

      buffer.write(utf8.decode(bytes.sublist(dataStart, dataEnd), allowMalformed: true));
      offset = dataEnd + 2; // skip \r\n after chunk data
    }

    return buffer.toString();
  }
}
