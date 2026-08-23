import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/compose_cli_client.dart';
import '../models/compose_stack_model.dart';
import 'connection_status_provider.dart';

class ComposeState {
  final List<ComposeStackModel> stacks;
  final bool isLoading;
  final bool isInstalled;
  final String? error;

  ComposeState({
    required this.stacks,
    this.isLoading = false,
    this.isInstalled = true,
    this.error,
  });

  ComposeState copyWith({
    List<ComposeStackModel>? stacks,
    bool? isLoading,
    bool? isInstalled,
    String? error,
  }) {
    return ComposeState(
      stacks: stacks ?? this.stacks,
      isLoading: isLoading ?? this.isLoading,
      isInstalled: isInstalled ?? this.isInstalled,
      error: error,
    );
  }
}

final composeCliClientProvider = Provider<ComposeCliClient>((ref) {
  return ComposeCliClient();
});

class ComposeStacksNotifier extends StateNotifier<ComposeState> {
  final ComposeCliClient _cli;
  final bool _isConnected;
  final Set<String> _trackedFilePaths = {};

  ComposeStacksNotifier(this._cli, this._isConnected)
      : super(ComposeState(stacks: [], isLoading: true)) {
    if (_isConnected) {
      _init();
    } else {
      state = ComposeState(stacks: [], isLoading: false, error: 'Docker daemon disconnected');
    }
  }

  Future<void> _init() async {
    final installed = await _cli.isComposeInstalled();
    if (!installed) {
      state = ComposeState(
        stacks: [],
        isLoading: false,
        isInstalled: false,
        error: 'Docker Compose CLI binary not found on PATH',
      );
      return;
    }

    refreshStacks();
  }

  Future<void> refreshStacks({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final activeList = await _cli.listStacks();

      // Track active stack paths
      for (final s in activeList) {
        if (s.configFiles.isNotEmpty) {
          _trackedFilePaths.add(s.configFiles);
        }
      }

      final combined = <ComposeStackModel>[...activeList];

      // Re-add tracked stacks that are down/inactive so users can UP them again!
      for (final filePath in _trackedFilePaths) {
        final existsInActive = combined.any((s) => s.configFiles == filePath);
        if (!existsInActive) {
          final dirName = p.basename(p.dirname(filePath));
          final stackName = dirName.isEmpty ? p.basenameWithoutExtension(filePath) : dirName;

          combined.add(ComposeStackModel(
            name: stackName,
            status: 'stopped',
            configFiles: filePath,
          ));
        }
      }

      state = state.copyWith(stacks: combined, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> stackUp(String composeFilePath) async {
    try {
      _trackedFilePaths.add(composeFilePath);
      await _cli.stackUp(composeFilePath);
      await refreshStacks(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> stackDown(String composeFilePath) async {
    try {
      _trackedFilePaths.add(composeFilePath);
      await _cli.stackDown(composeFilePath);
      await refreshStacks(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> stackRestart(String composeFilePath) async {
    try {
      _trackedFilePaths.add(composeFilePath);
      await _cli.stackRestart(composeFilePath);
      await refreshStacks(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> removeStack(String composeFilePath, {bool removeVolumes = true}) async {
    try {
      await _cli.removeStack(composeFilePath, removeVolumes: removeVolumes);
      _trackedFilePaths.remove(composeFilePath);
      await refreshStacks(silent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<String> createStack(String dirPath, String filename, String yamlContent, {bool startNow = true}) async {
    try {
      final path = await _cli.createStack(dirPath, filename, yamlContent, startNow: startNow);
      _trackedFilePaths.add(path);
      await refreshStacks(silent: true);
      return path;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final composeStacksNotifierProvider =
    StateNotifierProvider<ComposeStacksNotifier, ComposeState>((ref) {
  final cli = ref.watch(composeCliClientProvider);
  final connState = ref.watch(connectionStatusProvider);
  return ComposeStacksNotifier(cli, connState.isConnected);
});
