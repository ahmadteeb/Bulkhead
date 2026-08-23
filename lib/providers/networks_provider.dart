import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/network_model.dart';
import 'connection_status_provider.dart';

class NetworksState {
  final List<NetworkModel> networks;
  final bool isLoading;
  final String? error;

  NetworksState({
    required this.networks,
    this.isLoading = false,
    this.error,
  });

  NetworksState copyWith({
    List<NetworkModel>? networks,
    bool? isLoading,
    String? error,
  }) {
    return NetworksState(
      networks: networks ?? this.networks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final networkSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredNetworksProvider = Provider<List<NetworkModel>>((ref) {
  final state = ref.watch(networksNotifierProvider);
  final search = ref.watch(networkSearchQueryProvider).toLowerCase().trim();

  if (search.isEmpty) return state.networks;

  return state.networks.where((net) {
    return net.name.toLowerCase().contains(search) ||
        net.driver.toLowerCase().contains(search) ||
        net.id.toLowerCase().contains(search);
  }).toList();
});

class NetworksNotifier extends StateNotifier<NetworksState> {
  final dynamic _client;
  final bool _isConnected;

  NetworksNotifier(this._client, this._isConnected)
      : super(NetworksState(networks: [], isLoading: true)) {
    if (_isConnected) {
      refreshNetworks();
    } else {
      state = NetworksState(networks: [], isLoading: false, error: 'Docker daemon disconnected');
    }
  }

  Future<void> refreshNetworks({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final list = await _client.getNetworks();
      state = NetworksState(networks: list, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createNetwork(String name, {String driver = 'bridge'}) async {
    try {
      await _client.createNetwork(name, driver: driver);
      await refreshNetworks(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> removeNetwork(String id) async {
    try {
      await _client.removeNetwork(id);
      await refreshNetworks(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final networksNotifierProvider =
    StateNotifierProvider<NetworksNotifier, NetworksState>((ref) {
  final client = ref.watch(dockerApiClientProvider);
  final connState = ref.watch(connectionStatusProvider);
  return NetworksNotifier(client, connState.isConnected);
});
