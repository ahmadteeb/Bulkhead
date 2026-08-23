import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/container_model.dart';
import 'connection_status_provider.dart';

class ContainersState {
  final List<ContainerModel> containers;
  final bool isLoading;
  final String? error;

  ContainersState({
    required this.containers,
    this.isLoading = false,
    this.error,
  });

  ContainersState copyWith({
    List<ContainerModel>? containers,
    bool? isLoading,
    String? error,
  }) {
    return ContainersState(
      containers: containers ?? this.containers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final containerSearchQueryProvider = StateProvider<String>((ref) => '');
final containerFilterStateProvider = StateProvider<String>((ref) => 'all'); // 'all', 'running', 'stopped'

final filteredContainersProvider = Provider<List<ContainerModel>>((ref) {
  final state = ref.watch(containersNotifierProvider);
  final search = ref.watch(containerSearchQueryProvider).toLowerCase().trim();
  final filterState = ref.watch(containerFilterStateProvider);

  return state.containers.where((c) {
    if (filterState == 'running' && c.state != 'running') return false;
    if (filterState == 'stopped' && c.state == 'running') return false;

    if (search.isEmpty) return true;
    return c.name.toLowerCase().contains(search) ||
        c.image.toLowerCase().contains(search) ||
        c.id.toLowerCase().contains(search) ||
        c.status.toLowerCase().contains(search);
  }).toList();
});

final systemDfProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = ref.watch(dockerApiClientProvider);
  final connState = ref.watch(connectionStatusProvider);
  if (!connState.isConnected) {
    return {'images': 0, 'containers': 0, 'volumes': 0, 'total': 0};
  }

  try {
    final df = await client.getSystemDf();

    int imagesBytes = 0;
    final imagesList = df['Images'] as List<dynamic>? ?? [];
    for (final img in imagesList) {
      if (img is Map<String, dynamic>) {
        imagesBytes += (img['Size'] as int? ?? 0);
      }
    }

    int containersBytes = 0;
    final containersList = df['Containers'] as List<dynamic>? ?? [];
    for (final c in containersList) {
      if (c is Map<String, dynamic>) {
        containersBytes += (c['SizeRw'] as int? ?? 0);
      }
    }

    int volumesBytes = 0;
    final volumesList = df['Volumes'] as List<dynamic>? ?? [];
    for (final v in volumesList) {
      if (v is Map<String, dynamic>) {
        final usage = v['UsageData'] as Map<String, dynamic>? ?? {};
        volumesBytes += (usage['Size'] as int? ?? 0);
      }
    }

    final total = imagesBytes + containersBytes + volumesBytes;
    return {
      'images': imagesBytes,
      'containers': containersBytes,
      'volumes': volumesBytes,
      'total': total,
    };
  } catch (_) {
    return {'images': 0, 'containers': 0, 'volumes': 0, 'total': 0};
  }
});

class ContainersNotifier extends StateNotifier<ContainersState> {
  final dynamic _client;
  final bool _isConnected;

  ContainersNotifier(this._client, this._isConnected)
      : super(ContainersState(containers: [], isLoading: true)) {
    if (_isConnected) {
      refreshContainers();
    } else {
      state = ContainersState(containers: [], isLoading: false, error: 'Docker daemon disconnected');
    }
  }

  Future<void> refreshContainers({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final list = await _client.getContainers(showAll: true);
      state = ContainersState(containers: list, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startContainer(String id) async {
    try {
      await _client.startContainer(id);
      await refreshContainers(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> stopContainer(String id) async {
    try {
      await _client.stopContainer(id);
      await refreshContainers(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> restartContainer(String id) async {
    try {
      await _client.restartContainer(id);
      await refreshContainers(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> removeContainer(String id, {bool force = false}) async {
    try {
      await _client.removeContainer(id, force: force);
      await refreshContainers(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final containersNotifierProvider =
    StateNotifierProvider<ContainersNotifier, ContainersState>((ref) {
  final client = ref.watch(dockerApiClientProvider);
  final connState = ref.watch(connectionStatusProvider);
  return ContainersNotifier(client, connState.isConnected);
});
