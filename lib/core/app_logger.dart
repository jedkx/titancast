import 'package:flutter/foundation.dart';

/// Log seviyeleri
enum LogLevel { verbose, debug, info, warning, error }

/// Tek bir log kaydı
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

/// Merkezi uygulama loggeri.
///
/// Kullanım:
///   AppLogger.i('PhilipsProtocol', 'connected to $ip');
///   AppLogger.e('RemoteController', 'TCP failed: $e');
///
/// UI'da izlemek için [entries] ValueNotifier'ını dinle.
class AppLogger {
  AppLogger._();

  static const int _maxEntries = 500;

  /// UI'ın dinleyeceği notifier. Her yeni log'da notify eder.
  static final ValueNotifier<List<LogEntry>> entries =
      ValueNotifier<List<LogEntry>>([]);

  /// Release build'de verbose/debug logları bastır
  static LogLevel minLevel =
      kDebugMode ? LogLevel.verbose : LogLevel.info;

  // ── Public API ─────────────────────────────────────────────────────────────

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

    // Flutter debug konsoluna da yaz
    debugPrint(entry.toString());

    // Buffer'a ekle (son _maxEntries kaydı tut)
    final current = List<LogEntry>.from(entries.value)..add(entry);
    if (current.length > _maxEntries) {
      current.removeRange(0, current.length - _maxEntries);
    }
    entries.value = current;
  }
}
