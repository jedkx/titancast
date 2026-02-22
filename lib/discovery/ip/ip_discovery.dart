import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../discovery_model.dart';

class IpDiscoveryService {
  static const Duration _httpTimeout = Duration(seconds: 3);
  static const Duration _socketTimeout = Duration(milliseconds: 500);

  // UPnP description XML endpoints ordered by likelihood of success.
  static const List<_PortPath> _upnpEndpoints = [
    _PortPath(49152, '/description.xml'),
    _PortPath(49153, '/description.xml'),
    _PortPath(8080, '/description.xml'),
    _PortPath(8008, '/ssdp/device-desc.xml'),
    _PortPath(80, '/description.xml'),
  ];

  static const List<int> _probePorts = [1925, 1926, 8008, 8080, 80, 49152];

  StreamController<DiscoveredDevice>? _controller;
  bool _isActive = false;

  /// Attempts to identify the device at [ip].
  /// Returns a single-emission stream that closes when resolution completes.
  Stream<DiscoveredDevice> resolve({
    required String ip,
    Duration timeout = const Duration(seconds: 10),
  }) {
    // Clean up any leftover state from a previous call.
    stopDiscovery();

    _controller = StreamController<DiscoveredDevice>();
    _isActive = true;

    _resolve(ip, timeout);

    return _controller!.stream;
  }

  /// Stops an in-progress resolution and closes the stream.
  void stopDiscovery() {
    _isActive = false;
    if (_controller?.isClosed == false) _controller?.close();
    _controller = null;
  }

  // ---------------------------------------------------------------------------
  // Internal resolution pipeline
  // ---------------------------------------------------------------------------

  Future<void> _resolve(String ip, Duration timeout) async {
    try {
      await _runResolution(ip).timeout(timeout);
    } on TimeoutException {
      _controller?.addError(
        'Connection to $ip timed out. '
            'Make sure the device is on and on the same network.',
      );
    } catch (e) {
      _controller?.addError('IP resolution failed: $e');
    } finally {
      // Always close the stream when resolution ends, regardless of outcome.
      if (_controller?.isClosed == false) _controller?.close();
      _isActive = false;
    }
  }

  Future<void> _runResolution(String ip) async {
    if (!_isActive) return;

    // Step 1: UPnP description XML.
    for (final endpoint in _upnpEndpoints) {
      if (!_isActive) return;
      final device = await _tryUpnpDescription(ip, endpoint);
      if (device != null) {
        _emit(device);
        return;
      }
    }

    // Step 2: Philips JointSpace REST API.
    for (final port in [1925, 1926]) {
      if (!_isActive) return;
      final device = await _tryPhilipsJointSpace(ip, port);
      if (device != null) {
        _emit(device);
        return;
      }
    }

    // Step 3: Raw TCP reachability.
    // Even if we cannot identify the device, let the user try to connect.
    if (!_isActive) return;
    final reachablePort = await _findOpenPort(ip, _probePorts);
    if (reachablePort != null) {
      _emit(DiscoveredDevice(
        ip: ip,
        friendlyName: 'Device at $ip',
        method: DiscoveryMethod.manualIp,
        port: reachablePort,
      ));
      return;
    }

    // Nothing responded -- surface an error to the stream.
    _controller?.addError(
      'No response from $ip. '
          'Check the address and make sure the device is on the same Wi-Fi network.',
    );
  }

  // ---------------------------------------------------------------------------
  // Protocol-specific resolution helpers
  // ---------------------------------------------------------------------------

  Future<DiscoveredDevice?> _tryUpnpDescription(
      String ip,
      _PortPath endpoint,
      ) async {
    try {
      final uri = Uri.parse('http://$ip:${endpoint.port}${endpoint.path}');
      final response = await http.get(uri).timeout(_httpTimeout);
      if (response.statusCode != 200) return null;

      final doc = XmlDocument.parse(response.body);
      return DiscoveredDevice(
        ip: ip,
        friendlyName:
        doc.findAllElements('friendlyName').firstOrNull?.innerText ??
            'Smart Device',
        method: DiscoveryMethod.manualIp,
        manufacturer: doc.findAllElements('manufacturer').firstOrNull?.innerText,
        modelName: doc.findAllElements('modelName').firstOrNull?.innerText,
        serviceType: _cleanServiceType(
          doc.findAllElements('deviceType').firstOrNull?.innerText,
        ),
        location: uri.toString(),
        port: endpoint.port,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DiscoveredDevice?> _tryPhilipsJointSpace(
      String ip,
      int port,
      ) async {
    final protocol = port == 1926 ? 'https' : 'http';
    for (final path in ['/1/system', '/5/system', '/6/system']) {
      try {
        final uri = Uri.parse('$protocol://$ip:$port$path');
        final response = await http.get(uri).timeout(_httpTimeout);
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body) as Map<String, dynamic>;
        return DiscoveredDevice(
          ip: ip,
          friendlyName: (data['name'] ?? data['model'] ?? 'Philips TV') as String,
          method: DiscoveryMethod.manualIp,
          manufacturer: 'Philips',
          modelName: data['model'] as String?,
          serviceType: 'JointSpace TV',
          port: port,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<int?> _findOpenPort(String ip, List<int> ports) async {
    for (final port in ports) {
      try {
        final socket = await Socket.connect(ip, port, timeout: _socketTimeout);
        socket.destroy();
        return port;
      } catch (_) {}
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts "urn:schemas-upnp-org:device:MediaRenderer:1" -> "MediaRenderer"
  String? _cleanServiceType(String? raw) {
    if (raw == null) return null;
    if (!raw.startsWith('urn:')) return raw;
    final parts = raw.split(':');
    return parts.length >= 2 ? parts[parts.length - 2] : raw;
  }

  void _emit(DiscoveredDevice device) {
    if (_isActive && _controller?.isClosed == false) {
      _controller?.add(device);
    }
  }
}

/// Port + URL path pair used to probe UPnP endpoints.
class _PortPath {
  final int port;
  final String path;
  const _PortPath(this.port, this.path);
}