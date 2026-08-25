import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_version.dart';
import '../../models/update_model.dart';
import '../../providers/connection_status_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/update_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _socketController;

  @override
  void initState() {
    super.initState();
    _socketController = TextEditingController(
      text: ref.read(socketPathProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryContainerColor = Theme.of(
      context,
    ).colorScheme.primaryContainer;
    final onPrimaryContainerColor = Theme.of(
      context,
    ).colorScheme.onPrimaryContainer;
    final cardBgColor = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);
    final commandBgColor = AppColors.isDark(context)
        ? const Color(0xFF0C0E11)
        : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Settings & Configuration',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Docker daemon connection parameters and app preferences',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),

          // Socket Path Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_ethernet, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(
                      'Docker Engine Socket Path',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Default Linux Unix Socket path is /var/run/docker.sock',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _socketController,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: '/var/run/docker.sock',
                          prefixIcon: Icon(Icons.terminal, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(socketPathProvider.notifier).state =
                            _socketController.text.trim();
                        ref
                            .read(connectionStatusProvider.notifier)
                            .checkConnection();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryContainerColor,
                        foregroundColor: onPrimaryContainerColor,
                      ),
                      child: const Text('Save & Test Connection'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Permission Fix Instructions Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.security_outlined,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Linux Socket Permissions Guide',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'If Bulkhead displays a "Permission Denied" error, your user account needs to be added to the docker group.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: commandBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          'sudo usermod -aG docker \$USER && newgrp docker',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, size: 16, color: primaryColor),
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(
                              text:
                                  'sudo usermod -aG docker \$USER && newgrp docker',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Command copied to clipboard'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Appearance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(
                      'Appearance & Theme',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light Mode'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark Mode'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System Default'),
                      icon: Icon(Icons.settings_suggest_outlined),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      ref.read(appThemeModeProvider.notifier).state = set.first;
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Software Updates Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.system_update_rounded, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(
                      'Software Updates & Version',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulkhead Desktop v${AppVersion.currentVersion}',
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Over-the-Air (OTA) release channel',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Check for Updates'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final notifier = ref.read(updateCheckNotifierProvider.notifier);
                        await notifier.checkForUpdates(forceUserCheck: true);
                        if (!mounted) return;
                        final updateState = ref.read(updateCheckNotifierProvider);
                        final updateInfo = updateState.value;
                        if (updateInfo != null) {
                          if (updateInfo.hasUpdate) {
                            _showUpdateDialog(updateInfo);
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Bulkhead is up to date! 🎉'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(UpdateInfoModel info) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  void dispose() {
    _socketController.dispose();
    super.dispose();
  }
}
