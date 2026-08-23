import 'package:flutter_test/flutter_test.dart';
import 'package:bulkhead/core/docker_api_client.dart';

void main() {
  test('Test Docker Socket Connection and API client ping', () async {
    final client = DockerApiClient();
    final isAlive = await client.ping();
    expect(isAlive, isTrue);

    final containers = await client.getContainers(showAll: true);
    expect(containers, isNotNull);
  });
}
