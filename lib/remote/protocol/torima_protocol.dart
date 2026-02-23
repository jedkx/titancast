import 'package:flutter/foundation.dart';
import 'package:flutter_adb/adb_connection.dart';
import 'package:flutter_adb/adb_crypto.dart';
import 'package:flutter_adb/flutter_adb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';

const _tag = 'TorimaProtocol';

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
    AppLogger.i(_tag, '── connect() start ─────────────────────────────');
    AppLogger.d(_tag, 'target=$ip:$port');

    if (kIsWeb) {
      AppLogger.e(_tag, 'ADB over WiFi is not supported on web — aborting');
      throw const TvProtocolException('ADB over WiFi is not supported on web.');
    }

    final prefs          = await SharedPreferences.getInstance();
    final key            = '$_prefKeyPrefix$ip';
    final everAuthorised = prefs.getBool(key) ?? false;
    AppLogger.d(_tag, 'everAuthorised=$everAuthorised (key=$key)');

    AppLogger.d(_tag, 'creating AdbCrypto and AdbConnection');
    _crypto     = AdbCrypto();
    _connection = AdbConnection(ip, port, _crypto!);

    AppLogger.d(_tag, 'calling AdbConnection.connect() (timeout=15s) — '
        '${everAuthorised ? "previously authorized" : "first time, projector will show approval dialog"}');

    bool ok = false;
    final sw = Stopwatch()..start();
    try {
      ok = await _connection!.connect().timeout(const Duration(seconds: 15));
    } catch (e) {
      sw.stop();
      AppLogger.e(_tag, 'AdbConnection.connect() threw after ${sw.elapsedMilliseconds}ms: $e');
      throw TvProtocolException('Torima: $e');
    }
    sw.stop();
    AppLogger.d(_tag, 'AdbConnection.connect() returned ok=$ok in ${sw.elapsedMilliseconds}ms');

    if (!ok) {
      final msg = everAuthorised
          ? 'Torima: Bağlantı kurulamadı. USB hata ayıklamanın açık olduğunu kontrol edin.'
          : 'Torima: Projeksiyon ekranında "İzin ver" tuşuna basın, ardından tekrar deneyin.';
      AppLogger.e(_tag, 'connect failed (ok=false, everAuthorised=$everAuthorised): $msg');
      throw TvProtocolException(msg);
    }

    await prefs.setBool(key, true);
    _connected = true;
    AppLogger.i(_tag, 'connected to $ip:$port via ADB in ${sw.elapsedMilliseconds}ms');
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected || _crypto == null) {
      AppLogger.w(_tag, 'sendCommand($command) called while disconnected');
      throw const TvProtocolException('Not connected');
    }

    final appTarget = _appMap[command];
    if (appTarget != null) {
      final cmd = 'am start -a android.intent.action.MAIN '
          '-c android.intent.category.LAUNCHER -n $appTarget';
      AppLogger.d(_tag, '→ sendCommand($command): launching app → $appTarget');
      AppLogger.v(_tag, 'shell: $cmd');
      await _shell(cmd);
      AppLogger.v(_tag, '← sendCommand($command) app launch OK');
      return;
    }

    final keycode = _keycodeMap[command];
    if (keycode == null) {
      AppLogger.w(_tag, 'sendCommand: no keycode mapped for $command — dropped');
      return;
    }

    final cmd = 'input keyevent $keycode';
    AppLogger.d(_tag, '→ sendCommand($command): keyevent $keycode');
    AppLogger.v(_tag, 'shell: $cmd');
    await _shell(cmd);
    AppLogger.v(_tag, '← sendCommand($command) OK');
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i(_tag, 'disconnect(): nulling connection and crypto');
    _connected  = false;
    _connection = null;
    _crypto     = null;
    AppLogger.i(_tag, 'disconnect(): done');
  }

  // ---------------------------------------------------------------------------

  Future<void> _shell(String cmd) async {
    AppLogger.v(_tag, 'ADB shell → "$cmd"');
    final sw = Stopwatch()..start();
    try {
      await Adb.sendSingleCommand(cmd, ip: ip, port: port, crypto: _crypto!);
      sw.stop();
      AppLogger.v(_tag, 'ADB shell ← OK in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      sw.stop();
      _connected = false;
      AppLogger.e(_tag, 'ADB shell error after ${sw.elapsedMilliseconds}ms: $e '
          '(cmd="$cmd") — marking disconnected');
      throw TvProtocolException('Torima shell error: $e');
    }
  }

  static const Map<RemoteCommand, String> _appMap = {
    RemoteCommand.netflix: 'com.netflix.ninja/.MainActivity',
    RemoteCommand.youtube: 'com.google.android.youtube/.HomeActivity',
  };

  static const Map<RemoteCommand, int> _keycodeMap = {
    RemoteCommand.power:       26,
    RemoteCommand.powerOn:     26,
    RemoteCommand.powerOff:    26,
    RemoteCommand.volumeUp:    24,
    RemoteCommand.volumeDown:  25,
    RemoteCommand.mute:        164,
    RemoteCommand.channelUp:   166,
    RemoteCommand.channelDown: 167,
    RemoteCommand.up:          19,
    RemoteCommand.down:        20,
    RemoteCommand.left:        21,
    RemoteCommand.right:       22,
    RemoteCommand.ok:          23,
    RemoteCommand.back:        4,
    RemoteCommand.home:        3,
    RemoteCommand.menu:        82,
    RemoteCommand.play:        126,
    RemoteCommand.pause:       127,
    RemoteCommand.stop:        86,
    RemoteCommand.rewind:      89,
    RemoteCommand.fastForward: 90,
    RemoteCommand.source:      178,
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
