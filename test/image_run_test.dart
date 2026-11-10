import 'dart:async';
import 'package:bulkhead/features/images/images_screen.dart';
import 'package:bulkhead/models/image_model.dart';
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/preview_clients.dart';

class ImageDocker extends PreviewDocker {
  final creation = Completer<String>();
  @override
  Future<List<ImageModel>> getImages({bool showAll = true}) async => [
    ImageModel.fromJson({
      'Id': 'image',
      'RepoTags': ['alpine:latest'],
      'Size': 1,
    }),
  ];
  @override
  Future<String> createContainer({
    required String name,
    required String image,
    List<String>? env,
    Map<String, String>? portMappings,
    bool autoStart = true,
  }) => creation.future;
}

void main() {
  testWidgets(
    'running an image waits for Docker and shows a failure dialog on rejection',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = ImageDocker();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dockerApiClientProvider.overrideWithValue(client)],
          child: const MaterialApp(home: Scaffold(body: ImagesScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Run Container from Image'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Spawned container'), findsNothing);
      client.creation.completeError(StateError('image not found'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('image not found'), findsOneWidget);
      expect(find.textContaining('Spawned container'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
