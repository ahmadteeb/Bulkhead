import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_status_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'update_dialog.dart';

class AppSidebarItem {
  final String title;
  final IconData icon;
  final int index;
  const AppSidebarItem({
    required this.title,
    required this.icon,
    required this.index,
  });
}

class AppSidebar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = false,
  });

  static const items = [
    AppSidebarItem(
      title: 'Overview',
      icon: Icons.space_dashboard_outlined,
      index: 0,
    ),
    AppSidebarItem(
      title: 'Containers',
      icon: Icons.inventory_2_outlined,
      index: 1,
    ),
    AppSidebarItem(title: 'Images', icon: Icons.layers_outlined, index: 2),
    AppSidebarItem(
      title: 'Compose stacks',
      icon: Icons.account_tree_outlined,
      index: 3,
    ),
    AppSidebarItem(title: 'Volumes', icon: Icons.storage_outlined, index: 4),
    AppSidebarItem(title: 'Networks', icon: Icons.hub_outlined, index: 5),
    AppSidebarItem(title: 'Settings', icon: Icons.tune_rounded, index: 6),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStatusProvider);
    final update = ref.watch(updateCheckNotifierProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final connected = connection.isConnected;
    final statusColor = connected ? AppColors.success : AppColors.warning;

    Widget destination(AppSidebarItem item) {
      final selected = selectedIndex == item.index;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tooltip(
          message: compact ? item.title : '',
          child: Material(
            color: selected
                ? scheme.primary.withValues(alpha: .12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignTokens.controlRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(DesignTokens.controlRadius),
              onTap: () => onDestinationSelected(item.index),
              child: Semantics(
                selected: selected,
                label: compact ? item.title : null,
                child: SizedBox(
                  height: 46,
                  child: Row(
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      if (!compact) const SizedBox(width: 14),
                      Icon(
                        item.icon,
                        size: 21,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: scheme.primary,
                          ),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: compact
          ? DesignTokens.compactSidebarWidth
          : DesignTokens.sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        border: Border(right: BorderSide(color: scheme.outline)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 17 : 22,
              vertical: 28,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.anchor_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BULKHEAD',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                fontSize: 15,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'DOCKER WORKSPACE',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontSize: 9, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 0, 16),
                    child: Text(
                      'WORKSPACE',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ...items.take(4).map(destination),
                const SizedBox(height: 18),
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 0, 12),
                    child: Text(
                      'RESOURCES',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ...items.skip(4).take(2).map(destination),
              ],
            ),
          ),
          if (update?.hasUpdate == true)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Tooltip(
                message: 'Update available',
                child: TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => UpdateDialog(updateInfo: update!),
                  ),
                  child: compact
                      ? const Icon(Icons.system_update_alt, size: 20)
                      : const Text('Update available ↗'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: destination(items.last),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            child: Tooltip(
              message: connection.errorMessage ?? ref.watch(socketPathProvider),
              child: Container(
                padding: EdgeInsets.all(compact ? 12 : 14),
                decoration: BoxDecoration(
                  color: AppColors.containerLow(context),
                  borderRadius: BorderRadius.circular(
                    DesignTokens.controlRadius,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    if (!compact) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connected
                                  ? 'Engine connected'
                                  : connection.status ==
                                        ConnectionStateEnum.connecting
                                  ? 'Connecting…'
                                  : 'Engine offline',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ref.watch(socketPathProvider),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
