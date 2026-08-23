import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/compose_stack_model.dart';
import '../../providers/compose_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/data_table_shell.dart';
import '../../widgets/log_viewer.dart';
import '../../widgets/status_badge.dart';

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
    final dirController = TextEditingController(text: '/home/ahmadteeb/compose_stacks/my-service-stack');
    final yamlController = TextEditingController(text: '''version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    restart: always
''');
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
                        dirController.text = '/home/ahmadteeb/compose_stacks/$name';
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
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: startNow,
                        onChanged: (val) => setStateDialog(() => startNow = val ?? true),
                      ),
                      const Text('Start containers immediately (docker compose up -d)'),
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
                        .createStack(dirPath, 'docker-compose.yml', yamlContent, startNow: startNow);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Deploy Failed: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              child: const Text('Deploy Stack'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final composeState = ref.watch(composeStacksNotifierProvider);

    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final containerLowColor = AppColors.containerLow(context);
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(context).colorScheme.onPrimaryContainer;

    final isAllSelected = composeState.stacks.isNotEmpty &&
        composeState.stacks.every((s) => _selectedPaths.contains(s.configFiles));
    final isSomeSelected = composeState.stacks.any((s) => _selectedPaths.contains(s.configFiles));
    final selectAllValue = isAllSelected ? true : (isSomeSelected ? null : false);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;

              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Docker Compose Stacks',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Multi-container application stacks managed via docker compose CLI',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );

              final actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(composeStacksNotifierProvider.notifier).refreshStacks();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(isNarrow ? '' : 'Refresh Stacks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: containerLowColor,
                      foregroundColor: onSurfaceColor,
                      elevation: 0,
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  actionButtons,
                ],
              );
            },
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
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      composeState.error ?? 'Docker Compose CLI binary not found on system PATH.',
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
                    title: 'Active Compose Stacks',
                    subtitle: _selectedPaths.isEmpty
                        ? '${composeState.stacks.length} projects detected'
                        : '${_selectedPaths.length} stack(s) selected',
                    showSelectAll: true,
                    selectAllValue: selectAllValue,
                    onSelectAllChanged: (val) => _toggleSelectAll(composeState.stacks, val),
                    bulkActions: _selectedPaths.isEmpty
                        ? null
                        : [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final paths = List<String>.from(_selectedPaths);
                                for (final p in paths) {
                                  await ref.read(composeStacksNotifierProvider.notifier).stackUp(p);
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
                                  message: 'Bring down ${_selectedPaths.length} selected stacks?',
                                  confirmLabel: 'Down All',
                                );
                                if (confirm == true) {
                                  final paths = List<String>.from(_selectedPaths);
                                  for (final p in paths) {
                                    await ref.read(composeStacksNotifierProvider.notifier).stackDown(p);
                                  }
                                }
                              },
                              icon: const Icon(Icons.pause, size: 16),
                              label: Text('Down (${_selectedPaths.length})'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                              tooltip: 'Delete Selected Stacks',
                              onPressed: () async {
                                final confirm = await ConfirmDialog.show(
                                  context,
                                  title: 'Purge Selected Stacks',
                                  message: 'Permanently remove containers, networks, and volumes for ${_selectedPaths.length} selected stacks?',
                                  confirmLabel: 'Delete All',
                                  isDestructive: true,
                                );
                                if (confirm == true) {
                                  final paths = List<String>.from(_selectedPaths);
                                  for (final p in paths) {
                                    await ref.read(composeStacksNotifierProvider.notifier).removeStack(p, removeVolumes: true);
                                  }
                                  setState(() => _selectedPaths.clear());
                                }
                              },
                            ),
                          ],
                    isLoading: composeState.isLoading && composeState.stacks.isEmpty,
                    columns: const [
                      DataTableColumnSpec(title: 'Stack Name', width: 180),
                      DataTableColumnSpec(title: 'Status', width: 140),
                      DataTableColumnSpec(title: 'Config File Path', flex: true),
                      DataTableColumnSpec(title: 'Actions', width: 240),
                    ],
                    itemCount: composeState.stacks.length,
                    rowBuilder: (context, index) {
                      final stack = composeState.stacks[index];
                      final isSelected = _selectedPaths.contains(stack.configFiles);

                      return InkWell(
                        onTap: () => setState(() => _selectedStack = stack),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              // Checkbox
                              SizedBox(
                                width: 40,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelect(stack.configFiles),
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
                                width: 140,
                                child: StatusBadge.fromState(stack.status),
                              ),

                              // Config Files Path
                              Expanded(
                                child: Text(
                                  stack.configFiles.isEmpty ? 'N/A' : stack.configFiles,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),

                              // Actions
                              SizedBox(
                                width: 240,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_outline, size: 20, color: AppColors.success),
                                      tooltip: 'Up Stack (docker compose up -d)',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              await ref
                                                  .read(composeStacksNotifierProvider.notifier)
                                                  .stackUp(stack.configFiles);
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.pause_circle_outline, size: 20, color: AppColors.warning),
                                      tooltip: 'Down Stack (docker compose down)',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              final confirm = await ConfirmDialog.show(
                                                context,
                                                title: 'Down Stack',
                                                message: 'Bring down stack "${stack.name}"?',
                                                confirmLabel: 'Down',
                                              );
                                              if (confirm == true) {
                                                await ref
                                                    .read(composeStacksNotifierProvider.notifier)
                                                    .stackDown(stack.configFiles);
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.restart_alt, size: 20, color: Theme.of(context).colorScheme.primary),
                                      tooltip: 'Restart Stack',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              await ref
                                                  .read(composeStacksNotifierProvider.notifier)
                                                  .stackRestart(stack.configFiles);
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                      tooltip: 'Purge / Delete Stack',
                                      onPressed: stack.configFiles.isEmpty
                                          ? null
                                          : () async {
                                              final confirm = await ConfirmDialog.show(
                                                context,
                                                title: 'Delete Stack',
                                                message: 'Permanently remove all containers, networks, and volumes for "${stack.name}"?',
                                                confirmLabel: 'Delete Stack',
                                                isDestructive: true,
                                              );
                                              if (confirm == true) {
                                                await ref
                                                    .read(composeStacksNotifierProvider.notifier)
                                                    .removeStack(stack.configFiles, removeVolumes: true);
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 20),
                                      tooltip: 'View / Edit Stack YAML',
                                      onPressed: () => setState(() => _selectedStack = stack),
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

  const _ComposeStackDetailView({
    required this.stack,
    required this.onBack,
  });

  @override
  ConsumerState<_ComposeStackDetailView> createState() => __ComposeStackDetailViewState();
}

class __ComposeStackDetailViewState extends ConsumerState<_ComposeStackDetailView> {
  final TextEditingController _yamlController = TextEditingController();
  List<ComposeServiceInfo> _services = [];
  bool _loadingYaml = false;
  bool _savingYaml = false;
  String? _selectedLogService;
  final List<String> _serviceLogs = [];
  StreamSubscription<String>? _logSub;

  @override
  void initState() {
    super.initState();
    _loadServicesAndYaml();
  }

  Future<void> _loadServicesAndYaml() async {
    final cli = ref.read(composeCliClientProvider);
    if (widget.stack.configFiles.isNotEmpty) {
      setState(() => _loadingYaml = true);
      try {
        final content = await cli.readComposeFile(widget.stack.configFiles);
        final services = await cli.listStackServices(widget.stack.configFiles);
        if (mounted) {
          setState(() {
            _yamlController.text = content;
            _services = services;
            _loadingYaml = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingYaml = false);
      }
    }
  }

  void _listenServiceLogs(String serviceName) {
    _logSub?.cancel();
    setState(() {
      _selectedLogService = serviceName;
      _serviceLogs.clear();
    });

    final cli = ref.read(composeCliClientProvider);
    _logSub = cli.streamServiceLogs(widget.stack.configFiles, serviceName).listen((line) {
      if (mounted) {
        setState(() {
          _serviceLogs.add(line);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardBgColor = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(context).colorScheme.onPrimaryContainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Header
        Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stack: ${widget.stack.name}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _savingYaml
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _savingYaml = true);
                      try {
                        await ref
                            .read(composeCliClientProvider)
                            .writeComposeFile(widget.stack.configFiles, _yamlController.text);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Compose file updated successfully')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _savingYaml = false);
                      }
                    },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save docker-compose.yml'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryContainerColor,
                foregroundColor: onPrimaryContainerColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _services.isEmpty
                              ? const Center(child: Text('No service container information'))
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
                                        style: GoogleFonts.jetBrainsMono(fontSize: 11),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.terminal, size: 18),
                                        onPressed: () => _listenServiceLogs(s.name),
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
                  color: const Color(0xFF0C0E11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'docker-compose.yml',
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
