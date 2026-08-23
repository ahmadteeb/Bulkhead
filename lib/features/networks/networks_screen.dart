import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/network_model.dart';
import '../../providers/networks_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/data_table_shell.dart';

class NetworksScreen extends ConsumerStatefulWidget {
  const NetworksScreen({super.key});

  @override
  ConsumerState<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends ConsumerState<NetworksScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelectAll(List<NetworkModel> networks, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.addAll(networks.map((n) => n.id));
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

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedDriver = 'bridge';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.cardBg(context),
          title: const Text('Create Docker Network'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Network Name',
                  hintText: 'e.g. app_net, frontend_net',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedDriver,
                decoration: const InputDecoration(labelText: 'Driver'),
                items: const [
                  DropdownMenuItem(value: 'bridge', child: Text('bridge')),
                  DropdownMenuItem(value: 'host', child: Text('host')),
                  DropdownMenuItem(value: 'overlay', child: Text('overlay')),
                  DropdownMenuItem(value: 'macvlan', child: Text('macvlan')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => selectedDriver = val);
                },
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
                  await ref
                      .read(networksNotifierProvider.notifier)
                      .createNetwork(name, driver: selectedDriver);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final networksState = ref.watch(networksNotifierProvider);
    final filteredNetworks = ref.watch(filteredNetworksProvider);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(context).colorScheme.onPrimaryContainer;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedTextColor = Theme.of(context).textTheme.bodySmall?.color;

    final isAllSelected = filteredNetworks.isNotEmpty &&
        filteredNetworks.every((n) => _selectedIds.contains(n.id));
    final isSomeSelected = filteredNetworks.any((n) => _selectedIds.contains(n.id));
    final selectAllValue = isAllSelected ? true : (isSomeSelected ? null : false);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Docker Networks',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Virtual bridge and overlay networks',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Network'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryContainerColor,
                  foregroundColor: onPrimaryContainerColor,
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Data Table
          Expanded(
            child: DataTableShell(
              title: 'Virtual Network Topology',
              subtitle: _selectedIds.isEmpty
                  ? '${filteredNetworks.length} active networks'
                  : '${_selectedIds.length} network(s) selected',
              showSelectAll: true,
              selectAllValue: selectAllValue,
              onSelectAllChanged: (val) => _toggleSelectAll(filteredNetworks, val),
              bulkActions: _selectedIds.isEmpty
                  ? null
                  : [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await ConfirmDialog.show(
                            context,
                            title: 'Remove Selected Networks',
                            message: 'Remove ${_selectedIds.length} selected networks?',
                            confirmLabel: 'Remove All',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            final ids = List<String>.from(_selectedIds);
                            for (final id in ids) {
                              await ref.read(networksNotifierProvider.notifier).removeNetwork(id);
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
              isLoading: networksState.isLoading && networksState.networks.isEmpty,
              searchBar: TextField(
                onChanged: (val) {
                  ref.read(networkSearchQueryProvider.notifier).state = val;
                },
                decoration: const InputDecoration(
                  hintText: 'Search network name...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              columns: const [
                DataTableColumnSpec(title: 'Network Name', flex: true),
                DataTableColumnSpec(title: 'Driver', width: 120),
                DataTableColumnSpec(title: 'Scope', width: 120),
                DataTableColumnSpec(title: 'Subnet / Gateway', flex: true),
                DataTableColumnSpec(title: 'Actions', width: 100),
              ],
              itemCount: filteredNetworks.length,
              rowBuilder: (context, index) {
                final net = filteredNetworks[index];
                final isSelected = _selectedIds.contains(net.id);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Checkbox
                      SizedBox(
                        width: 40,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelect(net.id),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name
                      Expanded(
                        child: Text(
                          net.name,
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
                          net.driver,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                      ),

                      // Scope
                      SizedBox(
                        width: 120,
                        child: Text(
                          net.scope,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: mutedTextColor,
                          ),
                        ),
                      ),

                      // Subnet
                      Expanded(
                        child: Text(
                          net.subnet != null ? '${net.subnet} (${net.gateway})' : 'N/A',
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
                          tooltip: 'Remove Network',
                          onPressed: () async {
                            final confirm = await ConfirmDialog.show(
                              context,
                              title: 'Remove Network',
                              message: 'Permanently remove network "${net.name}"?',
                              confirmLabel: 'Remove',
                              isDestructive: true,
                            );
                            if (confirm == true) {
                              await ref
                                  .read(networksNotifierProvider.notifier)
                                  .removeNetwork(net.id);
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
