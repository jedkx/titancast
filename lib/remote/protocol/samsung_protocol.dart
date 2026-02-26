import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

const _tag = 'SamsungProtocol';

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

  Completer<void>? _connectCompleter;

  SamsungProtocol({
    required this.ip,
    this.port = 8001,
    this.appName = 'TitanCast',
  });

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // TvProtocol
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect() async {
    AppLogger.i(_tag, '── connect() start ─────────────────────────────');
    AppLogger.d(_tag, 'ip=$ip port=$port appName="$appName"');

    if (_channel != null) {
      AppLogger.d(_tag, 'cleaning up previous connection before reconnect');
      await _sub?.cancel();
      await _channel?.sink.close();
      _channel = null;
      _connected = false;
    }

    final nameB64 = base64.encode(utf8.encode(appName));
    final uri = Uri.parse(
      'ws://$ip:$port/api/v2/channels/samsung.remote.control?name=$nameB64',
    );
    AppLogger.d(_tag, 'opening WebSocket → $uri');

    _connectCompleter = Completer<void>();
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (Object e) {
        _connected = false;
        AppLogger.e(_tag, 'WebSocket stream error: $e');
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.completeError(TvProtocolException('$e'));
        }
      },
      onDone: () {
        _connected = false;
        AppLogger.w(_tag, 'WebSocket stream closed (onDone)');
      },
    );

    AppLogger.d(_tag, 'waiting for ms.channel.connect event (timeout=10s)');
    final sw = Stopwatch()..start();
    await _connectCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        AppLogger.e(_tag, 'connect timeout (10s) — TV did not send ms.channel.connect');
        throw TvProtocolException(
          'Samsung: connection timed out. Accept the pairing request on your TV.',
        );
      },
    );
    sw.stop();
    AppLogger.i(_tag, 'connect() complete in ${sw.elapsedMilliseconds}ms');
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) {
      AppLogger.w(_tag, 'sendCommand($command) called while disconnected');
      throw TvProtocolException('Not connected');
    }

    final keyName = _keyMap[command];
    if (keyName == null) {
      AppLogger.w(_tag, 'sendCommand: no Samsung key mapped for $command — dropped');
      return;
    }

    AppLogger.d(_tag, '→ sendCommand($command) → key=$keyName');

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
    AppLogger.v(_tag, 'TX: ms.remote.control Cmd=Click DataOfCmd=$keyName');
  }

  @override
  Future<void> sendText(String text) async {
    // Samsung Tizen WS API does not expose a direct text-input endpoint.
    // Text entry requires Tizen REST API (port 8002) which is outside the
    // scope of the current WS-only driver. Silently drop the call.
    AppLogger.w(_tag, 'sendText: not supported by Samsung WS protocol — dropped');
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i(_tag, 'disconnect(): closing WebSocket');
    _connected = false;
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    AppLogger.i(_tag, 'disconnect(): done');
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = map['event'] as String?;
      final data  = map['data'];
      AppLogger.v(_tag, 'RX event=$event data=${_truncate(data.toString(), 100)}');

      switch (event) {
        case 'ms.channel.connect':
          _connected = true;
          AppLogger.i(_tag, 'ms.channel.connect received — connected=true');
          if (_connectCompleter?.isCompleted == false) {
            _connectCompleter!.complete();
          }

        case 'ms.channel.clientConnect':
          AppLogger.d(_tag, 'ms.channel.clientConnect — another client joined session');

        case 'ms.channel.clientDisconnect':
          AppLogger.d(_tag, 'ms.channel.clientDisconnect — a client left session');

        case 'ms.error':
          final errMsg = (data is Map ? data['message'] : data)?.toString() ?? 'unknown';
          AppLogger.e(_tag, 'ms.error from TV: $errMsg');

        default:
          AppLogger.v(_tag, 'RX unhandled event=$event');
      }
    } catch (e, st) {
      AppLogger.e(_tag, 'parse error: $e\n$st');
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

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
