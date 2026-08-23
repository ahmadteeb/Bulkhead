import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/container_model.dart';
import '../../providers/connection_status_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/log_viewer.dart';
import '../../widgets/status_badge.dart';

Future<void> launchNativeContainerTerminal(
  String containerId, {
  String shell = 'bash',
}) async {
  final shortId = containerId.length >= 12
      ? containerId.substring(0, 12)
      : containerId;
  final execCmd =
      'docker exec -it $shortId $shell || docker exec -it $shortId sh';

  final terminals = [
    [
      'gnome-terminal',
      '--title=Bulkhead Container $shortId',
      '--',
      'sh',
      '-c',
      execCmd,
    ],
    [
      'konsole',
      '--title',
      'Bulkhead Container $shortId',
      '-e',
      'sh',
      '-c',
      execCmd,
    ],
    ['kitty', '--title', 'Bulkhead Container $shortId', 'sh', '-c', execCmd],
    [
      'alacritty',
      '--title',
      'Bulkhead Container $shortId',
      '-e',
      'sh',
      '-c',
      execCmd,
    ],
    [
      'ptyxis',
      '--title',
      'Bulkhead Container $shortId',
      '--',
      'sh',
      '-c',
      execCmd,
    ],
    ['xfce4-terminal', '--title=Bulkhead Container $shortId', '-e', execCmd],
    ['x-terminal-emulator', '-e', execCmd],
    ['xterm', '-title', 'Bulkhead Container $shortId', '-e', execCmd],
  ];

  for (final t in terminals) {
    try {
      final res = await Process.run('which', [t.first]);
      if (res.exitCode == 0) {
        await Process.start(t.first, t.sublist(1));
        return;
      }
    } catch (_) {}
  }
}

class ContainerDetailScreen extends ConsumerStatefulWidget {
  final ContainerModel container;
  final VoidCallback onBack;

  const ContainerDetailScreen({
    super.key,
    required this.container,
    required this.onBack,
  });

  @override
  ConsumerState<ContainerDetailScreen> createState() =>
      _ContainerDetailScreenState();
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
    _tabController = TabController(length: 6, vsync: this);
    _startStreams();
    _fetchInspect();
  }

  void _startStreams() {
    final client = ref.read(dockerApiClientProvider);

    // Stream logs
    try {
      _logsSub = client.streamContainerLogs(widget.container.id).listen((line) {
        if (mounted) {
          setState(() {
            _logLines.add(line);
            if (_logLines.length > 2000) {
              _logLines.removeAt(0);
            }
          });
        }
      }, onError: (_) {});
    } catch (_) {}

    // Stream stats
    try {
      _statsSub = client.streamContainerStats(widget.container.id).listen((
        stats,
      ) {
        if (!mounted) return;
        _parseStats(stats);
      }, onError: (_) {});
    } catch (_) {}
  }

  void _parseStats(Map<String, dynamic> stats) {
    try {
      final cpuStats = stats['cpu_stats'] as Map<String, dynamic>? ?? {};
      final precpuStats = stats['precpu_stats'] as Map<String, dynamic>? ?? {};
      final memoryStats = stats['memory_stats'] as Map<String, dynamic>? ?? {};

      final cpuDelta =
          (cpuStats['cpu_usage']?['total_usage'] as num? ?? 0) -
          (precpuStats['cpu_usage']?['total_usage'] as num? ?? 0);
      final systemDelta =
          (cpuStats['system_cpu_usage'] as num? ?? 0) -
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

        final double spotIndex = _cpuPoints.length.toDouble();
        _cpuPoints.add(FlSpot(spotIndex, cpuPercent));
        _memPoints.add(
          FlSpot(spotIndex, (memUsage / (1024 * 1024)).toDouble()),
        );

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
      final data = await ref
          .read(dockerApiClientProvider)
          .inspectContainer(widget.container.id);
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
  void dispose() {
    _tabController.dispose();
    _logsSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryContainerColor = Theme.of(
      context,
    ).colorScheme.primaryContainer;
    final mutedTextColor = Theme.of(context).textTheme.bodySmall?.color;
    final client = ref.watch(dockerApiClientProvider);

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
                        StatusBadge.fromState(
                          widget.container.state,
                          size: StatusBadgeSize.large,
                        ),
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
              Tab(icon: Icon(Icons.computer, size: 18), text: 'Exec Terminal'),
              Tab(
                icon: Icon(Icons.folder_open, size: 18),
                text: 'Volume Browser',
              ),
              Tab(
                icon: Icon(Icons.show_chart, size: 18),
                text: 'Realtime Stats',
              ),
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

                // 2. Exec Terminal Tab
                _ContainerExecView(
                  containerId: widget.container.id,
                  client: client,
                ),

                // 3. Volume File Browser Tab
                _ContainerVolumeBrowserView(
                  containerId: widget.container.id,
                  mounts: widget.container.mounts,
                  client: client,
                ),

                // 4. Stats Tab
                _buildStatsTab(context),

                // 5. Inspect JSON Tab
                _buildInspectTab(context),

                // 6. Overview Tab
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
    final primaryContainerColor = Theme.of(
      context,
    ).colorScheme.primaryContainer;
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
          const SizedBox(height: 20),

          // CPU Chart Card
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
                  'CPU Usage (%)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _cpuPoints.isEmpty
                              ? [const FlSpot(0, 0)]
                              : _cpuPoints,
                          isCurved: true,
                          color: primaryContainerColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Memory Chart Card
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
                  'Memory Usage (MB)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _memPoints.isEmpty
                              ? [const FlSpot(0, 0)]
                              : _memPoints,
                          isCurved: true,
                          color: AppColors.success,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
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

  Widget _buildInspectTab(BuildContext context) {
    if (_loadingInspect) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_inspectData == null) {
      return const Center(child: Text('Inspect data unavailable.'));
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(_inspectData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Raw Docker Inspect Payload',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy JSON',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inspect JSON copied to clipboard!'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: AppColors.isDark(context)
                      ? const Color(0xFF70D2FF)
                      : const Color(0xFF006699),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final borderColor = AppColors.borderColor(context);
    final cardBg = AppColors.cardBg(context);

    final envList =
        (_inspectData?['Config']?['Env'] as List<dynamic>?)?.cast<String>() ??
        [];
    final ports = widget.container.ports;
    final mounts = widget.container.mounts;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Environment Variables Table
          Text(
            'Environment Variables',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: envList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No environment variables set.'),
                  )
                : Column(
                    children: envList.map((e) {
                      final parts = e.split('=');
                      final key = parts.first;
                      final val = parts.skip(1).join('=');
                      return ListTile(
                        dense: true,
                        title: Text(
                          key,
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(val, style: GoogleFonts.jetBrainsMono()),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Ports Table
          Text('Port Mappings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: ports.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No ports exposed.'),
                  )
                : Column(
                    children: ports.map((p) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.input, size: 18),
                        title: Text(
                          'IP: ${p.ip ?? "0.0.0.0"} • Host: ${p.publicPort ?? "dynamic"} -> Container: ${p.privatePort}/${p.type}',
                          style: GoogleFonts.jetBrainsMono(),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Mounts Table
          Text('Volume Mounts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: mounts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No volume mounts configured.'),
                  )
                : Column(
                    children: mounts.map((m) {
                      final type = m.type ?? 'volume';
                      final source = m.source ?? '';
                      final destination = m.destination ?? '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.storage, size: 18),
                        title: Text(
                          '[$type] $destination',
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Host Source: $source',
                          style: GoogleFonts.jetBrainsMono(),
                        ),
                      );
                    }).toList(),
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
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContainerExecView extends StatefulWidget {
  final String containerId;
  final dynamic client;

  const _ContainerExecView({required this.containerId, required this.client});

  @override
  State<_ContainerExecView> createState() => _ContainerExecViewState();
}

class _ContainerExecViewState extends State<_ContainerExecView> {
  late final Terminal _terminal;
  Process? _process;
  String _selectedShell = '/bin/bash';
  final List<String> _terminalLogBuffer = [];

  final List<String> _availableShells = ['/bin/sh', '/bin/bash'];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 5000);
    _connectTerminal();
  }

  String _cleanTerminalOutput(String input) {
    var s = input;
    // Strip xterm title setting sequences (e.g. \x1b]0;...\x07)
    s = s.replaceAll(RegExp(r'\x1b\][0-9];[^\x07]*\x07'), '');
    // Strip bracketed paste mode escape sequences (e.g. \x1b[?2004h, \x1b[?2004l)
    s = s.replaceAll(RegExp(r'\x1b\[\?[0-9]+[h|l]'), '');
    // Strip non-printable control characters except \n, \r, \t, and \x1b
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1A\x1C-\x1F]'), '');
    return s;
  }

  Future<void> _connectTerminal() async {
    _process?.kill();
    _terminalLogBuffer.clear();
    _terminal.write(
      'Connecting interactive terminal to container ($_selectedShell)...\r\n',
    );

    try {
      final shortId = widget.containerId.length >= 12
          ? widget.containerId.substring(0, 12)
          : widget.containerId;
      try {
        final scriptCheck = await Process.run('which', ['script']);
        if (scriptCheck.exitCode == 0) {
          _process = await Process.start('script', [
            '-q',
            '-c',
            'docker exec -it $shortId $_selectedShell',
            '/dev/null',
          ]);
        } else {
          _process = await Process.start('docker', [
            'exec',
            '-i',
            '-e',
            'TERM=xterm-256color',
            shortId,
            _selectedShell,
          ]);
        }
      } catch (_) {
        _process = await Process.start('docker', [
          'exec',
          '-i',
          '-e',
          'TERM=xterm-256color',
          shortId,
          _selectedShell,
        ]);
      }

      _process!.stdout.listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        final cleaned = _cleanTerminalOutput(text);
        final normalized = cleaned
            .replaceAll('\r\n', '\n')
            .replaceAll('\n', '\r\n');
        _terminal.write(normalized);
        _terminalLogBuffer.add(text);
      });
      _process!.stderr.listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        final cleaned = _cleanTerminalOutput(text);
        final normalized = cleaned
            .replaceAll('\r\n', '\n')
            .replaceAll('\n', '\r\n');
        _terminal.write(normalized);
        _terminalLogBuffer.add(text);
      });

      _terminal.onOutput = (input) {
        _process?.stdin.write(input);
      };

      _process!.exitCode.then((code) {
        if (mounted) {
          _terminal.write(
            '\r\n[Container terminal session closed (Exit code $code)]\r\n',
          );
        }
      });
    } catch (e) {
      _terminal.write('Failed to spawn container terminal process: $e\r\n');
    }
  }

  void _showTerminalContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('Copy Terminal Output'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.content_paste, size: 16),
              SizedBox(width: 8),
              Text('Paste to Terminal Stdin'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy') {
        _copyTerminalLogs();
      } else if (value == 'paste') {
        _pasteFromClipboard();
      }
    });
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _process?.stdin.write(data.text);
    }
  }

  void _copyTerminalLogs() {
    final fullText = _terminalLogBuffer.join('');
    Clipboard.setData(ClipboardData(text: fullText));
  }

  @override
  void dispose() {
    _process?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.borderColor(context);
    final cardBg = const Color(0xFF0D0E11);

    return Column(
      children: [
        // Top Toolbar
        Row(
          children: [
            // Shell Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedShell,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  items: _availableShells.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(
                        'Shell: $s',
                        style: GoogleFonts.jetBrainsMono(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedShell = val);
                      _connectTerminal();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _connectTerminal(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reconnect'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste, size: 16),
              label: const Text('Paste Stdin'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _copyTerminalLogs,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Terminal Logs'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => launchNativeContainerTerminal(
                widget.containerId,
                shell: _selectedShell,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open External Terminal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Terminal Output Screen with Right-Click Context Menu
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: GestureDetector(
              onSecondaryTapDown: (details) =>
                  _showTerminalContextMenu(context, details.globalPosition),
              child: SelectionArea(
                child: TerminalView(
                  _terminal,
                  autofocus: true,
                  theme: TerminalThemes.whiteOnBlack,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContainerVolumeBrowserView extends StatefulWidget {
  final String containerId;
  final List<ContainerMountPoint> mounts;
  final dynamic client;

  const _ContainerVolumeBrowserView({
    required this.containerId,
    required this.mounts,
    required this.client,
  });

  @override
  State<_ContainerVolumeBrowserView> createState() =>
      _ContainerVolumeBrowserViewState();
}

class _ContainerVolumeBrowserViewState
    extends State<_ContainerVolumeBrowserView> {
  final TextEditingController _pathCtrl = TextEditingController(text: '/');
  List<Map<String, String>> _files = [];
  bool _isLoading = false;
  String? _error;
  String _selectedMountPath = '/';

  final List<String> _history = ['/'];
  int _historyIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.mounts.isNotEmpty && widget.mounts.first.destination != null) {
      _selectedMountPath = widget.mounts.first.destination!;
      _history[0] = _selectedMountPath;
    }
    _loadFiles(_selectedMountPath, pushHistory: false);
  }

  void _loadFiles(String path, {bool pushHistory = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _pathCtrl.text = path;
      if (pushHistory) {
        if (_historyIndex < _history.length - 1) {
          _history.removeRange(_historyIndex + 1, _history.length);
        }
        _history.add(path);
        _historyIndex = _history.length - 1;
      }
    });

    try {
      final res = await widget.client.listContainerFiles(
        widget.containerId,
        path,
      );
      if (mounted) {
        setState(() {
          _files = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _uploadFile() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty && files.first.path != null) {
        final hostPath = files.first.path!;
        final currentPath = _pathCtrl.text;
        final shortId = widget.containerId.length >= 12
            ? widget.containerId.substring(0, 12)
            : widget.containerId;

        final res = await Process.run('docker', [
          'cp',
          hostPath,
          '$shortId:$currentPath',
        ]);
        if (mounted) {
          if (res.exitCode == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Uploaded ${files.first.name} successfully!',
                ),
                backgroundColor: AppColors.success,
              ),
            );
            _loadFiles(currentPath, pushHistory: false);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${res.stderr}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _downloadItem(String fileName) async {
    try {
      final currentPath = _pathCtrl.text;
      final remotePath = currentPath.endsWith('/')
          ? '$currentPath$fileName'
          : '$currentPath/$fileName';
      final shortId = widget.containerId.length >= 12
          ? widget.containerId.substring(0, 12)
          : widget.containerId;

      final String? targetDir = await FilePicker.getDirectoryPath();
      if (targetDir == null) return; // User cancelled download dialog!

      final res = await Process.run('docker', [
        'cp',
        '$shortId:$remotePath',
        '$targetDir/',
      ]);
      if (mounted) {
        if (res.exitCode == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded $fileName to $targetDir!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${res.stderr}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = AppColors.cardBg(context);
    final borderColor = AppColors.borderColor(context);
    final currentPath = _pathCtrl.text;

    final mountItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '/', child: Text('Root (/)')),
      ...widget.mounts.map((m) {
        final dest = m.destination ?? '/';
        final name = m.name ?? m.source ?? 'Mount';
        final type = m.type ?? 'volume';
        return DropdownMenuItem(
          value: dest,
          child: Text(
            '[$type] $name -> $dest',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    ];

    final canGoBack = _historyIndex > 0;
    final canGoForward = _historyIndex < _history.length - 1;

    return Column(
      children: [
        Row(
          children: [
            // Back & Forward Navigation Buttons
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              tooltip: 'Go Back',
              onPressed: canGoBack
                  ? () {
                      _historyIndex--;
                      _loadFiles(_history[_historyIndex], pushHistory: false);
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              tooltip: 'Go Forward',
              onPressed: canGoForward
                  ? () {
                      _historyIndex++;
                      _loadFiles(_history[_historyIndex], pushHistory: false);
                    }
                  : null,
            ),
            const SizedBox(width: 8),

            // Attached Volumes Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: mountItems.any((it) => it.value == _selectedMountPath)
                      ? _selectedMountPath
                      : '/',
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  items: mountItems,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMountPath = val);
                      _loadFiles(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _pathCtrl,
                onSubmitted: (val) => _loadFiles(val),
                decoration: const InputDecoration(
                  labelText: 'Volume Path',
                  prefixIcon: Icon(Icons.folder_open, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _loadFiles(_pathCtrl.text),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Browse'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _uploadFile,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                ? Center(
                    child: SelectableText(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                : ListView.separated(
                    itemCount: _files.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: borderColor),
                    itemBuilder: (context, idx) {
                      final item = _files[idx];
                      final isDir = item['isDir'] == 'true';
                      final name = item['name'] ?? '';
                      final perms = item['permissions'] ?? '';
                      final size = item['size'] ?? '';

                      return ListTile(
                        leading: Icon(
                          isDir ? Icons.folder : Icons.insert_drive_file,
                          color: isDir
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '$perms • $size bytes',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download, size: 18),
                              tooltip: 'Download File/Folder to Host',
                              onPressed: () => _downloadItem(name),
                            ),
                            if (isDir)
                              const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                        onTap: isDir
                            ? () {
                                final nextPath = currentPath.endsWith('/')
                                    ? '$currentPath$name'
                                    : '$currentPath/$name';
                                _loadFiles(nextPath);
                              }
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
