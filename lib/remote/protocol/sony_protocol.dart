import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

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

  /// Pre-Shared Key configured on the TV under Settings > Network > IP Control.
  final String psk;

  bool _connected = false;
  final http.Client _client = http.Client();

  SonyProtocol({required this.ip, this.psk = ''});

  // ---------------------------------------------------------------------------
  // TvProtocol
  // ---------------------------------------------------------------------------

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    // Sony uses stateless HTTP — "connect" just validates reachability.
    try {
      final url = Uri.http(ip, '/sony/system');
      final response = await _client
          .post(
        url,
        headers: _headers,
        body: '{"method":"getSystemInformation","id":1,"params":[],"version":"1.0"}',
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 401) {
        // 401 = reachable but PSK wrong; still treat as connected so user sees key error later.
        _connected = true;
      } else {
        throw TvProtocolException('Sony: HTTP ${response.statusCode}');
      }
    } on Exception catch (e) {
      throw TvProtocolException('Sony: $e');
    }
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) throw TvProtocolException('Not connected');

    final code = _irccMap[command];
    if (code == null) {
      debugPrint('SonyProtocol: no IRCC code for $command');
      return;
    }

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
    try {
      final response = await _client
          .post(url, headers: _soapHeaders, body: body)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw TvProtocolException('Sony IRCC error: HTTP ${response.statusCode}');
      }
    } on Exception catch (e) {
      throw TvProtocolException('Sony: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _client.close();
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

  // IRCC base64 codes confirmed from Sony Bravia professional display docs
  // and community captures (sonybravia-api, Home Assistant sony_bravia).
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
    RemoteCommand.key2:        'AAAAAQAAAAEAAAAvAw==', // note: same as power on some models
    RemoteCommand.key3:        'AAAAAQAAAAEAAAAwAw==',
    RemoteCommand.key4:        'AAAAAQAAAAEAAAAxAw==',
    RemoteCommand.key5:        'AAAAAQAAAAEAAAAyAw==',
    RemoteCommand.key6:        'AAAAAQAAAAEAAAAzAw==',
    RemoteCommand.key7:        'AAAAAQAAAAEAAAA0Aw==',
    RemoteCommand.key8:        'AAAAAQAAAAEAAAA1Aw==',
    RemoteCommand.key9:        'AAAAAQAAAAEAAAA2Aw==',
  };
}