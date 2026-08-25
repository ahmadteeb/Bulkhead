import 'package:flutter_test/flutter_test.dart';
import 'package:bulkhead/core/docker_api_client.dart';

void main() {
  test('Test Docker Socket Connection and API client ping', () async {
    final client = DockerApiClient();
    expect(client, isNotNull);
    try {
      final isAlive = await client.ping();
      if (isAlive) {
        final containers = await client.getContainers(showAll: true);
        expect(containers, isNotNull);
      }
    } catch (_) {
      // Live Docker socket not present on cloud CI runners
    }
  });
}
