import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/image_model.dart';
import '../../providers/connection_status_provider.dart';
import '../../providers/images_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/data_table_shell.dart';

class ImagesScreen extends ConsumerStatefulWidget {
  const ImagesScreen({super.key});

  @override
  ConsumerState<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends ConsumerState<ImagesScreen> {
  final Set<String> _selectedIds = {};

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

  void _toggleSelectAll(List<ImageModel> images, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.addAll(images.map((img) => img.id));
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

  void _showPullDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: 'alpine:latest');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PullImageProgressDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagesState = ref.watch(imagesNotifierProvider);
    final filteredImages = ref.watch(filteredImagesProvider);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(context).colorScheme.onPrimaryContainer;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedTextColor = Theme.of(context).textTheme.bodySmall?.color;

    final isAllSelected = filteredImages.isNotEmpty &&
        filteredImages.every((img) => _selectedIds.contains(img.id));
    final isSomeSelected = filteredImages.any((img) => _selectedIds.contains(img.id));
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
                    'Docker Images',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Inspect local registry, pull images, and prune unused layers',
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
                        title: 'Prune Unused Images',
                        message: 'Remove all dangling images not referenced by any container?',
                        confirmLabel: 'Prune',
                        isDestructive: true,
                      );
                      if (confirm == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pruning unused images...')),
                        );
                        final res = await ref.read(imagesNotifierProvider.notifier).pruneImages();
                        final reclaimed = res['SpaceReclaimed'] as int? ?? 0;
                        final deleted = (res['ImagesDeleted'] as List?)?.length ?? 0;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Prune complete! Deleted $deleted image(s), reclaimed ${_formatBytes(reclaimed)} space.',
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
                    onPressed: () => _showPullDialog(context, ref),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Pull Image'),
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

          // Main Table
          Expanded(
            child: DataTableShell(
              title: 'Local Image Storage',
              subtitle: _selectedIds.isEmpty
                  ? '${filteredImages.length} images available'
                  : '${_selectedIds.length} image(s) selected',
              showSelectAll: true,
              selectAllValue: selectAllValue,
              onSelectAllChanged: (val) => _toggleSelectAll(filteredImages, val),
              bulkActions: _selectedIds.isEmpty
                  ? null
                  : [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await ConfirmDialog.show(
                            context,
                            title: 'Remove Selected Images',
                            message: 'Remove ${_selectedIds.length} selected images?',
                            confirmLabel: 'Remove All',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            final ids = List<String>.from(_selectedIds);
                            for (final id in ids) {
                              await ref.read(imagesNotifierProvider.notifier).removeImage(id, force: true);
                            }
                            setState(() => _selectedIds.clear());
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text('Delete Selected (${_selectedIds.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
              isLoading: imagesState.isLoading && imagesState.images.isEmpty,
              searchBar: TextField(
                onChanged: (val) {
                  ref.read(imageSearchQueryProvider.notifier).state = val;
                },
                decoration: const InputDecoration(
                  hintText: 'Search image tag, ID...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              columns: const [
                DataTableColumnSpec(title: 'Repository & Tag', flex: true),
                DataTableColumnSpec(title: 'Image ID', width: 160),
                DataTableColumnSpec(title: 'Size', width: 120),
                DataTableColumnSpec(title: 'Created', width: 160),
                DataTableColumnSpec(title: 'Actions', width: 100),
              ],
              itemCount: filteredImages.length,
              rowBuilder: (context, index) {
                final image = filteredImages[index];
                final isSelected = _selectedIds.contains(image.id);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Checkbox
                      SizedBox(
                        width: 40,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelect(image.id),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tag
                      Expanded(
                        child: Text(
                          image.primaryTag,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceColor,
                          ),
                        ),
                      ),

                      // ID
                      SizedBox(
                        width: 160,
                        child: Text(
                          image.shortId,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: mutedTextColor,
                          ),
                        ),
                      ),

                      // Size
                      SizedBox(
                        width: 120,
                        child: Text(
                          _formatBytes(image.size),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),

                      // Created
                      SizedBox(
                        width: 160,
                        child: Text(
                          '${image.created.year}-${image.created.month.toString().padLeft(2, '0')}-${image.created.day.toString().padLeft(2, '0')}',
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
                          tooltip: 'Remove Image',
                          onPressed: () async {
                            final confirm = await ConfirmDialog.show(
                              context,
                              title: 'Remove Image',
                              message: 'Remove image "${image.primaryTag}"?',
                              confirmLabel: 'Remove',
                              isDestructive: true,
                            );
                            if (confirm == true) {
                              await ref
                                  .read(imagesNotifierProvider.notifier)
                                  .removeImage(image.id, force: true);
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

class _PullImageProgressDialog extends ConsumerStatefulWidget {
  final TextEditingController controller;

  const _PullImageProgressDialog({required this.controller});

  @override
  ConsumerState<_PullImageProgressDialog> createState() => __PullImageProgressDialogState();
}

class __PullImageProgressDialogState extends ConsumerState<_PullImageProgressDialog> {
  bool _isPulling = false;
  String _status = '';
  final List<String> _progressLines = [];
  StreamSubscription? _pullSub;

  void _startPull() {
    final name = widget.controller.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isPulling = true;
      _status = 'Initiating pull for $name...';
      _progressLines.clear();
    });

    final client = ref.read(dockerApiClientProvider);
    _pullSub = client.pullImage(name).listen(
      (data) {
        if (!mounted) return;
        final statusText = data['status'] as String? ?? '';
        final id = data['id'] as String? ?? '';
        final progress = data['progress'] as String? ?? '';

        setState(() {
          _status = statusText;
          final line = id.isNotEmpty ? '$id: $statusText $progress' : statusText;
          if (line.isNotEmpty) _progressLines.add(line);
        });
      },
      onDone: () {
        if (!mounted) return;
        ref.read(imagesNotifierProvider.notifier).refreshImages();
        setState(() {
          _isPulling = false;
          _status = 'Pull Completed Successfully!';
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isPulling = false;
          _status = 'Pull Failed: $err';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBgColor = AppColors.cardBg(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      backgroundColor: cardBgColor,
      title: const Text('Pull Docker Image'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.controller,
              enabled: !_isPulling,
              decoration: const InputDecoration(
                labelText: 'Image Name & Tag',
                hintText: 'e.g. nginx:latest, postgres:16',
              ),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty) ...[
              Text(
                _status,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isPulling) const LinearProgressIndicator(),
            if (_progressLines.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0E11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _progressLines.length,
                  itemBuilder: (ctx, idx) => Text(
                    _progressLines[idx],
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isPulling)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        if (!_isPulling)
          ElevatedButton(
            onPressed: _startPull,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            child: const Text('Start Pull'),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pullSub?.cancel();
    super.dispose();
  }
}
