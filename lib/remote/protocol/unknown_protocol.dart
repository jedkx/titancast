import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

/// Stub protocol used when no brand-specific driver is available.
/// All commands are silently dropped with a debug message.
class UnknownProtocol implements TvProtocol {
  const UnknownProtocol();

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {
    throw const TvProtocolException(
      'This device brand is not yet supported. '
          'Samsung, LG, and Sony are currently available.',
    );
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {}

  @override
  Future<void> disconnect() async {}
}