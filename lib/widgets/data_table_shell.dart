import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class DataTableColumnSpec {
  final String title;
  final double? width;
  final bool flex;

  const DataTableColumnSpec({
    required this.title,
    this.width,
    this.flex = false,
  });
}

class DataTableShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? searchBar;
  final List<Widget>? actions;
  final List<Widget>? bulkActions;
  final List<DataTableColumnSpec> columns;
  final int itemCount;
  final Widget Function(BuildContext context, int index) rowBuilder;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? emptyMessage;
  final bool showSelectAll;
  final bool? selectAllValue;
  final ValueChanged<bool?>? onSelectAllChanged;

  const DataTableShell({
    super.key,
    required this.title,
    this.subtitle,
    this.searchBar,
    this.actions,
    this.bulkActions,
    required this.columns,
    required this.itemCount,
    required this.rowBuilder,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyMessage = 'No items found.',
    this.showSelectAll = false,
    this.selectAllValue = false,
    this.onSelectAllChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.borderColor(context);

    final fixedWidth = columns.fold<double>(
      0,
      (sum, column) => sum + (column.width ?? 0),
    );
    final flexibleCount = columns
        .where((column) => column.width == null)
        .length;
    final minWidth =
        fixedWidth + flexibleCount * 160 + (showSelectAll ? 92 : 40);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                );
                final controls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...?bulkActions,
                    if (searchBar != null)
                      SizedBox(
                        width: constraints.maxWidth < 280
                            ? constraints.maxWidth
                            : 240,
                        height: DesignTokens.controlHeight,
                        child: searchBar,
                      ),
                    ...?actions,
                  ],
                );
                if (constraints.maxWidth < 900 ||
                    bulkActions?.isNotEmpty == true) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      if (searchBar != null ||
                          actions?.isNotEmpty == true ||
                          bulkActions?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        controls,
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 16),
                    controls,
                  ],
                );
              },
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < minWidth
                    ? minWidth
                    : constraints.maxWidth;
                return Scrollbar(
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      height: constraints.maxHeight,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            color: AppColors.containerLow(context),
                            child: Row(
                              children: [
                                if (showSelectAll) ...[
                                  SizedBox(
                                    width: 40,
                                    child: Checkbox(
                                      value: selectAllValue,
                                      tristate: true,
                                      onChanged: onSelectAllChanged,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                ...columns.map((column) {
                                  final label = Text(
                                    column.title.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(letterSpacing: .8),
                                  );
                                  return column.width == null
                                      ? Expanded(child: label)
                                      : SizedBox(
                                          width: column.width,
                                          child: label,
                                        );
                                }),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: borderColor),
                          Expanded(
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : itemCount == 0
                                ? Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            size: 40,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            emptyMessage ?? 'No items found.',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Try another search or add a resource to get started.',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: itemCount,
                                    itemBuilder: rowBuilder,
                                    separatorBuilder: (_, index) =>
                                        Divider(height: 1, color: borderColor),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Text(
              isLoading ? 'Loading resources…' : '$itemCount resources',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
