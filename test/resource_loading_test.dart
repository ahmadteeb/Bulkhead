import 'package:bulkhead/features/images/images_screen.dart';
import 'package:bulkhead/features/settings/settings_screen.dart';
import 'package:bulkhead/models/image_model.dart';
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:bulkhead/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/preview_clients.dart';

class RecoveringImages extends PreviewDocker {
  bool fail = true;
  @override
  Future<List<ImageModel>> getImages({bool showAll = true}) async {
    if (fail) throw StateError('Failed to list images');
    return [
      ImageModel.fromJson({
        'Id': 'img',
        'RepoTags': ['alpine:latest'],
      }),
    ];
  }
}

void main() {
  testWidgets('a failed resource load shows an error and can be retried', (
    tester,
  ) async {
    final client = RecoveringImages();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dockerApiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: Scaffold(body: ImagesScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Failed to list images'), findsOneWidget);
    client.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('alpine:latest'), findsOneWidget);
    expect(find.textContaining('Failed to list images'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an empty endpoint cannot replace a working connection', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        socketPathProvider.overrideWith((ref) => '/tmp/working.sock'),
        dockerApiClientProvider.overrideWithValue(PreviewDocker()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.text('Save & Test Connection'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid connection'), findsOneWidget);
    expect(container.read(socketPathProvider), '/tmp/working.sock');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
