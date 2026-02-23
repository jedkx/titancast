import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

const _tag = 'PhilipsProtocol';

/// Controls Philips Smart TVs (2011+) via the JointSpace JSON API.
///
/// Protocol details:
///   Non-Android TVs (2011-2015) : http://<ip>:1925/<ver>/input/key  — no auth
///   Android TVs   (2016+)       : https://<ip>:1926/<ver>/input/key — Digest Auth
///
/// Android TV models ALSO require a one-time pairing (PIN on screen) before
/// Digest Auth credentials are known.  Call [pair] from the UI when the
/// connect throws [PhilipsPairingRequiredException].
class PhilipsProtocol implements TvProtocol {
  final String ip;

  static const String _prefUser  = 'philips_user_';
  static const String _prefPass  = 'philips_pass_';
  static const String _prefDevId = 'philips_devid_';

  late String _baseUrl;
  late int    _apiVersion;
  late http.Client _client;

  String? _username;
  String? _password;
  bool    _needsAndroidAuth = false;
  bool    _connected = false;

  // Keyboard state polling
  Timer? _keyboardPollTimer;
  bool   _keyboardVisible = false;

  /// Fires when the TV reports that its on-screen keyboard became visible.
  /// RemoteScreen listens to this to auto-open the keyboard bottom sheet.
  final void Function()? onKeyboardAppeared;

  PhilipsProtocol({required this.ip, this.onKeyboardAppeared});

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // TvProtocol
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect() async {
    AppLogger.i(_tag, '── connect() start ─────────────────────────────');
    AppLogger.d(_tag, 'ip=$ip, building HTTP client (SSL cert bypass enabled)');
    _client = _buildClient();

    AppLogger.d(_tag, 'loading stored credentials from SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    _username   = prefs.getString('$_prefUser$ip');
    _password   = prefs.getString('$_prefPass$ip');
    AppLogger.d(_tag, 'credentials: user=${_username != null ? '"$_username"' : 'none'} '
        'pass=${_password != null ? "set" : "none"}');

    final candidates = [
      (scheme: 'https', port: 1926),
      (scheme: 'http',  port: 1925),
    ];

    for (final c in candidates) {
      AppLogger.d(_tag, 'probing ${c.scheme}://$ip:${c.port} (API versions: 6, 5, 1)');
      final version = await _probe(c.scheme, c.port);
      if (version != null) {
        _baseUrl          = '${c.scheme}://$ip:${c.port}';
        _apiVersion       = version;
        _needsAndroidAuth = c.port == 1926;

        // Android TV (port 1926) needs Digest Auth for every command.
        // /system returns 200 without auth so probe succeeds, but /input/key
        // will immediately 401. Catch this NOW at connect time, not on first command.
        if (_needsAndroidAuth && (_username == null || _password == null)) {
          AppLogger.w(_tag, 'connect: port 1926 reachable but no credentials stored '
              '→ PhilipsPairingRequired (catch at connect, not on first command)');
          throw const PhilipsPairingRequiredException();
        }

        _connected = true;
        AppLogger.i(_tag, 'connected: baseUrl=$_baseUrl apiVersion=$_apiVersion '
            'digestAuth=$_needsAndroidAuth');
        _startKeyboardPolling();
        return;
      }
      AppLogger.d(_tag, '${c.scheme}://$ip:${c.port} — no usable API version found, trying next');
    }

    AppLogger.d(_tag, 'all probes failed — checking if https:1926 is reachable (needs pairing?)');
    final httpsReachable = await _isReachable('https', 1926);
    AppLogger.d(_tag, 'https:1926 reachable=$httpsReachable');

    if (httpsReachable) {
      AppLogger.w(_tag, 'https:1926 reachable but no credentials → PhilipsPairingRequired');
      throw const PhilipsPairingRequiredException();
    }

    AppLogger.e(_tag, 'TV not found on port 1925 or 1926 — JointSpace may be disabled');
    throw const TvProtocolException(
      'Philips: TV bulunamadı (port 1925/1926). '
      'TV uzaktan kumandasıyla 5646877223 tuşlarına basarak '
      'JointSpace\'i etkinleştirin.',
    );
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) {
      AppLogger.w(_tag, 'sendCommand($command) called while disconnected');
      throw const TvProtocolException('Not connected');
    }

    final keyName = _keyMap[command];
    if (keyName == null) {
      AppLogger.w(_tag, 'sendCommand: no JointSpace key mapped for $command — dropped');
      return;
    }

    final url  = Uri.parse('$_baseUrl/$_apiVersion/input/key');
    final body = jsonEncode({'key': keyName});

    AppLogger.d(_tag, '→ sendCommand($command): key=$keyName url=$url '
        'digestAuth=$_needsAndroidAuth user=$_username');

    final sw = Stopwatch()..start();
    try {
      final response = _needsAndroidAuth
          ? await _postWithDigest(url, body)
          : await _client
              .post(url, headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 5));
      sw.stop();

      AppLogger.d(_tag, '← sendCommand($command): HTTP ${response.statusCode} '
          'in ${sw.elapsedMilliseconds}ms body="${_truncate(response.body, 80)}"');

      if (response.statusCode != 200 && response.statusCode != 204) {
        AppLogger.e(_tag, 'sendCommand($command) failed: HTTP ${response.statusCode} | ${response.body}');
        throw TvProtocolException(
          'Philips: "$keyName" → HTTP ${response.statusCode} | ${response.body}',
        );
      }
    } on TvProtocolException {
      rethrow;
    } on Exception catch (e) {
      sw.stop();
      AppLogger.e(_tag, 'sendCommand($command) exception after ${sw.elapsedMilliseconds}ms: $e');
      throw TvProtocolException('Philips: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i(_tag, 'disconnect(): stopping polling + closing HTTP client');
    _stopKeyboardPolling();
    _connected = false;
    _client.close();
    AppLogger.i(_tag, 'disconnect(): done');
  }

  // ---------------------------------------------------------------------------
  // Keyboard state polling
  // ---------------------------------------------------------------------------

  /// Polls the TV every 2 seconds to detect on-screen keyboard visibility.
  /// When the TV raises a keyboard, [onKeyboardAppeared] fires so RemoteScreen
  /// can open the input bottom sheet automatically.
  void _startKeyboardPolling() {
    _keyboardPollTimer?.cancel();
    _keyboardPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_connected) return;
      try {
        final data  = await _getJson('$_baseUrl/$_apiVersion/input/textentry');
        final state = data['state'] as String?;
        // Philips reports "KEYBOARD_ACTIVE" when its on-screen keyboard is shown.
        final isVisible = state == 'KEYBOARD_ACTIVE' || state == 'ACTIVE';
        if (isVisible && !_keyboardVisible) {
          _keyboardVisible = true;
          AppLogger.i(_tag, 'keyboard appeared on TV screen');
          onKeyboardAppeared?.call();
        } else if (!isVisible) {
          _keyboardVisible = false;
        }
      } catch (_) {
        // textentry endpoint may not exist on older firmware — silently ignore.
      }
    });
  }

  void _stopKeyboardPolling() {
    _keyboardPollTimer?.cancel();
    _keyboardPollTimer = null;
  }

  bool get keyboardVisible => _keyboardVisible;

  // ---------------------------------------------------------------------------
  // Pairing (Android TV 2016+)
  // ---------------------------------------------------------------------------

  Future<String> startPairing() async {
    AppLogger.i(_tag, 'startPairing(): requesting PIN for $ip');
    final prefs  = await SharedPreferences.getInstance();
    String devId = prefs.getString('$_prefDevId$ip') ?? 'titancast_${_randomHex(8)}';
    await prefs.setString('$_prefDevId$ip', devId);
    AppLogger.d(_tag, 'startPairing(): devId=$devId');

    final url  = Uri.parse('https://$ip:1926/6/pair/request');
    final body = jsonEncode({
      'scope': ['read', 'write', 'control'],
      'device': {
        'device_name': 'TitanCast',
        'device_os': 'Android',
        'app_name': 'TitanCast',
        'app_id': 'app.titancast',
        'type': 'native',
        'id': devId,
      },
    });

    AppLogger.d(_tag, 'startPairing(): POST $url');
    final response = await _client
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 8));

    AppLogger.d(_tag, 'startPairing(): response HTTP ${response.statusCode} '
        'body="${_truncate(response.body, 100)}"');

    if (response.statusCode != 200) {
      AppLogger.e(_tag, 'startPairing() failed: HTTP ${response.statusCode}');
      throw TvProtocolException(
          'Philips pairing request failed: HTTP ${response.statusCode}');
    }

    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final authKey = data['auth_key'] as String? ?? '';
    AppLogger.d(_tag, 'startPairing(): auth_key received (${authKey.length} chars), '
        'storing temporarily');
    final prefs2 = await SharedPreferences.getInstance();
    await prefs2.setString('philips_authkey_$ip', authKey);
    AppLogger.i(_tag, 'startPairing(): done — PIN should be visible on TV screen');
    return devId;
  }

  Future<void> confirmPairing(String pin) async {
    AppLogger.i(_tag, 'confirmPairing(): verifying PIN for $ip');
    final prefs   = await SharedPreferences.getInstance();
    final devId   = prefs.getString('$_prefDevId$ip') ?? '';
    final authKey = prefs.getString('philips_authkey_$ip') ?? '';
    AppLogger.d(_tag, 'confirmPairing(): devId=$devId authKey=${authKey.length} chars');

    // Philips Android TV uses HMAC-SHA1 with a hardcoded secret key, NOT SHA-256.
    // Source: https://github.com/suborb/philips_android_tv
    // auth_signature = base64(HMAC-SHA1(base64decode(secretKey), (timestamp + pin).bytes))
    const secretKeyB64 =
        'ZmVay1EQVFOaZhwQ4Kv81ypLAZNczV9sG4KkseXWn1NEk6cXmPKO/MCa9sryslvLCFMnNe4Z4CPXzToowvhHvA==';
    final keyBytes      = base64.decode(secretKeyB64);
    final authTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hmacSha1      = Hmac(sha1, keyBytes);
    final signature     = base64.encode(
      hmacSha1.convert(utf8.encode('$authTimestamp$pin')).bytes,
    );
    AppLogger.d(_tag,
        'confirmPairing(): HMAC-SHA1 signature computed (timestamp=$authTimestamp)');

    final url  = Uri.parse('https://$ip:1926/6/pair/grant');
    final body = jsonEncode({
      'device': {
        'device_name': 'TitanCast',
        'device_os':   'Android',
        'app_name':    'TitanCast',
        'app_id':      'app.titancast',
        'type':        'native',
        'id':          devId,
      },
      'auth': {
        'auth_AppId':       '1',
        'pin':              pin,
        'auth_timestamp':   '$authTimestamp',
        'auth_signature':   signature,
      },
    });

    // Grant endpoint requires Digest Auth: username=devId, password=authKey.
    // Temporarily set credentials so _postWithDigest can use them.
    _username = devId;
    _password = authKey;
    AppLogger.d(_tag,
        'confirmPairing(): POST $url with Digest Auth (user=$devId)');

    final response = await _postWithDigest(url, body);

    AppLogger.d(_tag, 'confirmPairing(): response HTTP ${response.statusCode} '
        'body="${_truncate(response.body, 100)}"');

    if (response.statusCode != 200) {
      // Clear credentials on failure so retry works correctly.
      _username = null;
      _password = null;
      AppLogger.e(_tag, 'confirmPairing() failed: HTTP ${response.statusCode}');
      throw TvProtocolException(
          'Philips PIN doğrulaması başarısız (HTTP ${response.statusCode}). '
          "PIN'i kontrol edip tekrar deneyin.");
    }

    // After a successful grant, the ongoing Digest Auth credentials are:
    //   username = devId (the random device ID we generated)
    //   password = authKey (from the pair/request response, NOT the grant response)
    // This matches the reference implementation (suborb/philips_android_tv).
    AppLogger.i(_tag,
        'confirmPairing(): grant accepted — persisting user=$devId / authKey as pass');
    await prefs.setString('$_prefUser$ip', devId);
    await prefs.setString('$_prefPass$ip', authKey);

    _needsAndroidAuth = true;
    _baseUrl          = 'https://$ip:1926';
    _apiVersion       = 6;
    _connected        = true;
    _startKeyboardPolling();
    AppLogger.i(_tag, 'confirmPairing(): complete — user=$devId connected=true');
  }

  // ---------------------------------------------------------------------------
  // Philips Advanced API (Ambilight, Apps, Keyboard, Settings)
  // ---------------------------------------------------------------------------

  /// Ambilight mevcut durumunu döndürür (on/off + mevcut mod).
  /// Endpoint: GET /<ver>/ambilight/currentconfiguration
  Future<Map<String, dynamic>> ambilightGetConfig() async {
    AppLogger.d(_tag, 'ambilightGetConfig()');
    return _getJson('$_baseUrl/$_apiVersion/ambilight/currentconfiguration');
  }

  /// Ambilight'ı açar veya kapatır.
  /// Endpoint: POST /<ver>/ambilight/power  { "power": "On" | "Off" }
  /// Turns Ambilight on or off.
  /// Primary: POST /ambilight/power {"power": "On"|"Off"}
  /// Fallback: POST /ambilight/currentconfiguration {"styleName": "OFF"} for older firmware.
  Future<void> ambilightSetPower({required bool on}) async {
    AppLogger.d(_tag, 'ambilightSetPower(on=$on)');
    if (on) {
      // Turning ON: use /ambilight/power endpoint
      try {
        await _postJson('$_baseUrl/$_apiVersion/ambilight/power',
            jsonEncode({'power': 'On'}));
        return;
      } catch (e) {
        AppLogger.w(_tag, 'ambilightSetPower ON via /power failed: $e — trying currentconfiguration');
      }
      // Fallback: re-enable last known style via FOLLOW_VIDEO
      await _postJson('$_baseUrl/$_apiVersion/ambilight/currentconfiguration',
          jsonEncode({'styleName': 'FOLLOW_VIDEO', 'isExpert': false, 'menuSetting': 'STANDARD'}));
    } else {
      // Turning OFF: two approaches
      try {
        await _postJson('$_baseUrl/$_apiVersion/ambilight/power',
            jsonEncode({'power': 'Off'}));
        return;
      } catch (e) {
        AppLogger.w(_tag, 'ambilightSetPower OFF via /power failed: $e — trying currentconfiguration');
      }
      // Fallback: set styleName to OFF
      await _postJson('$_baseUrl/$_apiVersion/ambilight/currentconfiguration',
          jsonEncode({'styleName': 'OFF', 'isExpert': false}));
    }
  }

  /// Ambilight modunu değiştirir.
  /// Geçerli modlar: "Standard", "Natural", "Immersive", "Game", "Comfort", "Relax"
  /// Endpoint: POST /<ver>/ambilight/currentconfiguration
  /// Sets Ambilight style.
  /// [styleName] must be one of: FOLLOW_VIDEO, FOLLOW_AUDIO, FOLLOW_COLOR, LOUNGE, MANUAL
  /// [menuSetting] for FOLLOW_VIDEO: STANDARD, NATURAL, VIVID, GAME, COMFORT, RELAX
  /// [algorithm] for FOLLOW_AUDIO: ENERGY_ADAPTIVE_BRIGHTNESS, ENERGY_ADAPTIVE_COLORS,
  ///   VU_METER, SPECTRUM_ANALYZER, KNIGHT_RIDER_CLOCKWISE, KNIGHT_RIDER_ALTERNATING,
  ///   RANDOM_PIXEL_FLASH, STROBO, PARTY
  Future<void> ambilightSetMode(String styleName, {String? menuSetting, String? algorithm}) async {
    final payload = <String, dynamic>{
      'styleName': styleName,
      'isExpert': false,
    };
    if (menuSetting != null) payload['menuSetting'] = menuSetting;
    if (algorithm != null) payload['algorithm'] = algorithm;
    final body = jsonEncode(payload);
    AppLogger.d(_tag, 'ambilightSetMode($styleName menuSetting=$menuSetting algorithm=$algorithm)');
    await _postJson('$_baseUrl/$_apiVersion/ambilight/currentconfiguration', body);
  }

  /// Ambilight rengini sabit renge ayarlar (lounge/party modu).
  /// Endpoint: POST /<ver>/ambilight/currentconfiguration
  /// Sets Ambilight to a fixed color (FOLLOW_COLOR style).
  /// Converts RGB to Philips HSB color space.
  /// algorithm: MANUAL_HUE (fixed color) or AUTOMATIC_HUE (color shifts with content)
  Future<void> ambilightSetColor({
    required int r, required int g, required int b,
    String algorithm = 'MANUAL_HUE',
  }) async {
    // Convert RGB to HSV/HSB for Philips API
    // Philips uses hue 0-360, saturation 0-255, brightness 0-255
    final hsb = _rgbToHsb(r, g, b);
    final body = jsonEncode({
      'styleName': 'FOLLOW_COLOR',
      'isExpert': false,
      'algorithm': algorithm,
      'colorSettings': {
        'color': {
          'hue': hsb[0].round(),
          'saturation': hsb[1].round(),
          'brightness': hsb[2].round(),
        },
        'colorDelta': {'hue': 0, 'saturation': 0, 'brightness': 0},
        'speed': 255,
      },
    });
    AppLogger.d(_tag, 'ambilightSetColor(r=$r,g=$g,b=$b → h=${hsb[0].round()} s=${hsb[1].round()} v=${hsb[2].round()})');
    await _postJson('$_baseUrl/$_apiVersion/ambilight/currentconfiguration', body);
  }

  /// Sets Ambilight to Lounge/Party mode.
  /// [speed] 0-255, [mode]: "Default", "Random"
  Future<void> ambilightSetLounge({int speed = 128, String mode = 'Default'}) async {
    // Step 1: set LOUNGE style
    await _postJson('$_baseUrl/$_apiVersion/ambilight/currentconfiguration',
        jsonEncode({'styleName': 'LOUNGE', 'isExpert': false}));
    // Step 2: set lounge parameters
    final body = jsonEncode({
      'color': {'hue': 0, 'saturation': 0, 'brightness': 0},
      'colordelta': {'hue': 0, 'saturation': 0, 'brightness': 0},
      'speed': speed,
      'mode': mode,
    });
    AppLogger.d(_tag, 'ambilightSetLounge(speed=$speed mode=$mode)');
    await _postJson('$_baseUrl/$_apiVersion/ambilight/lounge', body);
  }

  /// Fetches the TV-reported supported styles from /ambilight/supportedstyles.
  /// Returns list of style maps: [{styleName, algorithms?, maxTuning?, maxSpeed?}, ...]
  Future<List<Map<String, dynamic>>> ambilightGetSupportedStyles() async {
    AppLogger.d(_tag, 'ambilightGetSupportedStyles()');
    final data = await _getJson('$_baseUrl/$_apiVersion/ambilight/supportedstyles');
    final list = data['supportedStyles'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Converts RGB (0-255 each) to Philips HSB: [hue 0-360, sat 0-255, bri 0-255]
  static List<double> _rgbToHsb(int r, int g, int b) {
    final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
    final max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    final min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    final delta = max - min;

    double hue = 0;
    if (delta > 0) {
      if (max == rf)      hue = 60 * (((gf - bf) / delta) % 6);
      else if (max == gf) hue = 60 * (((bf - rf) / delta) + 2);
      else                hue = 60 * (((rf - gf) / delta) + 4);
      if (hue < 0) hue += 360;
    }

    final sat = max == 0 ? 0.0 : delta / max;
    return [hue, sat * 255, max * 255];
  }

  /// Yüklü uygulamaların listesini döndürür.
  /// Endpoint: GET /<ver>/applications
  Future<List<Map<String, dynamic>>> getApplications() async {
    AppLogger.d(_tag, 'getApplications()');
    final data = await _getJson('$_baseUrl/$_apiVersion/applications');
    final list = data['applications'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Belirtilen paketi başlatır.
  /// Endpoint: POST /<ver>/activities/launch  { "intent": { ... } }
  Future<void> launchApplication(Map<String, dynamic> intent) async {
    final body = jsonEncode({'intent': intent});
    AppLogger.d(_tag, 'launchApplication(${intent['component']?['packageName']})');
    await _postJson('$_baseUrl/$_apiVersion/activities/launch', body);
  }

  /// Ekran klavyesini gösterir veya gizler.
  /// Endpoint: POST /<ver>/input/key  key=PhilipsMenu (açık menü aracılığıyla)
  /// Not: JointSpace'in doğrudan bir "show keyboard" endpoint'i yoktur;
  /// bunun yerine metin girme için /input/keyboard kullanılır.
  Future<void> sendKeyboardInput(String text) async {
    if (!_connected) return;
    AppLogger.d(_tag, 'sendKeyboardInput("${_truncate(text, 40)}")');

    // Philips JointSpace keyboard API:
    // /input/keyboard (v5) returns HTTP 405 on Android TV firmware.
    // Correct approach: send each character individually via /input/key.
    // Philips accepts single unicode characters as key values (confirmed via
    // pylips and HA philips_js integration source code).
    //
    // Step 1: set cursor to end of empty string (resets the field)
    // Step 2: send each character as a separate /input/key POST
    //
    // On non-Android TVs (port 1925) the same key endpoint works without auth.

    final keyUrl = Uri.parse('$_baseUrl/$_apiVersion/input/key');

    // Step 1: Reset / focus the text field via a synthetic clear sequence.
    // Some firmware versions need this to accept character input.
    // We ignore errors here — the char send is the critical path.
    try {
      final clearBody = jsonEncode({'key': 'VK_BACK_SPACE'});
      if (_needsAndroidAuth) {
        await _postWithDigest(keyUrl, clearBody);
      } else {
        await _client.post(keyUrl,
            headers: {'Content-Type': 'application/json'}, body: clearBody)
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}

    // Step 2: Send each character one at a time.
    for (final char in text.runes.map(String.fromCharCode)) {
      final body = jsonEncode({'key': char});
      try {
        if (_needsAndroidAuth) {
          await _postWithDigest(keyUrl, body);
        } else {
          await _client.post(keyUrl,
              headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 3));
        }
        // Small delay between keystrokes — prevents TV input buffer overflow.
        await Future<void>.delayed(const Duration(milliseconds: 80));
      } catch (e) {
        AppLogger.w(_tag, 'sendKeyboardInput: char "$char" failed — $e');
      }
    }
    AppLogger.i(_tag, 'sendKeyboardInput: sent ${text.length} chars');
  }

  /// TV sistem bilgilerini döndürür (model, software version, vs).
  /// Endpoint: GET /<ver>/system
  Future<Map<String, dynamic>> getSystemInfo() async {
    AppLogger.d(_tag, 'getSystemInfo()');
    return _getJson('$_baseUrl/$_apiVersion/system');
  }

  /// Ağ bilgilerini döndürür (IP, MAC, SSID).
  /// Endpoint: GET /<ver>/network/devices
  Future<Map<String, dynamic>> getNetworkInfo() async {
    AppLogger.d(_tag, 'getNetworkInfo()');
    return _getJson('$_baseUrl/$_apiVersion/network/devices');
  }

  /// Ses ayarlarını döndürür (volume, mute, min, max).
  /// Endpoint: GET /<ver>/audio/volume
  Future<Map<String, dynamic>> getVolume() async {
    AppLogger.d(_tag, 'getVolume()');
    return _getJson('$_baseUrl/$_apiVersion/audio/volume');
  }

  /// Ses seviyesini direkt değere ayarlar.
  /// Endpoint: POST /<ver>/audio/volume  { "current": N, "muted": false }
  Future<void> setVolume(int level) async {
    final body = jsonEncode({'current': level, 'muted': false});
    AppLogger.d(_tag, 'setVolume($level)');
    await _postJson('$_baseUrl/$_apiVersion/audio/volume', body);
  }

  /// Mevcut kanal bilgisini döndürür.
  /// Endpoint: GET /<ver>/channels/current
  Future<Map<String, dynamic>> getCurrentChannel() async {
    AppLogger.d(_tag, 'getCurrentChannel()');
    return _getJson('$_baseUrl/$_apiVersion/channels/current');
  }

  /// Kanal listesini döndürür.
  /// Endpoint: GET /<ver>/channels
  Future<List<Map<String, dynamic>>> getChannels() async {
    AppLogger.d(_tag, 'getChannels()');
    final data = await _getJson('$_baseUrl/$_apiVersion/channels');
    final list = data['Channel'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Philips REST helpers
  // ---------------------------------------------------------------------------

  /// GET helper — returns parsed JSON map. Supports Digest Auth if needed.
  Future<Map<String, dynamic>> _getJson(String url) async {
    AppLogger.v(_tag, 'GET $url');
    final uri = Uri.parse(url);
    final sw  = Stopwatch()..start();
    try {
      final http.Response response;
      if (_needsAndroidAuth) {
        // GET with Digest: do a dry-run POST trick — actually just attempt GET,
        // if 401 re-do with digest manually.
        response = await _getWithDigest(uri);
      } else {
        response = await _client.get(uri).timeout(const Duration(seconds: 5));
      }
      sw.stop();
      AppLogger.v(_tag, 'GET $url → HTTP ${response.statusCode} in ${sw.elapsedMilliseconds}ms');
      if (response.statusCode != 200) {
        AppLogger.w(_tag, '_getJson: HTTP ${response.statusCode} for $url');
        return {};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      sw.stop();
      AppLogger.e(_tag, '_getJson failed for $url after ${sw.elapsedMilliseconds}ms: $e');
      return {};
    }
  }

  /// POST helper — fires and checks status. Supports Digest Auth if needed.
  Future<void> _postJson(String url, String body) async {
    AppLogger.v(_tag, 'POST $url body="${_truncate(body, 60)}"');
    final uri = Uri.parse(url);
    final sw  = Stopwatch()..start();
    try {
      final http.Response response;
      if (_needsAndroidAuth) {
        response = await _postWithDigest(uri, body);
      } else {
        response = await _client
            .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 5));
      }
      sw.stop();
      AppLogger.v(_tag, 'POST $url → HTTP ${response.statusCode} in ${sw.elapsedMilliseconds}ms');
      if (response.statusCode != 200 && response.statusCode != 204) {
        AppLogger.w(_tag, '_postJson: HTTP ${response.statusCode} for $url');
        throw TvProtocolException('Philips API error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      sw.stop();
      if (e is TvProtocolException) rethrow;
      AppLogger.e(_tag, '_postJson failed for $url after ${sw.elapsedMilliseconds}ms: $e');
      throw TvProtocolException('Philips: $e');
    }
  }

  /// GET with Digest Auth (mirrors _postWithDigest logic for GET requests).
  Future<http.Response> _getWithDigest(Uri uri) async {
    AppLogger.v(_tag, 'getWithDigest: first attempt (no auth) → $uri');
    final first = await _client.get(uri).timeout(const Duration(seconds: 5));
    AppLogger.v(_tag, 'getWithDigest: first attempt HTTP ${first.statusCode}');

    if (first.statusCode != 401) return first;

    if (_username == null || _password == null) {
      AppLogger.w(_tag, 'getWithDigest: got 401 but no credentials');
      throw const PhilipsPairingRequiredException();
    }

    final wwwAuth = first.headers['www-authenticate'] ?? '';
    final auth = _parseDigestChallenge(wwwAuth);
    if (auth == null) return first;

    final realm  = auth['realm']  ?? '';
    final nonce  = auth['nonce']  ?? '';
    final qop    = auth['qop']    ?? '';
    final nc     = '00000001';
    final cnonce = _randomHex(8);
    final ha1    = _md5('$_username:$realm:$_password');
    final ha2    = _md5('GET:${uri.path}');
    final res    = qop == 'auth'
        ? _md5('$ha1:$nonce:$nc:$cnonce:$qop:$ha2')
        : _md5('$ha1:$nonce:$ha2');

    final authHeader = 'Digest username="$_username", realm="$realm", '
        'nonce="$nonce", uri="${uri.path}", qop=$qop, nc=$nc, cnonce="$cnonce", '
        'response="$res"';

    AppLogger.v(_tag, 'getWithDigest: retrying with Digest credentials');
    final second = await _client
        .get(uri, headers: {'Authorization': authHeader})
        .timeout(const Duration(seconds: 5));
    AppLogger.v(_tag, 'getWithDigest: retry HTTP ${second.statusCode}');
    return second;
  }

  // ---------------------------------------------------------------------------
  // Digest Auth
  // ---------------------------------------------------------------------------

  Future<http.Response> _postWithDigest(Uri url, String body) async {
    AppLogger.v(_tag, 'postWithDigest: first attempt (no auth) → $url');
    final first = await _client
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 5));

    AppLogger.v(_tag, 'postWithDigest: first attempt HTTP ${first.statusCode}');

    if (first.statusCode != 401) {
      AppLogger.v(_tag, 'postWithDigest: not a 401, returning directly');
      return first;
    }

    if (_username == null || _password == null) {
      AppLogger.w(_tag, 'postWithDigest: got 401 but no credentials → pairing required');
      throw const PhilipsPairingRequiredException();
    }

    final wwwAuth = first.headers['www-authenticate'] ?? '';
    AppLogger.v(_tag, 'postWithDigest: parsing Digest challenge: '
        '"${_truncate(wwwAuth, 80)}"');
    final auth = _parseDigestChallenge(wwwAuth);
    if (auth == null) {
      AppLogger.w(_tag, 'postWithDigest: could not parse Digest challenge, returning 401');
      return first;
    }

    final realm  = auth['realm']  ?? '';
    final nonce  = auth['nonce']  ?? '';
    final qop    = auth['qop']    ?? '';
    final nc     = '00000001';
    final cnonce = _randomHex(8);
    AppLogger.v(_tag, 'postWithDigest: realm="$realm" nonce="$nonce" qop="$qop" cnonce="$cnonce"');

    final method = 'POST';
    final uri    = url.path;
    final ha1    = _md5('$_username:$realm:$_password');
    final ha2    = _md5('$method:$uri');
    final res    = qop == 'auth'
        ? _md5('$ha1:$nonce:$nc:$cnonce:$qop:$ha2')
        : _md5('$ha1:$nonce:$ha2');

    final authHeader = 'Digest username="$_username", realm="$realm", '
        'nonce="$nonce", uri="$uri", qop=$qop, nc=$nc, cnonce="$cnonce", '
        'response="$res"';

    AppLogger.v(_tag, 'postWithDigest: retrying with Digest credentials');
    final second = await _client
        .post(url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': authHeader,
            },
            body: body)
        .timeout(const Duration(seconds: 5));
    AppLogger.v(_tag, 'postWithDigest: retry HTTP ${second.statusCode}');
    return second;
  }

  Map<String, String>? _parseDigestChallenge(String header) {
    if (!header.startsWith('Digest')) return null;
    final map     = <String, String>{};
    final pattern = RegExp(r'(\w+)="?([^",]+)"?');
    for (final m in pattern.allMatches(header)) {
      map[m.group(1)!] = m.group(2)!;
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Probe helpers
  // ---------------------------------------------------------------------------

  Future<int?> _probe(String scheme, int port) async {
    for (final version in [6, 5, 1]) {
      try {
        final url = Uri.parse('$scheme://$ip:$port/$version/system');
        AppLogger.v(_tag, 'probe: GET $url');
        final sw = Stopwatch()..start();
        final r  = await _client.get(url).timeout(const Duration(seconds: 4));
        sw.stop();
        AppLogger.d(_tag, 'probe: $url → HTTP ${r.statusCode} in ${sw.elapsedMilliseconds}ms');

        if (r.statusCode == 200 || r.statusCode == 401) {
          if (r.statusCode == 401 && (_username == null || _password == null)) {
            AppLogger.w(_tag, 'probe: 401 on $url but no credentials stored → needs pairing');
            return null;
          }
          AppLogger.i(_tag, 'probe: ✓ accepted $url (API v$version, HTTP ${r.statusCode})');
          return version;
        }
        AppLogger.v(_tag, 'probe: HTTP ${r.statusCode} not acceptable, trying next version');
      } catch (e) {
        AppLogger.w(_tag, 'probe: $scheme://$ip:$port/v$version/system → exception: $e');
      }
    }
    AppLogger.d(_tag, 'probe: all versions (6,5,1) failed for $scheme://$ip:$port');
    return null;
  }

  Future<bool> _isReachable(String scheme, int port) async {
    try {
      final url = Uri.parse('$scheme://$ip:$port/6/system');
      AppLogger.v(_tag, 'isReachable: GET $url');
      final r   = await _client.get(url).timeout(const Duration(seconds: 4));
      final ok  = r.statusCode == 200 || r.statusCode == 401;
      AppLogger.v(_tag, 'isReachable: HTTP ${r.statusCode} → reachable=$ok');
      return ok;
    } catch (e) {
      AppLogger.v(_tag, 'isReachable: $scheme://$ip:$port exception → false ($e)');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _md5(String data) => md5.convert(utf8.encode(data)).toString();

  String _randomHex(int len) {
    final rng = Random.secure();
    return List.generate(
      len,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  http.Client _buildClient() {
    if (kIsWeb) return http.Client();
    final native = HttpClient()..badCertificateCallback = (_, __, ___) => true;
    return IOClient(native);
  }

  static const Map<RemoteCommand, String> _keyMap = {
    RemoteCommand.power:        'Standby',
    RemoteCommand.powerOn:      'Standby',
    RemoteCommand.powerOff:     'Standby',
    RemoteCommand.volumeUp:     'VolumeUp',
    RemoteCommand.volumeDown:   'VolumeDown',
    RemoteCommand.mute:         'Mute',
    RemoteCommand.channelUp:    'ChannelStepUp',
    RemoteCommand.channelDown:  'ChannelStepDown',
    RemoteCommand.up:           'CursorUp',
    RemoteCommand.down:         'CursorDown',
    RemoteCommand.left:         'CursorLeft',
    RemoteCommand.right:        'CursorRight',
    RemoteCommand.ok:           'Confirm',
    RemoteCommand.back:         'Back',
    RemoteCommand.home:         'Home',
    RemoteCommand.menu:         'Options',
    RemoteCommand.exit:         'Exit',
    RemoteCommand.tv:           'WatchTV',
    RemoteCommand.play:         'Play',
    RemoteCommand.pause:        'Pause',
    RemoteCommand.stop:         'Stop',
    RemoteCommand.rewind:       'Rewind',
    RemoteCommand.fastForward:  'FastForward',
    RemoteCommand.record:       'Record',
    RemoteCommand.nextTrack:    'Next',
    RemoteCommand.prevTrack:    'Previous',
    RemoteCommand.source:       'Source',
    RemoteCommand.netflix:      'Netflix',
    RemoteCommand.youtube:      'YouTube',
    RemoteCommand.colorRed:     'RedColour',
    RemoteCommand.colorGreen:   'GreenColour',
    RemoteCommand.colorYellow:  'YellowColour',
    RemoteCommand.colorBlue:    'BlueColour',
    RemoteCommand.info:         'Info',
    RemoteCommand.guide:        'Guide',
    RemoteCommand.subtitle:     'Subtitle',
    RemoteCommand.teletext:     'Teletext',
    RemoteCommand.ambilight:    'AmbilightOnOff',
    RemoteCommand.key0:         'Digit0',
    RemoteCommand.key1:         'Digit1',
    RemoteCommand.key2:         'Digit2',
    RemoteCommand.key3:         'Digit3',
    RemoteCommand.key4:         'Digit4',
    RemoteCommand.key5:         'Digit5',
    RemoteCommand.key6:         'Digit6',
    RemoteCommand.key7:         'Digit7',
    RemoteCommand.key8:         'Digit8',
    RemoteCommand.key9:         'Digit9',
  };
}

class PhilipsPairingRequiredException extends TvProtocolException {
  const PhilipsPairingRequiredException()
      : super(
          'Philips Android TV eşleştirme gerekiyor. '
          'TV ekranında görünen PIN\'i girin.',
        );
}
