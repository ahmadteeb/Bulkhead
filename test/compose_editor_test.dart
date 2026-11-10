import 'package:bulkhead/core/compose_cli_client.dart';
import 'package:bulkhead/main.dart';
import 'package:bulkhead/models/compose_stack_model.dart';
import 'package:bulkhead/providers/compose_provider.dart';
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/preview_clients.dart';

class EditorCompose extends ComposeCliClient {
  final files = {
    '/app/compose.yml': 'base: original',
    '/app/override.yml': 'override: original',
  };
  final bool failRead;
  EditorCompose({this.failRead = false});
  @override
  Future<List<String>> getStackProfiles(String configPath) async => [];
  @override
  Future<bool> isComposeInstalled() async => true;
  @override
  Future<List<ComposeStackModel>> listStacks() async => [
    ComposeStackModel(
      name: 'demo',
      status: 'running(1)',
      configFiles: files.keys.join(','),
    ),
  ];
  @override
  Future<List<ComposeServiceInfo>> listStackServices(String configPath) async =>
      [];
  @override
  Future<String> readComposeFile(String path) async {
    if (failRead) throw StateError('permission denied');
    return files[path]!;
  }

  @override
  Future<void> writeComposeFile(String path, String content) async =>
      files[path] = content;
}

Future<void> openEditor(
  WidgetTester tester,
  EditorCompose cli,
  double width,
) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dockerApiClientProvider.overrideWithValue(PreviewDocker()),
        composeCliClientProvider.overrideWithValue(cli),
      ],
      child: const BulkheadApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    width < 1100
        ? find.byTooltip('Compose stacks')
        : find.text('Compose stacks'),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byTooltip('View / Edit Stack YAML'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('View / Edit Stack YAML'));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [800.0, 1440.0]) {
    testWidgets('multi-file editor saves only the selected file at $width', (
      tester,
    ) async {
      final cli = EditorCompose();
      await openEditor(tester, cli, width);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/app/override.yml').last);
      await tester.pumpAndSettle();
      expect(find.text('override: original'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'override: edited');
      await tester.tap(find.text('Save override.yml'));
      await tester.pumpAndSettle();
      expect(cli.files['/app/compose.yml'], 'base: original');
      expect(cli.files['/app/override.yml'], 'override: edited');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'failed reads cannot overwrite a Compose file with an empty editor',
    (tester) async {
      final cli = EditorCompose(failRead: true);
      await openEditor(tester, cli, 1440);
      expect(find.textContaining('Unable to load file:'), findsOneWidget);
      final save = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save compose.yml'),
      );
      expect(save.onPressed, isNull);
      expect(cli.files['/app/compose.yml'], 'base: original');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('switching files protects unsaved edits', (tester) async {
    final cli = EditorCompose();
    await openEditor(tester, cli, 1440);
    await tester.enterText(find.byType(TextField), 'base: unsaved');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/app/override.yml').last);
    await tester.pumpAndSettle();
    expect(find.text('Switch Compose file?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('base: unsaved'), findsOneWidget);
    expect(cli.files['/app/compose.yml'], 'base: original');
    expect(find.text('Save compose.yml'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
