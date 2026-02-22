import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../discovery_model.dart';

class NetworkProbeDiscoveryService {
  static const Duration _socketTimeout = Duration(milliseconds: 300);
  static const Duration _httpTimeout = Duration(seconds: 2);

  StreamController<DiscoveredDevice>? _controller;
  final Set<String> _processedIps = {};
  bool _isDiscovering = false;

  Stream<DiscoveredDevice> discover({
    required List<int> ports,
    Duration timeout = const Duration(seconds: 10),
  }) {
    _isDiscovering = true;
    _processedIps.clear();
    _controller = StreamController<DiscoveredDevice>(onCancel: stopDiscovery);
    _startProbing(ports);
    Timer(timeout, stopDiscovery);
    return _controller!.stream;
  }

  void stopDiscovery() {
    _isDiscovering = false;
    if (_controller?.isClosed == false) _controller?.close();
  }

  Future<void> _startProbing(List<int> ports) async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      if (interfaces.isEmpty) return;

      final wifiInterface = interfaces.firstWhere(
            (iface) {
          final name = iface.name.toLowerCase();
          return name.contains('wlan') ||
              name.contains('wifi') ||
              name.contains('en0') ||
              name.contains('wlp');
        },
        orElse: () => interfaces.first,
      );
      final myIp = wifiInterface.addresses.first.address;
      final subnet = myIp.substring(0, myIp.lastIndexOf('.'));

      final futures = <Future>[];
      for (int i = 1; i < 255; i++) {
        if (!_isDiscovering) break;
        final targetIp = '$subnet.$i';
        if (targetIp == myIp) continue;
        futures.add(_checkDevice(targetIp, ports));
        if (i % 25 == 0) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      // Close the stream after all devices have been checked.
      await Future.wait(futures);
    } catch (e) {
      _controller?.addError('Network probe error: $e');
    } finally {
      stopDiscovery();
    }
  }

  Future<void> _checkDevice(String ip, List<int> ports) async {
    for (final port in ports) {
      if (!_isDiscovering || _processedIps.contains(ip)) return;
      try {
        final socket = await Socket.connect(ip, port, timeout: _socketTimeout);
        socket.destroy();
        _processedIps.add(ip);
        _handleOpenPort(ip, port);
        break;
      } catch (_) {}
    }
  }

  void _handleOpenPort(String ip, int port) {
    if (_controller?.isClosed == true) return;

    // BUG FIX: serviceType must contain recognizable keywords so the UI
    // can render the correct icon. Use "TV" for known TV ports.
    // The placeholder will be replaced by the resolved device below.
    final placeholder = DiscoveredDevice(
      ip: ip,
      friendlyName: 'Identifying ($ip)...',
      method: DiscoveryMethod.networkProbe,
      // Map known ports to TV-recognizable service type labels.
      serviceType: _serviceTypeForPort(port),
      port: port,
    );
    _controller?.add(placeholder);

    if (port == 1925 || port == 1926) {
      _resolvePhilipsJointSpace(ip, port);
    } else if (port == 8008) {
      _resolveDialDevice(ip);
    } else if (port == 8080) {
      _resolveGenericHttp(ip, port);
    }
  }

  /// Maps a TCP port to a service type string the UI can use for icon selection.
  /// Must contain "TV" or "MediaRenderer" for TV icon to appear.
  String _serviceTypeForPort(int port) {
    return switch (port) {
      1925 || 1926 => 'JointSpace TV',    // Philips
      8008         => 'DIAL TV',          // Chromecast / Android TV
      8080         => 'HTTP TV',          // Generic smart TV
      _            => 'Unknown Device',
    };
  }

  Future<void> _resolvePhilipsJointSpace(String ip, int port) async {
    final protocol = port == 1926 ? 'https' : 'http';
    for (final path in ['/1/system', '/5/system', '/6/system']) {
      if (!_isDiscovering) return;
      try {
        final response = await http
            .get(Uri.parse('$protocol://$ip:$port$path'))
            .timeout(_httpTimeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          _emitIfActive(DiscoveredDevice(
            ip: ip,
            friendlyName: (data['name'] ?? data['model'] ?? 'Philips TV') as String,
            method: DiscoveryMethod.networkProbe,
            manufacturer: 'Philips',
            modelName: data['model'] as String?,
            serviceType: 'JointSpace TV',
            port: port,
          ));
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _resolveDialDevice(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:8008/ssdp/device-desc.xml'))
          .timeout(_httpTimeout);
      if (response.statusCode == 200) {
        final doc = XmlDocument.parse(response.body);
        final name = doc.findAllElements('friendlyName').firstOrNull?.innerText;
        final manufacturer = doc.findAllElements('manufacturer').firstOrNull?.innerText;
        if (name != null) {
          _emitIfActive(DiscoveredDevice(
            ip: ip,
            friendlyName: name,
            method: DiscoveryMethod.networkProbe,
            manufacturer: manufacturer,
            serviceType: 'DIAL TV',
            port: 8008,
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _resolveGenericHttp(String ip, int port) async {
    const paths = ['/description.xml', '/ssdp/device-desc.xml', '/upnp/desc.xml'];
    for (final path in paths) {
      if (!_isDiscovering) return;
      try {
        final response = await http
            .get(Uri.parse('http://$ip:$port$path'))
            .timeout(_httpTimeout);
        if (response.statusCode == 200) {
          final doc = XmlDocument.parse(response.body);
          final name = doc.findAllElements('friendlyName').firstOrNull?.innerText;
          final manufacturer = doc.findAllElements('manufacturer').firstOrNull?.innerText;
          if (name != null) {
            _emitIfActive(DiscoveredDevice(
              ip: ip,
              friendlyName: name,
              method: DiscoveryMethod.networkProbe,
              manufacturer: manufacturer,
              serviceType: 'HTTP TV',
              port: port,
            ));
            return;
          }
        }
      } catch (_) {}
    }
  }

  void _emitIfActive(DiscoveredDevice device) {
    if (_isDiscovering && _controller?.isClosed == false) {
      _controller?.add(device);
    }
  }
}