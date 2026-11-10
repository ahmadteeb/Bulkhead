import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'docker_endpoint.dart';

import '../models/compose_stack_model.dart';
import 'package:path/path.dart' as p;

class ComposeCliClient {
  final String? socketPath;
  ComposeCliClient({this.socketPath});
  Map<String, String>? get _environment => {
    if (socketPath != null) ...dockerEnvironment(socketPath!),
    'COMPOSE_PROFILES': '',
  };

  Future<ProcessResult> runDocker(List<String> arguments) =>
      Process.run('docker', arguments, environment: _environment);

  /// Check if docker compose CLI is available
  Future<bool> isComposeInstalled() async {
    try {
      final res = await runDocker(['compose', 'version']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// List all compose stacks on the machine (`docker compose ls --format json`)
  Future<List<ComposeStackModel>> listStacks() async {
    final res = await runDocker(['compose', 'ls', '--format', 'json', '-a']);
    if (res.exitCode != 0) {
      throw Exception('docker compose ls failed: ${res.stderr}');
    }

    final stdoutStr = (res.stdout as String).trim();
    if (stdoutStr.isEmpty) return [];

    return _parseObjects(stdoutStr).map(ComposeStackModel.fromJson).toList();
  }

  List<Map<String, dynamic>> _parseObjects(String output) {
    if (output.trim().isEmpty) return [];
    if (output.trimLeft().startsWith('[')) {
      return (jsonDecode(output) as List).cast<Map<String, dynamic>>();
    }
    return const LineSplitter()
        .convert(output)
        .where((line) => line.trim().isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
  }

  Future<List<String>> getStackProfiles(String configPath) async {
    final result = await runDocker([
      'compose',
      ...composeFileArguments(configPath),
      'config',
      '--profiles',
    ]);
    if (result.exitCode != 0) {
      throw StateError('Unable to load Compose profiles: ${result.stderr}');
    }
    return const LineSplitter()
        .convert(result.stdout as String)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// List services in a compose stack (`docker compose ps --format json`)
  Future<List<ComposeServiceInfo>> listStackServices(String configPath) async {
    final args = [
      'compose',
      ...composeFileArguments(configPath),
      ...composeProfileArguments(const ['*']),
      'ps',
      '--format',
      'json',
      '-a',
    ];
    final res = await runDocker(args);
    if (res.exitCode != 0) {
      throw Exception('docker compose ps failed: ${res.stderr}');
    }

    final stdoutStr = (res.stdout as String).trim();
    if (stdoutStr.isEmpty) return [];

    return _parseObjects(stdoutStr).map(ComposeServiceInfo.fromJson).toList();
  }

  /// Up stack (`docker compose -f <configPath> up -d`)
  Future<void> stackUp(
    String configPath, {
    List<String> profiles = const [],
  }) async {
    final res = await runDocker([
      'compose',
      ...composeFileArguments(configPath),
      ...composeProfileArguments(profiles),
      'up',
      '-d',
    ]);
    if (res.exitCode != 0) {
      throw Exception('docker compose up failed: ${res.stderr}');
    }
  }

  /// Down stack (`docker compose -f <configPath> down`)
  Future<void> stackDown(
    String configPath, {
    List<String> profiles = const [],
  }) async {
    final res = await runDocker([
      'compose',
      ...composeFileArguments(configPath),
      ...composeProfileArguments(profiles),
      'down',
    ]);
    if (res.exitCode != 0) {
      throw Exception('docker compose down failed: ${res.stderr}');
    }
  }

  /// Restart stack (`docker compose -f <configPath> restart`)
  Future<void> stackRestart(
    String configPath, {
    List<String> profiles = const [],
  }) async {
    final res = await runDocker([
      'compose',
      ...composeFileArguments(configPath),
      ...composeProfileArguments(profiles),
      'restart',
    ]);
    if (res.exitCode != 0) {
      throw Exception('docker compose restart failed: ${res.stderr}');
    }
  }

  /// Complete Delete/Purge stack (`docker compose -f <configPath> down -v --remove-orphans`)
  Future<void> removeStack(
    String configPath, {
    bool removeVolumes = true,
    List<String> profiles = const [],
  }) async {
    final args = [
      'compose',
      ...composeFileArguments(configPath),
      ...composeProfileArguments(profiles),
      'down',
      '--remove-orphans',
    ];
    if (removeVolumes) {
      args.add('-v');
    }
    final res = await runDocker(args);
    if (res.exitCode != 0) {
      throw Exception('docker compose down failed: ${res.stderr}');
    }
  }

  /// Create a new stack on disk and bring up
  Future<String> createStack(
    String dirPath,
    String filename,
    String yamlContent, {
    bool startNow = true,
    List<String> profiles = const [],
  }) async {
    if (filename.isEmpty ||
        p.basename(filename) != filename ||
        filename == '.' ||
        filename == '..') {
      throw ArgumentError('Compose filename must be a plain filename.');
    }
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filePath = p.normalize(p.absolute(p.join(dir.path, filename)));
    final file = File(filePath);
    await file.create(exclusive: true);
    await file.writeAsString(yamlContent);

    if (startNow) {
      await stackUp(filePath, profiles: profiles);
    }
    return filePath;
  }

  /// Stream service logs using `Process.start`
  Stream<String> streamServiceLogs(
    String configPath,
    String serviceName,
  ) async* {
    final process = await Process.start('docker', [
      'compose',
      ...composeFileArguments(configPath),
      ...composeProfileArguments(const ['*']),
      'logs',
      '-f',
      '--tail=200',
      serviceName,
    ], environment: _environment);

    final output = StreamController<String>();
    var completed = 0;
    void done() {
      if (++completed == 2) output.close();
    }

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(output.add, onError: output.addError, onDone: done);
    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(output.add, onError: output.addError, onDone: done);
    try {
      yield* output.stream;
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw ProcessException('docker', [], 'Compose logs failed', exitCode);
      }
    } finally {
      process.kill();
      await stdoutSub.cancel();
      await stderrSub.cancel();
    }
  }

  /// Read compose YAML content from disk
  Future<String> readComposeFile(String configPath) async {
    if (parseComposePaths(configPath).length != 1) {
      throw ArgumentError('Select one Compose file to edit.');
    }
    final file = File(configPath);
    if (!await file.exists()) {
      throw Exception('Compose file not found at path: $configPath');
    }
    return await file.readAsString();
  }

  /// Write updated compose YAML content to disk
  Future<void> writeComposeFile(String configPath, String content) async {
    if (parseComposePaths(configPath).length != 1) {
      throw ArgumentError('Select one Compose file to edit.');
    }
    final file = File(configPath);
    await file.writeAsString(content);
  }
}
