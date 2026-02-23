import 'dart:async';

import 'package:titancast/core/app_logger.dart';
import 'discovery_model.dart';
import 'network/ssdp_discovery.dart';
import 'network/mdns_discovery.dart';
import 'network/network_probe_discovery.dart';
import 'ip/ip_discovery.dart';
import 'scanner/qr_scanner_discovery.dart';

const _tag = 'DiscoveryManager';

class DiscoveryManager {
  final _ssdpService  = SsdpDiscoveryService();
  final _mdnsService  = MdnsDiscoveryService();
  final _probeService = NetworkProbeDiscoveryService();
  final _ipService    = IpDiscoveryService();
  final _qrService    = QrScannerDiscoveryService();

  StreamController<DiscoveredDevice>? _mainController;
  final Map<String, DiscoveredDevice> _deviceCache = {};

  Stream<DiscoveredDevice> startDiscovery({
    required DiscoveryMode mode,
    Duration timeout = const Duration(seconds: 15),
    String? targetIp,
  }) {
    AppLogger.i(_tag, '── startDiscovery() ────────────────────────────');
    AppLogger.i(_tag, 'mode=${mode.name} timeout=${timeout.inSeconds}s '
        'targetIp=${targetIp ?? "n/a"}');

    _deviceCache.clear();
    AppLogger.d(_tag, 'device cache cleared');
    _mainController = StreamController<DiscoveredDevice>.broadcast();

    switch (mode) {
      case DiscoveryMode.network:
        AppLogger.d(_tag, 'starting network discovery (SSDP + mDNS + port-probe)');
        _startNetworkDiscovery(timeout);
      case DiscoveryMode.manualIp:
        assert(targetIp != null, 'targetIp must be provided for manualIp mode');
        AppLogger.d(_tag, 'starting manual IP discovery for $targetIp');
        _startIpDiscovery(targetIp!, timeout);
      case DiscoveryMode.qrScan:
        AppLogger.d(_tag, 'starting QR scan discovery');
        _startQrDiscovery();
    }

    return _mainController!.stream;
  }

  void _startNetworkDiscovery(Duration timeout) {
    int activeSources = 2;
    AppLogger.d(_tag, 'network discovery: starting SSDP and mDNS sources '
        '(activeSources=$activeSources, probe delayed 200ms)');

    void onSourceDone(String name) {
      activeSources--;
      AppLogger.d(_tag, '$name finished (activeSources remaining=$activeSources)');
      if (activeSources <= 0) {
        AppLogger.i(_tag, 'all primary sources done — closing stream');
        _closeController();
      }
    }

    _ssdpService
        .discover(timeout: timeout)
        .listen(
          _processDevice,
          onError: (e) => _handleError('SSDP', e),
          onDone: () => onSourceDone('SSDP'),
        );

    _mdnsService
        .discover(timeout: timeout)
        .listen(
          _processDevice,
          onError: (e) => _handleError('mDNS', e),
          onDone: () => onSourceDone('mDNS'),
        );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_mainController?.isClosed == true) {
        AppLogger.d(_tag, 'probe start delayed 200ms but stream already closed — skipping');
        return;
      }
      AppLogger.d(_tag, 'starting port-probe (ports: 1925, 1926, 8008, 8080)');
      _probeService
          .discover(ports: [1925, 1926, 8008, 8080], timeout: timeout)
          .listen(
            _processDevice,
            onError: (e) => _handleError('probe', e),
            onDone: () => AppLogger.d(_tag, 'port-probe finished'),
          );
    });

    AppLogger.d(_tag, 'timeout timer set for ${timeout.inSeconds}s');
    Timer(timeout, () {
      AppLogger.i(_tag, 'discovery timeout reached (${timeout.inSeconds}s) — stopping');
      stopDiscovery();
    });
  }

  void _startIpDiscovery(String ip, Duration timeout) {
    AppLogger.d(_tag, 'IP discovery: resolving $ip (timeout=${timeout.inSeconds}s)');
    _ipService
        .resolve(ip: ip, timeout: timeout)
        .listen(
          _processDevice,
          onError: (e) => _handleError('IP', e),
          onDone: () {
            AppLogger.d(_tag, 'IP discovery finished for $ip');
            _closeController();
          },
        );
  }

  void _startQrDiscovery() {
    AppLogger.d(_tag, 'QR scan discovery: waiting for scan result');
    _qrService
        .scan()
        .listen(
          _processDevice,
          onError: (e) => _handleError('QR', e),
          onDone: () {
            AppLogger.d(_tag, 'QR scan discovery finished');
            _closeController();
          },
        );
  }

  void _processDevice(DiscoveredDevice incoming) {
    if (_mainController?.isClosed == true) {
      AppLogger.v(_tag, 'processDevice: stream closed, dropping ${incoming.ip}');
      return;
    }

    final existing = _deviceCache[incoming.ip];

    if (existing == null) {
      AppLogger.i(_tag, 'processDevice: NEW device ${incoming.ip} '
          '"${incoming.friendlyName}" brand=${incoming.detectedBrand?.name ?? "?"} '
          'method=${incoming.method.name}');
      _emit(incoming);
      return;
    }

    AppLogger.v(_tag, 'processDevice: UPDATE candidate for ${incoming.ip} '
        'existing.method=${existing.method.name} incoming.method=${incoming.method.name}');

    // SSDP is master — only upgrade name if current is a placeholder
    if (existing.method == DiscoveryMethod.ssdp) {
      if (_isPlaceholder(existing.friendlyName) && !_isPlaceholder(incoming.friendlyName)) {
        AppLogger.d(_tag, 'processDevice: upgrading SSDP placeholder name '
            '"${existing.friendlyName}" → "${incoming.friendlyName}"');
        _emit(existing.copyWith(friendlyName: incoming.friendlyName));
      } else {
        AppLogger.v(_tag, 'processDevice: SSDP master already has good name "${existing.friendlyName}", '
            'ignoring ${incoming.method.name} update');
      }
      return;
    }

    // Always upgrade any fallback to SSDP
    if (incoming.method == DiscoveryMethod.ssdp) {
      AppLogger.d(_tag, 'processDevice: upgrading ${existing.method.name} → SSDP '
          'for ${incoming.ip} "${incoming.friendlyName}"');
      _emit(incoming);
      return;
    }

    // Accept probe name resolution (placeholder → real name)
    if (_isPlaceholder(existing.friendlyName) && !_isPlaceholder(incoming.friendlyName)) {
      AppLogger.d(_tag, 'processDevice: placeholder resolved '
          '"${existing.friendlyName}" → "${incoming.friendlyName}" '
          'via ${incoming.method.name}');
      _emit(incoming);
      return;
    }

    // Accept manufacturer enrichment from fallback sources
    if (existing.manufacturer == null && incoming.manufacturer != null) {
      AppLogger.d(_tag, 'processDevice: enriching ${incoming.ip} with manufacturer '
          '"${incoming.manufacturer}" model="${incoming.modelName}" '
          'service="${incoming.serviceType}"');
      _emit(existing.copyWith(
        manufacturer: incoming.manufacturer,
        modelName: incoming.modelName ?? existing.modelName,
        serviceType: incoming.serviceType ?? existing.serviceType,
      ));
      return;
    }

    AppLogger.v(_tag, 'processDevice: no update criteria met for ${incoming.ip}, ignoring');
  }

  void _emit(DiscoveredDevice device) {
    _deviceCache[device.ip] = device;
    AppLogger.d(_tag, 'emit: ${device.ip} "${device.friendlyName}" '
        'brand=${device.detectedBrand?.name ?? "?"} '
        'manufacturer="${device.manufacturer ?? "?"}" '
        'method=${device.method.name} '
        'cache size=${_deviceCache.length}');
    _mainController?.add(device);
  }

  bool _isPlaceholder(String name) =>
      name.contains('...') || name.startsWith('Identifying');

  void _handleError(String source, Object error) {
    AppLogger.e(_tag, '[$source] discovery error: $error');
  }

  void _closeController() {
    if (_mainController?.isClosed == false) {
      AppLogger.d(_tag, 'closing main stream controller '
          '(total unique devices found: ${_deviceCache.length})');
      _mainController?.close();
    }
  }

  void stopDiscovery() {
    AppLogger.i(_tag, 'stopDiscovery(): stopping all sources');
    _ssdpService.stopDiscovery();
    _mdnsService.stopDiscovery();
    _probeService.stopDiscovery();
    _ipService.stopDiscovery();
    _qrService.stopScanning();
    _closeController();
    AppLogger.i(_tag, 'stopDiscovery(): all sources stopped, '
        '${_deviceCache.length} devices in cache');
  }
}
