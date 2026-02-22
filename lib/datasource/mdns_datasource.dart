
import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';
import 'discovery_model.dart';

/// Standard-compliant mDNS device discovery service
class MdnsDiscoveryService {
  static const List<String> _serviceTypes = [
    '_googlecast._tcp.local',
    '_airplay._tcp.local',
    '_spotify-connect._tcp.local',
    '_dlna-wss._tcp.local',
  ];

  MDnsClient? _client;
  StreamController<DiscoveredDevice>? _controller;
  bool _isDiscovering = false;

  /// Starts device discovery and returns a stream of discovered devices.
  Stream<DiscoveredDevice> discover({Duration timeout = const Duration(seconds: 12)}) {
    _cleanup();
    _controller = StreamController<DiscoveredDevice>(onCancel: stopDiscovery);
    _isDiscovering = true;
    _startDiscovery(timeout);
    return _controller!.stream;
  }

  /// Stops discovery and cleans up resources.
  void stopDiscovery() {
    _cleanup();
  }

  Future<void> _startDiscovery(Duration timeout) async {
    try {
      _client = MDnsClient();
      await _client!.start();

      for (final serviceType in _serviceTypes) {
        if (!_isDiscovering) break;
        await _discoverService(serviceType);
      }

      Future.delayed(timeout, () {
        if (_isDiscovering) stopDiscovery();
      });
    } catch (e) {
      _controller?.addError('mDNS Error: $e');
      stopDiscovery();
    }
  }

  Future<void> _discoverService(String serviceType) async {
    try {
      await for (final PtrResourceRecord ptr in _client!.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(serviceType))) {
        if (!_isDiscovering) break;

        await for (final SrvResourceRecord srv in _client!.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
          if (!_isDiscovering) break;

          String? ip;
          await for (final IPAddressResourceRecord ipRecord in _client!.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))) {
            ip = ipRecord.address.address;
            break;
          }

          Map<String, String> metadata = {};
          await for (final TxtResourceRecord txt in _client!.lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))) {
            metadata.addAll(_parseTxtRecord(txt.text));
          }

          final device = DiscoveredDevice(
            ip: ip ?? '',
            friendlyName: metadata['fn'] ?? srv.target.split('.').first,
            method: DiscoveryMethod.mdns,
            manufacturer: metadata['ma'] ?? metadata['vendor'] ?? _fallbackManufacturer(serviceType),
            modelName: metadata['md'] ?? metadata['model'],
            serviceType: serviceType.split('.').first.replaceAll('_', '').toUpperCase(),
          );

          if (_isDiscovering && _controller?.isClosed == false) {
            _controller?.add(device);
          }
        }
      }
    } catch (e) {
      _controller?.addError('Service discovery error: $e');
    }
  }

  Map<String, String> _parseTxtRecord(String txt) {
    final Map<String, String> result = {};
    for (final line in txt.split('\n')) {
      if (line.isEmpty) continue;
      final parts = line.split('=');
      if (parts.length < 2) continue;
      result[parts[0].toLowerCase()] = parts[1];
    }
    return result;
  }

  String _fallbackManufacturer(String serviceType) {
    if (serviceType.contains('googlecast')) return 'Google';
    if (serviceType.contains('airplay')) return 'Apple';
    if (serviceType.contains('spotify')) return 'Spotify';
    if (serviceType.contains('dlna')) return 'DLNA';
    return 'Unknown';
  }

  void _cleanup() {
    _isDiscovering = false;
    _client?.stop();
    _client = null;
    if (_controller?.isClosed == false) {
      _controller?.close();
    }
  }
}
