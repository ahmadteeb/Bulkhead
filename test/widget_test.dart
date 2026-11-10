import 'support/preview_clients.dart';
import 'package:bulkhead/providers/compose_provider.dart';
import 'package:bulkhead/main.dart';
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:bulkhead/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [800.0, 1440.0]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('workspace navigation at $width in ${mode.name}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dockerApiClientProvider.overrideWithValue(PreviewDocker()),
              composeCliClientProvider.overrideWithValue(PreviewCompose()),
              appThemeModeProvider.overrideWith((ref) => mode),
            ],
            child: const BulkheadApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Workspace overview'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // The compact rail has tooltips; the wide sidebar has visible labels.
        if (width < 1100) {
          await tester.tap(find.byTooltip('Containers'));
        } else {
          await tester.tap(find.text('Containers'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Container List'), findsOneWidget);
        expect(find.text('api-server'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField).first, 'postgres');
        await tester.pump();
        expect(find.text('api-server'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'postgres',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final (destination, heading) in [
          ('Images', 'Docker Images'),
          ('Compose stacks', 'Docker Compose Stacks'),
          ('Volumes', 'Docker Volumes'),
          ('Networks', 'Docker Networks'),
          ('Settings', 'Settings & Configuration'),
        ]) {
          if (width < 1100) {
            await tester.tap(find.byTooltip(destination));
          } else {
            await tester.tap(find.text(destination).first);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text(heading), findsWidgets);
          expect(tester.takeException(), isNull, reason: destination);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
