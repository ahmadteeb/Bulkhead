import 'package:bulkhead/core/docker_api_client.dart';
import 'package:bulkhead/core/compose_cli_client.dart';
import 'package:bulkhead/models/compose_stack_model.dart';
import 'package:bulkhead/models/container_model.dart';
import 'package:bulkhead/models/docker_event_model.dart';
import 'package:bulkhead/models/image_model.dart';
import 'package:bulkhead/models/network_model.dart';
import 'package:bulkhead/models/volume_model.dart';

class PreviewDocker extends DockerApiClient {
  @override
  Future<bool> ping() async => true;
  @override
  Stream<DockerEventModel> streamEvents() => Stream.multi((_) {});
  @override
  Future<List<ContainerModel>> getContainers({bool showAll = true}) async => [
    for (final (name, image, state) in [
      ('api-server', 'node:22-alpine', 'running'),
      ('postgres', 'postgres:17', 'running'),
      ('redis-cache', 'redis:7-alpine', 'running'),
      ('worker', 'bulkhead/worker:latest', 'exited'),
    ])
      ContainerModel.fromJson({
        'Id': 'abcdef123456$name',
        'Names': ['/$name'],
        'Image': image,
        'State': state,
        'Status': state == 'running' ? 'Up 2 hours' : 'Exited (0)',
        'Created': 1700000000,
      }),
  ];
  @override
  Future<List<ImageModel>> getImages({bool showAll = true}) async => [];
  @override
  Future<List<VolumeModel>> getVolumes() async => [];
  @override
  Future<List<NetworkModel>> getNetworks() async => [];
  @override
  Future<Map<String, dynamic>> getSystemDf() async => {
    'Images': [
      {'Size': 1258291200},
    ],
    'Containers': [
      {'SizeRw': 52428800},
    ],
    'Volumes': [
      {
        'UsageData': {'Size': 209715200},
      },
    ],
  };
}

class PreviewCompose extends ComposeCliClient {
  @override
  Future<List<String>> getStackProfiles(String configPath) async => [];
  @override
  Future<bool> isComposeInstalled() async => true;
  @override
  Future<List<ComposeStackModel>> listStacks() async => [];
}
