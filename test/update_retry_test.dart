import 'package:bulkhead/providers/update_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FailedUpdate extends UpdateNotifier {
  void fail() => state = AsyncValue.error(
    StateError('previous failure'),
    StackTrace.current,
  );
}

void main() {
  testWidgets('an automatic update check can retry after an earlier error', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Bulkhead',
      packageName: 'bulkhead',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final notifier = FailedUpdate();
    addTearDown(notifier.dispose);
    notifier.fail();
    // Widget tests return HTTP 400; the check must catch it instead of rethrowing old state.
    final first = notifier.checkForUpdates();
    final second = notifier.checkForUpdates(forceUserCheck: true);
    expect(identical(first, second), isTrue);
    await expectLater(first, completes);
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.error.toString(), contains('HTTP 400'));
  });
}
