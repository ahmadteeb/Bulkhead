import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/volume_model.dart';
import 'connection_status_provider.dart';

class VolumesState {
  final List<VolumeModel> volumes;
  final bool isLoading;
  final String? error;

  VolumesState({
    required this.volumes,
    this.isLoading = false,
    this.error,
  });

  VolumesState copyWith({
    List<VolumeModel>? volumes,
    bool? isLoading,
    String? error,
  }) {
    return VolumesState(
      volumes: volumes ?? this.volumes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final volumeSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredVolumesProvider = Provider<List<VolumeModel>>((ref) {
  final state = ref.watch(volumesNotifierProvider);
  final search = ref.watch(volumeSearchQueryProvider).toLowerCase().trim();

  if (search.isEmpty) return state.volumes;

  return state.volumes.where((vol) {
    return vol.name.toLowerCase().contains(search) ||
        vol.driver.toLowerCase().contains(search) ||
        vol.mountpoint.toLowerCase().contains(search);
  }).toList();
});

class VolumesNotifier extends StateNotifier<VolumesState> {
  final dynamic _client;
  final bool _isConnected;

  VolumesNotifier(this._client, this._isConnected)
      : super(VolumesState(volumes: [], isLoading: true)) {
    if (_isConnected) {
      refreshVolumes();
    } else {
      state = VolumesState(volumes: [], isLoading: false, error: 'Docker daemon disconnected');
    }
  }

  Future<void> refreshVolumes({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final list = await _client.getVolumes();
      state = VolumesState(volumes: list, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createVolume(String name) async {
    try {
      await _client.createVolume(name);
      await refreshVolumes(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> removeVolume(String name, {bool force = false}) async {
    try {
      await _client.removeVolume(name, force: force);
      await refreshVolumes(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> pruneVolumes() async {
    try {
      final res = await _client.pruneVolumes();
      await refreshVolumes(silent: true);
      return res;
    } catch (e) {
      return {'Error': e.toString()};
    }
  }
}

final volumesNotifierProvider =
    StateNotifierProvider<VolumesNotifier, VolumesState>((ref) {
  final client = ref.watch(dockerApiClientProvider);
  final connState = ref.watch(connectionStatusProvider);
  return VolumesNotifier(client, connState.isConnected);
});
