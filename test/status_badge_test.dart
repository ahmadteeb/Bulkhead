import 'package:bulkhead/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('status pill hugs its label inside a wide table cell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 48,
              child: StatusBadge.fromState('running(1)'),
            ),
          ),
        ),
      ),
    );
    final pill = find
        .descendant(
          of: find.byType(StatusBadge),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(tester.getSize(pill).width, lessThan(190));
    expect(tester.getSize(pill).height, lessThan(30));
    expect(find.text('RUNNING(1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long status labels fit a narrow cell without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              child: StatusBadge.fromState('running(12), restarting(3)'),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
