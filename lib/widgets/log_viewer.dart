import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class LogViewer extends StatefulWidget {
  final List<String> logs;
  final VoidCallback? onClear;
  final bool isStreaming;

  const LogViewer({
    super.key,
    required this.logs,
    this.onClear,
    this.isStreaming = true,
  });

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void didUpdateWidget(covariant LogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.logs.length != oldWidget.logs.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filter.isEmpty
        ? widget.logs
        : widget.logs.where((l) => l.toLowerCase().contains(_filter.toLowerCase())).toList();

    final isDark = AppColors.isDark(context);
    final termBg = isDark ? const Color(0xFF0C0E11) : const Color(0xFF0F172A);
    final toolbarBg = isDark ? const Color(0xFF1A1C1F) : const Color(0xFF1E293B);
    final borderColor = AppColors.borderColor(context);

    return Container(
      decoration: BoxDecoration(
        color: termBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: toolbarBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 18,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(width: 8),
                Text(
                  'LOG OUTPUT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.isStreaming)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE STREAM',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // Filter search
                SizedBox(
                  width: 180,
                  height: 30,
                  child: TextField(
                    onChanged: (val) => setState(() => _filter = val),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filter logs...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      fillColor: termBg,
                      hintStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _autoScroll ? Icons.arrow_downward : Icons.pause,
                    size: 16,
                    color: _autoScroll ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                  ),
                  tooltip: _autoScroll ? 'Auto-scroll On' : 'Auto-scroll Paused',
                  onPressed: () => setState(() => _autoScroll = !_autoScroll),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Color(0xFF94A3B8)),
                  tooltip: 'Copy Logs',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.logs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logs copied to clipboard')),
                    );
                  },
                ),
                if (widget.onClear != null)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, size: 16, color: Color(0xFF94A3B8)),
                    tooltip: 'Clear View',
                    onPressed: widget.onClear,
                  ),
              ],
            ),
          ),

          // Log Content Area
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) {
                  final line = filteredLogs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        height: 1.4,
                        color: line.toLowerCase().contains('err') || line.toLowerCase().contains('fail')
                            ? const Color(0xFFF87171)
                            : line.toLowerCase().contains('warn')
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
