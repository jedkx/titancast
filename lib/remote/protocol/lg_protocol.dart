import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

/// Controls LG Smart TVs (webOS 2014+) via the SSAP (Second Screen Application Protocol).
///
/// Protocol details:
///   - Endpoint : ws://<ip>:3000
///   - On first connect the TV shows a pairing prompt; accept to get a client-key.
///   - The client-key is persisted per IP to skip re-pairing on reconnect.
///   - Commands map to ssap:// URIs sent as JSON messages.
///
/// References:
///   - https://github.com/hobbyquaker/lgtv2
///   - https://github.com/klattimer/LGWebOSRemote
class LgProtocol implements TvProtocol {
  final String ip;
  final int port;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  int _msgId = 0;

  // Pending request completers keyed by message id.
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  Completer<void>? _connectCompleter;

  // Pairing client key stored in SharedPreferences.
  String? _clientKey;
  static const String _prefKeyPrefix = 'lg_client_key_';

  LgProtocol({required this.ip, this.port = 3000});

  // ---------------------------------------------------------------------------
  // TvProtocol
  // ---------------------------------------------------------------------------

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    // Load persisted client key for this IP (skip re-pairing if already paired).
    final prefs = await SharedPreferences.getInstance();
    _clientKey = prefs.getString('$_prefKeyPrefix$ip');

    final uri = Uri.parse('ws://$ip:$port');
    _connectCompleter = Completer<void>();
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (Object e) {
        _connected = false;
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.completeError(TvProtocolException('$e'));
        }
      },
      onDone: () => _connected = false,
    );

    // Send the registration handshake immediately after socket opens.
    _sendRegister();

    await _connectCompleter!.future.timeout(
      const Duration(seconds: 60), // user may need time to approve on TV
      onTimeout: () => throw TvProtocolException(
        'LG: pairing timed out. Accept the connection prompt on your TV.',
      ),
    );
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) throw TvProtocolException('Not connected');

    final uri = _commandMap[command];
    if (uri == null) {
      debugPrint('LgProtocol: no SSAP URI for $command');
      return;
    }

    final payload = uri['payload'] as Map<String, dynamic>?;
    await _request(uri['uri'] as String, payload: payload);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(TvProtocolException('Disconnected'));
      }
    }
    _pending.clear();
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Sends the SSAP register message (handshake).
  void _sendRegister() {
    final msg = <String, dynamic>{
      'type': 'register',
      'id': 'register_0',
      'payload': {
        'forcePairing': false,
        'pairingType': 'PROMPT',
        if (_clientKey != null) 'client-key': _clientKey,
        'manifest': {
          'manifestVersion': 1,
          'appVersion': '1.1',
          'signed': {
            'created': '20140509',
            'appId': 'com.lge.test',
            'vendorId': 'com.lge',
            'localizedAppNames': {'': 'TitanCast'},
            'localizedVendorNames': {'': 'TitanCast'},
            'permissions': [
              'TEST_SECURE',
              'CONTROL_INPUT_JOYSTICK',
              'CONTROL_MOUSE_AND_KEYBOARD',
              'READ_INSTALLED_APPS',
              'READ_LGE_SDX',
              'READ_NOTIFICATIONS',
              'SEARCH',
              'WRITE_SETTINGS',
              'WRITE_NOTIFICATION_ALERT',
              'CONTROL_POWER',
              'READ_CURRENT_CHANNEL',
              'READ_RUNNING_APPS',
              'READ_UPDATE_INFO',
              'UPDATE_FROM_REMOTE_APP',
              'READ_LGE_TV_INPUT_EVENTS',
              'READ_TV_CURRENT_TIME',
            ],
            'serial': '2f930e2d2cfe083771f68e4fe7bb07',
          },
          'permissions': [
            'LAUNCH',
            'LAUNCH_WEBAPP',
            'APP_TO_APP',
            'CLOSE',
            'TEST_OPEN',
            'TEST_PROTECTED',
            'CONTROL_AUDIO',
            'CONTROL_DISPLAY',
            'CONTROL_INPUT_JOYSTICK',
            'CONTROL_MOUSE_AND_KEYBOARD',
            'CONTROL_POWER',
            'READ_INSTALLED_APPS',
            'READ_LGE_SDX',
            'READ_NOTIFICATIONS',
            'SEARCH',
            'WRITE_SETTINGS',
            'WRITE_NOTIFICATION_ALERT',
            'READ_CURRENT_CHANNEL',
            'READ_RUNNING_APPS',
            'READ_UPDATE_INFO',
            'UPDATE_FROM_REMOTE_APP',
            'READ_LGE_TV_INPUT_EVENTS',
            'READ_TV_CURRENT_TIME',
          ],
          'signatures': [
            {
              'signatureVersion': 1,
              'signature':
              'eyJhbGdvcml0aG0iOiJSU0EtU0hBMjU2Iiwia2V5SWQiOiJ0ZXN0LXNpZ25pbmctY2VydCIsInNpZ25hdHVyZVZlcnNpb24iOjF9.hrVRgjCW_IhuL5jR8EgxOWhmlW4qQCgRXdKAp4sCOEqFBqSHFLMl4dRb8sHtJLdOoHzXYovASEYXeqMkxH5kS68FDEgSPFqNbJJMXEV3r3OOzTJSgXovg4gA-k7e3sUnhlx8Z1I3tfyoN5sG5BG3vDW4f-G8q0d8CHQVFE_A==',
            }
          ],
        },
      },
    };
    _channel!.sink.add(jsonEncode(msg));
  }

  /// Sends an SSAP request and returns the TV's response payload.
  Future<Map<String, dynamic>> _request(
      String uri, {
        Map<String, dynamic>? payload,
      }) {
    final id = '${++_msgId}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    final msg = <String, dynamic>{
      'type': 'request',
      'id': id,
      'uri': uri,
      if (payload != null) 'payload': payload,
    };
    _channel!.sink.add(jsonEncode(msg));

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pending.remove(id);
        throw TvProtocolException('LG: request $uri timed out');
      },
    );
  }

  void _onMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type    = map['type'] as String?;
      final id      = map['id'] as String?;
      final payload = map['payload'] as Map<String, dynamic>? ?? {};

      if (type == 'registered') {
        // Pairing accepted — save the client key for future sessions.
        final key = payload['client-key'] as String?;
        if (key != null && key.isNotEmpty) {
          _clientKey = key;
          SharedPreferences.getInstance().then(
                (p) => p.setString('$_prefKeyPrefix$ip', key),
          );
        }
        _connected = true;
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.complete();
        }
        return;
      }

      if (type == 'response' && id != null) {
        final completer = _pending.remove(id);
        completer?.complete(payload);
      }

      if (type == 'error' && id != null) {
        final completer = _pending.remove(id);
        final errMsg = payload['message'] as String? ?? 'Unknown error';
        completer?.completeError(TvProtocolException('LG error: $errMsg'));
      }
    } catch (e) {
      debugPrint('LgProtocol: parse error — $e');
    }
  }

  // LG SSAP URI map.
  // Source: https://github.com/hobbyquaker/lgtv2 + openHAB lgwebos binding.
  // Navigation (up/down/left/right/ok/back) use the input socket API.
  // ssap://com.webos.service.networkinput/getPointerInputSocket opens a
  // secondary WebSocket for cursor events — used here via button URI workaround.
  static const Map<RemoteCommand, Map<String, dynamic>> _commandMap = {
    RemoteCommand.power:       {'uri': 'ssap://system/turnOff'},
    RemoteCommand.powerOff:    {'uri': 'ssap://system/turnOff'},
    RemoteCommand.volumeUp:    {'uri': 'ssap://audio/volumeUp'},
    RemoteCommand.volumeDown:  {'uri': 'ssap://audio/volumeDown'},
    RemoteCommand.mute:        {'uri': 'ssap://audio/setMute', 'payload': {'mute': true}},
    RemoteCommand.channelUp:   {'uri': 'ssap://tv/channelUp'},
    RemoteCommand.channelDown: {'uri': 'ssap://tv/channelDown'},
    RemoteCommand.play:        {'uri': 'ssap://media.controls/play'},
    RemoteCommand.pause:       {'uri': 'ssap://media.controls/pause'},
    RemoteCommand.stop:        {'uri': 'ssap://media.controls/stop'},
    RemoteCommand.rewind:      {'uri': 'ssap://media.controls/rewind'},
    RemoteCommand.fastForward: {'uri': 'ssap://media.controls/fastForward'},
    RemoteCommand.source:      {'uri': 'ssap://tv/getExternalInputList'},

    // Navigation — ssap://com.webos.service.ime/sendKeyboardEvent with keyCode
    // Confirmed keyCodes from Home Assistant webostv integration source.
    RemoteCommand.up:    {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 38}},
    RemoteCommand.down:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 40}},
    RemoteCommand.left:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 37}},
    RemoteCommand.right: {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 39}},
    RemoteCommand.ok:    {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 13}},
    RemoteCommand.back:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 461}},
    RemoteCommand.menu:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 1003}},

    // App launchers
    RemoteCommand.home:    {'uri': 'ssap://system.launcher/launch', 'payload': {'id': 'com.webos.app.home'}},
    RemoteCommand.netflix: {'uri': 'ssap://system.launcher/launch', 'payload': {'id': 'netflix'}},
    RemoteCommand.youtube: {'uri': 'ssap://system.launcher/launch', 'payload': {'id': 'youtube.leanback.v4'}},
  };
}