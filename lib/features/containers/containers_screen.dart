import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/container_model.dart';
import '../../providers/containers_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/data_table_shell.dart';
import '../../widgets/status_badge.dart';

class ContainersScreen extends ConsumerStatefulWidget {
  final ValueChanged<ContainerModel> onSelectContainer;

  const ContainersScreen({
    super.key,
    required this.onSelectContainer,
  });

  @override
  ConsumerState<ContainersScreen> createState() => _ContainersScreenState();
}

class _ContainersScreenState extends ConsumerState<ContainersScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelectAll(List<ContainerModel> containers, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.addAll(containers.map((c) => c.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _showRunContainerDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: 'my_app_container');
    final imageCtrl = TextEditingController(text: 'nginx:alpine');
    final portCtrl = TextEditingController(text: '8080:80');
    final envCtrl = TextEditingController(text: 'ENV_VAR=value');
    bool autoStart = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.cardBg(context),
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 22),
              SizedBox(width: 10),
              Text('Run New Container'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Container Name',
                    hintText: 'e.g. my_web_app',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Image Name & Tag',
                    hintText: 'e.g. nginx:alpine, ubuntu:latest, postgres:16',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port Mapping (HostPort:ContainerPort)',
                    hintText: 'e.g. 8080:80, 5432:5432',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: envCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Environment Variables',
                    hintText: 'e.g. PORT=8080 or KEY=VAL',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: autoStart,
                      onChanged: (val) => setStateDialog(() => autoStart = val ?? true),
                    ),
                    const Text('Start container immediately'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final image = imageCtrl.text.trim();
                final port = portCtrl.text.trim();
                final envText = envCtrl.text.trim();

                if (name.isNotEmpty && image.isNotEmpty) {
                  Map<String, String>? ports;
                  if (port.contains(':')) {
                    final parts = port.split(':');
                    ports = {parts[1]: parts[0]};
                  }

                  List<String>? env;
                  if (envText.isNotEmpty) {
                    env = [envText];
                  }

                  try {
                    await ref.read(containersNotifierProvider.notifier).createContainer(
                          name: name,
                          image: image,
                          portMappings: ports,
                          env: env,
                          autoStart: autoStart,
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to run container: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              child: const Text('Run Container'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containersState = ref.watch(containersNotifierProvider);
    final filteredContainers = ref.watch(filteredContainersProvider);
    final activeFilter = ref.watch(containerFilterStateProvider);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedTextColor = Theme.of(context).textTheme.bodySmall?.color;
    final variantTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final isAllSelected = filteredContainers.isNotEmpty &&
        filteredContainers.every((c) => _selectedIds.contains(c.id));
    final isSomeSelected = filteredContainers.any((c) => _selectedIds.contains(c.id));
    final selectAllValue = isAllSelected ? true : (isSomeSelected ? null : false);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Containers',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage and monitor local container instances',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );

              final actions = ElevatedButton.icon(
                onPressed: () => _showRunContainerDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Run Container'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  elevation: 0,
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters row
          Row(
            children: [
              _buildFilterChip(context, ref, label: 'All', value: 'all', current: activeFilter),
              const SizedBox(width: 8),
              _buildFilterChip(context, ref, label: 'Running', value: 'running', current: activeFilter),
              const SizedBox(width: 8),
              _buildFilterChip(context, ref, label: 'Stopped', value: 'stopped', current: activeFilter),
            ],
          ),
          const SizedBox(height: 16),

          // Main Table Shell
          Expanded(
            child: DataTableShell(
              title: 'Container List',
              subtitle: _selectedIds.isEmpty
                  ? '${filteredContainers.length} containers matching filter'
                  : '${_selectedIds.length} container(s) selected',
              showSelectAll: true,
              selectAllValue: selectAllValue,
              onSelectAllChanged: (val) => _toggleSelectAll(filteredContainers, val),
              bulkActions: _selectedIds.isEmpty
                  ? null
                  : [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ids = List<String>.from(_selectedIds);
                          for (final id in ids) {
                            await ref.read(containersNotifierProvider.notifier).startContainer(id);
                          }
                        },
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: Text('Start (${_selectedIds.length})'),
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
                            title: 'Stop Selected Containers',
                            message: 'Stop ${_selectedIds.length} selected containers?',
                            confirmLabel: 'Stop All',
                          );
                          if (confirm == true) {
                            final ids = List<String>.from(_selectedIds);
                            for (final id in ids) {
                              await ref.read(containersNotifierProvider.notifier).stopContainer(id);
                            }
                          }
                        },
                        icon: const Icon(Icons.pause, size: 16),
                        label: Text('Stop (${_selectedIds.length})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.restart_alt, size: 20, color: AppColors.primary),
                        tooltip: 'Restart Selected',
                        onPressed: () async {
                          final ids = List<String>.from(_selectedIds);
                          for (final id in ids) {
                            await ref.read(containersNotifierProvider.notifier).restartContainer(id);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                        tooltip: 'Delete Selected',
                        onPressed: () async {
                          final confirm = await ConfirmDialog.show(
                            context,
                            title: 'Remove Selected Containers',
                            message: 'Permanently remove ${_selectedIds.length} selected containers?',
                            confirmLabel: 'Remove All',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            final ids = List<String>.from(_selectedIds);
                            for (final id in ids) {
                              await ref.read(containersNotifierProvider.notifier).removeContainer(id, force: true);
                            }
                            setState(() => _selectedIds.clear());
                          }
                        },
                      ),
                    ],
              isLoading: containersState.isLoading && containersState.containers.isEmpty,
              emptyMessage: 'No containers found.',
              searchBar: TextField(
                onChanged: (val) {
                  ref.read(containerSearchQueryProvider.notifier).state = val;
                },
                decoration: const InputDecoration(
                  hintText: 'Search container, image...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              columns: const [
                DataTableColumnSpec(title: 'Status', width: 140),
                DataTableColumnSpec(title: 'Container Name', flex: true),
                DataTableColumnSpec(title: 'Image', flex: true),
                DataTableColumnSpec(title: 'Port Mappings', width: 180),
                DataTableColumnSpec(title: 'Actions', width: 180),
              ],
              itemCount: filteredContainers.length,
              rowBuilder: (context, index) {
                final container = filteredContainers[index];
                final isSelected = _selectedIds.contains(container.id);

                return InkWell(
                  onTap: () => widget.onSelectContainer(container),
                  hoverColor: AppColors.isDark(context)
                      ? const Color(0xFF1E2023)
                      : const Color(0xFFF0F9FF),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        // Checkbox
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelect(container.id),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Status
                        SizedBox(
                          width: 140,
                          child: StatusBadge.fromState(container.state),
                        ),

                        // Name + ID
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                container.name,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                container.shortId,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: mutedTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Image
                        Expanded(
                          child: Text(
                            container.image,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: variantTextColor,
                            ),
                          ),
                        ),

                        // Ports
                        SizedBox(
                          width: 180,
                          child: Text(
                            container.ports.isEmpty
                                ? 'None'
                                : container.ports.map((p) => p.toString()).join(', '),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: mutedTextColor,
                            ),
                          ),
                        ),

                        // Actions
                        SizedBox(
                          width: 180,
                          child: Row(
                            children: [
                              if (container.state == 'running')
                                IconButton(
                                  icon: const Icon(Icons.pause_circle_outline, size: 20, color: AppColors.warning),
                                  tooltip: 'Stop Container',
                                  onPressed: () async {
                                    final confirm = await ConfirmDialog.show(
                                      context,
                                      title: 'Stop Container',
                                      message: 'Are you sure you want to stop "${container.name}"?',
                                      confirmLabel: 'Stop',
                                    );
                                    if (confirm == true) {
                                      await ref
                                          .read(containersNotifierProvider.notifier)
                                          .stopContainer(container.id);
                                    }
                                  },
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.play_circle_outline, size: 20, color: AppColors.success),
                                  tooltip: 'Start Container',
                                  onPressed: () async {
                                    await ref
                                        .read(containersNotifierProvider.notifier)
                                        .startContainer(container.id);
                                  },
                                ),
                              IconButton(
                                icon: Icon(Icons.restart_alt, size: 20, color: primaryColor),
                                tooltip: 'Restart Container',
                                onPressed: () async {
                                  await ref
                                      .read(containersNotifierProvider.notifier)
                                      .restartContainer(container.id);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.description_outlined, size: 20, color: variantTextColor),
                                tooltip: 'Inspect / Details',
                                onPressed: () => widget.onSelectContainer(container),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                tooltip: 'Remove Container',
                                onPressed: () async {
                                  final confirm = await ConfirmDialog.show(
                                    context,
                                    title: 'Remove Container',
                                    message: 'Are you sure you want to permanently remove "${container.name}"?',
                                    confirmLabel: 'Remove',
                                    isDestructive: true,
                                  );
                                  if (confirm == true) {
                                    await ref
                                        .read(containersNotifierProvider.notifier)
                                        .removeContainer(container.id, force: true);
                                  }
                                },
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

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String value,
    required String current,
  }) {
    final isSelected = value == current;
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(context).colorScheme.onPrimaryContainer;
    final cardBgColor = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(containerFilterStateProvider.notifier).state = value;
      },
      selectedColor: primaryContainerColor,
      backgroundColor: cardBgColor,
      labelStyle: TextStyle(
        color: isSelected ? onPrimaryContainerColor : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? primaryContainerColor : borderColor,
      ),
    );
  }
}
