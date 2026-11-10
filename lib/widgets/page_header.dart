import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// A page title and actions that stack before the window becomes cramped.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget actions;
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: DesignTokens.space / 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: DesignTokens.space * 2),
            actions,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 24),
          actions,
        ],
      );
    },
  );
}
