import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_logger.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _filterLevel;
  String _filterTag = '';
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    AppLogger.entries.addListener(_onNewLog);
  }

  @override
  void dispose() {
    AppLogger.entries.removeListener(_onNewLog);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewLog() {
    if (mounted) {
      setState(() {});
      if (_autoScroll) _scrollToBottom();
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

  List<LogEntry> get _filtered {
    return AppLogger.entries.value.where((e) {
      if (_filterLevel != null && e.level != _filterLevel) return false;
      if (_filterTag.isNotEmpty &&
          !e.tag.toLowerCase().contains(_filterTag.toLowerCase())) return false;
      return true;
    }).toList();
  }

  void _copyAll() {
    final text = _filtered.map((e) => e.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_filtered.length} satır kopyalandı'),
        backgroundColor: const Color(0xFF8B5CF6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0E),
        title: const Text(
          'Logs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom_rounded
                  : Icons.pause_rounded,
              color: _autoScroll
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF8A8A93),
            ),
            tooltip: 'Auto-scroll',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF8A8A93)),
            tooltip: 'Tümünü kopyala',
            onPressed: _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded,
                color: Color(0xFF8A8A93)),
            tooltip: 'Temizle',
            onPressed: () {
              AppLogger.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtre Barı ─────────────────────────────────────────────────
          Container(
            color: const Color(0xFF15151A),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Level filtresi
                ...LogLevel.values.map((level) {
                  final selected = _filterLevel == level;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() =>
                          _filterLevel = selected ? null : level),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? _levelColor(level).withValues(alpha: 0.25)
                              : const Color(0xFF22222A),
                          borderRadius: BorderRadius.circular(8),
                          border: selected
                              ? Border.all(
                                  color: _levelColor(level), width: 1)
                              : null,
                        ),
                        child: Text(
                          level.name[0].toUpperCase(),
                          style: TextStyle(
                            color: selected
                                ? _levelColor(level)
                                : const Color(0xFF8A8A93),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(width: 8),

                // Tag filtresi
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Tag filtrele...',
                      hintStyle: const TextStyle(
                          color: Color(0xFF8A8A93), fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFF22222A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _filterTag = v),
                  ),
                ),

                const SizedBox(width: 8),
                Text(
                  '${logs.length}',
                  style: const TextStyle(
                      color: Color(0xFF8A8A93), fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Log Listesi ──────────────────────────────────────────────────
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz log yok',
                      style: TextStyle(color: Color(0xFF8A8A93)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _LogRow(entry: logs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  static Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.verbose => const Color(0xFF6B7280),
        LogLevel.debug   => const Color(0xFF60A5FA),
        LogLevel.info    => const Color(0xFF34D399),
        LogLevel.warning => const Color(0xFFFBBF24),
        LogLevel.error   => const Color(0xFFF87171),
      };
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  static Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.verbose => const Color(0xFF6B7280),
        LogLevel.debug   => const Color(0xFF60A5FA),
        LogLevel.info    => const Color(0xFF34D399),
        LogLevel.warning => const Color(0xFFFBBF24),
        LogLevel.error   => const Color(0xFFF87171),
      };

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(entry.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zaman
          Text(
            entry.timeLabel,
            style: const TextStyle(
                color: Color(0xFF4B5563), fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 6),
          // Level badge
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Text(
                entry.levelLabel,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Tag
          Text(
            '${entry.tag}: ',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace'),
          ),
          // Mesaj
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
