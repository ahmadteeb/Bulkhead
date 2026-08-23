import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/docker_event_model.dart';
import 'connection_status_provider.dart';
import 'containers_provider.dart';
import 'images_provider.dart';
import 'networks_provider.dart';
import 'volumes_provider.dart';

final dockerEventsProvider = StreamProvider.autoDispose<DockerEventModel>((ref) async* {
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

  DockerEventsNotifier(this._client, this._ref) : super([]) {
    _subscribe();
  }

  void _subscribe() {
    try {
      final stream = _client.streamEvents();
      _sub = stream.listen((event) {
        state = [event, ...state.take(49)];

        // Real-time automatic provider sync upon Docker Engine events
        if (event.type == 'container') {
          _ref.read(containersNotifierProvider.notifier).refreshContainers();
        } else if (event.type == 'image') {
          _ref.read(imagesNotifierProvider.notifier).refreshImages();
        } else if (event.type == 'volume') {
          _ref.read(volumesNotifierProvider.notifier).refreshVolumes();
        } else if (event.type == 'network') {
          _ref.read(networksNotifierProvider.notifier).refreshNetworks();
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final recentEventsListProvider =
    StateNotifierProvider<DockerEventsNotifier, List<DockerEventModel>>((ref) {
  final client = ref.watch(dockerApiClientProvider);
  return DockerEventsNotifier(client, ref);
});
