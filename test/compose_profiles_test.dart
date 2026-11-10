import 'package:bulkhead/main.dart';
import 'package:bulkhead/features/compose/compose_screen.dart';
import 'package:bulkhead/models/compose_stack_model.dart';
import 'package:bulkhead/providers/compose_provider.dart';
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/preview_clients.dart';

class ProfileCompose extends PreviewCompose {
  final actions = <(String, List<String>)>[];
  List<String> availableProfiles = ['dev', 'tools'];
  @override
  Future<List<String>> getStackProfiles(String path) async => [
    ...availableProfiles,
  ];
  @override
  Future<List<ComposeStackModel>> listStacks() async => [
    ComposeStackModel(
      name: 'profile-app',
      status: 'running(1)',
      configFiles: '/app/compose.yml',
    ),
  ];
  @override
  Future<void> stackUp(String path, {List<String> profiles = const []}) async =>
      actions.add(('up', [...profiles]));
  @override
  Future<void> stackDown(
    String path, {
    List<String> profiles = const [],
  }) async => actions.add(('down', [...profiles]));
  @override
  Future<void> stackRestart(
    String path, {
    List<String> profiles = const [],
  }) async => actions.add(('restart', [...profiles]));
}

void main() {
  for (final width in [800.0, 1440.0]) {
    testWidgets(
      'profile choices are visible and reach stack actions at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cli = ProfileCompose();
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
        expect(find.text('Available profiles: dev, tools'), findsOneWidget);
        expect(cli.actions, isEmpty);
        await tester.ensureVisible(find.text('Available profiles: dev, tools'));
        await tester.tap(find.text('Available profiles: dev, tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('dev'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('Profiles: dev'), findsOneWidget);
        final up = find.byTooltip('Up Stack (docker compose up -d)');
        await tester.ensureVisible(up);
        await tester.pumpAndSettle();
        await tester.tap(up);
        await tester.pumpAndSettle();
        expect(cli.actions.single.$1, 'up');
        expect(cli.actions.single.$2, ['dev']);
        await tester.tap(find.byTooltip('Restart Stack'));
        await tester.pumpAndSettle();
        expect(cli.actions.last.$1, 'restart');
        expect(cli.actions.last.$2, ['dev']);
        await tester.tap(find.byTooltip('Down Stack (docker compose down)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Down'));
        await tester.pumpAndSettle();
        expect(cli.actions.last.$1, 'down');
        expect(cli.actions.last.$2, ['dev']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('Refresh discovers profiles added in an external editor', (
    tester,
  ) async {
    final cli = ProfileCompose()..availableProfiles = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dockerApiClientProvider.overrideWithValue(PreviewDocker()),
          composeCliClientProvider.overrideWithValue(cli),
        ],
        child: const MaterialApp(home: Scaffold(body: ComposeScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Available profiles:'), findsNothing);
    cli.availableProfiles = ['dev'];
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Available profiles: dev'), findsOneWidget);
    expect(cli.actions, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
