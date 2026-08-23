import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    this.emptyMessage = 'No items found.',
    this.showSelectAll = false,
    this.selectAllValue = false,
    this.onSelectAllChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.borderColor(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                if (bulkActions != null && bulkActions!.isNotEmpty) ...[
                  ...bulkActions!,
                  const SizedBox(width: 12),
                ],
                if (searchBar != null) ...[
                  SizedBox(
                    width: 260,
                    height: 38,
                    child: searchBar,
                  ),
                  const SizedBox(width: 12),
                ],
                ...?actions,
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                ...columns.map((col) {
                  final text = Text(
                    col.title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                  );

                  if (col.width != null) {
                    return SizedBox(width: col.width, child: text);
                  } else {
                    return Expanded(child: text);
                  }
                }),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // Table Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : itemCount == 0
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              emptyMessage!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: itemCount,
                        separatorBuilder: (context, index) => Divider(height: 1, color: borderColor),
                        itemBuilder: rowBuilder,
                      ),
          ),
        ],
      ),
    );
  }
}
