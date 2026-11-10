import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/compose_cli_client.dart';
import '../models/compose_stack_model.dart';
import 'connection_status_provider.dart';
import 'settings_provider.dart';

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
  return ComposeCliClient(socketPath: ref.watch(socketPathProvider));
});

final composeAvailableProfilesProvider =
    FutureProvider.family<List<String>, String>((ref, configFiles) {
      return ref.watch(composeCliClientProvider).getStackProfiles(configFiles);
    });

// Choices survive resource refreshes and temporary daemon disconnects.
final composeSelectedProfilesProvider =
    StateProvider.family<Set<String>, String>((ref, configFiles) => {});

class ComposeStacksNotifier extends StateNotifier<ComposeState> {
  final ComposeCliClient _cli;
  final bool _isConnected;
  final Ref _ref;
  int _refreshGeneration = 0;
  final Set<String> _trackedFilePaths = {};

  ComposeStacksNotifier(this._cli, this._isConnected, this._ref)
    : super(ComposeState(stacks: [], isLoading: true)) {
    if (_isConnected) {
      _init();
    } else {
      state = ComposeState(
        stacks: [],
        isLoading: false,
        error: 'Docker daemon disconnected',
      );
    }
  }

  Future<void> _init() async {
    final installed = await _cli.isComposeInstalled();
    if (!mounted) return;
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
    if (!mounted) return;
    final generation = ++_refreshGeneration;
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final activeList = await _cli.listStacks();
      if (!mounted || generation != _refreshGeneration) return;

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
          final dirName = p.basename(
            p.dirname(parseComposePaths(filePath).first),
          );
          final stackName = dirName.isEmpty
              ? p.basenameWithoutExtension(parseComposePaths(filePath).first)
              : dirName;

          combined.add(
            ComposeStackModel(
              name: stackName,
              status: 'stopped',
              configFiles: filePath,
            ),
          );
        }
      }

      state = state.copyWith(stacks: combined, isLoading: false, error: null);
    } catch (e) {
      if (!mounted || generation != _refreshGeneration) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<String> _profilesFor(String files) =>
      _ref.read(composeSelectedProfilesProvider(files)).toList()..sort();

  Future<void> stackUp(String composeFilePath) async {
    try {
      _trackedFilePaths.add(composeFilePath);
      await _cli.stackUp(
        composeFilePath,
        profiles: _profilesFor(composeFilePath),
      );
      if (mounted) {
        await refreshStacks(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> stackDown(String composeFilePath) async {
    try {
      _trackedFilePaths.add(composeFilePath);
      await _cli.stackDown(
        composeFilePath,
        profiles: _profilesFor(composeFilePath),
      );
      if (mounted) {
        await refreshStacks(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> stackRestart(String composeFilePath) async {
    try {
      _trackedFilePaths.add(composeFilePath);
      await _cli.stackRestart(
        composeFilePath,
        profiles: _profilesFor(composeFilePath),
      );
      if (mounted) {
        await refreshStacks(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> removeStack(
    String composeFilePath, {
    bool removeVolumes = true,
  }) async {
    try {
      await _cli.removeStack(
        composeFilePath,
        removeVolumes: removeVolumes,
        profiles: _profilesFor(composeFilePath),
      );
      _trackedFilePaths.remove(composeFilePath);
      if (mounted) {
        await refreshStacks(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<String> createStack(
    String dirPath,
    String filename,
    String yamlContent, {
    bool startNow = true,
    List<String> profiles = const [],
  }) async {
    try {
      final path = await _cli.createStack(
        dirPath,
        filename,
        yamlContent,
        startNow: startNow,
        profiles: profiles,
      );
      _trackedFilePaths.add(path);
      if (mounted) {
        _ref.read(composeSelectedProfilesProvider(path).notifier).state =
            profiles.toSet();
        await refreshStacks(silent: true);
      }
      return path;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }
}

final composeStacksNotifierProvider =
    StateNotifierProvider<ComposeStacksNotifier, ComposeState>((ref) {
      final cli = ref.watch(composeCliClientProvider);
      final connState = ref.watch(connectionStatusProvider);
      return ComposeStacksNotifier(cli, connState.isConnected, ref);
    });
