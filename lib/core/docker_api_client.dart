import 'dart:async';
import 'dart:convert';

import '../models/container_model.dart';
import '../models/docker_event_model.dart';
import '../models/image_model.dart';
import '../models/network_model.dart';
import '../models/volume_model.dart';
import 'docker_socket_connection.dart';
import 'docker_endpoint.dart';

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
      throw Exception(
        'Failed to list containers: ${res.statusCode} ${res.body}',
      );
    }

    final List<dynamic> decoded = jsonDecode(res.body);
    return decoded
        .map((item) => ContainerModel.fromJson(item as Map<String, dynamic>))
        .toList();
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
        final key = containerPort.contains('/')
            ? containerPort
            : '$containerPort/tcp';
        exposedPorts[key] = {};
        portBindings[key] = [
          {'HostPort': hostPort},
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
      try {
        await startContainer(id);
      } catch (error) {
        throw StateError(
          'Container "$name" ($id) was created but could not start: $error',
        );
      }
    }
    return id;
  }

  /// Inspect a single container
  Future<Map<String, dynamic>> inspectContainer(String id) async {
    final res = await _socket.request(
      method: 'GET',
      path: '/containers/$id/json',
    );
    if (!res.isSuccess) {
      throw Exception('Failed to inspect container $id: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Start a container
  Future<void> startContainer(String id) async {
    final res = await _socket.request(
      method: 'POST',
      path: '/containers/$id/start',
    );
    if (!res.isSuccess && res.statusCode != 304) {
      throw Exception('Failed to start container: ${res.body}');
    }
  }

  /// Stop a container
  Future<void> stopContainer(String id) async {
    final res = await _socket.request(
      method: 'POST',
      path: '/containers/$id/stop',
    );
    if (!res.isSuccess && res.statusCode != 304) {
      throw Exception('Failed to stop container: ${res.body}');
    }
  }

  /// Restart a container
  Future<void> restartContainer(String id) async {
    final res = await _socket.request(
      method: 'POST',
      path: '/containers/$id/restart',
    );
    if (!res.isSuccess) {
      throw Exception('Failed to restart container: ${res.body}');
    }
  }

  /// Remove a container
  Future<void> removeContainer(String id, {bool force = false}) async {
    final res = await _socket.request(
      method: 'DELETE',
      // Keep attached volumes unless the user explicitly removes them in Volumes.
      path: '/containers/$id?v=0&force=${force ? 1 : 0}',
    );
    if (!res.isSuccess) {
      throw Exception('Failed to remove container: ${res.body}');
    }
  }

  /// Stream live container logs with HTTP chunk header stripping and 8-byte frame demuxer
  Stream<String> streamContainerLogs(
    String id, {
    int tail = 200,
    bool follow = true,
  }) async* {
    final info = await inspectContainer(id);
    final tty = (info['Config'] as Map<String, dynamic>?)?['Tty'] == true;
    final path =
        '/containers/$id/logs?follow=$follow&stdout=true&stderr=true&timestamps=true&tail=$tail';
    final stream = _socket.streamResponse(method: 'GET', path: path);
    yield* _logPayload(
      stream,
      tty: tty,
    ).transform(utf8.decoder).transform(const LineSplitter());
  }

  Stream<List<int>> _logPayload(
    Stream<List<int>> stream, {
    required bool tty,
  }) async* {
    if (tty) {
      yield* stream;
      return;
    }
    var pending = <int>[];
    var remaining = 0;
    await for (final chunk in stream) {
      pending.addAll(chunk);
      while (true) {
        if (remaining == 0) {
          if (pending.length < 8) break;
          remaining =
              (pending[4] << 24) |
              (pending[5] << 16) |
              (pending[6] << 8) |
              pending[7];
          pending = pending.sublist(8);
          if (remaining == 0) continue;
        }
        if (pending.isEmpty) break;
        final count = pending.length < remaining ? pending.length : remaining;
        yield pending.sublist(0, count);
        pending = pending.sublist(count);
        remaining -= count;
      }
    }
    if (remaining != 0 || pending.isNotEmpty) {
      throw const FormatException('Incomplete Docker log frame');
    }
  }

  /// Create an exec instance inside a running container
  Future<String> createExec(
    String containerId,
    List<String> cmd, {
    bool tty = true,
  }) async {
    final body = jsonEncode({
      'AttachStdout': true,
      'AttachStderr': true,
      'Tty': tty,
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
  Stream<String> startExec(String execId, {bool tty = true}) async* {
    final body = jsonEncode({'Detach': false, 'Tty': tty});
    final stream = _socket.streamResponse(
      method: 'POST',
      path: '/exec/$execId/start',
      body: body,
      headers: {'Content-Type': 'application/json'},
    );

    yield* utf8.decoder.bind(_logPayload(stream, tty: tty));
  }

  /// Execute command inside container CLI using selected shell and return full output
  Future<String> execCommand(
    String containerId,
    String command, {
    String shell = 'sh',
  }) async {
    final execId = await createExec(containerId, [
      shell,
      '-c',
      command,
    ], tty: false);
    final buffer = StringBuffer();
    await for (final chunk in startExec(execId, tty: false)) {
      buffer.write(chunk);
    }
    final status = await _socket.request(
      method: 'GET',
      path: '/exec/$execId/json',
    );
    if (!status.isSuccess) {
      throw StateError('Unable to inspect command exit status: ${status.body}');
    }
    final exitCode =
        (jsonDecode(status.body) as Map<String, dynamic>)['ExitCode'];
    if (exitCode != 0) {
      throw StateError(
        'Command failed (exit $exitCode): ${buffer.toString().trim()}',
      );
    }
    return buffer.toString();
  }

  /// List files in a path inside container or mounted volume via exec
  Future<List<Map<String, String>>> listContainerFiles(
    String containerId,
    String path,
  ) async {
    final command =
        'directory=${shellQuote(path)}\n'
        r'''
if [ ! -d "$directory" ] || [ ! -r "$directory" ] || [ ! -x "$directory" ]; then
  printf '%s\n' 'Directory is not accessible.' >&2
  exit 1
fi
for entry in "$directory"/* "$directory"/.[!.]* "$directory"/..?*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  metadata=$(stat -c '%A %s' -- "$entry") || exit 1
  directoryEntry=false
  if [ -d "$entry" ]; then directoryEntry=true; fi
  printf '%s\000%s\000%s\000%s\000' "${entry##*/}" "${metadata% *}" "${metadata##* }" "$directoryEntry"
done
''';
    final raw = await execCommand(containerId, command);
    if (raw.isEmpty) return [];
    final fields = raw.split('\u0000');
    if (fields.last.isNotEmpty || (fields.length - 1) % 4 != 0) {
      throw const FormatException('Malformed directory listing');
    }
    return [
      for (var i = 0; i < fields.length - 1; i += 4)
        {
          'name': fields[i],
          'permissions': fields[i + 1],
          'size': fields[i + 2],
          'isDir': fields[i + 3],
        },
    ];
  }

  /// Stream container stats (CPU %, memory usage)
  Stream<Map<String, dynamic>> streamContainerStats(String id) async* {
    final path = '/containers/$id/stats?stream=true';
    final stream = _socket.streamResponse(method: 'GET', path: path);

    yield* _jsonLines(stream);
  }

  Stream<Map<String, dynamic>> _jsonLines(Stream<List<int>> stream) async* {
    await for (final line
        in utf8.decoder.bind(stream).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final value = jsonDecode(line);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Expected a Docker JSON object');
      }
      yield value;
    }
  }

  // --- IMAGES ---

  /// List Docker images
  Future<List<ImageModel>> getImages({bool showAll = true}) async {
    final res = await _socket.request(
      method: 'GET',
      path: '/images/json?all=${showAll ? 1 : 0}',
    );
    if (!res.isSuccess) {
      throw Exception('Failed to list images: ${res.body}');
    }
    final List<dynamic> decoded = jsonDecode(res.body);
    return decoded
        .map((item) => ImageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Pull image with streaming progress updates
  Stream<Map<String, dynamic>> pullImage(String imageName) async* {
    final reference = imageName.trim();
    final path = '/images/create?fromImage=${Uri.encodeComponent(reference)}';
    final stream = _socket.streamResponse(method: 'POST', path: path);

    await for (final object in _jsonLines(stream)) {
      if (object['error'] != null) throw StateError(object['error'].toString());
      yield object;
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
    return list
        .map((item) => VolumeModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Create a volume
  Future<VolumeModel> createVolume(
    String name, {
    String driver = 'local',
  }) async {
    final body = jsonEncode({'Name': name, 'Driver': driver});
    final res = await _socket.request(
      method: 'POST',
      path: '/volumes/create',
      body: body,
    );
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
    return decoded
        .map((item) => NetworkModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Create network
  Future<NetworkModel> createNetwork(
    String name, {
    String driver = 'bridge',
  }) async {
    final body = jsonEncode({
      'Name': name,
      'Driver': driver,
      'CheckDuplicate': true,
    });
    final res = await _socket.request(
      method: 'POST',
      path: '/networks/create',
      body: body,
    );
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

  /// Remove stopped containers, dangling images, unused anonymous volumes and networks.
  Future<Map<String, dynamic>> systemPruneAll() async {
    final results = <String, dynamic>{};
    for (final resource in ['containers', 'images', 'volumes', 'networks']) {
      final response = await _socket.request(
        method: 'POST',
        path: '/$resource/prune',
      );
      if (!response.isSuccess) {
        throw Exception(
          'Pruning $resource failed: ${response.body}. Earlier prune steps may have completed.',
        );
      }
      results[resource] = jsonDecode(response.body);
    }
    return results;
  }

  /// Real-time event stream (`/events`)
  Stream<DockerEventModel> streamEvents() async* {
    final stream = _socket.streamResponse(method: 'GET', path: '/events');
    await for (final object in _jsonLines(stream)) {
      yield DockerEventModel.fromJson(object);
    }
  }
}
