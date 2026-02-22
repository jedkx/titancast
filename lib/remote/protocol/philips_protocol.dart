import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

/// Controls Philips Smart TVs (2011+) via the JointSpace JSON API.
///
/// Protocol details:
///   - Non-Android TVs : http://<ip>:1925/<version>/input/key
///   - Android TVs     : https://<ip>:1926/<version>/input/key
///
/// Auto-detects port (1925/1926) and API version (6/5/1) on connect.
///
/// Key names source:
///   - JointSpace v1 official docs: http://jointspace.sourceforge.net
///   - pylips: github.com/eslavnov/pylips
///   - Home Assistant philips_js integration
class PhilipsProtocol implements TvProtocol {
  final String ip;

  late String _baseUrl;
  late int _apiVersion;
  late http.Client _client;
  bool _connected = false;

  PhilipsProtocol({required this.ip});

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _client = _buildClient();

    // Probe priority: HTTPS 1926 (Android TV 2016+) → HTTP 1925 (older models)
    final candidates = [
      (scheme: 'https', port: 1926),
      (scheme: 'http',  port: 1925),
    ];

    for (final c in candidates) {
      final version = await _probe(c.scheme, c.port);
      if (version != null) {
        _baseUrl    = '${c.scheme}://$ip:${c.port}';
        _apiVersion = version;
        _connected  = true;
        debugPrint('PhilipsProtocol: connected via $_baseUrl (API v$_apiVersion)');
        return;
      }
    }

    throw const TvProtocolException(
      'Philips: TV not reachable on port 1925 or 1926. '
          'Enable JointSpace by entering 5646877223 on your remote while watching TV.',
    );
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) throw const TvProtocolException('Not connected');

    final keyName = _keyMap[command];
    if (keyName == null) {
      debugPrint('PhilipsProtocol: no key mapping for $command');
      return;
    }

    final url  = Uri.parse('$_baseUrl/$_apiVersion/input/key');
    final body = jsonEncode({'key': keyName});

    try {
      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw TvProtocolException(
          'Philips: key "$keyName" returned HTTP ${response.statusCode}',
        );
      }
    } on TvProtocolException {
      rethrow;
    } on Exception catch (e) {
      throw TvProtocolException('Philips: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _client.close();
  }

  // ---------------------------------------------------------------------------

  Future<int?> _probe(String scheme, int port) async {
    for (final version in [6, 5, 1]) {
      try {
        final url      = Uri.parse('$scheme://$ip:$port/$version/system');
        final response = await _client.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) return version;
      } catch (_) {}
    }
    return null;
  }

  /// Returns an HTTP client that ignores self-signed certs (Philips Android TVs).
  /// Falls back to plain http.Client on web (no dart:io).
  http.Client _buildClient() {
    if (kIsWeb) return http.Client();

    // IOClient wraps dart:io HttpClient; imported from package:http/io_client.dart
    final native = HttpClient()..badCertificateCallback = (_, __, ___) => true;
    return IOClient(native);
  }

  static const Map<RemoteCommand, String> _keyMap = {
    RemoteCommand.power:       'Standby',
    RemoteCommand.powerOn:     'Standby',
    RemoteCommand.powerOff:    'Standby',
    RemoteCommand.volumeUp:    'VolumeUp',
    RemoteCommand.volumeDown:  'VolumeDown',
    RemoteCommand.mute:        'Mute',
    RemoteCommand.channelUp:   'ChannelStepUp',
    RemoteCommand.channelDown: 'ChannelStepDown',
    RemoteCommand.up:          'CursorUp',
    RemoteCommand.down:        'CursorDown',
    RemoteCommand.left:        'CursorLeft',
    RemoteCommand.right:       'CursorRight',
    RemoteCommand.ok:          'Confirm',
    RemoteCommand.back:        'Back',
    RemoteCommand.home:        'Home',
    RemoteCommand.menu:        'Options',
    RemoteCommand.play:        'Play',
    RemoteCommand.pause:       'Pause',
    RemoteCommand.stop:        'Stop',
    RemoteCommand.rewind:      'Rewind',
    RemoteCommand.fastForward: 'FastForward',
    RemoteCommand.source:      'Source',
    RemoteCommand.netflix:     'Netflix',
    RemoteCommand.youtube:     'YouTube',
    RemoteCommand.key0:        'Digit0',
    RemoteCommand.key1:        'Digit1',
    RemoteCommand.key2:        'Digit2',
    RemoteCommand.key3:        'Digit3',
    RemoteCommand.key4:        'Digit4',
    RemoteCommand.key5:        'Digit5',
    RemoteCommand.key6:        'Digit6',
    RemoteCommand.key7:        'Digit7',
    RemoteCommand.key8:        'Digit8',
    RemoteCommand.key9:        'Digit9',
  };
}