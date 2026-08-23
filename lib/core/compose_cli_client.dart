import 'dart:convert';
import 'dart:io';

import '../models/compose_stack_model.dart';

class ComposeCliClient {
  /// Check if docker compose CLI is available
  Future<bool> isComposeInstalled() async {
    try {
      final res = await Process.run('docker', ['compose', 'version']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// List all compose stacks on the machine (`docker compose ls --format json`)
  Future<List<ComposeStackModel>> listStacks() async {
    final res = await Process.run('docker', ['compose', 'ls', '--format', 'json', '-a']);
    if (res.exitCode != 0) {
      throw Exception('docker compose ls failed: ${res.stderr}');
    }

    final stdoutStr = (res.stdout as String).trim();
    if (stdoutStr.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(stdoutStr);
      return jsonList
          .map((item) => ComposeStackModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final lines = stdoutStr.split('\n');
      final stacks = <ComposeStackModel>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          try {
            final obj = jsonDecode(trimmed);
            if (obj is Map<String, dynamic>) {
              stacks.add(ComposeStackModel.fromJson(obj));
            }
          } catch (_) {}
        }
      }
      return stacks;
    }
  }

  /// List services in a compose stack (`docker compose ps --format json`)
  Future<List<ComposeServiceInfo>> listStackServices(String configPath) async {
    final args = ['compose', '-f', configPath, 'ps', '--format', 'json', '-a'];
    final res = await Process.run('docker', args);
    if (res.exitCode != 0) {
      throw Exception('docker compose ps failed: ${res.stderr}');
    }

    final stdoutStr = (res.stdout as String).trim();
    if (stdoutStr.isEmpty) return [];

    final services = <ComposeServiceInfo>[];
    if (stdoutStr.startsWith('[')) {
      final List<dynamic> jsonList = jsonDecode(stdoutStr);
      services.addAll(jsonList.map((i) => ComposeServiceInfo.fromJson(i as Map<String, dynamic>)));
    } else {
      final lines = stdoutStr.split('\n');
      for (final line in lines) {
        final t = line.trim();
        if (t.isNotEmpty) {
          try {
            final obj = jsonDecode(t);
            if (obj is Map<String, dynamic>) {
              services.add(ComposeServiceInfo.fromJson(obj));
            }
          } catch (_) {}
        }
      }
    }
    return services;
  }

  /// Up stack (`docker compose -f <configPath> up -d`)
  Future<void> stackUp(String configPath) async {
    final res = await Process.run('docker', ['compose', '-f', configPath, 'up', '-d']);
    if (res.exitCode != 0) {
      throw Exception('docker compose up failed: ${res.stderr}');
    }
  }

  /// Down stack (`docker compose -f <configPath> down`)
  Future<void> stackDown(String configPath) async {
    final res = await Process.run('docker', ['compose', '-f', configPath, 'down']);
    if (res.exitCode != 0) {
      throw Exception('docker compose down failed: ${res.stderr}');
    }
  }

  /// Restart stack (`docker compose -f <configPath> restart`)
  Future<void> stackRestart(String configPath) async {
    final res = await Process.run('docker', ['compose', '-f', configPath, 'restart']);
    if (res.exitCode != 0) {
      throw Exception('docker compose restart failed: ${res.stderr}');
    }
  }

  /// Complete Delete/Purge stack (`docker compose -f <configPath> down -v --remove-orphans`)
  Future<void> removeStack(String configPath, {bool removeVolumes = true}) async {
    final args = ['compose', '-f', configPath, 'down', '--remove-orphans'];
    if (removeVolumes) {
      args.add('-v');
    }
    final res = await Process.run('docker', args);
    if (res.exitCode != 0) {
      throw Exception('docker compose down failed: ${res.stderr}');
    }
  }

  /// Create a new stack on disk and bring up
  Future<String> createStack(String dirPath, String filename, String yamlContent, {bool startNow = true}) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filePath = '${dir.path}/$filename';
    final file = File(filePath);
    await file.writeAsString(yamlContent);

    if (startNow) {
      await stackUp(filePath);
    }
    return filePath;
  }

  /// Stream service logs using `Process.start`
  Stream<String> streamServiceLogs(String configPath, String serviceName) async* {
    final process = await Process.start('docker', [
      'compose',
      '-f',
      configPath,
      'logs',
      '-f',
      '--tail=200',
      serviceName,
    ]);

    final stdoutStream = process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final stderrStream = process.stderr.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in stdoutStream) {
      yield line;
    }
    await for (final line in stderrStream) {
      yield line;
    }
  }

  /// Read compose YAML content from disk
  Future<String> readComposeFile(String configPath) async {
    final file = File(configPath);
    if (!await file.exists()) {
      throw Exception('Compose file not found at path: $configPath');
    }
    return await file.readAsString();
  }

  /// Write updated compose YAML content to disk
  Future<void> writeComposeFile(String configPath, String content) async {
    final file = File(configPath);
    await file.writeAsString(content);
  }
}
