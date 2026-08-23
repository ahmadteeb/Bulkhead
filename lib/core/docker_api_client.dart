import 'dart:async';
import 'dart:convert';

import '../models/container_model.dart';
import '../models/docker_event_model.dart';
import '../models/image_model.dart';
import '../models/network_model.dart';
import '../models/volume_model.dart';
import 'docker_socket_connection.dart';

class DockerApiClient {
  final DockerSocketConnection _socket;

  DockerApiClient({DockerSocketConnection? socket})
      : _socket = socket ?? DockerSocketConnection();

  /// Ping Docker engine to test connection
  Future<bool> ping() async {
    final res = await _socket.request(method: 'GET', path: '/_ping');
    return res.isSuccess && res.body.trim() == 'OK';
  }

  // --- CONTAINERS ---

  /// List containers
  Future<List<ContainerModel>> getContainers({bool showAll = true}) async {
    final res = await _socket.request(
      method: 'GET',
      path: '/containers/json?all=${showAll ? 1 : 0}',
    );

    if (!res.isSuccess) {
      throw Exception('Failed to list containers: ${res.statusCode} ${res.body}');
    }

    final List<dynamic> decoded = jsonDecode(res.body);
    return decoded.map((item) => ContainerModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Create and start a container (`POST /containers/create`)
  Future<String> createContainer({
    required String name,
    required String image,
    List<String>? env,
    Map<String, String>? portMappings,
    bool autoStart = true,
  }) async {
    final portBindings = <String, dynamic>{};
    final exposedPorts = <String, dynamic>{};

    if (portMappings != null) {
      portMappings.forEach((containerPort, hostPort) {
        final key = containerPort.contains('/') ? containerPort : '$containerPort/tcp';
        exposedPorts[key] = {};
        portBindings[key] = [
          {'HostPort': hostPort}
        ];
      });
    }

    final bodyMap = <String, dynamic>{
      'Image': image,
      'ExposedPorts': exposedPorts,
      'HostConfig': {
        'PortBindings': portBindings,
        'RestartPolicy': {'Name': 'unless-stopped'},
      },
    };
    if (env != null && env.isNotEmpty) {
      bodyMap['Env'] = env;
    }

    final body = jsonEncode(bodyMap);
    final res = await _socket.request(
      method: 'POST',
      path: '/containers/create?name=${Uri.encodeComponent(name)}',
      body: body,
    );

    if (!res.isSuccess) {
      throw Exception('Failed to create container: ${res.body}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final id = map['Id'] as String;

    if (autoStart) {
      await startContainer(id);
    }
    return id;
  }

  /// Inspect a single container
  Future<Map<String, dynamic>> inspectContainer(String id) async {
    final res = await _socket.request(method: 'GET', path: '/containers/$id/json');
    if (!res.isSuccess) {
      throw Exception('Failed to inspect container $id: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Start a container
  Future<void> startContainer(String id) async {
    final res = await _socket.request(method: 'POST', path: '/containers/$id/start');
    if (!res.isSuccess && res.statusCode != 304) {
      throw Exception('Failed to start container: ${res.body}');
    }
  }

  /// Stop a container
  Future<void> stopContainer(String id) async {
    final res = await _socket.request(method: 'POST', path: '/containers/$id/stop');
    if (!res.isSuccess && res.statusCode != 304) {
      throw Exception('Failed to stop container: ${res.body}');
    }
  }

  /// Restart a container
  Future<void> restartContainer(String id) async {
    final res = await _socket.request(method: 'POST', path: '/containers/$id/restart');
    if (!res.isSuccess) {
      throw Exception('Failed to restart container: ${res.body}');
    }
  }

  /// Remove a container
  Future<void> removeContainer(String id, {bool force = false}) async {
    final res = await _socket.request(
      method: 'DELETE',
      path: '/containers/$id?v=1&force=${force ? 1 : 0}',
    );
    if (!res.isSuccess) {
      throw Exception('Failed to remove container: ${res.body}');
    }
  }

  /// Stream live container logs with HTTP chunk header stripping and 8-byte frame demuxer
  Stream<String> streamContainerLogs(String id, {int tail = 200, bool follow = true}) async* {
    final path = '/containers/$id/logs?follow=${follow ? "true" : "false"}&stdout=true&stderr=true&timestamps=true&tail=$tail';
    final stream = _socket.streamResponse(method: 'GET', path: path);

    final lineBuffer = StringBuffer();

    await for (final chunk in stream) {
      final rawText = utf8.decode(chunk, allowMalformed: true);
      lineBuffer.write(rawText);

      final content = lineBuffer.toString();
      final lines = content.split('\n');

      lineBuffer.clear();
      lineBuffer.write(lines.last);

      for (int i = 0; i < lines.length - 1; i++) {
        String line = lines[i].replaceAll('\r', '').trim();
        if (line.isEmpty) continue;

        // 1. Strip HTTP chunk length hex lines (e.g., "84", "6f", "28", "42")
        final isHexChunkHeader = RegExp(r'^[0-9a-fA-F]{1,6}$').hasMatch(line);
        if (isHexChunkHeader) continue;

        // 2. Strip 8-byte Docker stream header prefix (e.g. "\x01\x00\x00\x00...")
        if (line.length > 8 && (line.startsWith('\x01') || line.startsWith('\x02') || line.startsWith('\x00'))) {
          line = line.substring(8).trim();
        }

        // 3. Filter remaining control character junk at start of line
        line = line.replaceAll(RegExp(r'^[\x00-\x1F\x7F-\x9F]+'), '').trim();

        if (line.isNotEmpty) {
          yield line;
        }
      }
    }
  }

  /// Create an exec instance inside a running container
  Future<String> createExec(String containerId, List<String> cmd) async {
    final body = jsonEncode({
      'AttachStdout': true,
      'AttachStderr': true,
      'Tty': true,
      'Cmd': cmd,
    });
    final res = await _socket.request(
      method: 'POST',
      path: '/containers/$containerId/exec',
      body: body,
      headers: {'Content-Type': 'application/json'},
    );
    if (!res.isSuccess) {
      throw Exception('Failed to create exec: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['Id'] as String;
  }

  /// Start an exec instance and stream output text
  Stream<String> startExec(String execId) async* {
    final body = jsonEncode({'Detach': false, 'Tty': true});
    final stream = _socket.streamResponse(
      method: 'POST',
      path: '/exec/$execId/start',
      body: body,
      headers: {'Content-Type': 'application/json'},
    );

    await for (final chunk in stream) {
      final text = utf8.decode(chunk, allowMalformed: true);
      for (final line in text.split('\n')) {
        final cleaned = line.replaceAll('\r', '').trim();
        if (cleaned.isNotEmpty && !RegExp(r'^[0-9a-fA-F]{1,6}$').hasMatch(cleaned)) {
          yield line;
        }
      }
    }
  }

  /// Execute command inside container CLI using selected shell and return full output
  Future<String> execCommand(String containerId, String command, {String shell = 'sh'}) async {
    final execId = await createExec(containerId, [shell, '-c', command]);
    final buffer = StringBuffer();
    await for (final line in startExec(execId)) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  /// List files in a path inside container or mounted volume via exec
  Future<List<Map<String, String>>> listContainerFiles(String containerId, String path) async {
    final raw = await execCommand(containerId, 'ls -la "$path" 2>/dev/null || ls -la "$path"');
    final lines = raw.split('\n');
    final List<Map<String, String>> files = [];

    for (final line in lines) {
      final trimmed = line.replaceAll('\r', '').trim();
      if (trimmed.isEmpty || trimmed.startsWith('total')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 9) {
        final permissions = parts[0];
        final isDir = permissions.startsWith('d');
        final size = parts[4];
        String fullPathName = parts.sublist(8).join(' ');
        if (fullPathName.contains(' -> ')) {
          fullPathName = fullPathName.split(' -> ').first;
        }
        final name = fullPathName.trim();
        if (name == '.' || name == '..') continue;
        files.add({
          'name': name,
          'permissions': permissions,
          'size': size,
          'isDir': isDir ? 'true' : 'false',
        });
      }
    }
    return files;
  }

  /// Stream container stats (CPU %, memory usage)
  Stream<Map<String, dynamic>> streamContainerStats(String id) async* {
    final path = '/containers/$id/stats?stream=true';
    final stream = _socket.streamResponse(method: 'GET', path: path);

    final lineBuffer = StringBuffer();

    await for (final chunk in stream) {
      final chunkText = utf8.decode(chunk, allowMalformed: true);
      lineBuffer.write(chunkText);

      final content = lineBuffer.toString();
      final lines = content.split('\n');

      // Keep last incomplete segment in buffer
      lineBuffer.clear();
      lineBuffer.write(lines.last);

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            final parsed = jsonDecode(line);
            if (parsed is Map<String, dynamic>) {
              yield parsed;
            }
          } catch (_) {
            // Ignore malformed chunk boundary lines
          }
        }
      }
    }
  }

  // --- IMAGES ---

  /// List Docker images
  Future<List<ImageModel>> getImages({bool showAll = true}) async {
    final res = await _socket.request(method: 'GET', path: '/images/json?all=${showAll ? 1 : 0}');
    if (!res.isSuccess) {
      throw Exception('Failed to list images: ${res.body}');
    }
    final List<dynamic> decoded = jsonDecode(res.body);
    return decoded.map((item) => ImageModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Pull image with streaming progress updates
  Stream<Map<String, dynamic>> pullImage(String imageName) async* {
    String fromImage = imageName;
    String tag = 'latest';
    if (imageName.contains(':')) {
      final parts = imageName.split(':');
      fromImage = parts[0];
      tag = parts[1];
    }

    final path = '/images/create?fromImage=${Uri.encodeComponent(fromImage)}&tag=${Uri.encodeComponent(tag)}';
    final stream = _socket.streamResponse(method: 'POST', path: path);

    final lineBuffer = StringBuffer();

    await for (final chunk in stream) {
      final text = utf8.decode(chunk, allowMalformed: true);
      lineBuffer.write(text);

      final content = lineBuffer.toString();
      final lines = content.split('\n');

      lineBuffer.clear();
      lineBuffer.write(lines.last);

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            final obj = jsonDecode(line);
            if (obj is Map<String, dynamic>) {
              yield obj;
            }
          } catch (_) {}
        }
      }
    }
  }

  /// Remove an image
  Future<void> removeImage(String id, {bool force = false}) async {
    final res = await _socket.request(
      method: 'DELETE',
      path: '/images/$id?force=${force ? 1 : 0}',
    );
    if (!res.isSuccess) {
      throw Exception('Failed to remove image: ${res.body}');
    }
  }

  /// Prune unused images
  Future<Map<String, dynamic>> pruneImages() async {
    final res = await _socket.request(method: 'POST', path: '/images/prune');
    if (!res.isSuccess) {
      throw Exception('Failed to prune images: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // --- VOLUMES ---

  /// List Docker volumes
  Future<List<VolumeModel>> getVolumes() async {
    final res = await _socket.request(method: 'GET', path: '/volumes');
    if (!res.isSuccess) {
      throw Exception('Failed to list volumes: ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (map['Volumes'] as List<dynamic>?) ?? [];
    return list.map((item) => VolumeModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Create a volume
  Future<VolumeModel> createVolume(String name, {String driver = 'local'}) async {
    final body = jsonEncode({
      'Name': name,
      'Driver': driver,
    });
    final res = await _socket.request(method: 'POST', path: '/volumes/create', body: body);
    if (!res.isSuccess) {
      throw Exception('Failed to create volume: ${res.body}');
    }
    return VolumeModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Remove a volume
  Future<void> removeVolume(String name, {bool force = false}) async {
    final res = await _socket.request(
      method: 'DELETE',
      path: '/volumes/$name?force=${force ? 1 : 0}',
    );
    if (!res.isSuccess) {
      throw Exception('Failed to remove volume: ${res.body}');
    }
  }

  /// Prune unused volumes
  Future<Map<String, dynamic>> pruneVolumes() async {
    final res = await _socket.request(method: 'POST', path: '/volumes/prune');
    if (!res.isSuccess) {
      throw Exception('Failed to prune volumes: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // --- NETWORKS ---

  /// List Docker networks
  Future<List<NetworkModel>> getNetworks() async {
    final res = await _socket.request(method: 'GET', path: '/networks');
    if (!res.isSuccess) {
      throw Exception('Failed to list networks: ${res.body}');
    }
    final List<dynamic> decoded = jsonDecode(res.body);
    return decoded.map((item) => NetworkModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Create network
  Future<NetworkModel> createNetwork(String name, {String driver = 'bridge'}) async {
    final body = jsonEncode({
      'Name': name,
      'Driver': driver,
      'CheckDuplicate': true,
    });
    final res = await _socket.request(method: 'POST', path: '/networks/create', body: body);
    if (!res.isSuccess) {
      throw Exception('Failed to create network: ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final id = map['Id'] as String? ?? '';
    return NetworkModel(
      id: id,
      name: name,
      driver: driver,
      scope: 'local',
      internal: false,
      containers: {},
      labels: {},
    );
  }

  /// Remove network
  Future<void> removeNetwork(String id) async {
    final res = await _socket.request(method: 'DELETE', path: '/networks/$id');
    if (!res.isSuccess) {
      throw Exception('Failed to remove network: ${res.body}');
    }
  }

  // --- SYSTEM & EVENTS ---

  /// System Disk Usage (`docker system df`)
  Future<Map<String, dynamic>> getSystemDf() async {
    final res = await _socket.request(method: 'GET', path: '/system/df');
    if (!res.isSuccess) {
      throw Exception('Failed to get system df: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// System Prune All (`docker system prune -a --volumes`)
  Future<Map<String, dynamic>> systemPruneAll() async {
    final containersRes = await _socket.request(method: 'POST', path: '/containers/prune');
    final imagesRes = await _socket.request(method: 'POST', path: '/images/prune?all=1');
    final volumesRes = await _socket.request(method: 'POST', path: '/volumes/prune');
    final networksRes = await _socket.request(method: 'POST', path: '/networks/prune');

    return {
      'containers': containersRes.isSuccess ? jsonDecode(containersRes.body) : {},
      'images': imagesRes.isSuccess ? jsonDecode(imagesRes.body) : {},
      'volumes': volumesRes.isSuccess ? jsonDecode(volumesRes.body) : {},
      'networks': networksRes.isSuccess ? jsonDecode(networksRes.body) : {},
    };
  }

  /// Real-time event stream (`/events`)
  Stream<DockerEventModel> streamEvents() async* {
    final stream = _socket.streamResponse(method: 'GET', path: '/events');
    final lineBuffer = StringBuffer();

    await for (final chunk in stream) {
      final text = utf8.decode(chunk, allowMalformed: true);
      lineBuffer.write(text);

      final content = lineBuffer.toString();
      final lines = content.split('\n');

      lineBuffer.clear();
      lineBuffer.write(lines.last);

      for (int i = 0; i < lines.length - 1; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        // Clean HTTP Chunked encoding hex prefixes (e.g. "1a4\r\n{...}")
        final jsonStart = line.indexOf('{');
        if (jsonStart != -1) {
          line = line.substring(jsonStart);
        }
        final jsonEnd = line.lastIndexOf('}');
        if (jsonEnd != -1 && jsonEnd >= jsonStart) {
          line = line.substring(0, jsonEnd + 1);
        }

        if (line.startsWith('{') && line.endsWith('}')) {
          try {
            final obj = jsonDecode(line);
            if (obj is Map<String, dynamic>) {
              yield DockerEventModel.fromJson(obj);
            }
          } catch (_) {}
        }
      }
    }
  }
}
