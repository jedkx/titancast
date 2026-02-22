import 'package:flutter/foundation.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/brand_detector.dart';
import 'package:titancast/remote/protocol/lg_protocol.dart';
import 'package:titancast/remote/protocol/philips_protocol.dart';
import 'package:titancast/remote/protocol/samsung_protocol.dart';
import 'package:titancast/remote/protocol/sony_protocol.dart';
import 'package:titancast/remote/protocol/torima_protocol.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';
import 'package:titancast/remote/protocol/unknown_protocol.dart';
import 'package:titancast/remote/remote_command.dart';

/// Connection states for the UI to react to.
enum RemoteConnectionState { disconnected, connecting, connected, error }

/// Facade that owns the active [TvProtocol] and exposes a simple API to the UI.
///
/// Usage:
///   final ctrl = RemoteController(device);
///   await ctrl.connect();
///   await ctrl.send(RemoteCommand.volumeUp);
///   await ctrl.disconnect();
class RemoteController extends ChangeNotifier {
  final DiscoveredDevice device;

  TvProtocol? _protocol;
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  String? _errorMessage;

  RemoteController(this.device);

  RemoteConnectionState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _state == RemoteConnectionState.connected;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (_state == RemoteConnectionState.connecting) return;

    _setState(RemoteConnectionState.connecting);

    _protocol = _buildProtocol(device);

    try {
      await _protocol!.connect();
      _setState(RemoteConnectionState.connected);
    } on TvProtocolException catch (e) {
      _errorMessage = e.message;
      _setState(RemoteConnectionState.error);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(RemoteConnectionState.error);
    }
  }

  Future<void> send(RemoteCommand command) async {
    if (_protocol == null || !isConnected) {
      debugPrint('RemoteController: send called while not connected');
      return;
    }
    try {
      await _protocol!.sendCommand(command);
    } on TvProtocolException catch (e) {
      _errorMessage = e.message;
      _setState(RemoteConnectionState.error);
    }
  }

  Future<void> disconnect() async {
    await _protocol?.disconnect();
    _protocol = null;
    _setState(RemoteConnectionState.disconnected);
  }

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  static TvProtocol _buildProtocol(DiscoveredDevice device) {
    switch (device.detectedBrand) {
      case TvBrand.samsung:
        return SamsungProtocol(ip: device.ip, port: device.port ?? 8001);
      case TvBrand.lg:
        return LgProtocol(ip: device.ip);
      case TvBrand.sony:
      // Sony PSK is not stored in DiscoveredDevice yet; user flow TBD.
        return SonyProtocol(ip: device.ip, psk: '');
      case TvBrand.philips:
      // Port and API version are auto-detected during connect().
        return PhilipsProtocol(ip: device.ip);
      case TvBrand.torima:
      // Android-based projector; controlled via ADB over WiFi (port 5555).
        return TorimaProtocol(ip: device.ip);
      default:
        return const UnknownProtocol();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _setState(RemoteConnectionState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    // Disconnect without awaiting — protocol handles its own cleanup.
    _protocol?.disconnect().ignore();
    super.dispose();
  }
}