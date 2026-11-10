import '../../widgets/message_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../../models/compose_stack_model.dart';
import '../../providers/compose_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/resource_action.dart';
import '../../widgets/data_table_shell.dart';
import '../../widgets/page_header.dart';
import '../../widgets/log_viewer.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/compose_profiles_control.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  ComposeStackModel? _selectedStack;
  final Set<String> _selectedPaths = {};

  void _toggleSelectAll(List<ComposeStackModel> stacks, bool? value) {
    setState(() {
      if (value == true) {
        _selectedPaths.addAll(stacks.map((s) => s.configFiles));
      } else {
        _selectedPaths.clear();
      }
    });
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _showNewStackDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'my-service-stack');
    final dirController = TextEditingController(
      text: '/home/ahmadteeb/compose_stacks/my-service-stack',
    );
    final yamlController = TextEditingController(
      text: '''version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    restart: always
''',
    );
    final profilesController = TextEditingController();
    bool startNow = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.cardBg(context),
          title: const Text('Deploy New Compose Stack'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Stack Project Name',
                      hintText: 'e.g. my-app-stack',
                    ),
                    onChanged: (val) {
                      final name = val.trim();
                      if (name.isNotEmpty) {
                        dirController.text =
                            '/home/ahmadteeb/compose_stacks/$name';
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: dirController,
                    decoration: const InputDecoration(
                      labelText: 'Stack Directory Path',
                      hintText: '/path/to/stack/directory',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'docker-compose.yml Definition',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0E11),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderColor(context)),
                    ),
                    child: TextField(
                      controller: yamlController,
                      maxLines: null,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: profilesController,
                    decoration: const InputDecoration(
                      labelText: 'Profiles (optional)',
                      hintText: 'e.g. dev, tools',
                      helperText:
                          'Comma-separated profiles to enable for deployment.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: startNow,
                        onChanged: (val) =>
                            setStateDialog(() => startNow = val ?? true),
                      ),
                      const Text(
                        'Start containers immediately (docker compose up -d)',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final dirPath = dirController.text.trim();
                final yamlContent = yamlController.text;
                if (dirPath.isNotEmpty && yamlContent.isNotEmpty) {
                  try {
                    await ref
                        .read(composeStacksNotifierProvider.notifier)
                        .createStack(
                          dirPath,
                          'docker-compose.yml',
                          yamlContent,
                          startNow: startNow,
                          profiles: profilesController.text
                              .split(',')
                              .map((profile) => profile.trim())
                              .where((profile) => profile.isNotEmpty)
                              .toSet()
                              .toList(),
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (ctx.mounted) {
                      showMessageDialog(
                        ctx,
                        title: 'Operation failed',
                        message: 'Deploy Failed: $e',
                        type: MessageType.error,
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
              child: const Text('Deploy Stack'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      dirController.dispose();
      yamlController.dispose();
      profilesController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final composeState = ref.watch(composeStacksNotifierProvider);

    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final primaryContainerColor = Theme.of(
      context,
    ).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(
      context,
    ).colorScheme.onPrimaryContainer;
    final mutedTextColor = Theme.of(context).textTheme.bodySmall?.color;

    final isAllSelected =
        composeState.stacks.isNotEmpty &&
        composeState.stacks.every(
          (s) => _selectedPaths.contains(s.configFiles),
        );
    final isSomeSelected = composeState.stacks.any(
      (s) => _selectedPaths.contains(s.configFiles),
    );
    final selectAllValue = isAllSelected
        ? true
        : (isSomeSelected ? null : false);

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          PageHeader(
            title: 'Docker Compose Stacks',
            subtitle:
                'Manage services and deploy multi-container applications.',
            actions: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: composeState.isLoading
                      ? null
                      : () {
                          for (final stack in composeState.stacks) {
                            ref.invalidate(
                              composeAvailableProfilesProvider(
                                stack.configFiles,
                              ),
                            );
                          }
                          ref
                              .read(composeStacksNotifierProvider.notifier)
                              .refreshStacks();
                        },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showNewStackDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Deploy Stack'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryContainerColor,
                    foregroundColor: onPrimaryContainerColor,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // CLI Not Found Warning
          if (!composeState.isInstalled)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      composeState.error ??
                          'Docker Compose CLI binary not found on system PATH.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),

          // Main Table or Detail View
          Expanded(
            child: _selectedStack != null
                ? _ComposeStackDetailView(
                    stack: _selectedStack!,
                    onBack: () => setState(() => _selectedStack = null),
                  )
                : DataTableShell(
                    errorMessage: composeState.error,
                    onRetry: () => ref
                        .read(composeStacksNotifierProvider.notifier)
                        .refreshStacks(),
                    title: 'Active Compose Stacks',
                    subtitle: _selectedPaths.isEmpty
                        ? '${composeState.stacks.length} projects detected'
                        : '${_selectedPaths.length} stack(s) selected',
                    showSelectAll: true,
                    selectAllValue: selectAllValue,
                    onSelectAllChanged: (val) =>
                        _toggleSelectAll(composeState.stacks, val),
                    bulkActions: _selectedPaths.isEmpty
                        ? null
                        : [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final paths = List<String>.from(_selectedPaths);
                                if (!context.mounted) return;
                                if (!await runBulkResourceAction(
                                  context,
                                  'Start stack',
                                  paths,
                                  (p) => ref
                                      .read(
                                        composeStacksNotifierProvider.notifier,
                                      )
                                      .stackUp(p),
                                  onCompleted: (p) =>
                                      setState(() => _selectedPaths.remove(p)),
                                )) {
                                  return;
                                }
                              },
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: Text('Up (${_selectedPaths.length})'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final confirm = await ConfirmDialog.show(
                                  context,
                                  title: 'Down Selected Stacks',
                                  message:
                                      'Bring down ${_selectedPaths.length} stacks using each stack’s selected profiles? Default services are included.',
                                  confirmLabel: 'Down All',
                                );
                                if (confirm == true) {
                                  final paths = List<String>.from(
                                    _selectedPaths,
                                  );
                                  if (!context.mounted) return;
                                  if (!await runBulkResourceAction(
                                    context,
                                    'Stop stack',
                                    paths,
                                    (p) => ref
                                        .read(
                                          composeStacksNotifierProvider
                                              .notifier,
                                        )
                                        .stackDown(p),
                                    onCompleted: (p) => setState(
                                      () => _selectedPaths.remove(p),
                                    ),
                                  )) {
                                    return;
                                  }
                                }
                              },
                              icon: const Icon(Icons.pause, size: 16),
                              label: Text('Down (${_selectedPaths.length})'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.error,
                              ),
                              tooltip: 'Delete Selected Stacks',
                              onPressed: () async {
                                final confirm = await ConfirmDialog.show(
                                  context,
                                  title: 'Purge Selected Stacks',
                                  message:
                                      'Permanently remove containers, networks, and volumes for the selected profiles in ${_selectedPaths.length} stacks? Default services are included.',
                                  confirmLabel: 'Delete All',
                                  isDestructive: true,
                                );
                                if (confirm == true) {
                                  final paths = List<String>.from(
                                    _selectedPaths,
                                  );
                                  if (!context.mounted) return;
                                  if (!await runBulkResourceAction(
                                    context,
                                    'Remove stack',
                                    paths,
                                    (path) => ref
                                        .read(
                                          composeStacksNotifierProvider
                                              .notifier,
                                        )
                                        .removeStack(path, removeVolumes: true),
                                    onCompleted: (path) => setState(
                                      () => _selectedPaths.remove(path),
                                    ),
                                  )) {
                                    return;
                                  }
                                  if (mounted) {
                                    setState(() => _selectedPaths.clear());
                                  }
                                }
                              },
                            ),
                          ],
                    isLoading:
                        composeState.isLoading && composeState.stacks.isEmpty,
                    columns: const [
                      DataTableColumnSpec(title: 'Stack Name', width: 180),
                      DataTableColumnSpec(title: 'Status', width: 160),
                      DataTableColumnSpec(
                        title: 'Compose File & Path',
                        flex: true,
                      ),
                      DataTableColumnSpec(title: 'Actions', width: 240),
                    ],
                    itemCount: composeState.stacks.length,
                    rowBuilder: (context, index) {
                      final stack = composeState.stacks[index];
                      final isSelected = _selectedPaths.contains(
                        stack.configFiles,
                      );

                      final filePath = stack.configFiles;
                      final primaryPath = stack.configPaths.firstOrNull ?? '';
                      final fileName = stack.configPaths.length > 1
                          ? '${p.basename(primaryPath)} + ${stack.configPaths.length - 1} more'
                          : p.basename(primaryPath);
                      final dirPath = p.dirname(primaryPath);

                      return InkWell(
                        onTap: () => setState(() => _selectedStack = stack),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              SizedBox(
                                width: 40,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) =>
                                      _toggleSelect(stack.configFiles),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Name
                              SizedBox(
                                width: 180,
                                child: Text(
                                  stack.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: onSurfaceColor,
                                  ),
                                ),
                              ),

                              // Status
                              SizedBox(
                                width: 160,
                                child: StatusBadge.fromState(stack.status),
                              ),

                              // Config File Name & Path Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName.isEmpty
                                          ? 'docker-compose.yml'
                                          : fileName,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: onSurfaceColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dirPath.isEmpty ? filePath : dirPath,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                    ComposeProfilesControl(
                                      configFiles: stack.configFiles,
                                    ),
                                  ],
                                ),
                              ),

                              // Actions
                              SizedBox(
                                width: 240,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                        size: 20,
                                        color: AppColors.success,
                                      ),
                                      tooltip:
                                          'Up Stack (docker compose up -d)',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              if (!context.mounted) return;
                                              if (!await runResourceAction(
                                                context,
                                                'Start stack: ${stack.configFiles}',
                                                () => ref
                                                    .read(
                                                      composeStacksNotifierProvider
                                                          .notifier,
                                                    )
                                                    .stackUp(stack.configFiles),
                                              )) {
                                                return;
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.pause_circle_outline,
                                        size: 20,
                                        color: AppColors.warning,
                                      ),
                                      tooltip:
                                          'Down Stack (docker compose down)',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              final confirm =
                                                  await ConfirmDialog.show(
                                                    context,
                                                    title: 'Down Stack',
                                                    message:
                                                        'Bring down the selected profiles of "${stack.name}"? Default services are included.',
                                                    confirmLabel: 'Down',
                                                  );
                                              if (confirm == true) {
                                                if (!context.mounted) return;
                                                if (!await runResourceAction(
                                                  context,
                                                  'Stop stack: ${stack.configFiles}',
                                                  () => ref
                                                      .read(
                                                        composeStacksNotifierProvider
                                                            .notifier,
                                                      )
                                                      .stackDown(
                                                        stack.configFiles,
                                                      ),
                                                )) {
                                                  return;
                                                }
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.restart_alt,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      tooltip: 'Restart Stack',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              if (!context.mounted) return;
                                              if (!await runResourceAction(
                                                context,
                                                'Restart stack: ${stack.configFiles}',
                                                () => ref
                                                    .read(
                                                      composeStacksNotifierProvider
                                                          .notifier,
                                                    )
                                                    .stackRestart(
                                                      stack.configFiles,
                                                    ),
                                              )) {
                                                return;
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppColors.error,
                                      ),
                                      tooltip: 'Purge / Delete Stack',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              final confirm =
                                                  await ConfirmDialog.show(
                                                    context,
                                                    title: 'Delete Stack',
                                                    message:
                                                        'Permanently remove containers, networks, and volumes for the selected profiles of "${stack.name}"? Default services are included.',
                                                    confirmLabel:
                                                        'Delete Stack',
                                                    isDestructive: true,
                                                  );
                                              if (confirm == true) {
                                                if (!context.mounted) return;
                                                if (!await runResourceAction(
                                                  context,
                                                  'Remove stack: ${stack.configFiles}',
                                                  () => ref
                                                      .read(
                                                        composeStacksNotifierProvider
                                                            .notifier,
                                                      )
                                                      .removeStack(
                                                        stack.configFiles,
                                                        removeVolumes: true,
                                                      ),
                                                )) {
                                                  return;
                                                }
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_note,
                                        size: 20,
                                      ),
                                      tooltip: 'View / Edit Stack YAML',
                                      onPressed: () => setState(
                                        () => _selectedStack = stack,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ComposeStackDetailView extends ConsumerStatefulWidget {
  final ComposeStackModel stack;
  final VoidCallback onBack;

  const _ComposeStackDetailView({required this.stack, required this.onBack});

  @override
  ConsumerState<_ComposeStackDetailView> createState() =>
      __ComposeStackDetailViewState();
}

class __ComposeStackDetailViewState
    extends ConsumerState<_ComposeStackDetailView> {
  final TextEditingController _yamlController = TextEditingController();
  List<ComposeServiceInfo> _services = [];
  bool _loadingYaml = false;
  bool _savingYaml = false;
  late String? _selectedFile;
  String? _yamlError;
  String _loadedYaml = '';
  int _loadGeneration = 0;
  String? _selectedLogService;
  final List<String> _serviceLogs = [];
  StreamSubscription<String>? _logSub;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.stack.configPaths.firstOrNull;
    _loadServicesAndYaml();
  }

  Future<void> _loadServicesAndYaml() async {
    final cli = ref.read(composeCliClientProvider);
    final generation = ++_loadGeneration;
    setState(() {
      _loadingYaml = true;
      _yamlError = null;
    });
    try {
      final services = await cli.listStackServices(widget.stack.configFiles);
      if (mounted && generation == _loadGeneration) {
        setState(() => _services = services);
      }
    } catch (error) {
      if (mounted) showResourceError(context, 'Load stack services', error);
    }
    if (mounted && generation == _loadGeneration) await _loadYaml();
  }

  Future<void> _loadYaml() async {
    final path = _selectedFile;
    final generation = ++_loadGeneration;
    setState(() {
      _loadingYaml = true;
      _yamlError = null;
      _yamlController.clear();
    });
    try {
      if (path == null) {
        throw StateError('No Compose file was reported for this stack.');
      }
      final content = await ref
          .read(composeCliClientProvider)
          .readComposeFile(path);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _yamlController.text = content;
          _loadedYaml = content;
        });
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _yamlError = error.toString());
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadingYaml = false);
      }
    }
  }

  Future<void> _selectFile(String? path) async {
    if (path == null || path == _selectedFile || _savingYaml) return;
    if (_yamlController.text != _loadedYaml &&
        !_loadingYaml &&
        _yamlError == null) {
      final discard = await ConfirmDialog.show(
        context,
        title: 'Switch Compose file?',
        message:
            'Save your edits before switching. Switching files discards changes in this editor.',
        confirmLabel: 'Switch file',
        isDestructive: false,
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _selectedFile = path);
    await _loadYaml();
  }

  void _listenServiceLogs(String serviceName) {
    _logSub?.cancel();
    setState(() {
      _selectedLogService = serviceName;
      _serviceLogs.clear();
    });

    final cli = ref.read(composeCliClientProvider);
    _logSub = cli
        .streamServiceLogs(widget.stack.configFiles, serviceName)
        .listen(
          (line) {
            if (mounted) {
              setState(() {
                _serviceLogs.add(line);
                if (_serviceLogs.length > 2000) _serviceLogs.removeAt(0);
              });
            }
          },
          onError: (Object error) {
            if (mounted) {
              showResourceError(context, 'Stream service logs', error);
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final cardBgColor = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);
    final primaryContainerColor = Theme.of(
      context,
    ).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(
      context,
    ).colorScheme.onPrimaryContainer;

    final fileName = _selectedFile == null ? '' : p.basename(_selectedFile!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stack: ${widget.stack.name}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            ElevatedButton.icon(
              onPressed:
                  (_savingYaml ||
                      _loadingYaml ||
                      _yamlError != null ||
                      _selectedFile == null)
                  ? null
                  : () async {
                      final savedContent = _yamlController.text;
                      setState(() => _savingYaml = true);
                      try {
                        await ref
                            .read(composeCliClientProvider)
                            .writeComposeFile(_selectedFile!, savedContent);
                        if (context.mounted) {
                          _loadedYaml = savedContent;
                          ref.invalidate(
                            composeAvailableProfilesProvider(
                              widget.stack.configFiles,
                            ),
                          );
                          showMessageDialog(
                            context,
                            title: 'Information',
                            message: 'Compose file updated successfully',
                            type: MessageType.info,
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          showResourceError(context, 'Save $fileName', error);
                        }
                      } finally {
                        if (mounted) setState(() => _savingYaml = false);
                      }
                    },
              icon: const Icon(Icons.save, size: 18),
              label: Text(
                'Save ${fileName.isEmpty ? "docker-compose.yml" : fileName}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryContainerColor,
                foregroundColor: onPrimaryContainerColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ComposeProfilesControl(configFiles: widget.stack.configFiles),
        const SizedBox(height: 8),

        // Responsive Split View (Side-by-Side on wide screens, Vertical on narrow)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 850;

              final servicesAndLogsSection = Column(
                children: [
                  // Services list
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stack Services',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _services.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No service container information',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _services.length,
                                  itemBuilder: (ctx, idx) {
                                    final s = _services[idx];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        s.name,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'State: ${s.state}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.terminal,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            _listenServiceLogs(s.name),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Log Stream View
                  Expanded(
                    child: _selectedLogService == null
                        ? Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C0E11),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: const Center(
                              child: Text(
                                'Select a service terminal icon to stream logs',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          )
                        : LogViewer(
                            logs: _serviceLogs,
                            onClear: () => setState(() => _serviceLogs.clear()),
                          ),
                  ),
                ],
              );

              final yamlEditorSection = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.stack.configPaths.length > 1)
                      DropdownButton<String>(
                        value: _selectedFile,
                        isExpanded: true,
                        hint: const Text('Compose file'),
                        items: widget.stack.configPaths
                            .map(
                              (path) => DropdownMenuItem(
                                value: path,
                                child: Text(
                                  path,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _savingYaml || _loadingYaml
                            ? null
                            : _selectFile,
                      )
                    else
                      Text(
                        fileName.isEmpty ? 'docker-compose.yml' : fileName,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Divider(color: borderColor),
                    Expanded(
                      child: _loadingYaml
                          ? const Center(child: CircularProgressIndicator())
                          : _yamlError != null
                          ? Center(
                              child: Text(
                                'Unable to load file: $_yamlError',
                                style: const TextStyle(color: AppColors.error),
                              ),
                            )
                          : TextField(
                              controller: _yamlController,
                              maxLines: null,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.4,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                fillColor: Colors.transparent,
                              ),
                            ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Expanded(flex: 1, child: servicesAndLogsSection),
                    const SizedBox(height: 16),
                    Expanded(flex: 1, child: yamlEditorSection),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: servicesAndLogsSection),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: yamlEditorSection),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _yamlController.dispose();
    super.dispose();
  }
}
