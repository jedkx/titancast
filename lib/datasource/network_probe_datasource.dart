import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'discovery_model.dart';

/// A generic discovery service that identifies devices by probing specific TCP ports.
/// This service is designed to be extensible for different TV brands (Sony, LG, Philips, etc.).
class NetworkProbeDiscoveryService {
  final Duration _httpTimeout = const Duration(seconds: 2);
  final Duration _socketTimeout = const Duration(milliseconds: 300);
  
  StreamController<DiscoveredDevice>? _controller;
  final Set<String> _processedIps = {};
  bool _isDiscovering = false;

  /// Starts a parallel port probe on the local subnet.
  /// [ports] list allows targeting multiple device types simultaneously.
  Stream<DiscoveredDevice> discover({
    required List<int> ports,
    Duration timeout = const Duration(seconds: 10),
  }) {
    print("Network Probe: Starting discovery on ports $ports"); // use log in production
    
    _isDiscovering = true;
    _processedIps.clear();
    _controller = StreamController<DiscoveredDevice>(onCancel: stopDiscovery);

    _startProbing(ports);

    Timer(timeout, () {
      if (_isDiscovering) stopDiscovery();
    });
    
    return _controller!.stream;
  }

  void stopDiscovery() {
    print("Network Probe: Stopping discovery"); // use log in production
    _isDiscovering = false;
    if (_controller?.isClosed == false) {
      _controller?.close();
    }
  }

  Future<void> _startProbing(List<int> ports) async {
    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.IPv4);
      if (interfaces.isEmpty) return;

      final myIp = interfaces.first.addresses.first.address;
      final subnet = myIp.substring(0, myIp.lastIndexOf('.'));

      print("Network Probe: Probing subnet $subnet.1-255"); // use log in production

      for (int i = 1; i < 255; i++) {
        if (!_isDiscovering) break;
        final targetIp = '$subnet.$i';
        if (targetIp == myIp) continue;

        _checkDevice(targetIp, ports);
        
        // Prevent socket flooding by introducing small delays every batch
        if (i % 25 == 0) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      print("Network Probe Error: $e"); // use log in production
      if (_controller?.isClosed == false) _controller?.addError(e);
    }
  }

  Future<void> _checkDevice(String ip, List<int> ports) async {
    for (var port in ports) {
      if (!_isDiscovering || _processedIps.contains(ip)) return;

      try {
        final socket = await Socket.connect(ip, port, timeout: _socketTimeout);
        socket.destroy();

        print("Network Probe: Port $port is OPEN at $ip"); // use log in production
        _handleDeviceFound(ip, port);
        break; 
      } catch (_) {}
    }
  }

  void _handleDeviceFound(String ip, int port) {
    if (_processedIps.contains(ip)) return;
    _processedIps.add(ip);

    // Default entry while resolving details
    final device = DiscoveredDevice(
      ip: ip,
      friendlyName: "Identifying Device ($ip)...",
      method: DiscoveryMethod.manual,
      serviceType: "Port $port",
    );
    
    if (_isDiscovering && _controller?.isClosed == false) {
      _controller?.add(device);
      
      // Port-based Resolvers
      if (port == 1925 || port == 1926) {
        _resolvePhilipsJointSpace(ip, port);
      } else if (port == 8008) {
        _resolveDialDevice(ip);
      }
    }
  }

  Future<void> _resolvePhilipsJointSpace(String ip, int port) async {
    final paths = ['/1/system', '/5/system', '/6/system'];
    final protocol = port == 1926 ? "https" : "http";

    for (var path in paths) {
      if (!_isDiscovering) return;
      try {
        final response = await http.get(Uri.parse('$protocol://$ip:$port$path')).timeout(_httpTimeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (_isDiscovering && _controller?.isClosed == false) {
            print("Network Probe: Philips JointSpace resolved for $ip"); // use log in production
            _controller?.add(DiscoveredDevice(
              ip: ip,
              friendlyName: data['name'] ?? data['model'] ?? "Philips TV",
              method: DiscoveryMethod.manual,
              manufacturer: "Philips",
              modelName: data['model'],
              serviceType: "JointSpace TV",
            ));
          }
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _resolveDialDevice(String ip) async {
    try {
      final response = await http.get(Uri.parse('http://$ip:8008/ssdp/device-desc.xml')).timeout(_httpTimeout);
      if (response.statusCode == 200) {
        final doc = XmlDocument.parse(response.body);
        final name = doc.findAllElements('friendlyName').firstOrNull?.innerText;
        final manufacturer = doc.findAllElements('manufacturer').firstOrNull?.innerText;
        
        if (name != null && _isDiscovering && _controller?.isClosed == false) {
          print("Network Probe: DIAL device resolved for $ip"); // use log in production
          _controller?.add(DiscoveredDevice(
            ip: ip,
            friendlyName: name,
            method: DiscoveryMethod.manual,
            manufacturer: manufacturer ?? "Unknown",
            serviceType: "DIAL Device",
          ));
        }
      }
    } catch (_) {}
  }
}
