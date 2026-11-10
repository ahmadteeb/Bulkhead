import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/docker_event_model.dart';
import 'compose_provider.dart';
import 'connection_status_provider.dart';
import 'containers_provider.dart';
import 'images_provider.dart';
import 'networks_provider.dart';
import 'volumes_provider.dart';

final dockerEventsProvider = StreamProvider<DockerEventModel>((ref) async* {
  final client = ref.watch(dockerApiClientProvider);
  final connState = ref.watch(connectionStatusProvider);

  if (!connState.isConnected) {
    return;
  }

  yield* client.streamEvents();
});

class DockerEventsNotifier extends StateNotifier<List<DockerEventModel>> {
  final dynamic _client;
  final Ref _ref;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _refreshTimer;
  final Set<String> _pendingTypes = {};
  bool _refreshing = false;
  bool _isDisposed = false;

  DockerEventsNotifier(this._client, this._ref) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    if (_isDisposed || !mounted) return;
    _sub?.cancel();
    _reconnectTimer?.cancel();

    try {
      final stream = _client.streamEvents();
      _sub = stream.listen(
        (event) {
          if (_isDisposed || !mounted) return;
          state = [event, ...state.take(49)];

          if (!{
            'container',
            'image',
            'volume',
            'network',
          }.contains(event.type)) {
            return;
          }
          if (event.type == 'container' &&
              (event.action.startsWith('exec_') ||
                  {'attach', 'detach', 'resize'}.contains(event.action))) {
            return;
          }
          _pendingTypes.add(event.type);
          _refreshTimer ??= Timer(const Duration(milliseconds: 250), _refresh);
        },
        onError: (Object error) {
          _scheduleReconnect(error);
        },
        onDone: () {
          _scheduleReconnect(StateError('Docker event stream closed'));
        },
        cancelOnError: true,
      );
    } catch (error) {
      _scheduleReconnect(error);
    }
  }

  Future<void> _refresh() async {
    _refreshTimer = null;
    if (_isDisposed || _refreshing) return;
    _refreshing = true;
    final types = Set<String>.from(_pendingTypes);
    _pendingTypes.clear();
    try {
      await Future.wait([
        if (types.contains('container')) ...[
          _ref
              .read(containersNotifierProvider.notifier)
              .refreshContainers(silent: true),
          _ref
              .read(composeStacksNotifierProvider.notifier)
              .refreshStacks(silent: true),
        ],
        if (types.contains('image'))
          _ref
              .read(imagesNotifierProvider.notifier)
              .refreshImages(silent: true),
        if (types.contains('volume'))
          _ref
              .read(volumesNotifierProvider.notifier)
              .refreshVolumes(silent: true),
        if (types.contains('network'))
          _ref
              .read(networksNotifierProvider.notifier)
              .refreshNetworks(silent: true),
      ]);
      if (!_isDisposed) _ref.invalidate(systemDfProvider);
    } finally {
      _refreshing = false;
      if (!_isDisposed && _pendingTypes.isNotEmpty) {
        _refreshTimer ??= Timer(const Duration(milliseconds: 250), _refresh);
      }
    }
  }

  void _scheduleReconnect([Object? error]) {
    if (_isDisposed || !mounted) return;
    if (error != null) {
      _ref.read(connectionStatusProvider.notifier).markDisconnected(error);
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      if (_isDisposed || !mounted) return;
      await _ref.read(connectionStatusProvider.notifier).checkConnection();
      if (_isDisposed || !mounted) return;
      if (_ref.read(connectionStatusProvider).isConnected) {
        _subscribe();
      } else {
        _scheduleReconnect();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final recentEventsListProvider =
    StateNotifierProvider<DockerEventsNotifier, List<DockerEventModel>>((ref) {
      final client = ref.watch(dockerApiClientProvider);
      return DockerEventsNotifier(client, ref);
    });
