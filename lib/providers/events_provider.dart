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

          // 100% Real-Time Auto Refresh across ALL providers on ANY Docker Engine event
          _ref.read(containersNotifierProvider.notifier).refreshContainers(silent: true);
          _ref.read(imagesNotifierProvider.notifier).refreshImages(silent: true);
          _ref.read(volumesNotifierProvider.notifier).refreshVolumes(silent: true);
          _ref.read(networksNotifierProvider.notifier).refreshNetworks(silent: true);
          _ref.read(composeStacksNotifierProvider.notifier).refreshStacks(silent: true);
          _ref.invalidate(systemDfProvider);
        },
        onError: (_) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || !mounted) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_isDisposed && mounted) {
        _subscribe();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
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
