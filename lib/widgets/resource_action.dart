import 'message_dialog.dart';
import 'package:flutter/material.dart';

void showResourceError(BuildContext context, String action, Object error) {
  if (!context.mounted) return;
  showMessageDialog(
    context,
    title: 'Operation failed',
    message: '$action failed: $error',
    type: MessageType.error,
  );
}

Future<bool> runResourceAction(
  BuildContext context,
  String label,
  Future<void> Function() action,
) async {
  try {
    if (!context.mounted) return false;
    await withProgressDialog(context, label, action);
    return true;
  } catch (error) {
    if (context.mounted) showResourceError(context, label, error);
    return false;
  }
}

/// Stop on the first failure and retain only unfinished selections for retry.
Future<bool> runBulkResourceAction(
  BuildContext context,
  String label,
  List<String> items,
  Future<void> Function(String) action, {
  required void Function(String) onCompleted,
}) async {
  if (!context.mounted) return false;
  var completed = 0;
  String? failedItem;
  try {
    await withProgressDialog(context, label, () async {
      for (final item in items) {
        if (!context.mounted) return;
        failedItem = item;
        await action(item);
        completed++;
        if (!context.mounted) return;
        onCompleted(item);
      }
    });
    return context.mounted;
  } catch (error) {
    if (context.mounted) {
      showResourceError(
        context,
        '$label for $failedItem ($completed of ${items.length} completed)',
        error,
      );
    }
    return false;
  }
}
