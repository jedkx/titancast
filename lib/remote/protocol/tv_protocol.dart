import 'package:titancast/remote/remote_command.dart';

/// Base class for all brand-specific TV control protocols.
/// Each subclass handles connection lifecycle and command translation.
abstract class TvProtocol {
  /// Establishes the connection to the TV.
  /// May show a pairing prompt on the TV (Samsung / LG behaviour).
  Future<void> connect();

  /// Sends a single [command] to the TV.
  /// Throws [TvProtocolException] on failure.
  Future<void> sendCommand(RemoteCommand command);

  /// Sends [text] to the TV as keyboard input.
  /// Default implementation is a no-op for protocols that do not support text entry.
  Future<void> sendText(String text) async {}

  /// Releases all resources (sockets, timers).
  Future<void> disconnect();

  /// Whether the protocol currently has an active connection.
  bool get isConnected;
}

class TvProtocolException implements Exception {
  final String message;
  const TvProtocolException(this.message);

  @override
  String toString() => 'TvProtocolException: $message';
}