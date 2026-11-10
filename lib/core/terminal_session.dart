import 'dart:io';

/// Owns the current process, including a spawn that finishes after leaving a view.
class TerminalSession {
  Process? _process;
  Process? get process => _process;
  int _generation = 0;
  bool _disposed = false;

  Future<Process?> start(Future<Process> Function() spawn) async {
    if (_disposed) return null;
    final generation = ++_generation;
    _process?.kill();
    _process = null;
    try {
      final process = await spawn();
      if (_disposed || generation != _generation) {
        process.kill();
        return null;
      }
      return _process = process;
    } catch (_) {
      if (_disposed || generation != _generation) return null;
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _process?.kill();
    _process = null;
  }
}
