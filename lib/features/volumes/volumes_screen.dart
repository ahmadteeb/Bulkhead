import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/volume_model.dart';
import '../../providers/connection_status_provider.dart';
import '../../providers/containers_provider.dart';
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

  void _showVolumeBrowserDialog(BuildContext context, WidgetRef ref, VolumeModel volume) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        title: Row(
          children: [
            Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primaryContainer, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Volume Files: ${volume.name}',
                style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 500,
          child: _VolumeHostBrowserView(volume: volume),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
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
              final isNarrow = constraints.maxWidth < 650;

              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Docker Volumes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage persistent storage mountpoints & volumes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await ConfirmDialog.show(
                        context,
                        title: 'Prune Unused Volumes',
                        message: 'Remove all unreferenced local storage volumes?',
                        confirmLabel: 'Prune Volumes',
                        isDestructive: true,
                      );
                      if (confirm == true && context.mounted) {
                        final res = await ref.read(volumesNotifierProvider.notifier).pruneVolumes();
                        if (context.mounted) {
                          final count = (res['VolumesDeleted'] as List?)?.length ?? 0;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pruned $count unused volume(s).'),
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
                DataTableColumnSpec(title: 'Actions', width: 140),
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
                        width: 140,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.folder_open, size: 20),
                              color: Theme.of(context).colorScheme.primaryContainer,
                              tooltip: 'Browse Volume Files',
                              onPressed: () => _showVolumeBrowserDialog(context, ref, vol),
                            ),
                            IconButton(
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
                          ],
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

class _VolumeHostBrowserView extends ConsumerStatefulWidget {
  final VolumeModel volume;

  const _VolumeHostBrowserView({required this.volume});

  @override
  ConsumerState<_VolumeHostBrowserView> createState() => _VolumeHostBrowserViewState();
}

class _VolumeHostBrowserViewState extends ConsumerState<_VolumeHostBrowserView> {
  final TextEditingController _pathCtrl = TextEditingController(text: '/');
  List<Map<String, String>> _files = [];
  bool _isLoading = false;
  String? _error;
  String? _attachedContainerId;

  final List<String> _history = ['/'];
  int _historyIndex = 0;

  @override
  void initState() {
    super.initState();
    _findContainerAndBrowse('/', pushHistory: false);
  }

  void _findContainerAndBrowse(String path, {bool pushHistory = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _pathCtrl.text = path;
      if (pushHistory) {
        if (_historyIndex < _history.length - 1) {
          _history.removeRange(_historyIndex + 1, _history.length);
        }
        _history.add(path);
        _historyIndex = _history.length - 1;
      }
    });

    final client = ref.read(dockerApiClientProvider);
    final containersState = ref.read(containersNotifierProvider);

    // Find a running container attached to this volume
    String? containerId = _attachedContainerId;
    if (containerId == null) {
      for (final c in containersState.containers) {
        if (c.state == 'running') {
          for (final m in c.mounts) {
            if (m.name == widget.volume.name) {
              containerId = c.id;
              _attachedContainerId = c.id;
              break;
            }
          }
        }
        if (containerId != null) break;
      }
    }

    if (containerId != null) {
      try {
        final res = await client.listContainerFiles(containerId, path);
        if (mounted) {
          setState(() {
            _files = res;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _error = 'No active container currently using volume "${widget.volume.name}".\n\nHost Mountpoint Path:\n${widget.volume.mountpoint}';
          _isLoading = false;
        });
      }
    }
  }

  void _uploadFile() async {
    if (_attachedContainerId == null) return;
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty && files.first.path != null) {
        final hostPath = files.first.path!;
        final currentPath = _pathCtrl.text;
        final shortId = _attachedContainerId!.length >= 12 ? _attachedContainerId!.substring(0, 12) : _attachedContainerId!;

        final res = await Process.run('docker', ['cp', hostPath, '$shortId:$currentPath']);
        if (mounted) {
          if (res.exitCode == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Uploaded ${files.first.name} successfully!'), backgroundColor: AppColors.success),
            );
            _findContainerAndBrowse(currentPath, pushHistory: false);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: ${res.stderr}'), backgroundColor: AppColors.error),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _downloadItem(String fileName) async {
    if (_attachedContainerId == null) return;
    try {
      final currentPath = _pathCtrl.text;
      final remotePath = currentPath.endsWith('/') ? '$currentPath$fileName' : '$currentPath/$fileName';
      final shortId = _attachedContainerId!.length >= 12 ? _attachedContainerId!.substring(0, 12) : _attachedContainerId!;

      final String? targetDir = await FilePicker.getDirectoryPath();
      if (targetDir == null) return; // User cancelled download dialog!

      final res = await Process.run('docker', ['cp', '$shortId:$remotePath', '$targetDir/']);
      if (mounted) {
        if (res.exitCode == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded $fileName to $targetDir!'), backgroundColor: AppColors.success),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: ${res.stderr}'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.borderColor(context);
    final currentPath = _pathCtrl.text;
    final canGoBack = _historyIndex > 0;
    final canGoForward = _historyIndex < _history.length - 1;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              tooltip: 'Go Back',
              onPressed: canGoBack
                  ? () {
                      _historyIndex--;
                      _findContainerAndBrowse(_history[_historyIndex], pushHistory: false);
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              tooltip: 'Go Forward',
              onPressed: canGoForward
                  ? () {
                      _historyIndex++;
                      _findContainerAndBrowse(_history[_historyIndex], pushHistory: false);
                    }
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _pathCtrl,
                onSubmitted: (val) => _findContainerAndBrowse(val),
                decoration: const InputDecoration(
                  labelText: 'Volume Internal Path',
                  prefixIcon: Icon(Icons.folder_open, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _findContainerAndBrowse(_pathCtrl.text),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Browse'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _attachedContainerId == null ? null : _uploadFile,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SelectableText(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _files.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: borderColor),
                        itemBuilder: (context, idx) {
                          final item = _files[idx];
                          final isDir = item['isDir'] == 'true';
                          final name = item['name'] ?? '';
                          final perms = item['permissions'] ?? '';
                          final size = item['size'] ?? '';

                          return ListTile(
                            leading: Icon(
                              isDir ? Icons.folder : Icons.insert_drive_file,
                              color: isDir
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            title: Text(name, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text('$perms • $size bytes', style: GoogleFonts.jetBrainsMono(fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download, size: 18),
                                  tooltip: 'Download File/Folder to Host',
                                  onPressed: () => _downloadItem(name),
                                ),
                                if (isDir) const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                            onTap: isDir
                                ? () {
                                    final nextPath = currentPath.endsWith('/')
                                        ? '$currentPath$name'
                                        : '$currentPath/$name';
                                    _findContainerAndBrowse(nextPath);
                                  }
                                : null,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
