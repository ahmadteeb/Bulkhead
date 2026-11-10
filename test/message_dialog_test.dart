import 'dart:async';
import 'dart:io';

import 'package:bulkhead/widgets/message_dialog.dart';
import 'package:bulkhead/widgets/update_dialog.dart';
import 'package:bulkhead/models/update_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app feedback contains no SnackBar call sites', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains('SnackBar')),
        reason: file.path,
      );
      expect(
        file.readAsStringSync(),
        isNot(contains('ScaffoldMessenger')),
        reason: file.path,
      );
    }
  });

  testWidgets('long message dialogs fit a small window and dismiss normally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMessageDialog(
                context,
                title:
                    'A long resource action failed while processing this container',
                message: List.filled(100, 'Docker error details.').join('\n'),
                type: MessageType.error,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'progress cleanup removes its own route and preserves another dialog',
    (tester) async {
      late BuildContext page;
      final finished = Completer<int>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                page = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final result = withProgressDialog(page, 'Working', () => finished.future);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      unawaited(
        showDialog<void>(
          context: page,
          builder: (_) => const AlertDialog(title: Text('Another dialog')),
        ),
      );
      await tester.pump();
      finished.complete(42);
      await tester.pumpAndSettle();
      expect(await result, 42);
      expect(find.text('Another dialog'), findsOneWidget);
      expect(find.text('Working'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('release dialogs fit short windows and long asset names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final info = UpdateInfoModel(
      latestVersion: '1.0.1',
      currentVersion: '1.0.0',
      hasUpdate: true,
      releaseNotes: List.filled(100, 'Release details').join('\n'),
      releaseHtmlUrl: '',
      assets: [
        UpdateAssetModel(
          name: 'bulkhead-linux-a-very-long-release-download-name.zip',
          downloadUrl: '',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => UpdateDialog(updateInfo: info),
              ),
              child: const Text('Release'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Release'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
