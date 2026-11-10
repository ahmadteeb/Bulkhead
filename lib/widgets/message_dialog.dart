import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum MessageType { info, success, error }

Future<void> showMessageDialog(
  BuildContext context, {
  required String message,
  String title = 'Information',
  MessageType type = MessageType.info,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          Icon(
            switch (type) {
              MessageType.error => Icons.error_outline,
              MessageType.success => Icons.check_circle_outline,
              MessageType.info => Icons.info_outline,
            },
            color: switch (type) {
              MessageType.error => AppColors.error,
              MessageType.success => AppColors.success,
              MessageType.info => Theme.of(dialogContext).colorScheme.primary,
            },
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
        ],
      ),
      content: SizedBox(width: 480, child: SelectableText(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Remove only this operation's route, even if another route opens meanwhile.
Future<T> withProgressDialog<T>(
  BuildContext context,
  String title,
  Future<T> Function() operation,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Please wait…')),
          ],
        ),
      ),
    ),
  );
  unawaited(navigator.push(route));
  try {
    return await operation();
  } finally {
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}
