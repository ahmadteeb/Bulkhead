import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/container_model.dart';
import '../../providers/connection_status_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/log_viewer.dart';
import '../../widgets/status_badge.dart';

class ContainerDetailScreen extends ConsumerStatefulWidget {
  final ContainerModel container;
  final VoidCallback onBack;

  const ContainerDetailScreen({
    super.key,
    required this.container,
    required this.onBack,
  });

  @override
  ConsumerState<ContainerDetailScreen> createState() => _ContainerDetailScreenState();
}

class _ContainerDetailScreenState extends ConsumerState<ContainerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Logs stream
  final List<String> _logLines = [];
  StreamSubscription<String>? _logsSub;

  // Stats stream
  final List<FlSpot> _cpuPoints = [];
  final List<FlSpot> _memPoints = [];
  double _currentCpu = 0.0;
  int _currentMem = 0;
  int _maxMem = 0;
  StreamSubscription<Map<String, dynamic>>? _statsSub;

  // Inspect data
  Map<String, dynamic>? _inspectData;
  bool _loadingInspect = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startStreams();
    _fetchInspect();
  }

  void _startStreams() {
    final client = ref.read(dockerApiClientProvider);

    // Stream logs
    try {
      _logsSub = client.streamContainerLogs(widget.container.id).listen(
        (line) {
          if (mounted) {
            setState(() {
              _logLines.add(line);
              if (_logLines.length > 2000) {
                _logLines.removeAt(0);
              }
            });
          }
        },
        onError: (_) {},
      );
    } catch (_) {}

    // Stream stats
    try {
      _statsSub = client.streamContainerStats(widget.container.id).listen(
        (stats) {
          if (!mounted) return;
          _parseStats(stats);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _parseStats(Map<String, dynamic> stats) {
    try {
      final cpuStats = stats['cpu_stats'] as Map<String, dynamic>? ?? {};
      final precpuStats = stats['precpu_stats'] as Map<String, dynamic>? ?? {};
      final memoryStats = stats['memory_stats'] as Map<String, dynamic>? ?? {};

      final cpuDelta = (cpuStats['cpu_usage']?['total_usage'] as num? ?? 0) -
          (precpuStats['cpu_usage']?['total_usage'] as num? ?? 0);
      final systemDelta = (cpuStats['system_cpu_usage'] as num? ?? 0) -
          (precpuStats['system_cpu_usage'] as num? ?? 0);
      final onlineCpus = (cpuStats['online_cpus'] as num? ?? 1).toDouble();

      double cpuPercent = 0.0;
      if (systemDelta > 0 && cpuDelta > 0) {
        cpuPercent = (cpuDelta / systemDelta) * onlineCpus * 100.0;
      }

      final memUsage = memoryStats['usage'] as int? ?? 0;
      final memLimit = memoryStats['limit'] as int? ?? 1;

      setState(() {
        _currentCpu = cpuPercent;
        _currentMem = memUsage;
        _maxMem = memLimit;

        final timeIndex = _cpuPoints.length.toDouble();
        _cpuPoints.add(FlSpot(timeIndex, cpuPercent));
        _memPoints.add(FlSpot(timeIndex, (memUsage / (1024 * 1024)).toDouble()));

        if (_cpuPoints.length > 30) {
          _cpuPoints.removeAt(0);
          _memPoints.removeAt(0);
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchInspect() async {
    setState(() => _loadingInspect = true);
    try {
      final data = await ref.read(dockerApiClientProvider).inspectContainer(widget.container.id);
      if (mounted) {
        setState(() {
          _inspectData = data;
          _loadingInspect = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInspect = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final mutedTextColor = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Back Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.container.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(width: 12),
                        StatusBadge.fromState(widget.container.state),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${widget.container.id} • Image: ${widget.container.image}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: primaryColor,
            unselectedLabelColor: mutedTextColor,
            indicatorColor: primaryContainerColor,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.terminal, size: 18), text: 'Logs'),
              Tab(icon: Icon(Icons.show_chart, size: 18), text: 'Realtime Stats'),
              Tab(icon: Icon(Icons.code, size: 18), text: 'Inspect JSON'),
              Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Overview'),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Logs Tab
                LogViewer(
                  logs: _logLines,
                  onClear: () => setState(() => _logLines.clear()),
                ),

                // 2. Stats Tab
                _buildStatsTab(context),

                // 3. Inspect JSON Tab
                _buildInspectTab(context),

                // 4. Overview Tab
                _buildOverviewTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(BuildContext context) {
    final memMb = (_currentMem / (1024 * 1024)).toStringAsFixed(1);
    final maxMemMb = (_maxMem / (1024 * 1024)).toStringAsFixed(1);
    final primaryContainerColor = Theme.of(context).colorScheme.primaryContainer;
    final cardBgColor = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricGauge(
                  context,
                  title: 'CPU USAGE',
                  value: '${_currentCpu.toStringAsFixed(1)}%',
                  color: primaryContainerColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricGauge(
                  context,
                  title: 'MEMORY USAGE',
                  value: '$memMb MB / $maxMemMb MB',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // CPU History Graph Card
          Container(
            height: 260,
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
                  'CPU Utilization (%)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _cpuPoints.isEmpty ? [const FlSpot(0, 0)] : _cpuPoints,
                          isCurved: true,
                          color: primaryContainerColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: primaryContainerColor.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGauge(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
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
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectTab(BuildContext context) {
    if (_loadingInspect) {
      return const Center(child: CircularProgressIndicator());
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(_inspectData ?? {});

    final termBg = AppColors.isDark(context) ? const Color(0xFF0C0E11) : const Color(0xFF0F172A);
    final borderColor = AppColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: termBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'RAW JSON INSPECT',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy, size: 16, color: primaryColor),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inspect JSON copied to clipboard')),
                  );
                },
              ),
            ],
          ),
          Divider(color: borderColor),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final envList = (_inspectData?['Config']?['Env'] as List<dynamic>?)?.cast<String>() ?? [];
    final ports = widget.container.ports;
    final mounts = widget.container.mounts;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final variantTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Port Mappings Card
          _buildInfoSection(
            context,
            title: 'Port Mappings',
            icon: Icons.alt_route_outlined,
            child: ports.isEmpty
                ? const Text('No exposed ports mapped.')
                : Column(
                    children: ports.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              p.toString(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // Environment Variables Card
          _buildInfoSection(
            context,
            title: 'Environment Variables',
            icon: Icons.key_outlined,
            child: envList.isEmpty
                ? const Text('No environment variables set.')
                : Column(
                    children: envList.map((e) {
                      final parts = e.split('=');
                      final k = parts.first;
                      final v = parts.sublist(1).join('=');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 200,
                              child: Text(
                                k,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                v,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  color: variantTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // Mounts Card
          _buildInfoSection(
            context,
            title: 'Volume & Directory Mounts',
            icon: Icons.folder_open_outlined,
            child: mounts.isEmpty
                ? const Text('No mounts attached.')
                : Column(
                    children: mounts.map((m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              '[${m.type?.toUpperCase() ?? "BIND"}]',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${m.source} ➔ ${m.destination}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  color: onSurfaceColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final cardBgColor = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
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
              Icon(icon, size: 20, color: primaryColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logsSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }
}
