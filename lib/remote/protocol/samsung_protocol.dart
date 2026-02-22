import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

/// Controls Samsung Smart TVs (Tizen, 2016+) via the Samsung Remote WebSocket API.
///
/// Protocol details:
///   - Endpoint : ws://<ip>:8001/api/v2/channels/samsung.remote.control
///   - The TV shows a pairing prompt on first connect; user must "Allow".
///   - Commands use method="ms.remote.control" with DataOfCmd = Samsung key name.
///
/// Key reference: https://github.com/xchwarze/samsung-tv-ws-api
class SamsungProtocol implements TvProtocol {
  final String ip;
  final int port;
  final String appName;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;

  // Completer used to await the ms.channel.connect event from the TV.
  Completer<void>? _connectCompleter;

  SamsungProtocol({
    required this.ip,
    this.port = 8001,
    this.appName = 'TitanCast',
  });

  // ---------------------------------------------------------------------------
  // TvProtocol
  // ---------------------------------------------------------------------------

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    // Clean up any previous connection before reconnecting.
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _connected = false;

    // App name must be base64-encoded in the WebSocket URL query param.
    final nameB64 = base64.encode(utf8.encode(appName));
    final uri = Uri.parse(
      'ws://$ip:$port/api/v2/channels/samsung.remote.control?name=$nameB64',
    );

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

    // Wait until the TV sends ms.channel.connect (≈ 3 s timeout).
    await _connectCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
      throw TvProtocolException('Samsung: connection timed out. '
          'Accept the pairing request on your TV.'),
    );
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) throw TvProtocolException('Not connected');

    final keyName = _keyMap[command];
    if (keyName == null) {
      debugPrint('SamsungProtocol: no key mapping for $command');
      return;
    }

    final payload = jsonEncode({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': 'Click',
        'DataOfCmd': keyName,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });

    _channel!.sink.add(payload);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = map['event'] as String?;

      if (event == 'ms.channel.connect') {
        _connected = true;
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.complete();
        }
      }
    } catch (_) {}
  }

  // Samsung key name reference (confirmed from samsungtvws / openHAB binding).
  static const Map<RemoteCommand, String> _keyMap = {
    RemoteCommand.power:       'KEY_POWER',
    RemoteCommand.powerOn:     'KEY_POWERON',
    RemoteCommand.powerOff:    'KEY_POWEROFF',
    RemoteCommand.volumeUp:    'KEY_VOLUP',
    RemoteCommand.volumeDown:  'KEY_VOLDOWN',
    RemoteCommand.mute:        'KEY_MUTE',
    RemoteCommand.channelUp:   'KEY_CHUP',
    RemoteCommand.channelDown: 'KEY_CHDOWN',
    RemoteCommand.up:          'KEY_UP',
    RemoteCommand.down:        'KEY_DOWN',
    RemoteCommand.left:        'KEY_LEFT',
    RemoteCommand.right:       'KEY_RIGHT',
    RemoteCommand.ok:          'KEY_ENTER',
    RemoteCommand.back:        'KEY_RETURN',
    RemoteCommand.home:        'KEY_HOME',
    RemoteCommand.menu:        'KEY_MENU',
    RemoteCommand.play:        'KEY_PLAY',
    RemoteCommand.pause:       'KEY_PAUSE',
    RemoteCommand.stop:        'KEY_STOP',
    RemoteCommand.rewind:      'KEY_REWIND',
    RemoteCommand.fastForward: 'KEY_FF',
    RemoteCommand.source:      'KEY_SOURCE',
    RemoteCommand.netflix:     'KEY_NETFLIX',
    RemoteCommand.youtube:     'KEY_YOUTUBE',
    RemoteCommand.key0:        'KEY_0',
    RemoteCommand.key1:        'KEY_1',
    RemoteCommand.key2:        'KEY_2',
    RemoteCommand.key3:        'KEY_3',
    RemoteCommand.key4:        'KEY_4',
    RemoteCommand.key5:        'KEY_5',
    RemoteCommand.key6:        'KEY_6',
    RemoteCommand.key7:        'KEY_7',
    RemoteCommand.key8:        'KEY_8',
    RemoteCommand.key9:        'KEY_9',
  };
}