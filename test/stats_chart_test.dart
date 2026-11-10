import 'dart:async';
import 'package:bulkhead/features/containers/container_detail_screen.dart';
import 'package:bulkhead/providers/connection_status_provider.dart';
import 'package:bulkhead/providers/settings_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/preview_clients.dart';

class StatsDocker extends PreviewDocker {
  final stats = StreamController<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> inspectContainer(String id) async => {
    'Config': <String, dynamic>{},
  };
  @override
  Stream<String> streamContainerLogs(
    String id, {
    int tail = 200,
    bool follow = true,
  }) => Stream.multi((_) {});
  @override
  Stream<Map<String, dynamic>> streamContainerStats(String id) => stats.stream;
  @override
  Future<List<Map<String, String>>> listContainerFiles(
    String containerId,
    String path,
  ) async => [];
}

void main() {
  testWidgets('charts retain increasing time coordinates after 30 samples', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = StatsDocker();
    addTearDown(client.stats.close);
    final container = (await client.getContainers()).first;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dockerApiClientProvider.overrideWithValue(client),
          socketPathProvider.overrideWith(
            (ref) => '/tmp/bulkhead-test-missing.sock',
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ContainerDetailScreen(container: container, onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index = 3;
    await tester.pumpAndSettle();
    for (var i = 0; i < 60; i++) {
      client.stats.add({
        'cpu_stats': {
          'cpu_usage': {'total_usage': 20},
          'system_cpu_usage': 200,
          'online_cpus': 1,
        },
        'precpu_stats': {
          'cpu_usage': {'total_usage': 10},
          'system_cpu_usage': 100,
        },
        'memory_stats': {'usage': 1024, 'limit': 4096},
      });
    }
    await tester.pumpAndSettle();
    final charts = tester.widgetList<LineChart>(find.byType(LineChart));
    expect(charts.length, 2);
    for (final chart in charts) {
      expect(chart.data.lineBarsData.single.spots.map((point) => point.x), [
        for (var i = 30; i < 60; i++) i.toDouble(),
      ]);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
