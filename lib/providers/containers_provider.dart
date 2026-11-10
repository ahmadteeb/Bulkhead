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
final containerFilterStateProvider = StateProvider<String>(
  (ref) => 'all',
); // 'all', 'running', 'stopped'

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

  final df = await client.getSystemDf();
  return parseSystemDiskUsage(df);
});

Map<String, int> parseSystemDiskUsage(Map<String, dynamic> df) {
  int knownSize(Object? value) => value is num && value > 0 ? value.toInt() : 0;
  var images = 0;
  for (final image in df['Images'] as List? ?? []) {
    images += knownSize(image['Size']);
  }
  final layersSize = df['LayersSize'];
  if (layersSize is num && layersSize >= 0) images = layersSize.toInt();
  var containers = 0;
  for (final container in df['Containers'] as List? ?? []) {
    containers += knownSize(container['SizeRw']);
  }
  var volumes = 0;
  for (final volume in df['Volumes'] as List? ?? []) {
    volumes += knownSize(volume['UsageData']?['Size']);
  }
  return {
    'images': images,
    'containers': containers,
    'volumes': volumes,
    'total': images + containers + volumes,
  };
}

class ContainersNotifier extends StateNotifier<ContainersState> {
  final dynamic _client;
  final bool _isConnected;
  int _refreshGeneration = 0;

  ContainersNotifier(this._client, this._isConnected)
    : super(ContainersState(containers: [], isLoading: true)) {
    if (_isConnected) {
      refreshContainers();
    } else {
      state = ContainersState(
        containers: [],
        isLoading: false,
        error: 'Docker daemon disconnected',
      );
    }
  }

  Future<void> refreshContainers({bool silent = false}) async {
    if (!mounted) return;
    final generation = ++_refreshGeneration;
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final list = await _client.getContainers(showAll: true);
      if (!mounted || generation != _refreshGeneration) return;
      state = ContainersState(containers: list, isLoading: false, error: null);
    } catch (e) {
      if (!mounted || generation != _refreshGeneration) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String> createContainer({
    required String name,
    required String image,
    List<String>? env,
    Map<String, String>? portMappings,
    bool autoStart = true,
  }) async {
    try {
      final id = await _client.createContainer(
        name: name,
        image: image,
        env: env,
        portMappings: portMappings,
        autoStart: autoStart,
      );
      if (mounted) {
        await refreshContainers(silent: true);
      }
      return id;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> startContainer(String id) async {
    try {
      await _client.startContainer(id);
      if (mounted) {
        await refreshContainers(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> stopContainer(String id) async {
    try {
      await _client.stopContainer(id);
      if (mounted) {
        await refreshContainers(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> restartContainer(String id) async {
    try {
      await _client.restartContainer(id);
      if (mounted) {
        await refreshContainers(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> removeContainer(String id, {bool force = false}) async {
    try {
      await _client.removeContainer(id, force: force);
      if (mounted) {
        await refreshContainers(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
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
