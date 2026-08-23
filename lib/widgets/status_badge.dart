import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusBadgeType {
  running,
  paused,
  exited,
  created,
  restarting,
  unknown,
}

class StatusBadge extends StatelessWidget {
  final String statusText;
  final StatusBadgeType? type;

  const StatusBadge({
    super.key,
    required this.statusText,
    this.type,
  });

  factory StatusBadge.fromState(String stateText) {
    final lower = stateText.toLowerCase();
    if (lower == 'running' || lower == 'up') {
      return StatusBadge(statusText: stateText, type: StatusBadgeType.running);
    } else if (lower == 'paused') {
      return StatusBadge(statusText: stateText, type: StatusBadgeType.paused);
    } else if (lower == 'exited' || lower == 'dead' || lower == 'stopped') {
      return StatusBadge(statusText: stateText, type: StatusBadgeType.exited);
    } else if (lower == 'created') {
      return StatusBadge(statusText: stateText, type: StatusBadgeType.created);
    } else if (lower.contains('restart')) {
      return StatusBadge(statusText: stateText, type: StatusBadgeType.restarting);
    }
    return StatusBadge(statusText: stateText, type: StatusBadgeType.unknown);
  }

  @override
  Widget build(BuildContext context) {
    final semanticColor = _getSemanticColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: semanticColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: semanticColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: semanticColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: semanticColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSemanticColor() {
    switch (type ?? StatusBadgeType.unknown) {
      case StatusBadgeType.running:
        return AppColors.success;
      case StatusBadgeType.paused:
      case StatusBadgeType.restarting:
        return AppColors.warning;
      case StatusBadgeType.exited:
        return AppColors.error;
      case StatusBadgeType.created:
        return AppColors.primaryContainer;
      case StatusBadgeType.unknown:
        return AppColors.inactive;
    }
  }
}
