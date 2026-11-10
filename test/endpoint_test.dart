import 'package:bulkhead/core/docker_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CLI host follows the selected socket or explicit TCP endpoint', () {
    expect(dockerHost('/tmp/docker.sock'), 'unix:///tmp/docker.sock');
    expect(
      dockerHost(r'\\.\pipe\docker_engine'),
      'npipe:////./pipe/docker_engine',
    );
    expect(dockerHost('tcp://127.0.0.1:2375'), 'tcp://127.0.0.1:2375');
    expect(dockerHost('http://127.0.0.1:2375'), 'tcp://127.0.0.1:2375');
    expect(dockerEnvironment('/tmp/docker.sock')['DOCKER_CONTEXT'], '');
  });

  test('external terminal arguments remain one literal shell argument', () {
    expect(
      shellQuote("a'\$(touch /tmp/nope)"),
      "'a'\"'\"'\$(touch /tmp/nope)'",
    );
  });
}
