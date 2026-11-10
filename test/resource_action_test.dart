import 'package:bulkhead/widgets/resource_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single action failures are visible and do not escape', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runResourceAction(
                context,
                'Remove network web',
                () async => throw StateError('network has active endpoints'),
              ),
              child: const Text('Remove'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Remove'));
    await tester.pump();
    expect(find.textContaining('Remove network web failed:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bulk failure reports progress and retains unfinished selections',
    (tester) async {
      final selected = {'first', 'blocked', 'last'};
      final attempted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => runBulkResourceAction(
                  context,
                  'Remove network',
                  selected.toList(),
                  (id) async {
                    attempted.add(id);
                    if (id == 'blocked') throw StateError('in use');
                  },
                  onCompleted: selected.remove,
                ),
                child: const Text('Remove selected'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Remove selected'));
      await tester.pump();
      expect(attempted, ['first', 'blocked']);
      expect(selected, {'blocked', 'last'});
      expect(find.textContaining('blocked (1 of 3 completed)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
