import 'package:bulkhead/widgets/log_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'log tools fit narrow panels and auto-scroll after capped mutable history updates',
    (tester) async {
      final logs = [for (var i = 0; i < 100; i++) 'Log $i'];
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 320,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return LogViewer(logs: logs, onClear: () {});
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      rebuild(() {
        logs.removeAt(0);
        logs.add('Newest line');
      });
      await tester.pump();
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.controller!.offset,
        list.controller!.position.maxScrollExtent,
      );
      expect(find.text('Newest line'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
