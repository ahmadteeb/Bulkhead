import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusBadgeType { running, paused, exited, created, restarting, unknown }

enum StatusBadgeSize { medium, large }

class StatusBadge extends StatelessWidget {
  final String statusText;
  final StatusBadgeType? type;
  final StatusBadgeSize size;

  const StatusBadge({
    super.key,
    required this.statusText,
    this.type,
    this.size = StatusBadgeSize.medium,
  });

  factory StatusBadge.fromState(
    String stateText, {
    StatusBadgeSize size = StatusBadgeSize.medium,
  }) {
    final lower = stateText.toLowerCase();
    if (lower.contains('running') ||
        lower.contains('up') ||
        lower == 'active') {
      return StatusBadge(
        statusText: stateText,
        type: StatusBadgeType.running,
        size: size,
      );
    } else if (lower.contains('pause')) {
      return StatusBadge(
        statusText: stateText,
        type: StatusBadgeType.paused,
        size: size,
      );
    } else if (lower.contains('exit') ||
        lower.contains('dead') ||
        lower.contains('stop')) {
      return StatusBadge(
        statusText: stateText,
        type: StatusBadgeType.exited,
        size: size,
      );
    } else if (lower.contains('create')) {
      return StatusBadge(
        statusText: stateText,
        type: StatusBadgeType.created,
        size: size,
      );
    } else if (lower.contains('restart')) {
      return StatusBadge(
        statusText: stateText,
        type: StatusBadgeType.restarting,
        size: size,
      );
    }
    return StatusBadge(
      statusText: stateText,
      type: StatusBadgeType.unknown,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final semanticColor = _getSemanticColor();

    final isLarge = size == StatusBadgeSize.large;
    final horizontalPadding = isLarge ? 10.0 : 8.0;
    final verticalPadding = isLarge ? 4.0 : 3.0;
    final dotSize = isLarge ? 7.0 : 6.0;
    final fontSize = isLarge ? 12.0 : 11.0;

    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: semanticColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: semanticColor.withValues(alpha: 0.40),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: semanticColor,
              ),
            ),
            SizedBox(width: isLarge ? 6 : 5),
            Flexible(
              child: Text(
                statusText.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: semanticColor,
                ),
              ),
            ),
          ],
        ),
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
