import 'dart:async';
import 'dart:io';
import 'package:bulkhead/core/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProcess implements Process {
  bool killed = false;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'a process that starts after disposing its terminal is killed',
    () async {
      final session = TerminalSession();
      final pending = Completer<Process>();
      final started = session.start(() => pending.future);
      session.dispose();
      final process = FakeProcess();
      pending.complete(process);
      expect(await started, isNull);
      expect(process.killed, isTrue);
      expect(session.process, isNull);
    },
  );

  test('overlapping reconnects keep only the newest process', () async {
    final session = TerminalSession();
    addTearDown(session.dispose);
    final first = Completer<Process>(), second = Completer<Process>();
    final older = session.start(() => first.future);
    final newer = session.start(() => second.future);
    final oldProcess = FakeProcess(), newProcess = FakeProcess();
    second.complete(newProcess);
    expect(await newer, same(newProcess));
    first.complete(oldProcess);
    expect(await older, isNull);
    expect(oldProcess.killed, isTrue);
    expect(newProcess.killed, isFalse);
    expect(session.process, same(newProcess));
  });
}
