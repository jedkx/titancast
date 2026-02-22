import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'discovery_model.dart';

/// A robust, stream-based SSDP (Simple Service Discovery Protocol) scanner.
class SsdpDiscoveryService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _port = 1900;
  static const Duration _httpTimeout = Duration(seconds: 2);

  RawDatagramSocket? _socket;
  StreamController<DiscoveredDevice>? _controller;
  Timer? _discoveryTimer;

  final Set<String> _processedIps = {};
  bool _isDiscovering = false;

  final List<String> _searchTargets = [
    'ssdp:all',
    'upnp:rootdevice',
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'urn:dial-multiscreen-org:service:dial:1',
  ];

  Stream<DiscoveredDevice> discover({Duration timeout = const Duration(seconds: 10)}) {
    print("SSDP: Starting discovery"); // use log in production
    _cleanup();
    _controller = StreamController<DiscoveredDevice>(onCancel: stopDiscovery);
    _isDiscovering = true;
    _processedIps.clear();
    _startDiscoveryProcess(timeout);
    
    return _controller!.stream;
  }

  void stopDiscovery() {
    print("SSDP: Stopping discovery"); // use log in production
    _cleanup();
  }

  Future<void> _startDiscoveryProcess(Duration timeout) async {
    try {
      // Fix: Improved socket binding for Android to avoid reusePort issues
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 
        0, 
        reuseAddress: true
      );
      _socket?.broadcastEnabled = true;
      _socket?.multicastLoopback = false;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read && _isDiscovering) {
          final datagram = _socket?.receive();
          if (datagram != null) _handleDatagram(datagram);
        }
      });

      _sendSearchPackets();
      _discoveryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_isDiscovering) {
          _sendSearchPackets();
        } else {
          timer.cancel();
        }
      });

      Timer(timeout, () {
        if (_isDiscovering) stopDiscovery();
      });
    } catch (e) {
      print("SSDP Socket Error: $e"); // use log in production
      _addError("SSDP Socket Error: $e");
      stopDiscovery();
    }
  }

  void _sendSearchPackets() {
    for (var target in _searchTargets) {
      final message = _buildSearchMessage(target);
      try {
        _socket?.send(utf8.encode(message), InternetAddress(_multicastAddress), _port);
      } catch (e) {
        print("SSDP: Failed to send packet for $target: $e"); // use log in production
      }
    }
  }

  void _handleDatagram(Datagram datagram) {
    final ip = datagram.address.address;
    try {
      final response = utf8.decode(datagram.data);
      final headers = _parseHeaders(response);
      final location = headers['LOCATION'];

      if (location != null && !_processedIps.contains(ip)) {
        print("SSDP: Found potential device at $ip"); // use log in production
        _processedIps.add(ip);
        _resolveDeviceDetails(ip, location, headers);
      }
    } catch (_) {}
  }

  Future<void> _resolveDeviceDetails(String ip, String location, Map<String, String> headers) async {
    try {
      final response = await http.get(Uri.parse(location)).timeout(_httpTimeout);
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final rawType = _extractXml(document, 'deviceType');
        
        final device = DiscoveredDevice(
          ip: ip,
          friendlyName: _extractXml(document, 'friendlyName') ?? "Smart Device",
          method: DiscoveryMethod.ssdp,
          location: location,
          manufacturer: _extractXml(document, 'manufacturer'),
          modelName: _extractXml(document, 'modelName'),
          serviceType: _cleanServiceType(rawType),
          rawHeaders: headers,
        );
        
        if (_isDiscovering && _controller?.isClosed == false) {
          print("SSDP: Resolved details for ${device.friendlyName} ($ip)"); // use log in production
          _controller?.add(device);
        }
      }
    } catch (e) {
      print("SSDP: Failed to resolve details for $ip: $e"); // use log in production
    }
  }

  String? _cleanServiceType(String? raw) {
    if (raw == null) return null;
    if (!raw.startsWith("urn:")) return raw;
    final parts = raw.split(':');
    if (parts.length >= 2) return parts[parts.length - 2];
    return raw;
  }

  String? _extractXml(XmlDocument doc, String name) => doc.findAllElements(name).firstOrNull?.innerText;

  String _buildSearchMessage(String target) {
    return 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $_multicastAddress:$_port\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 3\r\n'
        'ST: $target\r\n'
        'USER-AGENT: TitanCast/1.0\r\n'
        '\r\n';
  }

  Map<String, String> _parseHeaders(String raw) {
    final headers = <String, String>{};
    for (final line in raw.split('\r\n')) {
      final index = line.indexOf(':');
      if (index > 0) headers[line.substring(0, index).trim().toUpperCase()] = line.substring(index + 1).trim();
    }
    return headers;
  }

  void _addError(String msg) {
    if (_controller?.isClosed == false) _controller?.addError(msg);
  }

  void _cleanup() {
    _isDiscovering = false;
    _discoveryTimer?.cancel();
    _socket?.close();
    _socket = null;
    if (_controller?.isClosed == false) {
      _controller?.close();
    }
  }
}
