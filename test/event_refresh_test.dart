import 'dart:async';

import 'package:bulkhead/core/docker_api_client.dart';
import 'package:bulkhead/models/docker_event_model.dart';
import 'package:bulkhead/models/image_model.dart';
import 'package:bulkhead/models/container_model.dart';
import 'package:bulkhead/providers/compose_provider.dart';
import 'support/preview_clients.dart' show PreviewCompose;
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:bulkhead/providers/events_provider.dart';
import 'package:bulkhead/providers/images_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class EventDocker extends DockerApiClient {
  final events = StreamController<DockerEventModel>.broadcast();
  int imageCalls = 0;
  int containerCalls = 0;
  int subscriptions = 0;
  bool alive = true;
  @override
  Future<bool> ping() async => alive;
  @override
  Stream<DockerEventModel> streamEvents() {
    subscriptions++;
    return events.stream;
  }

  @override
  Future<List<ContainerModel>> getContainers({bool showAll = true}) async {
    containerCalls++;
    return [];
  }

  @override
  Future<List<ImageModel>> getImages({bool showAll = true}) async {
    imageCalls++;
    return [];
  }
}

void main() {
  test(
    'image event bursts share one refresh and keep only 50 recent events',
    () async {
      final client = EventDocker();
      final container = ProviderContainer(
        overrides: [dockerApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(() async {
        container.dispose();
        await client.events.close();
      });
      container.read(connectionStatusProvider);
      await Future<void>.delayed(Duration.zero);
      container.read(imagesNotifierProvider);
      container.read(recentEventsListProvider);
      await Future<void>.delayed(Duration.zero);
      final before = client.imageCalls;
      for (var i = 0; i < 100; i++) {
        client.events.add(
          DockerEventModel.fromJson({
            'Type': 'image',
            'Action': 'pull',
            'time': i,
            'Actor': {'ID': '$i', 'Attributes': <String, String>{}},
          }),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(client.imageCalls - before, 1);
      expect(container.read(recentEventsListProvider).length, 50);
      expect(container.read(recentEventsListProvider).first.actorId, '99');
    },
  );
  test('exec events do not launch resource refreshes', () async {
    final client = EventDocker();
    final container = ProviderContainer(
      overrides: [
        dockerApiClientProvider.overrideWithValue(client),
        composeCliClientProvider.overrideWithValue(PreviewCompose()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await client.events.close();
    });
    container.read(recentEventsListProvider);
    for (final action in ['exec_create', 'exec_start', 'exec_die', 'resize']) {
      client.events.add(
        DockerEventModel.fromJson({'Type': 'container', 'Action': action}),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(client.containerCalls, 0);
    expect(container.read(recentEventsListProvider).length, 4);
  });

  test(
    'event stream failures mark the engine offline and reconnect after recovery',
    () async {
      final client = EventDocker();
      final container = ProviderContainer(
        overrides: [dockerApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(() async {
        container.dispose();
        await client.events.close();
      });
      container.read(connectionStatusProvider);
      container.read(recentEventsListProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(connectionStatusProvider).isConnected, isTrue);
      client.alive = false;
      client.events.addError(StateError('engine stopped'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(connectionStatusProvider).isConnected, isFalse);
      client.alive = true;
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(container.read(connectionStatusProvider).isConnected, isTrue);
      expect(client.subscriptions, 2);
    },
  );
}
