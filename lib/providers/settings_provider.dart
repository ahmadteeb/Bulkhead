import 'package:flutter/material.dart';
import '../core/docker_socket_connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socketPathProvider = StateProvider<String>(
  (ref) => DockerSocketConnection.defaultSocketPath,
);

final appThemeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.system,
);
