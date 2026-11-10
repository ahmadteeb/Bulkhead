import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  test(
    'terminal copy source discards output beyond the visible history limit',
    () {
      final terminal = Terminal(maxLines: 40);
      terminal.resize(80, 10);
      for (var i = 0; i < 1000; i++) {
        terminal.write('output $i\r\n');
      }
      final copied = terminal.buffer.getText();
      expect(copied, contains('output 999'));
      expect(copied, isNot(contains('output 0\n')));
      expect(copied.split('\n').length, lessThanOrEqualTo(41));
    },
  );
}
