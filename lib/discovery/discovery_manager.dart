import 'dart:async';

import 'discovery_model.dart';
import 'network/ssdp_discovery.dart';
import 'network/mdns_discovery.dart';
import 'network/network_probe_discovery.dart';
import 'ip/ip_discovery.dart';
import 'scanner/qr_scanner_discovery.dart';

class DiscoveryManager {
  final _ssdpService = SsdpDiscoveryService();
  final _mdnsService = MdnsDiscoveryService();
  final _probeService = NetworkProbeDiscoveryService();
  final _ipService = IpDiscoveryService();
  final _qrService = QrScannerDiscoveryService();

  StreamController<DiscoveredDevice>? _mainController;
  final Map<String, DiscoveredDevice> _deviceCache = {};

  Stream<DiscoveredDevice> startDiscovery({
    required DiscoveryMode mode,
    Duration timeout = const Duration(seconds: 15),
    String? targetIp,
  }) {
    _deviceCache.clear();
    _mainController = StreamController<DiscoveredDevice>.broadcast();

    switch (mode) {
      case DiscoveryMode.network:
        _startNetworkDiscovery(timeout);
      case DiscoveryMode.manualIp:
        assert(targetIp != null, 'targetIp must be provided for manualIp mode');
        _startIpDiscovery(targetIp!, timeout);
      case DiscoveryMode.qrScan:
        _startQrDiscovery();
    }

    return _mainController!.stream;
  }

  void _startNetworkDiscovery(Duration timeout) {
    _ssdpService
        .discover(timeout: timeout)
        .listen(_processDevice, onError: _handleError);

    _mdnsService
        .discover(timeout: timeout)
        .listen(_processDevice, onError: _handleError);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_mainController?.isClosed == true) return;
      _probeService
          .discover(ports: [1925, 1926, 8008, 8080], timeout: timeout)
          .listen(_processDevice, onError: _handleError);
    });

    Timer(timeout, stopDiscovery);
  }

  void _startIpDiscovery(String ip, Duration timeout) {
    _ipService
        .resolve(ip: ip, timeout: timeout)
        .listen(_processDevice, onError: _handleError, onDone: _closeController);
  }

  void _startQrDiscovery() {
    _qrService
        .scan()
        .listen(_processDevice, onError: _handleError, onDone: _closeController);
  }

  void _processDevice(DiscoveredDevice incoming) {
    if (_mainController?.isClosed == true) return;

    final existing = _deviceCache[incoming.ip];

    if (existing == null) {
      _emit(incoming);
      return;
    }

    // SSDP is master -- only allow a name upgrade if still a placeholder.
    if (existing.method == DiscoveryMethod.ssdp) {
      if (_isPlaceholder(existing.friendlyName) &&
          !_isPlaceholder(incoming.friendlyName)) {
        _emit(existing.copyWith(friendlyName: incoming.friendlyName));
      }
      return;
    }

    // Always upgrade any fallback to SSDP.
    if (incoming.method == DiscoveryMethod.ssdp) {
      _emit(incoming);
      return;
    }

    // BUG FIX: probe emits a placeholder first, then emits the resolved device.
    // Accept the update when the existing name is a placeholder and the
    // incoming one is real -- regardless of which fallback method produced it.
    if (_isPlaceholder(existing.friendlyName) &&
        !_isPlaceholder(incoming.friendlyName)) {
      _emit(incoming);
      return;
    }

    // Fallback enrichment: accept if it adds manufacturer data.
    if (existing.manufacturer == null && incoming.manufacturer != null) {
      _emit(existing.copyWith(
        manufacturer: incoming.manufacturer,
        modelName: incoming.modelName ?? existing.modelName,
        serviceType: incoming.serviceType ?? existing.serviceType,
      ));
    }
  }

  void _emit(DiscoveredDevice device) {
    _deviceCache[device.ip] = device;
    _mainController?.add(device);
  }

  bool _isPlaceholder(String name) =>
      name.contains('...') || name.startsWith('Identifying');

  void _handleError(Object error) {
    print('DiscoveryManager error: $error');
  }

  void _closeController() {
    if (_mainController?.isClosed == false) _mainController?.close();
  }

  void stopDiscovery() {
    _ssdpService.stopDiscovery();
    _mdnsService.stopDiscovery();
    _probeService.stopDiscovery();
    _ipService.stopDiscovery();
    _qrService.stopScanning();
    _closeController();
  }
}