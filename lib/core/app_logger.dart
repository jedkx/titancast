import 'package:flutter/foundation.dart';
import 'constants.dart';

/// Severity levels
enum LogLevel { verbose, debug, info, warning, error, fatal }

/// Log context for structured logging
class LogContext {
  const LogContext({
    this.userId,
    this.deviceId, 
    this.sessionId,
    this.operation,
    this.duration,
    this.metadata,
  });
  
  final String? userId;
  final String? deviceId;
  final String? sessionId;
  final String? operation;
  final Duration? duration;
  final Map<String, dynamic>? metadata;
  
  LogContext copyWith({
    String? userId,
    String? deviceId,
    String? sessionId,
    String? operation,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    return LogContext(
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      operation: operation ?? this.operation,
      duration: duration ?? this.duration,
      metadata: metadata ?? this.metadata,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'userId': userId,
      if (deviceId != null) 'deviceId': deviceId,
      if (sessionId != null) 'sessionId': sessionId,
      if (operation != null) 'operation': operation,
      if (duration != null) 'durationMs': duration!.inMilliseconds,
      if (metadata != null) ...metadata!,
    };
  }
}

/// A single log record with enhanced structured data
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final LogContext? context;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.context,
    this.error,
    this.stackTrace,
  }) : time = DateTime.now();

  String get levelLabel => switch (level) {
        LogLevel.verbose => LoggingConstants.verbose,
        LogLevel.debug   => LoggingConstants.debug,
        LogLevel.info    => LoggingConstants.info,
        LogLevel.warning => LoggingConstants.warning,
        LogLevel.error   => LoggingConstants.error,
        LogLevel.fatal   => 'F',
      };

  String get timeLabel {
    final t = time;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
  
  String get formattedMessage {
    final buffer = StringBuffer(message);
    if (context != null) {
      final contextJson = context!.toJson();
      if (contextJson.isNotEmpty) {
        buffer.write(' | Context: $contextJson');
      }
    }
    if (error != null) {
      buffer.write(' | Error: $error');
    }
    return buffer.toString();
  }

  @override
  String toString() => '[$timeLabel] $levelLabel/$tag: $formattedMessage';
  
  /// Convert to JSON for structured logging backends
  Map<String, dynamic> toJson() {
    return {
      'timestamp': time.toIso8601String(),
      'level': level.name,
      'tag': tag,
      'message': message,
      if (context != null) 'context': context!.toJson(),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
  }
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
