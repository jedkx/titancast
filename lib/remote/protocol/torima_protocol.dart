import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_adb/adb_connection.dart';
import 'package:flutter_adb/adb_crypto.dart';
import 'package:flutter_adb/flutter_adb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

/// Controls Android-based projectors (Torima HY300/HY320/HY350/T11, etc.)
/// via ADB over WiFi (Android Debug Bridge, TCP port 5555).
///
/// Commands: `input keyevent <KEYCODE>` shell | apps via `am start`.
/// First connect: projector shows RSA fingerprint prompt → user taps "Allow".
///
/// Prerequisites (one-time):
///   1. Settings → About → tap "Build Number" 7 times.
///   2. Developer Options → USB Debugging ON.
///   3. Developer Options → ADB over Network ON (if listed).
///
/// References:
///   - flutter_adb: https://pub.dev/packages/flutter_adb
///   - Android KEYCODE table: https://developer.android.com/reference/android/view/KeyEvent
class TorimaProtocol implements TvProtocol {
  final String ip;
  final int port;

  static const String _prefKeyPrefix = 'torima_adb_auth_';

  AdbConnection? _connection;
  AdbCrypto? _crypto;
  bool _connected = false;

  TorimaProtocol({required this.ip, this.port = 5555});

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    if (kIsWeb) {
      throw const TvProtocolException(
        'ADB over WiFi is not supported on web.',
      );
    }

    final prefs          = await SharedPreferences.getInstance();
    final key            = '$_prefKeyPrefix$ip';
    final everAuthorised = prefs.getBool(key) ?? false;

    _crypto     = AdbCrypto();
    _connection = AdbConnection(ip, port, _crypto!);

    bool ok = false;
    try {
      ok = await _connection!.connect().timeout(const Duration(seconds: 15));
    } catch (e) {
      throw TvProtocolException('Torima: $e');
    }

    if (!ok) {
      throw TvProtocolException(
        everAuthorised
            ? 'Torima: Bağlantı kurulamadı. USB hata ayıklamanın açık olduğunu kontrol edin.'
            : 'Torima: Projeksiyon ekranında "İzin ver" tuşuna basın, ardından tekrar deneyin.',
      );
    }

    await prefs.setBool(key, true);
    _connected = true;
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected || _crypto == null) {
      throw const TvProtocolException('Not connected');
    }

    // App-launch commands use am start instead of keyevent.
    final appTarget = _appMap[command];
    if (appTarget != null) {
      await _shell(
        'am start -a android.intent.action.MAIN '
            '-c android.intent.category.LAUNCHER '
            '-n $appTarget',
      );
      return;
    }

    final keycode = _keycodeMap[command];
    if (keycode == null) {
      debugPrint('TorimaProtocol: no keycode for $command');
      return;
    }

    await _shell('input keyevent $keycode');
  }

  @override
  Future<void> disconnect() async {
    _connected  = false;
    _connection = null;
    _crypto     = null;
  }

  // ---------------------------------------------------------------------------

  Future<void> _shell(String command) async {
    try {
      await Adb.sendSingleCommand(
        command,
        ip: ip,
        port: port,
        crypto: _crypto!,
      );
    } catch (e) {
      _connected = false;
      throw TvProtocolException('Torima shell error: $e');
    }
  }

  // App package/activity paths (standard Android TV app manifests)
  static const Map<RemoteCommand, String> _appMap = {
    RemoteCommand.netflix: 'com.netflix.ninja/.MainActivity',
    RemoteCommand.youtube: 'com.google.android.youtube/.HomeActivity',
  };

  // Android KEYCODE integers — https://developer.android.com/reference/android/view/KeyEvent
  static const Map<RemoteCommand, int> _keycodeMap = {
    RemoteCommand.power:       26,   // KEYCODE_POWER
    RemoteCommand.powerOn:     26,
    RemoteCommand.powerOff:    26,
    RemoteCommand.volumeUp:    24,   // KEYCODE_VOLUME_UP
    RemoteCommand.volumeDown:  25,   // KEYCODE_VOLUME_DOWN
    RemoteCommand.mute:        164,  // KEYCODE_VOLUME_MUTE
    RemoteCommand.channelUp:   166,  // KEYCODE_CHANNEL_UP
    RemoteCommand.channelDown: 167,  // KEYCODE_CHANNEL_DOWN
    RemoteCommand.up:          19,   // KEYCODE_DPAD_UP
    RemoteCommand.down:        20,   // KEYCODE_DPAD_DOWN
    RemoteCommand.left:        21,   // KEYCODE_DPAD_LEFT
    RemoteCommand.right:       22,   // KEYCODE_DPAD_RIGHT
    RemoteCommand.ok:          23,   // KEYCODE_DPAD_CENTER
    RemoteCommand.back:        4,    // KEYCODE_BACK
    RemoteCommand.home:        3,    // KEYCODE_HOME
    RemoteCommand.menu:        82,   // KEYCODE_MENU
    RemoteCommand.play:        126,  // KEYCODE_MEDIA_PLAY
    RemoteCommand.pause:       127,  // KEYCODE_MEDIA_PAUSE
    RemoteCommand.stop:        86,   // KEYCODE_MEDIA_STOP
    RemoteCommand.rewind:      89,   // KEYCODE_MEDIA_REWIND
    RemoteCommand.fastForward: 90,   // KEYCODE_MEDIA_FAST_FORWARD
    RemoteCommand.source:      178,  // KEYCODE_TV_INPUT
    RemoteCommand.key0:        7,
    RemoteCommand.key1:        8,
    RemoteCommand.key2:        9,
    RemoteCommand.key3:        10,
    RemoteCommand.key4:        11,
    RemoteCommand.key5:        12,
    RemoteCommand.key6:        13,
    RemoteCommand.key7:        14,
    RemoteCommand.key8:        15,
    RemoteCommand.key9:        16,
  };
}