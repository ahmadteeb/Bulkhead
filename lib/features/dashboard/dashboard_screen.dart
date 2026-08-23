import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/connection_status_provider.dart';
import '../../providers/containers_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/images_provider.dart';
import '../../providers/networks_provider.dart';
import '../../providers/volumes_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectionStatusProvider);
    final containersState = ref.watch(containersNotifierProvider);
    final imagesState = ref.watch(imagesNotifierProvider);
    final volumesState = ref.watch(volumesNotifierProvider);
    final networksState = ref.watch(networksNotifierProvider);
    final events = ref.watch(recentEventsListProvider);
    final systemDfAsync = ref.watch(systemDfProvider);

    final totalContainers = containersState.containers.length;
    final runningContainers = containersState.containers.where((c) => c.state == 'running').length;
    final totalImages = imagesState.images.length;
    final totalImageBytes = imagesState.images.fold<int>(0, (sum, img) => sum + img.size);
    final totalVolumes = volumesState.volumes.length;
    final totalNetworks = networksState.networks.length;

    // Accurate Storage & Usage Calculations from System DF
    int imagesBytes = totalImageBytes;
    int containersBytes = 0;
    int volumesBytes = 0;

    systemDfAsync.whenData((df) {
      if ((df['images'] ?? 0) > 0) imagesBytes = df['images']!;
      containersBytes = df['containers'] ?? 0;
      volumesBytes = df['volumes'] ?? 0;
    });

    final totalBytes = imagesBytes + containersBytes + volumesBytes;

    double imageProgress = 0.0;
    double containerProgress = 0.0;
    double volumeProgress = 0.0;

    if (totalBytes > 0) {
      imageProgress = (imagesBytes / totalBytes).clamp(0.0, 1.0);
      containerProgress = (containersBytes / totalBytes).clamp(0.0, 1.0);
      volumeProgress = (volumesBytes / totalBytes).clamp(0.0, 1.0);
    } else {
      imageProgress = 0.0;
      containerProgress = totalContainers == 0 ? 0.0 : (runningContainers / totalContainers);
      volumeProgress = 0.0;
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final cardBgColor = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);
    final containerLowColor = AppColors.containerLow(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Overview',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Local Docker Engine status & system metrics',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );

              final actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await ConfirmDialog.show(
                        context,
                        title: 'System Prune All',
                        message: 'Remove all stopped containers, unused networks, dangling images, and volumes?',
                        confirmLabel: 'Prune System',
                        isDestructive: true,
                      );
                      if (confirm == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pruning Docker system artifacts...')),
                        );
                        final client = ref.read(dockerApiClientProvider);
                        await client.systemPruneAll();
                        ref.read(containersNotifierProvider.notifier).refreshContainers();
                        ref.read(imagesNotifierProvider.notifier).refreshImages();
                        ref.read(volumesNotifierProvider.notifier).refreshVolumes();
                        ref.read(networksNotifierProvider.notifier).refreshNetworks();
                        ref.invalidate(systemDfProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('System Prune complete! All unused resources cleaned.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: const Text('Prune System'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.borderColor(context)),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Error / Permission Banner
          if (!connState.isConnected)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Docker Daemon Connection Warning',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          connState.errorMessage ?? 'Unable to connect to Docker Unix Socket.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => ref.read(connectionStatusProvider.notifier).checkConnection(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry Connection'),
                  ),
                ],
              ),
            ),

          // Summary Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = 4;
              if (width < 900) crossAxisCount = 2;
              if (width < 500) crossAxisCount = 1;

              final cardWidth = (width - ((crossAxisCount - 1) * 16)) / crossAxisCount;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      context,
                      title: 'CONTAINERS',
                      mainMetric: '$runningContainers',
                      subMetric: 'of $totalContainers total running',
                      icon: Icons.inventory_2_outlined,
                      accentColor: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      context,
                      title: 'IMAGES',
                      mainMetric: '$totalImages',
                      subMetric: _formatBytes(totalImageBytes),
                      icon: Icons.layers_outlined,
                      accentColor: primaryContainerColor,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      context,
                      title: 'VOLUMES',
                      mainMetric: '$totalVolumes',
                      subMetric: 'active volumes',
                      icon: Icons.storage_outlined,
                      accentColor: AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      context,
                      title: 'NETWORKS',
                      mainMetric: '$totalNetworks',
                      subMetric: 'virtual networks',
                      icon: Icons.hub_outlined,
                      accentColor: const Color(0xFF732EE4),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Main Section: System Disk Usage + Real-time Event Stream
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final children = [
                // System Disk Breakdown
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
                      Text(
                        'Storage & Resource Usage',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Disk space occupied by local Docker artifacts',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),

                      _buildDiskUsageBar(
                        context,
                        label: 'Images Total Size',
                        valueText: _formatBytes(imagesBytes),
                        progress: imageProgress,
                        color: primaryContainerColor,
                      ),
                      const SizedBox(height: 16),
                      _buildDiskUsageBar(
                        context,
                        label: 'Writable Container Data',
                        valueText: containersBytes > 0
                            ? _formatBytes(containersBytes)
                            : '$runningContainers active slots',
                        progress: containerProgress,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 16),
                      _buildDiskUsageBar(
                        context,
                        label: 'Volume Storage Points',
                        valueText: volumesBytes > 0
                            ? _formatBytes(volumesBytes)
                            : '$totalVolumes volumes',
                        progress: volumeProgress,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),

                if (isNarrow) const SizedBox(height: 24) else const SizedBox(width: 24),

                // Docker Events Stream
                Container(
                  height: 320,
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
                          Expanded(
                            child: Text(
                              'Real-Time Docker Events',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SUBSCRIBED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 12),

                      Expanded(
                        child: events.isEmpty
                            ? Center(
                                child: Text(
                                  'Listening for engine activity...',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            : ListView.builder(
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final ev = events[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: containerLowColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ev.type.toUpperCase(),
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          ev.action,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            ev.actorName,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 12,
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${ev.time.hour.toString().padLeft(2, '0')}:${ev.time.minute.toString().padLeft(2, '0')}:${ev.time.second.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            color: Theme.of(context).textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: children[0]),
                  children[1],
                  Expanded(flex: 4, child: children[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String mainMetric,
    required String subMetric,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              Icon(icon, color: accentColor, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            mainMetric,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subMetric,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDiskUsageBar(
    BuildContext context, {
    required String label,
    required String valueText,
    required double progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueText,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.containerLow(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
