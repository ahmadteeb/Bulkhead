import 'dart:io';

import 'package:bulkhead/core/compose_cli_client.dart';
import 'package:bulkhead/models/compose_stack_model.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingCompose extends ComposeCliClient {
  final commands = <List<String>>[];
  String profilesOutput = '';
  @override
  Future<ProcessResult> runDocker(List<String> arguments) async {
    commands.add(arguments);
    return ProcessResult(
      0,
      0,
      arguments.contains('--profiles')
          ? profilesOutput
          : arguments.contains('ps')
          ? '[]'
          : '',
      '',
    );
  }
}

class JsonCompose extends ComposeCliClient {
  final String output;
  JsonCompose(this.output);
  @override
  Future<ProcessResult> runDocker(List<String> arguments) async =>
      ProcessResult(0, 0, output, '');
}

void main() {
  test('creating a stack never overwrites an existing compose file', () async {
    final dir = await Directory.systemTemp.createTemp('bulkhead-compose-');
    addTearDown(() => dir.delete(recursive: true));
    final cli = ComposeCliClient();
    final path = await cli.createStack(
      dir.path,
      'compose.yml',
      'original',
      startNow: false,
    );
    await expectLater(
      cli.createStack(dir.path, 'compose.yml', 'replacement', startNow: false),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(path).readAsString(), 'original');
  });

  test('new stack filenames cannot escape the selected directory', () async {
    await expectLater(
      ComposeCliClient().createStack(
        '/tmp',
        '../outside.yml',
        '',
        startNow: false,
      ),
      throwsArgumentError,
    );
  });
  test('all stack lifecycle commands preserve ordered Compose files', () async {
    const files = '/app/compose.yml, /app/override.yml';
    final cli = RecordingCompose();
    await cli.stackUp(files);
    await cli.stackDown(files);
    await cli.stackRestart(files);
    await cli.removeStack(files, removeVolumes: false);
    await cli.listStackServices(files);
    for (final command in cli.commands) {
      expect(command.take(5), [
        'compose',
        '-f',
        '/app/compose.yml',
        '-f',
        '/app/override.yml',
      ]);
    }
    expect(cli.commands[0].skip(5), ['up', '-d']);
    expect(cli.commands[3].skip(5), ['down', '--remove-orphans']);
    expect(() => composeFileArguments(' , '), throwsArgumentError);
  });

  test(
    'editing requires one explicit file and leaves other stack files intact',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'bulkhead-multi-compose-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final base = File('${dir.path}/compose.yml');
      final override = File('${dir.path}/override.yml');
      await base.writeAsString('base');
      await override.writeAsString('override');
      final cli = ComposeCliClient();
      await cli.writeComposeFile(override.path, 'edited');
      expect(await cli.readComposeFile(base.path), 'base');
      expect(await cli.readComposeFile(override.path), 'edited');
      await expectLater(
        cli.writeComposeFile('${base.path},${override.path}', 'invalid'),
        throwsArgumentError,
      );
    },
  );
  test(
    'Compose accepts array and line JSON and reports malformed output',
    () async {
      final array = JsonCompose('[{"Name":"web"},{"Name":"worker"}]');
      expect((await array.listStacks()).map((stack) => stack.name), [
        'web',
        'worker',
      ]);
      final lines = JsonCompose('{"Service":"web"}\n{"Service":"worker"}\n');
      expect(
        (await lines.listStackServices(
          '/compose.yml',
        )).map((service) => service.name),
        ['web', 'worker'],
      );
      await expectLater(
        JsonCompose('not-json').listStacks(),
        throwsFormatException,
      );
      await expectLater(
        JsonCompose(
          '{"Service":"web"}\ninvalid',
        ).listStackServices('/compose.yml'),
        throwsFormatException,
      );
    },
  );
  test(
    'profile discovery uses Compose config and returns unique sorted names',
    () async {
      final cli = RecordingCompose()..profilesOutput = 'tools\ndev\ndev\n';
      expect(await cli.getStackProfiles('/app/compose.yml'), ['dev', 'tools']);
      expect(cli.commands.single, [
        'compose',
        '-f',
        '/app/compose.yml',
        'config',
        '--profiles',
      ]);
    },
  );

  test(
    'explicit profiles reach every write action and reads include all existing profile services',
    () async {
      final cli = RecordingCompose();
      const profiles = ['dev', 'tools', 'dev'];
      await cli.stackUp('/compose.yml', profiles: profiles);
      await cli.stackDown('/compose.yml', profiles: profiles);
      await cli.stackRestart('/compose.yml', profiles: profiles);
      await cli.removeStack('/compose.yml', profiles: profiles);
      for (final command in cli.commands) {
        expect(command.skip(3).take(4), [
          '--profile',
          'dev',
          '--profile',
          'tools',
        ]);
      }
      await cli.listStackServices('/compose.yml');
      expect(cli.commands.last, [
        'compose',
        '-f',
        '/compose.yml',
        '--profile',
        '*',
        'ps',
        '--format',
        'json',
        '-a',
      ]);
    },
  );

  test(
    'deployment passes requested profiles when starting the new stack',
    () async {
      final dir = await Directory.systemTemp.createTemp('bulkhead-profiles-');
      addTearDown(() => dir.delete(recursive: true));
      final cli = RecordingCompose();
      await cli.createStack(
        dir.path,
        'compose.yml',
        'services: {}',
        profiles: ['dev'],
      );
      expect(cli.commands.single.skip(3), ['--profile', 'dev', 'up', '-d']);
    },
  );
}
