import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_status_provider.dart';
import '../providers/update_provider.dart';
import '../theme/app_theme.dart';
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

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const List<AppSidebarItem> items = [
    AppSidebarItem(title: 'Dashboard', icon: Icons.dashboard_outlined, index: 0),
    AppSidebarItem(title: 'Containers', icon: Icons.inventory_2_outlined, index: 1),
    AppSidebarItem(title: 'Images', icon: Icons.layers_outlined, index: 2),
    AppSidebarItem(title: 'Compose Stacks', icon: Icons.account_tree_outlined, index: 3),
    AppSidebarItem(title: 'Volumes', icon: Icons.storage_outlined, index: 4),
    AppSidebarItem(title: 'Networks', icon: Icons.hub_outlined, index: 5),
    AppSidebarItem(title: 'Settings', icon: Icons.settings_outlined, index: 6),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectionStatusProvider);
    final updateState = ref.watch(updateCheckNotifierProvider);
    final updateInfo = updateState.value;
    final isDark = AppColors.isDark(context);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.sidebarBg(context),
        border: Border(
          right: BorderSide(color: AppColors.borderColor(context), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.anchor,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BULKHEAD',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                      ),
                      Text(
                        'Docker Engine Manager',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor(context)),

          const SizedBox(height: 16),

          // Navigation List
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final isSelected = selectedIndex == item.index;

                final activeBg = isDark
                    ? const Color(0xFF0DB7ED).withValues(alpha: 0.15)
                    : const Color(0xFFE0F2FE);
                final activeColor = Theme.of(context).colorScheme.primary;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onDestinationSelected(item.index),
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected ? activeBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Selection accent bar
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? activeColor : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? activeColor
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.title,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight:
                                          isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected
                                          ? activeColor
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Divider(height: 1, color: AppColors.borderColor(context)),

          if (updateInfo != null && updateInfo.hasUpdate)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => UpdateDialog(updateInfo: updateInfo),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withAlpha(128)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Update: v${updateInfo.latestVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Connection Status Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getConnColor(connState.status),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getConnLabel(connState.status),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          connState.errorMessage ?? 'Engine v29.6 Unix Socket',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConnColor(ConnectionStateEnum status) {
    switch (status) {
      case ConnectionStateEnum.connected:
        return AppColors.success;
      case ConnectionStateEnum.permissionDenied:
      case ConnectionStateEnum.socketNotFound:
      case ConnectionStateEnum.error:
        return AppColors.error;
      case ConnectionStateEnum.connecting:
        return AppColors.warning;
    }
  }

  String _getConnLabel(ConnectionStateEnum status) {
    switch (status) {
      case ConnectionStateEnum.connected:
        return 'Docker Active';
      case ConnectionStateEnum.permissionDenied:
        return 'Permission Denied';
      case ConnectionStateEnum.socketNotFound:
        return 'Socket Not Found';
      case ConnectionStateEnum.error:
        return 'Connection Error';
      case ConnectionStateEnum.connecting:
        return 'Connecting...';
    }
  }
}
