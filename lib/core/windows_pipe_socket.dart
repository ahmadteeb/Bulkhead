import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win;

/// Adapts a Windows pipe to the byte-stream contract used by HttpClient.
/// Overlapped I/O keeps reads cancellable without blocking Flutter's UI thread.
class WindowsPipeSocket extends Stream<Uint8List> implements Socket {
  final win.HANDLE _handle;
  final String path;
  late final StreamController<Uint8List> _input;
  late final IOSink _output;
  Completer<void>? _paused;
  bool _closed = false;
  bool _handleClosed = false;
  int _operations = 0;

  WindowsPipeSocket._(this._handle, this.path) {
    _input = StreamController<Uint8List>(
      onListen: _read,
      onPause: () => _paused ??= Completer<void>(),
      onResume: () {
        _paused?.complete();
        _paused = null;
      },
      onCancel: destroy,
    );
    _output = IOSink(_PipeWriter(this));
    _output.done.then(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (!_closed) _input.addError(error, stack);
        destroy();
      },
    );
  }

  static Future<WindowsPipeSocket> connect(String path) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows pipes require Windows.');
    }
    if (path.startsWith('npipe://')) path = path.substring('npipe://'.length);
    path = path.replaceAll('/', r'\');
    if (!path.startsWith(r'\\.\pipe\')) {
      throw ArgumentError('Expected a local Windows pipe path.');
    }
    final name = path.toNativeUtf16();
    try {
      final elapsed = Stopwatch()..start();
      while (true) {
        final result = win.CreateFile(
          win.PCWSTR(name),
          win.GENERIC_READ | win.GENERIC_WRITE,
          const win.FILE_SHARE_MODE(0),
          null,
          win.OPEN_EXISTING,
          // Let the server identify the client without impersonating its user.
          win.FILE_FLAG_OVERLAPPED |
              win.SECURITY_SQOS_PRESENT |
              win.SECURITY_IDENTIFICATION,
          null,
        );
        if (result.value != win.INVALID_HANDLE_VALUE) {
          return WindowsPipeSocket._(result.value, path);
        }
        if (result.error != win.ERROR_PIPE_BUSY ||
            elapsed.elapsed >= const Duration(seconds: 10)) {
          throw SocketException(
            'Cannot open Docker pipe $path',
            osError: OSError('Windows pipe connection failed', result.error),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    } finally {
      calloc.free(name);
    }
  }

  Future<Uint8List> _transfer({List<int>? data}) async {
    if (_closed) throw const SocketException('Docker pipe is closed');
    _operations++;
    final buffer = calloc<Uint8>(data?.length ?? 65536);
    final count = calloc<Uint32>();
    final operation = calloc<win.OVERLAPPED>();
    win.HANDLE? event;
    try {
      final created = win.CreateEvent(null, true, false, null);
      if (created.value == win.HANDLE(nullptr)) {
        throw SocketException(
          'Cannot create pipe I/O event',
          osError: OSError('', created.error),
        );
      }
      event = created.value;
      operation.ref.hEvent = event;
      if (data != null) buffer.asTypedList(data.length).setAll(0, data);
      final started = data == null
          ? win.ReadFile(_handle, buffer, 65536, count, operation)
          : win.WriteFile(_handle, buffer, data.length, count, operation);
      var result = started;
      if (!result.value && result.error == win.ERROR_IO_PENDING) {
        do {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          result = win.GetOverlappedResult(_handle, operation, count, false);
        } while (!result.value && result.error == win.ERROR_IO_INCOMPLETE);
      }
      if (!result.value) {
        if (data == null &&
            (result.error == win.ERROR_BROKEN_PIPE ||
                result.error == win.ERROR_PIPE_NOT_CONNECTED)) {
          return Uint8List(0);
        }
        throw SocketException(
          'Docker pipe ${data == null ? 'read' : 'write'} failed',
          osError: OSError('', result.error),
        );
      }
      if (data != null && count.value != data.length) {
        throw const SocketException('Incomplete Docker pipe write');
      }
      return data == null
          ? Uint8List.fromList(buffer.asTypedList(count.value))
          : Uint8List(0);
    } finally {
      // Pending I/O has completed (including cancellation) before native memory is freed.
      if (event != null) win.CloseHandle(event);
      calloc.free(operation);
      calloc.free(count);
      calloc.free(buffer);
      _operations--;
      _closeHandle();
    }
  }

  Future<void> _read() async {
    try {
      while (!_closed) {
        if (_paused != null) await _paused!.future;
        if (_closed) break;
        final data = await _transfer();
        if (data.isEmpty) break;
        if (!_closed) _input.add(data);
      }
    } catch (error, stack) {
      if (!_closed) _input.addError(error, stack);
    } finally {
      destroy();
      await _input.close();
    }
  }

  void _closeHandle() {
    if (_closed && _operations == 0 && !_handleClosed) {
      _handleClosed = true;
      win.CloseHandle(_handle);
    }
  }

  @override
  void destroy() {
    if (_closed) return;
    _closed = true;
    win.CancelIoEx(_handle, null);
    _paused?.complete();
    _paused = null;
    _output.close();
    _closeHandle();
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _input.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  void add(List<int> data) => _output.add(data);
  @override
  Future<void> addStream(Stream<List<int>> stream) => _output.addStream(stream);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      throw UnsupportedError('Socket.addError');
  @override
  void write(Object? object) => _output.write(object);
  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _output.writeAll(objects, separator);
  @override
  void writeln([Object? object = '']) => _output.writeln(object);
  @override
  void writeCharCode(int charCode) => _output.writeCharCode(charCode);
  @override
  Encoding get encoding => _output.encoding;
  @override
  set encoding(Encoding value) => _output.encoding = value;
  @override
  Future<void> flush() => _output.flush();
  @override
  Future close() => _output.close();
  @override
  Future get done => _output.done;
  @override
  InternetAddress get address => InternetAddress.loopbackIPv4;
  @override
  InternetAddress get remoteAddress => address;
  @override
  int get port => 0;
  @override
  int get remotePort => 0;
  @override
  bool setOption(SocketOption option, bool enabled) => false;
  @override
  Uint8List getRawOption(RawSocketOption option) =>
      throw UnsupportedError('Pipe socket option');
  @override
  void setRawOption(RawSocketOption option) =>
      throw UnsupportedError('Pipe socket option');
  // Socket's private raw-detach API is not available for named pipes or TLS upgrades.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PipeWriter implements StreamConsumer<List<int>> {
  final WindowsPipeSocket socket;
  _PipeWriter(this.socket);
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      if (data.isNotEmpty) await socket._transfer(data: data);
    }
  }

  @override
  Future<void> close() async {}
}
