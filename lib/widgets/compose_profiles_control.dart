import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/compose_provider.dart';
import 'message_dialog.dart';
import 'resource_action.dart';

class ComposeProfilesControl extends ConsumerWidget {
  final String configFiles;
  const ComposeProfilesControl({super.key, required this.configFiles});

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    List<String> available,
    Set<String> selected,
  ) async {
    try {
      available = await withProgressDialog(
        context,
        'Loading Compose profiles',
        () => ref.refresh(composeAvailableProfilesProvider(configFiles).future),
      );
    } catch (error) {
      if (context.mounted) {
        showResourceError(context, 'Load Compose profiles', error);
      }
      return;
    }
    if (!context.mounted) return;
    final choice = selected.contains('*')
        ? available.toSet()
        : selected.intersection(available.toSet());
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Compose profiles'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose optional services for the next stack actions. Services without a profile are always included.',
                  ),
                  const SizedBox(height: 12),
                  for (final profile in available)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(profile),
                      value: choice.contains(profile),
                      onChanged: (enabled) => setState(() {
                        if (enabled == true) {
                          choice.add(profile);
                        } else {
                          choice.remove(profile);
                        }
                      }),
                    ),
                  const Text(
                    'Changing this selection does not start or stop existing containers.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setState(choice.clear),
              child: const Text('Default only'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(choice),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null && context.mounted) {
      ref.read(composeSelectedProfilesProvider(configFiles).notifier).state =
          Set.unmodifiable(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (configFiles.isEmpty) return const SizedBox.shrink();
    final available = ref.watch(composeAvailableProfilesProvider(configFiles));
    final selected = ref.watch(composeSelectedProfilesProvider(configFiles));
    return available.when(
      loading: () => Text(
        'Loading profiles…',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      error: (error, _) => Tooltip(
        message: error.toString(),
        child: TextButton.icon(
          onPressed: () =>
              ref.invalidate(composeAvailableProfilesProvider(configFiles)),
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Retry profiles'),
        ),
      ),
      data: (profiles) {
        if (profiles.isEmpty) return const SizedBox.shrink();
        final displayed = selected.isEmpty
            ? profiles
            : (selected.toList()..sort());
        final names = selected.contains('*')
            ? 'All profiles'
            : displayed.join(', ');
        return Tooltip(
          message: selected.isEmpty
              ? 'Using default services. Choose profiles for stack actions.'
              : 'Selected profiles for stack actions: $names',
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => _choose(context, ref, profiles, selected),
            icon: const Icon(Icons.tune, size: 14),
            label: Text(
              '${selected.isEmpty ? 'Available profiles' : 'Profiles'}: $names',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
