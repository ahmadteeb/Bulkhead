import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bulkhead/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BulkheadApp()));
    expect(find.text('BULKHEAD'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
