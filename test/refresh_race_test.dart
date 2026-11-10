import 'dart:async';
import 'package:bulkhead/core/docker_api_client.dart';
import 'package:bulkhead/models/image_model.dart';
import 'package:bulkhead/providers/images_provider.dart';
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedDocker extends DockerApiClient {
  final images = <Completer<List<ImageModel>>>[];
  final pings = <Completer<bool>>[];
  @override
  Future<List<ImageModel>> getImages({bool showAll = true}) {
    final request = Completer<List<ImageModel>>();
    images.add(request);
    return request.future;
  }

  @override
  Future<bool> ping() {
    final request = Completer<bool>();
    pings.add(request);
    return request.future;
  }
}

void main() {
  test('an older resource refresh cannot overwrite a newer result', () async {
    final client = DelayedDocker();
    final notifier = ImagesNotifier(client, false);
    addTearDown(notifier.dispose);
    final older = notifier.refreshImages();
    final newer = notifier.refreshImages();
    client.images[1].complete([
      ImageModel.fromJson({'Id': 'new'}),
    ]);
    await newer;
    client.images[0].complete([
      ImageModel.fromJson({'Id': 'old'}),
    ]);
    await older;
    expect(notifier.state.images.single.id, 'new');
  });

  test(
    'a stale failed ping cannot mark a recovered engine disconnected',
    () async {
      final client = DelayedDocker();
      final notifier = ConnectionStatusNotifier(client);
      addTearDown(notifier.dispose);
      final newer = notifier.checkConnection();
      client.pings[1].complete(true);
      await newer;
      client.pings[0].complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isConnected, isTrue);
    },
  );
}
