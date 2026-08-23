import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socketPathProvider = StateProvider<String>((ref) => '/var/run/docker.sock');

final appThemeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
