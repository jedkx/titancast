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
    _PortPath(8008, '/ssdp/device-desc.xml'),   // Chromecast, Android TV
    _PortPath(8080, '/description.xml'),         // Generic smart TV
    _PortPath(80,   '/description.xml'),         // LG WebOS, Samsung
    _PortPath(49152, '/description.xml'),        // UPnP dynamic port
    _PortPath(49153, '/description.xml'),        // UPnP dynamic port
  ];

  static const List<int> _probePorts = [
    4352,               // PJLink — Epson, Sony, Panasonic, BenQ, Optoma, NEC, JVC
    3629,               // Epson ESC/VP.net
    1925, 1926,         // Philips JointSpace
    8008, 8080,         // Chromecast / Android TV
    80, 443,            // HTTP / HTTPS
    53484,              // Sony PJ Talk
    49152, 49153,       // UPnP dynamic ports
  ];

  StreamController<DiscoveredDevice>? _controller;
  bool _isActive = false;

  /// Attempts to identify the device at [ip].
  /// Returns a single-emission stream that closes when resolution completes.
  Stream<DiscoveredDevice> resolve({
    required String ip,
    Duration timeout = const Duration(seconds: 20),
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

    if (!_isActive) return;
    final projDevice = await _tryPJLink(ip);
    if (projDevice != null) {
      _emit(projDevice);
      return;
    }

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
    final completer = Completer<int?>();
    int remaining = ports.length;

    for (final port in ports) {
      Socket.connect(ip, port, timeout: _socketTimeout).then((socket) {
        socket.destroy();
        if (!completer.isCompleted) completer.complete(port);
      }).catchError((_) {
        remaining--;
        if (remaining <= 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // PJLink —  (TCP 4352)
  // ---------------------------------------------------------------------------

  Future<DiscoveredDevice?> _tryPJLink(String ip) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip, 4352,
        timeout: const Duration(milliseconds: 800),
      );

      final buffer = StringBuffer();
      await for (final chunk in socket
          .map(utf8.decode)
          .timeout(const Duration(seconds: 2))) {
        buffer.write(chunk);
        if (buffer.toString().contains('\r')) break;
      }

      final greeting = buffer.toString().trim();
      if (!greeting.startsWith('PJLINK')) return null;

      if (greeting.startsWith('PJLINK 1')) {
        socket.destroy();
        return DiscoveredDevice(
          ip: ip,
          friendlyName: 'Projector at $ip',
          method: DiscoveryMethod.manualIp,
          serviceType: 'Projector',
          port: 4352,
        );
      }
      String? name;
      String? manufacturer;
      String? model;

      for (final query in ['%1NAME ?', '%1INF1 ?', '%1INF2 ?']) {
        socket.write('$query\r');
        final resp = StringBuffer();
        await for (final chunk in socket
            .map(utf8.decode)
            .timeout(const Duration(seconds: 2))) {
          resp.write(chunk);
          if (resp.toString().contains('\r')) break;
        }
        final line = resp.toString().trim();
        if (query.contains('NAME')) name = _parsePJLink(line, 'NAME');
        if (query.contains('INF1')) manufacturer = _parsePJLink(line, 'INF1');
        if (query.contains('INF2')) model = _parsePJLink(line, 'INF2');
      }

      socket.destroy();

      return DiscoveredDevice(
        ip: ip,
        friendlyName: name ?? model ?? 'Projector at $ip',
        method: DiscoveryMethod.manualIp,
        manufacturer: manufacturer,
        modelName: model,
        serviceType: 'Projector',
        port: 4352,
      );
    } catch (_) {
      socket?.destroy();
      return null;
    }
  }

  String? _parsePJLink(String raw, String command) {
    final prefix = '%1$command=';
    if (!raw.startsWith(prefix)) return null;
    final value = raw.substring(prefix.length).trim();
    // ERR1/ERR2 hata kodlarını görmezden gel
    if (value.startsWith('ERR') || value.isEmpty) return null;
    return value;
  }

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