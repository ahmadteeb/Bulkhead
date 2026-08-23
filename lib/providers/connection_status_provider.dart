import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/docker_api_client.dart';
import '../core/docker_socket_connection.dart';
import 'settings_provider.dart';

enum ConnectionStateEnum {
  connecting,
  connected,
  permissionDenied,
  socketNotFound,
  error,
}

class ConnectionStatusState {
  final ConnectionStateEnum status;
  final String? errorMessage;

  ConnectionStatusState({
    required this.status,
    this.errorMessage,
  });

  bool get isConnected => status == ConnectionStateEnum.connected;
}

final dockerApiClientProvider = Provider<DockerApiClient>((ref) {
  final socketPath = ref.watch(socketPathProvider);
  return DockerApiClient(socket: DockerSocketConnection(socketPath: socketPath));
});

final connectionStatusProvider =
    StateNotifierProvider<ConnectionStatusNotifier, ConnectionStatusState>((ref) {
  final client = ref.watch(dockerApiClientProvider);
  return ConnectionStatusNotifier(client);
});

class ConnectionStatusNotifier extends StateNotifier<ConnectionStatusState> {
  final DockerApiClient _client;

  ConnectionStatusNotifier(this._client)
      : super(ConnectionStatusState(status: ConnectionStateEnum.connecting)) {
    checkConnection();
  }

  Future<void> checkConnection() async {
    try {
      final ok = await _client.ping();
      if (ok) {
        state = ConnectionStatusState(status: ConnectionStateEnum.connected);
      } else {
        state = ConnectionStatusState(
          status: ConnectionStateEnum.error,
          errorMessage: 'Docker daemon returned unexpected response.',
        );
      }
    } on DockerPermissionDeniedException catch (e) {
      state = ConnectionStatusState(
        status: ConnectionStateEnum.permissionDenied,
        errorMessage: e.message,
      );
    } on DockerSocketNotFoundException catch (e) {
      state = ConnectionStatusState(
        status: ConnectionStateEnum.socketNotFound,
        errorMessage: e.message,
      );
    } catch (e) {
      state = ConnectionStatusState(
        status: ConnectionStateEnum.error,
        errorMessage: e.toString(),
      );
    }
  }
}
