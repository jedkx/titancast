/// Enhanced logging utility for structured logging and performance monitoring
/// This complements the existing AppLogger with advanced features

import 'package:flutter/foundation.dart';
import 'app_logger.dart';

/// Performance monitoring and metrics collection
class PerformanceMonitor {
  PerformanceMonitor._();
  
  static final Map<String, List<Duration>> _metrics = {};
  static final Map<String, Stopwatch> _activeOperations = {};
  
  /// Start timing an operation
  static void startOperation(String operationId) {
    _activeOperations[operationId] = Stopwatch()..start();
  }
  
  /// End timing and log performance
  static void endOperation(String operationId, {String? description}) {
    final stopwatch = _activeOperations.remove(operationId);
    if (stopwatch != null) {
      stopwatch.stop();
      final duration = stopwatch.elapsed;
      
      // Store metric
      _metrics.putIfAbsent(operationId, () => []).add(duration);
      
      // Log performance
      AppLogger.d('PERF', 
        '$operationId: ${description ?? operationId} (${duration.inMilliseconds}ms)');
      
      // Cleanup old metrics
      final metrics = _metrics[operationId]!;
      if (metrics.length > 100) {
        metrics.removeRange(0, 50);
      }
    }
  }
  
  /// Get performance statistics
  static Map<String, dynamic>? getStats(String operationId) {
    final metrics = _metrics[operationId];
    if (metrics == null || metrics.isEmpty) return null;
    
    final ms = metrics.map((d) => d.inMilliseconds).toList()..sort();
    final sum = ms.reduce((a, b) => a + b);
    
    return {
      'operation': operationId,
      'count': ms.length,
      'avgMs': (sum / ms.length).round(),
      'minMs': ms.first,
      'maxMs': ms.last,
      'p95Ms': ms[(ms.length * 0.95).floor()],
    };
  }
  
  /// Clear all metrics
  static void clear() {
    _metrics.clear();
    _activeOperations.clear();
  }
}

/// Error tracking and reporting utilities
class ErrorReporter {
  ErrorReporter._();
  
  /// Report an error with context
  static void reportError(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    // Log error
    AppLogger.e(tag, message);
    
    // In production, you could send to crash reporting service
    if (kReleaseMode && error != null) {
      _sendToCrashlytics(tag, message, error, stackTrace, context);
    }
  }
  
  /// Handle uncaught errors
  static void handleUncaughtError(Object error, StackTrace stackTrace) {
    AppLogger.e('UNCAUGHT', 'Uncaught error: $error');
    
    if (kReleaseMode) {
      _sendToCrashlytics('UNCAUGHT', 'Uncaught error', error, stackTrace, null);
    }
  }
  
  static void _sendToCrashlytics(
    String tag,
    String message,
    Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    // TODO: Integrate with Firebase Crashlytics or similar service
    debugPrint('Would send to crashlytics: $tag - $message');
  }
}

/// Structured logging helpers
class StructuredLogger {
  StructuredLogger._();
  
  /// Log with structured data
  static void log({
    required String tag,
    required String message,
    required LogLevel level,
    String? operation,
    String? deviceId,
    Duration? duration,
    Map<String, dynamic>? data,
    Object? error,
  }) {
    final buffer = StringBuffer(message);
    
    // Add structured data
    final metadata = <String, dynamic>{
      if (operation != null) 'op': operation,
      if (deviceId != null) 'device': deviceId,
      if (duration != null) 'duration': '${duration.inMilliseconds}ms',
      ...?data,
    };
    
    if (metadata.isNotEmpty) {
      buffer.write(' | ${metadata.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    }
    
    if (error != null) {
      buffer.write(' | error=$error');
    }
    
    // Log with appropriate level
    switch (level) {
      case LogLevel.verbose:
        AppLogger.v(tag, buffer.toString());
      case LogLevel.debug:
        AppLogger.d(tag, buffer.toString());
      case LogLevel.info:
        AppLogger.i(tag, buffer.toString());
      case LogLevel.warning:
        AppLogger.w(tag, buffer.toString());
      case LogLevel.error:
      case LogLevel.fatal:
        AppLogger.e(tag, buffer.toString());
    }
  }
  
  /// Log network request
  static void logNetworkRequest({
    required String method,
    required String url,
    int? statusCode,
    Duration? duration,
    Object? error,
  }) {
    final data = <String, dynamic>{
      'method': method,
      'url': url,
      if (statusCode != null) 'status': statusCode,
    };
    
    final level = error != null 
        ? LogLevel.error
        : (statusCode != null && statusCode >= 400)
            ? LogLevel.warning
            : LogLevel.debug;
    
    log(
      tag: 'HTTP',
      message: '$method $url',
      level: level,
      duration: duration,
      data: data,
      error: error,
    );
  }
  
  /// Log device operation
  static void logDeviceOperation({
    required String deviceId,
    required String operation,
    bool success = true,
    Duration? duration,
    Object? error,
  }) {
    log(
      tag: 'DEVICE',
      message: success ? '$operation succeeded' : '$operation failed',
      level: success ? LogLevel.info : LogLevel.error,
      operation: operation,
      deviceId: deviceId,
      duration: duration,
      error: error,
    );
  }
  
  /// Log user action
  static void logUserAction({
    required String action,
    Map<String, dynamic>? properties,
  }) {
    log(
      tag: 'USER',
      message: 'User $action',
      level: LogLevel.info,
      operation: action,
      data: properties,
    );
  }
}

/// Logging extensions for common patterns
extension LoggingExtensions<T> on Future<T> {
  /// Log the execution of this future
  Future<T> logged(String tag, String operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await this;
      stopwatch.stop();
      AppLogger.d(tag, '$operation completed in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      AppLogger.e(tag, '$operation failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }
}

extension PerformanceExtensions on Stopwatch {
  /// Log elapsed time for this stopwatch
  void logElapsed(String tag, String operation) {
    if (isRunning) stop();
    AppLogger.d(tag, '$operation took ${elapsedMilliseconds}ms');
  }
}