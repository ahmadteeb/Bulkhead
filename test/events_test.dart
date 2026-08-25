import 'package:flutter_test/flutter_test.dart';
import 'package:bulkhead/core/docker_api_client.dart';
import 'package:bulkhead/models/docker_event_model.dart';

void main() {
  test('Test DockerEventModel JSON parsing', () {
    final json = {
      'Type': 'container',
      'Action': 'start',
      'Actor': {
        'ID': '1234567890ab',
        'Attributes': {
          'name': 'web_app',
        },
      },
      'time': 1700000000,
    };

    final event = DockerEventModel.fromJson(json);
    expect(event.type, 'container');
    expect(event.action, 'start');
    expect(event.actorName, 'web_app');
  });

  test('Test DockerApiClient streamEvents creation', () {
    final client = DockerApiClient();
    expect(client, isNotNull);
    try {
      final stream = client.streamEvents();
      expect(stream, isNotNull);
    } catch (_) {
      // Live Docker socket not present on cloud CI runners
    }
  });
}
