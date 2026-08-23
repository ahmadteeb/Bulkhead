import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/volume_model.dart';
import '../../providers/volumes_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/data_table_shell.dart';

class VolumesScreen extends ConsumerStatefulWidget {
  const VolumesScreen({super.key});

  @override
  ConsumerState<VolumesScreen> createState() => _VolumesScreenState();
}

class _VolumesScreenState extends ConsumerState<VolumesScreen> {
  final Set<String> _selectedNames = {};

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _toggleSelectAll(List<VolumeModel> volumes, bool? value) {
    setState(() {
      if (value == true) {
        _selectedNames.addAll(volumes.map((v) => v.name));
      } else {
        _selectedNames.clear();
      }
    });
  }

  void _toggleSelect(String name) {
    setState(() {
      if (_selectedNames.contains(name)) {
        _selectedNames.remove(name);
      } else {
        _selectedNames.add(name);
      }
    });
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        title: const Text('Create Docker Volume'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Volume Name',
                hintText: 'e.g. app_data, db_volume',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await ref.read(volumesNotifierProvider.notifier).createVolume(name);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final volumesState = ref.watch(volumesNotifierProvider);
    final filteredVolumes = ref.watch(filteredVolumesProvider);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(context).colorScheme.onPrimaryContainer;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedTextColor = Theme.of(context).textTheme.bodySmall?.color;

    final isAllSelected = filteredVolumes.isNotEmpty &&
        filteredVolumes.every((v) => _selectedNames.contains(v.name));
    final isSomeSelected = filteredVolumes.any((v) => _selectedNames.contains(v.name));
    final selectAllValue = isAllSelected ? true : (isSomeSelected ? null : false);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Docker Volumes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Persistent storage volumes for data preservation',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await ConfirmDialog.show(
                        context,
                        title: 'Prune Unused Volumes',
                        message: 'Remove all local volumes not in use by at least one container?',
                        confirmLabel: 'Prune',
                        isDestructive: true,
                      );
                      if (confirm == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pruning unused volumes...')),
                        );
                        final res = await ref.read(volumesNotifierProvider.notifier).pruneVolumes();
                        final reclaimed = res['SpaceReclaimed'] as int? ?? 0;
                        final deleted = (res['VolumesDeleted'] as List?)?.length ?? 0;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Prune complete! Removed $deleted volume(s), reclaimed ${_formatBytes(reclaimed)} space.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: Text(isNarrow ? 'Prune' : 'Prune Unused'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.borderColor(context)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Volume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryContainerColor,
                      foregroundColor: onPrimaryContainerColor,
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

          // Data Table
          Expanded(
            child: DataTableShell(
              title: 'Volume Storage Points',
              subtitle: _selectedNames.isEmpty
                  ? '${filteredVolumes.length} volume instances'
                  : '${_selectedNames.length} volume(s) selected',
              showSelectAll: true,
              selectAllValue: selectAllValue,
              onSelectAllChanged: (val) => _toggleSelectAll(filteredVolumes, val),
              bulkActions: _selectedNames.isEmpty
                  ? null
                  : [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await ConfirmDialog.show(
                            context,
                            title: 'Remove Selected Volumes',
                            message: 'Remove ${_selectedNames.length} selected volumes?',
                            confirmLabel: 'Remove All',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            final names = List<String>.from(_selectedNames);
                            for (final name in names) {
                              await ref.read(volumesNotifierProvider.notifier).removeVolume(name, force: true);
                            }
                            setState(() => _selectedNames.clear());
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text('Delete Selected (${_selectedNames.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
              isLoading: volumesState.isLoading && volumesState.volumes.isEmpty,
              searchBar: TextField(
                onChanged: (val) {
                  ref.read(volumeSearchQueryProvider.notifier).state = val;
                },
                decoration: const InputDecoration(
                  hintText: 'Search volume name...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              columns: const [
                DataTableColumnSpec(title: 'Volume Name', flex: true),
                DataTableColumnSpec(title: 'Driver', width: 120),
                DataTableColumnSpec(title: 'Mountpoint Path', flex: true),
                DataTableColumnSpec(title: 'Actions', width: 100),
              ],
              itemCount: filteredVolumes.length,
              rowBuilder: (context, index) {
                final vol = filteredVolumes[index];
                final isSelected = _selectedNames.contains(vol.name);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Checkbox
                      SizedBox(
                        width: 40,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelect(vol.name),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name
                      Expanded(
                        child: Text(
                          vol.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceColor,
                          ),
                        ),
                      ),

                      // Driver
                      SizedBox(
                        width: 120,
                        child: Text(
                          vol.driver,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                      ),

                      // Mountpoint
                      Expanded(
                        child: Text(
                          vol.mountpoint,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: mutedTextColor,
                          ),
                        ),
                      ),

                      // Actions
                      SizedBox(
                        width: 100,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          tooltip: 'Remove Volume',
                          onPressed: () async {
                            final confirm = await ConfirmDialog.show(
                              context,
                              title: 'Remove Volume',
                              message: 'Permanently remove volume "${vol.name}"?',
                              confirmLabel: 'Remove',
                              isDestructive: true,
                            );
                            if (confirm == true) {
                              await ref
                                  .read(volumesNotifierProvider.notifier)
                                  .removeVolume(vol.name, force: true);
                            }
                          },
                        ),
                      ),
                    ],
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
