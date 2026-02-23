import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/brand_detector.dart';
import 'package:titancast/remote/tv_brand.dart';
import 'package:titancast/remote/protocol/lg_protocol.dart';
import 'package:titancast/remote/protocol/philips_protocol.dart';
import 'package:titancast/remote/protocol/samsung_protocol.dart';
import 'package:titancast/remote/protocol/sony_protocol.dart';
import 'package:titancast/remote/protocol/android_tv_protocol.dart';
import 'package:titancast/remote/protocol/torima_protocol.dart';
import 'package:titancast/remote/protocol/tv_protocol.dart';
import 'package:titancast/remote/protocol/unknown_protocol.dart';
import 'package:titancast/remote/remote_command.dart';

const _tag = 'RemoteController';

/// Connection states for the UI to react to.
enum RemoteConnectionState { disconnected, connecting, connected, error }

/// Facade that owns the active [TvProtocol] and exposes a simple API to the UI.
///
/// Usage:
///   final ctrl = RemoteController(device);
///   await ctrl.connect();
///   await ctrl.send(RemoteCommand.volumeUp);
///   await ctrl.disconnect();
class RemoteController extends ChangeNotifier {
  final DiscoveredDevice device;

  /// Called when the port-probe resolves an unknown brand so the caller can
  /// persist the result (e.g. DeviceRepository.setBrand).
  final void Function(String ip, TvBrand brand)? onBrandResolved;

  /// Called when a Philips TV raises its on-screen keyboard.
  /// UI should open the keyboard input sheet automatically.
  final void Function()? onPhilipsKeyboardAppeared;

  TvProtocol? _protocol;
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  String? _errorMessage;
  bool _needsPhilipsPairing = false;

  RemoteController(this.device, {this.onBrandResolved, this.onPhilipsKeyboardAppeared});

  RemoteConnectionState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _state == RemoteConnectionState.connected;

  /// Exposes the active protocol for brand-specific flows (e.g. Philips pairing).
  TvProtocol? get protocol => _protocol;

  /// True when [connect] failed with [PhilipsPairingRequiredException].
  /// UI should show a PIN entry dialog and call [philipsPair].
  bool get needsPhilipsPairing => _needsPhilipsPairing;

  /// Called by the UI after the user enters the PIN shown on a Philips Android TV.
  Future<void> philipsPair(String pin) async {
    AppLogger.i(_tag, 'philipsPair: confirming PIN for ${device.ip}');
    if (_protocol is! PhilipsProtocol) {
      AppLogger.w(_tag, 'philipsPair: active protocol is not PhilipsProtocol, aborting');
      return;
    }
    await (_protocol as PhilipsProtocol).confirmPairing(pin);
    _needsPhilipsPairing = false;
    AppLogger.i(_tag, 'philipsPair: pairing confirmed, transitioning to connected');
    _setState(RemoteConnectionState.connected);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (_state == RemoteConnectionState.connecting) {
      AppLogger.w(_tag, 'connect() called while already connecting — ignored');
      return;
    }

    AppLogger.i(_tag, '── connect() start ──────────────────────────────────');
    AppLogger.i(_tag, 'device: "${device.friendlyName}" ip=${device.ip} '
        'port=${device.port} brand=${device.detectedBrand?.name ?? "unknown"} '
        'method=${device.method.name}');

    _setState(RemoteConnectionState.connecting);
    _needsPhilipsPairing = false;

    // ── Step 1: Unknown brand → port-probe to auto-detect ──────────────────
    AppLogger.d(_tag, 'step 1: resolving brand (detectedBrand=${device.detectedBrand?.name})');
    final effectiveBrand = await _resolveUnknownBrand(device);
    AppLogger.i(_tag, 'step 1 done: effectiveBrand=${effectiveBrand.name}');

    // Persist the resolved brand so we skip port-probe on next connect.
    if (effectiveBrand != TvBrand.unknown &&
        (device.detectedBrand == null || device.detectedBrand == TvBrand.unknown)) {
      AppLogger.i(_tag, 'brand resolved from unknown → ${effectiveBrand.name}, persisting via onBrandResolved');
      onBrandResolved?.call(device.ip, effectiveBrand);
    }

    // ── Step 2: TCP reachability pre-check ───────────────────────────────────
    if (!kIsWeb && effectiveBrand != TvBrand.philips) {
      AppLogger.d(_tag, 'step 2: TCP reachability check for ${device.ip} (brand=${effectiveBrand.name})');
      final checkResult = await _tcpReachable(device.ip, effectiveBrand);
      if (!checkResult.reachable) {
        AppLogger.e(_tag, 'step 2 failed: ${checkResult.message}');
        _errorMessage = checkResult.message;
        _setState(RemoteConnectionState.error);
        return;
      }
      AppLogger.d(_tag, 'step 2 done: TCP reachable');
    } else if (effectiveBrand == TvBrand.philips) {
      AppLogger.d(_tag, 'step 2: skipped — Philips does its own port probe internally');
    } else {
      AppLogger.d(_tag, 'step 2: skipped — running on web');
    }

    // ── Step 3: Brand-specific connect ───────────────────────────────────────
    AppLogger.d(_tag, 'step 3: building protocol for brand=${effectiveBrand.name}');
    _protocol = _buildProtocolForBrand(device, effectiveBrand, onKeyboardAppeared: onPhilipsKeyboardAppeared);
    AppLogger.d(_tag, 'step 3: protocol=${_protocol.runtimeType}, calling connect()');

    try {
      final sw = Stopwatch()..start();
      await _protocol!.connect();
      sw.stop();
      AppLogger.i(_tag, 'step 3 done: connected in ${sw.elapsedMilliseconds}ms '
          '→ ${device.ip} (${effectiveBrand.name})');
      _setState(RemoteConnectionState.connected);
    } on PhilipsPairingRequiredException catch (e) {
      AppLogger.w(_tag, 'step 3: Philips pairing required for ${device.ip} — starting PIN flow');
      _errorMessage = e.message;
      _needsPhilipsPairing = true;
      (_protocol as PhilipsProtocol).startPairing().ignore();
      _setState(RemoteConnectionState.error);
    } on TvProtocolException catch (e) {
      AppLogger.e(_tag, 'step 3 failed (TvProtocolException): ${e.message}');
      _errorMessage = e.message;
      _setState(RemoteConnectionState.error);
    } catch (e, st) {
      AppLogger.e(_tag, 'step 3 failed (unexpected): $e\n$st');
      _errorMessage = e.toString();
      _setState(RemoteConnectionState.error);
    }
  }

  Future<void> send(RemoteCommand command) async {
    if (_protocol == null || !isConnected) {
      AppLogger.w(_tag, 'send($command) called while not connected — dropped');
      return;
    }
    AppLogger.d(_tag, '→ send($command) via ${_protocol.runtimeType}');
    try {
      final sw = Stopwatch()..start();
      await _protocol!.sendCommand(command);
      sw.stop();
      AppLogger.v(_tag, '← send($command) OK in ${sw.elapsedMilliseconds}ms');
    } on TvProtocolException catch (e) {
      AppLogger.e(_tag, 'send($command) failed: ${e.message}');
      _errorMessage = e.message;
      _setState(RemoteConnectionState.error);
    }
  }

  Future<void> disconnect() async {
    AppLogger.i(_tag, 'disconnect() called (state=$_state, protocol=${_protocol?.runtimeType})');
    await _protocol?.disconnect();
    _protocol = null;
    _setState(RemoteConnectionState.disconnected);
    AppLogger.i(_tag, 'disconnect() done');
  }

  // ---------------------------------------------------------------------------
  // TCP pre-check
  // ---------------------------------------------------------------------------

  static Future<({bool reachable, String message})> _tcpReachable(
      String ip,
      TvBrand? brand,
      ) async {
    final int? port = switch (brand) {
      TvBrand.samsung                                          => 8001,
      TvBrand.lg                                              => 3000,
      TvBrand.sony                                            => 80,
      TvBrand.torima                                          => 5555,
      TvBrand.androidTv ||
      TvBrand.hisense  ||
      TvBrand.tcl      ||
      TvBrand.sharp    ||
      TvBrand.toshiba  ||
      TvBrand.google                                          => 5555,
      TvBrand.philips                                         => null,
      _                                                       => null,
    };

    if (port == null) {
      AppLogger.v(_tag, 'TCP check: no port defined for brand=${brand?.name}, skipping');
      return (reachable: true, message: '');
    }

    AppLogger.d(_tag, 'TCP check: connecting to $ip:$port (brand=${brand?.name}, timeout=4s)');
    Socket? socket;
    final sw = Stopwatch()..start();
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
      sw.stop();
      AppLogger.d(_tag, 'TCP check: ✓ $ip:$port reachable in ${sw.elapsedMilliseconds}ms');
      return (reachable: true, message: '');
    } on SocketException catch (e) {
      sw.stop();
      final reason = e.osError?.message ?? e.message;
      AppLogger.w(_tag, 'TCP check: ✗ $ip:$port unreachable after ${sw.elapsedMilliseconds}ms '
          '(osError=${e.osError?.errorCode}, msg=$reason)');
      return (
      reachable: false,
      message: 'Cihaza ulaşılamıyor ($ip:$port). '
          'TV\'nin açık ve aynı ağda olduğundan emin olun. ($reason)',
      );
    } catch (e) {
      sw.stop();
      AppLogger.w(_tag, 'TCP check: ✗ $ip:$port unexpected error after ${sw.elapsedMilliseconds}ms: $e');
      return (reachable: false, message: 'Bağlantı testi başarısız: $e');
    } finally {
      socket?.destroy();
    }
  }

  // ---------------------------------------------------------------------------
  // Unknown brand resolution — port probe
  // ---------------------------------------------------------------------------

  static Future<TvBrand> _resolveUnknownBrand(DiscoveredDevice device) async {
    final brand = device.detectedBrand;
    if (brand != null && brand != TvBrand.unknown) {
      AppLogger.v(_tag, 'brand already known: ${brand.name}, skipping probe');
      return brand;
    }
    if (kIsWeb) {
      AppLogger.v(_tag, 'brand unknown but running on web — returning unknown');
      return TvBrand.unknown;
    }

    // Before expensive port-probe, try a quick name-based heuristic.
    // This covers Torima projectors (HY350Max, HY300, etc.) that may be
    // offline or have ADB on port 5555 which our probe maps to androidTv.
    AppLogger.d(_tag, 'brand unknown for ${device.ip} — checking name heuristic first '
        '(name="${device.friendlyName}")');
    final nameHint = BrandDetector.detectSync(device);
    if (nameHint != TvBrand.unknown) {
      AppLogger.i(_tag, 'brand resolved via name heuristic: ${nameHint.name} '
          '(skipping port probe)');
      return nameHint;
    }
    AppLogger.d(_tag, 'name heuristic miss — starting concurrent port probe');

    final probes = <(int, TvBrand)>[
      (1925, TvBrand.philips),
      (1926, TvBrand.philips),
      (3000, TvBrand.lg),
      (8001, TvBrand.samsung),
      (80,   TvBrand.sony),
      (5555, TvBrand.androidTv),
    ];

    final completer = Completer<TvBrand>();
    var remaining = probes.length;
    final sw = Stopwatch()..start();

    for (final (port, candidate) in probes) {
      AppLogger.v(_tag, 'probe: trying ${device.ip}:$port → $candidate');
      Socket.connect(device.ip, port, timeout: const Duration(seconds: 3))
          .then((s) {
        s.destroy();
        if (!completer.isCompleted) {
          sw.stop();
          AppLogger.i(_tag, 'probe: ✓ ${device.ip}:$port responded '
              '→ brand resolved to ${candidate.name} in ${sw.elapsedMilliseconds}ms');
          completer.complete(candidate);
        } else {
          AppLogger.v(_tag, 'probe: ${device.ip}:$port responded but winner already determined');
        }
      })
          .catchError((e) {
        AppLogger.v(_tag, 'probe: ✗ ${device.ip}:$port failed ($e)');
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          sw.stop();
          AppLogger.w(_tag, 'probe: all ${probes.length} ports failed after '
              '${sw.elapsedMilliseconds}ms — brand remains unknown');
          completer.complete(TvBrand.unknown);
        }
      });
    }

    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        AppLogger.w(_tag, 'probe: timeout after 4s — returning unknown');
        return TvBrand.unknown;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Protocol factory
  // ---------------------------------------------------------------------------

  TvProtocol _buildProtocolForBrand(DiscoveredDevice device, TvBrand brand, {VoidCallback? onKeyboardAppeared}) {
    AppLogger.v(_tag, 'buildProtocol: brand=${brand.name} ip=${device.ip} port=${device.port}');
    switch (brand) {
      case TvBrand.samsung:
        return SamsungProtocol(ip: device.ip, port: device.port ?? 8001);
      case TvBrand.lg:
        return LgProtocol(ip: device.ip);
      case TvBrand.sony:
        return SonyProtocol(ip: device.ip, psk: '');
      case TvBrand.philips:
        return PhilipsProtocol(ip: device.ip, onKeyboardAppeared: onKeyboardAppeared);
      case TvBrand.torima:
        return TorimaProtocol(ip: device.ip);
      case TvBrand.androidTv:
      case TvBrand.hisense:
      case TvBrand.tcl:
      case TvBrand.sharp:
      case TvBrand.toshiba:
      case TvBrand.google:
        return AndroidTvProtocol(ip: device.ip);
      default:
        AppLogger.w(_tag, 'buildProtocol: no driver for brand=${brand.name} — using UnknownProtocol');
        return const UnknownProtocol();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _setState(RemoteConnectionState s) {
    AppLogger.d(_tag, 'state: $_state → $s');
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    AppLogger.d(_tag, 'dispose() — disconnecting protocol if active');
    _protocol?.disconnect().ignore();
    super.dispose();
  }
}