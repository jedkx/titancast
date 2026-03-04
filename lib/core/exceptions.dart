/// Custom exceptions for TitanCast application
/// Better error categorization for improved debugging and user experience

/// Base exception class for all TitanCast specific exceptions
abstract class TitanCastException implements Exception {
  const TitanCastException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Network-related exceptions
class NetworkException extends TitanCastException {
  const NetworkException(super.message);
}

/// Device discovery related exceptions  
class DiscoveryException extends TitanCastException {
  const DiscoveryException(super.message);
}

/// Authentication/authorization exceptions
class AuthenticationException extends TitanCastException {
  const AuthenticationException(super.message);
}

/// Device connection exceptions
class ConnectionException extends TitanCastException {
  const ConnectionException(super.message);
}

/// Protocol-specific exceptions
class ProtocolException extends TitanCastException {
  const ProtocolException(super.message);
}

/// Configuration/settings exceptions
class ConfigurationException extends TitanCastException {
  const ConfigurationException(super.message);
}

/// Timeout exceptions
class TimeoutException extends TitanCastException {
  const TimeoutException(super.message);
}