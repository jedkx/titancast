import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

const _tag = 'LgProtocol';

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

  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  Completer<void>? _connectCompleter;
  String? _clientKey;

  static const String _prefKeyPrefix = 'lg_client_key_';

  Completer<void>? _socketOpenCompleter;

  LgProtocol({required this.ip, this.port = 3000});

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // TvProtocol
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect() async {
    AppLogger.i(_tag, '── connect() start ─────────────────────────────');
    AppLogger.d(_tag, 'loading persisted client-key for $ip');
    final prefs = await SharedPreferences.getInstance();
    _clientKey = prefs.getString('$_prefKeyPrefix$ip');
    AppLogger.d(_tag, 'clientKey: ${_clientKey != null ? "found (cached, skip re-pair)" : "not found (first-time pairing)"}');

    final uri = Uri.parse('ws://$ip:$port');
    AppLogger.d(_tag, 'opening WebSocket → $uri');

    _connectCompleter  = Completer<void>();
    _socketOpenCompleter = Completer<void>();
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (Object e) {
        _connected = false;
        AppLogger.e(_tag, 'WebSocket stream error: $e');
        final err = TvProtocolException(
          'LG: Connection error. Make sure the TV is on and on the same network. ($e)',
        );
        if (_socketOpenCompleter?.isCompleted == false) {
          _socketOpenCompleter!.completeError(err);
        }
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.completeError(err);
        }
      },
      onDone: () {
        _connected = false;
        AppLogger.w(_tag, 'WebSocket stream closed (onDone)');
        if (_socketOpenCompleter?.isCompleted == false) {
          _socketOpenCompleter!.completeError(
              const TvProtocolException('LG: Connection closed unexpectedly.'));
        }
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.completeError(
              const TvProtocolException('LG: Connection closed unexpectedly.'));
        }
      },
    );

    AppLogger.d(_tag, 'sending SSAP register handshake (clientKey=${_clientKey != null})');
    _sendRegister();

    // ── Phase 1: wait for first WS message (TCP confirmed) ──
    AppLogger.d(_tag, 'phase 1: waiting for first WebSocket message (timeout=4s)');
    final sw = Stopwatch()..start();
    await _socketOpenCompleter!.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        AppLogger.e(_tag, 'phase 1 timeout (4s) — TV in standby or not responding');
        throw const TvProtocolException(
          'LG: TV is in standby or not responding. '
          'Power cycle the TV and try again.',
        );
      },
    );
    AppLogger.d(_tag, 'phase 1 done: first message received in ${sw.elapsedMilliseconds}ms');

    // ── Phase 2: wait for registered event ──
    final pairingTimeout = _clientKey != null
        ? const Duration(seconds: 8)
        : const Duration(seconds: 60);
    AppLogger.d(_tag, 'phase 2: waiting for "registered" event '
        '(mode=${_clientKey != null ? "cached-key" : "user-prompt"}, '
        'timeout=${pairingTimeout.inSeconds}s)');

    await _connectCompleter!.future.timeout(
      pairingTimeout,
      onTimeout: () {
        AppLogger.e(_tag, 'phase 2 timeout (${pairingTimeout.inSeconds}s) — '
            '${_clientKey != null ? "TV not responding" : "user did not approve"}');
        throw TvProtocolException(
          _clientKey != null
              ? 'LG: TV not responding. Restart the TV and try again.'
              : 'LG: Pairing timeout. Press "Allow" on the TV screen.',
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

    final entry = _commandMap[command];
    if (entry == null) {
      AppLogger.w(_tag, 'sendCommand: no SSAP URI mapped for $command — dropped');
      return;
    }

    final ssapUri = entry['uri'] as String;
    final payload = entry['payload'] as Map<String, dynamic>?;
    AppLogger.d(_tag, '→ sendCommand($command): ssap=$ssapUri payload=$payload');

    final sw = Stopwatch()..start();
    await _request(ssapUri, payload: payload);
    sw.stop();
    AppLogger.v(_tag, '← sendCommand($command) OK in ${sw.elapsedMilliseconds}ms');
  }

  @override
  Future<void> sendText(String text) async {
    if (!_connected) return;
    // LG webOS IME: insertText replaces the current input field content.
    // Source: https://github.com/hobbyquaker/lgtv2 (com.webos.service.ime)
    AppLogger.d(_tag, 'sendText: "${text.length > 40 ? text.substring(0, 40) : text}"');
    try {
      await _request('ssap://com.webos.service.ime/insertText',
          payload: {'text': text, 'replace': 0});
    } catch (e) {
      AppLogger.w(_tag, 'sendText failed: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i(_tag, 'disconnect(): pending=${_pending.length} requests will be cancelled');
    _connected = false;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(TvProtocolException('Disconnected'));
    }
    _pending.clear();
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    AppLogger.i(_tag, 'disconnect(): WebSocket closed');
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

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
              'TEST_SECURE', 'CONTROL_INPUT_JOYSTICK',
              'CONTROL_MOUSE_AND_KEYBOARD', 'READ_INSTALLED_APPS',
              'READ_LGE_SDX', 'READ_NOTIFICATIONS', 'SEARCH',
              'WRITE_SETTINGS', 'WRITE_NOTIFICATION_ALERT', 'CONTROL_POWER',
              'READ_CURRENT_CHANNEL', 'READ_RUNNING_APPS', 'READ_UPDATE_INFO',
              'UPDATE_FROM_REMOTE_APP', 'READ_LGE_TV_INPUT_EVENTS',
              'READ_TV_CURRENT_TIME',
            ],
            'serial': '2f930e2d2cfe083771f68e4fe7bb07',
          },
          'permissions': [
            'LAUNCH', 'LAUNCH_WEBAPP', 'APP_TO_APP', 'CLOSE', 'TEST_OPEN',
            'TEST_PROTECTED', 'CONTROL_AUDIO', 'CONTROL_DISPLAY',
            'CONTROL_INPUT_JOYSTICK', 'CONTROL_MOUSE_AND_KEYBOARD',
            'CONTROL_POWER', 'READ_INSTALLED_APPS', 'READ_LGE_SDX',
            'READ_NOTIFICATIONS', 'SEARCH', 'WRITE_SETTINGS',
            'WRITE_NOTIFICATION_ALERT', 'READ_CURRENT_CHANNEL',
            'READ_RUNNING_APPS', 'READ_UPDATE_INFO', 'UPDATE_FROM_REMOTE_APP',
            'READ_LGE_TV_INPUT_EVENTS', 'READ_TV_CURRENT_TIME',
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
    AppLogger.v(_tag, 'TX register → ws://$ip:$port (id=register_0)');
    _channel!.sink.add(jsonEncode(msg));
  }

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
    AppLogger.v(_tag, 'TX request id=$id uri=$uri payload=$payload '
        '(pending=${_pending.length})');
    _channel!.sink.add(jsonEncode(msg));

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pending.remove(id);
        AppLogger.e(_tag, 'request id=$id uri=$uri timed out (5s)');
        throw TvProtocolException('LG: request $uri timed out');
      },
    );
  }

  void _onMessage(dynamic raw) {
    if (_socketOpenCompleter?.isCompleted == false) {
      AppLogger.d(_tag, 'RX: first message received — WebSocket confirmed open');
      _socketOpenCompleter!.complete();
    }

    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type    = map['type'] as String?;
      final id      = map['id'] as String?;
      final payload = map['payload'] as Map<String, dynamic>? ?? {};

      AppLogger.v(_tag, 'RX type=$type id=$id '
          'payload=${_truncate(payload.toString(), 120)}');

      if (type == 'registered') {
        final key = payload['client-key'] as String?;
        if (key != null && key.isNotEmpty) {
          final isNew = _clientKey != key;
          _clientKey = key;
          if (isNew) {
            AppLogger.i(_tag, 'received new client-key — persisting to SharedPreferences');
          } else {
            AppLogger.d(_tag, 'received same client-key as cached — no update needed');
          }
          SharedPreferences.getInstance().then(
            (p) => p.setString('$_prefKeyPrefix$ip', key),
          );
        } else {
          AppLogger.w(_tag, 'registered event had no client-key in payload');
        }
        _connected = true;
        AppLogger.i(_tag, 'registered: _connected=true, clientKey=${_clientKey != null}');
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.complete();
        }
        return;
      }

      if (type == 'response' && id != null) {
        final completer = _pending.remove(id);
        if (completer != null) {
          AppLogger.v(_tag, 'RX response id=$id → resolving pending request');
          completer.complete(payload);
        } else {
          AppLogger.w(_tag, 'RX response id=$id but no pending completer found');
        }
        return;
      }

      if (type == 'error' && id != null) {
        final completer = _pending.remove(id);
        final errMsg = payload['message'] as String? ?? 'Unknown error';
        AppLogger.w(_tag, 'RX error id=$id message="$errMsg"');
        completer?.completeError(TvProtocolException('LG error: $errMsg'));
        return;
      }

      if (type == 'hello') {
        AppLogger.d(_tag, 'RX hello from TV (connection acknowledged)');
        return;
      }

      AppLogger.v(_tag, 'RX unhandled type=$type id=$id');
    } catch (e, st) {
      AppLogger.e(_tag, 'parse error: $e\n$st');
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

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
    RemoteCommand.up:    {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 38}},
    RemoteCommand.down:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 40}},
    RemoteCommand.left:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 37}},
    RemoteCommand.right: {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 39}},
    RemoteCommand.ok:    {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 13}},
    RemoteCommand.back:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 461}},
    RemoteCommand.menu:  {'uri': 'ssap://com.webos.service.ime/sendKeyboardEvent', 'payload': {'keyCode': 1003}},
    RemoteCommand.home:    {'uri': 'ssap://system.launcher/launch', 'payload': {'id': 'com.webos.app.home'}},
    RemoteCommand.netflix: {'uri': 'ssap://system.launcher/launch', 'payload': {'id': 'netflix'}},
    RemoteCommand.youtube: {'uri': 'ssap://system.launcher/launch', 'payload': {'id': 'youtube.leanback.v4'}},
  };
}
