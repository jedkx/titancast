import 'package:flutter/foundation.dart';

/// Severity levels
enum LogLevel { verbose, debug, info, warning, error }

/// A single log record
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
  }) : time = DateTime.now();

  String get levelLabel => switch (level) {
        LogLevel.verbose => 'V',
        LogLevel.debug   => 'D',
        LogLevel.info    => 'I',
        LogLevel.warning => 'W',
        LogLevel.error   => 'E',
      };

  String get timeLabel {
    final t = time;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() => '[$timeLabel] $levelLabel/$tag: $message';
}

/// Centralised application logger.
///
/// Usage:
///   AppLogger.i('PhilipsProtocol', 'connected to $ip');
///   AppLogger.e('RemoteController', 'TCP failed: $e');
///
/// Listen to [entries] to observe logs in the UI.
class AppLogger {
  AppLogger._();

  static const int _maxEntries = 5000;

  /// ValueNotifier that fires on every new log entry — consumed by LogsScreen.
  static final ValueNotifier<List<LogEntry>> entries =
      ValueNotifier<List<LogEntry>>([]);

  /// Suppress verbose/debug logs in release builds
  static LogLevel minLevel =
      kDebugMode ? LogLevel.verbose : LogLevel.info;

  // ── Public API ──────────────────────────────────────────────────────────────

  static void v(String tag, String msg) =>
      _log(LogLevel.verbose, tag, msg);

  static void d(String tag, String msg) =>
      _log(LogLevel.debug, tag, msg);

  static void i(String tag, String msg) =>
      _log(LogLevel.info, tag, msg);

  static void w(String tag, String msg) =>
      _log(LogLevel.warning, tag, msg);

  static void e(String tag, String msg) =>
      _log(LogLevel.error, tag, msg);

  static void clear() {
    entries.value = [];
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static void _log(LogLevel level, String tag, String msg) {
    if (level.index < minLevel.index) return;

    final entry = LogEntry(level: level, tag: tag, message: msg);

    // Print to Flutter debug console.
    debugPrint(entry.toString());

    // Append to buffer, capped at _maxEntries most-recent entries.
    final current = List<LogEntry>.from(entries.value)..add(entry);
    if (current.length > _maxEntries) {
      current.removeRange(0, current.length - _maxEntries);
    }
    entries.value = current;
  }
}
