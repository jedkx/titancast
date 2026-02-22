import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../discovery_model.dart';

/// A robust, stream-based SSDP (Simple Service Discovery Protocol) scanner.
///
/// SSDP sends M-SEARCH multicast packets to 239.255.255.250:1900 and listens
/// for HTTP-like responses. When a device responds, we fetch its UPnP device
/// description XML (the LOCATION header URL) to get the rich metadata.
///
/// Priority: SSDP is the highest-quality source in the discovery pipeline.
/// The [DiscoveryManager] will never downgrade an SSDP result to a lower-quality one.
class SsdpDiscoveryService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _port = 1900;
  static const Duration _httpTimeout = Duration(seconds: 2);

  RawDatagramSocket? _socket;
  StreamController<DiscoveredDevice>? _controller;
  Timer? _retryTimer;

  final Set<String> _processedIps = {};
  bool _isDiscovering = false;

  // We search for multiple service types to maximize device coverage.
  // 'ssdp:all' is a broad sweep; the rest target specific device classes.
  final List<String> _searchTargets = [
    'ssdp:all',
    'upnp:rootdevice',
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'urn:dial-multiscreen-org:service:dial:1',
  ];

  Stream<DiscoveredDevice> discover({
    Duration timeout = const Duration(seconds: 10),
  }) {
    _cleanup();
    _isDiscovering = true;
    _processedIps.clear();
    _controller = StreamController<DiscoveredDevice>(onCancel: stopDiscovery);
    _startDiscoveryProcess(timeout);
    return _controller!.stream;
  }

  void stopDiscovery() => _cleanup();

  Future<void> _startDiscoveryProcess(Duration timeout) async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: false,
      );
      _socket?.broadcastEnabled = true;
      _socket?.multicastLoopback = false;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read && _isDiscovering) {
          final datagram = _socket?.receive();
          if (datagram != null) _handleDatagram(datagram);
        }
      });

      // Send immediately, then repeat every 2 seconds.
      // Some devices only respond to later packets after waking their network stack.
      _sendSearchPackets();
      _retryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_isDiscovering) _sendSearchPackets();
      });

      Timer(timeout, stopDiscovery);
    } catch (e) {
      print('SSDP socket error: $e');
      _cleanup();
    }
  }

  void _sendSearchPackets() {
    for (final target in _searchTargets) {
      try {
        _socket?.send(
          utf8.encode(_buildSearchMessage(target)),
          InternetAddress(_multicastAddress),
          _port,
        );
      } catch (_) {
        // Individual packet failures are non-fatal; other targets may still succeed.
      }
    }
  }

  void _handleDatagram(Datagram datagram) {
    final ip = datagram.address.address;
    if (_processedIps.contains(ip)) return;

    try {
      final response = utf8.decode(datagram.data);
      final headers = _parseHeaders(response);
      final location = headers['LOCATION'];

      if (location != null) {
        _processedIps.add(ip);
        _resolveDeviceDetails(ip, location, headers);
      }
    } catch (_) {}
  }

  Future<void> _resolveDeviceDetails(
      String ip,
      String location,
      Map<String, String> headers,
      ) async {
    try {
      final response =
      await http.get(Uri.parse(location)).timeout(_httpTimeout);

      if (response.statusCode != 200) return;

      final document = XmlDocument.parse(response.body);

      final device = DiscoveredDevice(
        ip: ip,
        friendlyName:
        _extractXml(document, 'friendlyName') ?? 'Smart Device',
        method: DiscoveryMethod.ssdp,
        location: location,
        manufacturer: _extractXml(document, 'manufacturer'),
        modelName: _extractXml(document, 'modelName'),
        serviceType: _cleanServiceType(_extractXml(document, 'deviceType')),
        rawHeaders: headers,
      );

      if (_isDiscovering && _controller?.isClosed == false) {
        _controller?.add(device);
      }
    } catch (_) {
      // Network or parse failure -- silently skip this device.
    }
  }

  /// Converts a full UPnP deviceType URN into a short readable label.
  /// e.g. "urn:schemas-upnp-org:device:MediaRenderer:1" -> "MediaRenderer"
  String? _cleanServiceType(String? raw) {
    if (raw == null) return null;
    if (!raw.startsWith('urn:')) return raw;
    final parts = raw.split(':');
    return parts.length >= 2 ? parts[parts.length - 2] : raw;
  }

  String? _extractXml(XmlDocument doc, String tag) =>
      doc.findAllElements(tag).firstOrNull?.innerText;

  String _buildSearchMessage(String target) =>
      'M-SEARCH * HTTP/1.1\r\n'
          'HOST: $_multicastAddress:$_port\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: $target\r\n'
          'USER-AGENT: TitanCast/1.0\r\n'
          '\r\n';

  Map<String, String> _parseHeaders(String raw) {
    final headers = <String, String>{};
    for (final line in raw.split('\r\n')) {
      final index = line.indexOf(':');
      if (index > 0) {
        headers[line.substring(0, index).trim().toUpperCase()] =
            line.substring(index + 1).trim();
      }
    }
    return headers;
  }

  void _cleanup() {
    _isDiscovering = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _socket?.close();
    _socket = null;
    if (_controller?.isClosed == false) _controller?.close();
  }
}