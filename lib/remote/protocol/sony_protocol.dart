import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

const _tag = 'SonyProtocol';

/// Controls Sony Bravia TVs (2013+) via the IRCC-IP over HTTP protocol.
///
/// Protocol details:
///   - Endpoint : POST http://<ip>/sony/IRCC
///   - Auth     : X-Auth-PSK header (set by user in TV Settings > IP Control)
///   - Payload  : SOAP envelope with base64-encoded IRCC command code
///
/// References:
///   - https://pro-bravia.sony.net/develop/integrate/ircc-ip/
///   - https://gist.github.com/kalleth/e10e8f3b8b7cb1bac21463b0073a65fb
class SonyProtocol implements TvProtocol {
  final String ip;
  final String psk;

  bool _connected = false;
  final http.Client _client = http.Client();

  SonyProtocol({required this.ip, this.psk = ''});

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // TvProtocol
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect() async {
    AppLogger.i(_tag, '── connect() start ─────────────────────────────');
    AppLogger.d(_tag, 'ip=$ip psk=${psk.isNotEmpty ? "set (${psk.length} chars)" : "not set"}');

    final url = Uri.http(ip, '/sony/system');
    AppLogger.d(_tag, 'verifying device reachability: POST $url');
    AppLogger.d(_tag, 'method=getSystemInformation headers=${_headers.keys.join(", ")}');

    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .post(
            url,
            headers: _headers,
            body: '{"method":"getSystemInformation","id":1,"params":[],"version":"1.0"}',
          )
          .timeout(const Duration(seconds: 5));
      sw.stop();

      AppLogger.d(_tag, 'response: HTTP ${response.statusCode} in ${sw.elapsedMilliseconds}ms '
          'body="${_truncate(response.body, 120)}"');

      if (response.statusCode == 401) {
        _connected = true;
        AppLogger.w(_tag, 'HTTP 401 — PSK is wrong or not set, but device is reachable. '
            'connected=true (commands will likely fail until PSK is configured)');
        return;
      }

      if (response.statusCode == 200) {
        final body = response.body;
        final hasSonySignature = body.contains('"result"') ||
            body.contains('"product"') ||
            body.contains('"model"');
        AppLogger.d(_tag, 'verifying Sony signature in response: '
            'hasSonySignature=$hasSonySignature');

        if (!hasSonySignature) {
          AppLogger.e(_tag, 'response does not look like a Sony Bravia — '
              'missing "result"/"product"/"model" fields');
          throw const TvProtocolException(
            'Sony: Bu cihaz Sony Bravia degil — beklenen JSON yaniti alinamadi.',
          );
        }
        _connected = true;
        AppLogger.i(_tag, 'connected to Sony Bravia at $ip in ${sw.elapsedMilliseconds}ms');
        return;
      }

      AppLogger.e(_tag, 'unexpected HTTP ${response.statusCode} from $ip');
      throw TvProtocolException('Sony: HTTP ${response.statusCode}');
    } on TvProtocolException {
      rethrow;
    } on Exception catch (e) {
      sw.stop();
      AppLogger.e(_tag, 'connect() exception after ${sw.elapsedMilliseconds}ms: $e');
      throw TvProtocolException('Sony: $e');
    }
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) {
      AppLogger.w(_tag, 'sendCommand($command) called while disconnected');
      throw TvProtocolException('Not connected');
    }

    final code = _irccMap[command];
    if (code == null) {
      AppLogger.w(_tag, 'sendCommand: no IRCC code mapped for $command — dropped');
      return;
    }

    AppLogger.d(_tag, '→ sendCommand($command): IRCC code=$code');

    final body = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
      <IRCCCode>$code</IRCCCode>
    </u:X_SendIRCC>
  </s:Body>
</s:Envelope>''';

    final url = Uri.http(ip, '/sony/IRCC');
    AppLogger.v(_tag, 'POST $url (SOAP X_SendIRCC, psk=${psk.isNotEmpty})');

    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .post(url, headers: _soapHeaders, body: body)
          .timeout(const Duration(seconds: 5));
      sw.stop();

      AppLogger.d(_tag, '← sendCommand($command): HTTP ${response.statusCode} '
          'in ${sw.elapsedMilliseconds}ms');

      if (response.statusCode != 200) {
        AppLogger.e(_tag, 'sendCommand($command) failed: HTTP ${response.statusCode} '
            'body="${_truncate(response.body, 80)}"');
        throw TvProtocolException(
            'Sony IRCC error: HTTP ${response.statusCode}');
      }
      AppLogger.v(_tag, '← sendCommand($command) OK');
    } on TvProtocolException {
      rethrow;
    } on Exception catch (e) {
      sw.stop();
      AppLogger.e(_tag, 'sendCommand($command) exception after ${sw.elapsedMilliseconds}ms: $e');
      throw TvProtocolException('Sony: $e');
    }
  }

  @override
  Future<void> sendText(String text) async {
    if (!_connected) return;
    // Sony Bravia text input via REST appControl setTextForm.
    // Source: https://pro-bravia.sony.net/develop/integrate/rest-api/
    AppLogger.d(_tag, 'sendText: "${text.length > 40 ? text.substring(0, 40) : text}"');
    final url = Uri.http(ip, '/sony/appControl');
    final body = '{"method":"setTextForm","id":1,"params":[{"encKey":"","text":"${text.replaceAll('"', '\\"')}"}],"version":"1.0"}';
    try {
      final response = await _client
          .post(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 5));
      AppLogger.d(_tag, 'sendText response: HTTP ${response.statusCode}');
    } catch (e) {
      AppLogger.w(_tag, 'sendText failed: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i(_tag, 'disconnect(): closing HTTP client');
    _connected = false;
    _client.close();
    AppLogger.i(_tag, 'disconnect(): done');
  }

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (psk.isNotEmpty) 'X-Auth-PSK': psk,
  };

  Map<String, String> get _soapHeaders => {
    'Content-Type': 'text/xml; charset=utf-8',
    'SOAPACTION': '"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"',
    if (psk.isNotEmpty) 'X-Auth-PSK': psk,
  };

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  static const Map<RemoteCommand, String> _irccMap = {
    RemoteCommand.power:       'AAAAAQAAAAEAAAAvAw==',
    RemoteCommand.powerOn:     'AAAAAQAAAAEAAAA6Aw==',
    RemoteCommand.powerOff:    'AAAAAQAAAAEAAAAvAw==',
    RemoteCommand.volumeUp:    'AAAAAQAAAAEAAAASAw==',
    RemoteCommand.volumeDown:  'AAAAAQAAAAEAAAATAw==',
    RemoteCommand.mute:        'AAAAAQAAAAEAAAAUAw==',
    RemoteCommand.channelUp:   'AAAAAQAAAAEAAAAQAw==',
    RemoteCommand.channelDown: 'AAAAAQAAAAEAAAARAw==',
    RemoteCommand.up:          'AAAAAQAAAAEAAAB0Aw==',
    RemoteCommand.down:        'AAAAAQAAAAEAAAB1Aw==',
    RemoteCommand.left:        'AAAAAQAAAAEAAAA0Aw==',
    RemoteCommand.right:       'AAAAAQAAAAEAAAAzAw==',
    RemoteCommand.ok:          'AAAAAQAAAAEAAABlAw==',
    RemoteCommand.back:        'AAAAAgAAAJcAAAAjAw==',
    RemoteCommand.home:        'AAAAAQAAAAEAAABgAw==',
    RemoteCommand.menu:        'AAAAAQAAAAEAAAAtAw==',
    RemoteCommand.play:        'AAAAAgAAABoAAAAaAw==',
    RemoteCommand.pause:       'AAAAAgAAABoAAAAZAw==',
    RemoteCommand.stop:        'AAAAAgAAABoAAAAYAw==',
    RemoteCommand.rewind:      'AAAAAgAAABoAAAAbAw==',
    RemoteCommand.fastForward: 'AAAAAgAAABoAAAAcAw==',
    RemoteCommand.source:      'AAAAAQAAAAEAAAAkAw==',
    RemoteCommand.netflix:     'AAAAAgAAABoAAAB8Aw==',
    RemoteCommand.key0:        'AAAAAQAAAAEAAAAJAw==',
    RemoteCommand.key1:        'AAAAAQAAAAEAAAAuAw==',
    RemoteCommand.key2:        'AAAAAQAAAAEAAAAvAw==',
    RemoteCommand.key3:        'AAAAAQAAAAEAAAAwAw==',
    RemoteCommand.key4:        'AAAAAQAAAAEAAAAxAw==',
    RemoteCommand.key5:        'AAAAAQAAAAEAAAAyAw==',
    RemoteCommand.key6:        'AAAAAQAAAAEAAAAzAw==',
    RemoteCommand.key7:        'AAAAAQAAAAEAAAA0Aw==',
    RemoteCommand.key8:        'AAAAAQAAAAEAAAA1Aw==',
    RemoteCommand.key9:        'AAAAAQAAAAEAAAA2Aw==',
  };
}
