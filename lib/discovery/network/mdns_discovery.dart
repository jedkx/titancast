import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';
import '../discovery_model.dart';

/// mDNS (Multicast DNS / Bonjour / Zeroconf) discovery service.
///
/// Queries well-known service types over mDNS. Each service type produces
/// PTR -> SRV -> A record lookups to resolve hostname to IP, then TXT records
/// to extract metadata like friendly name and manufacturer.
///
/// Priority: Secondary to SSDP. The [DiscoveryManager] will accept mDNS results
/// only if SSDP has not already captured the same IP with richer data.
class MdnsDiscoveryService {
  // Each entry is a well-known mDNS service type.
  // Ordered roughly by prevalence in living room devices.
  static const List<String> _serviceTypes = [
    '_googlecast._tcp.local',       // Chromecast, Android TV, Google TV
    '_airplay._tcp.local',          // Apple TV, AirPlay receivers
    '_spotify-connect._tcp.local',  // Spotify-enabled speakers and TVs
    '_dlna-wss._tcp.local',         // DLNA devices that advertise over mDNS
  ];

  MDnsClient? _client;
  StreamController<DiscoveredDevice>? _controller;
  bool _isDiscovering = false;

  Stream<DiscoveredDevice> discover({
    Duration timeout = const Duration(seconds: 12),
  }) {
    _cleanup();
    _isDiscovering = true;
    _controller = StreamController<DiscoveredDevice>(onCancel: stopDiscovery);
    _startDiscovery(timeout);
    return _controller!.stream;
  }

  void stopDiscovery() => _cleanup();

  Future<void> _startDiscovery(Duration timeout) async {
    try {
      _client = MDnsClient();
      await _client!.start();

      for (final serviceType in _serviceTypes) {
        if (!_isDiscovering) break;
        await _discoverService(serviceType);
      }

      // Let the timeout drive stream closure rather than closing immediately
      // after iterating -- some slow devices may still respond.
      Future.delayed(timeout, () {
        if (_isDiscovering) stopDiscovery();
      });
    } catch (e) {
      _controller?.addError('mDNS error: $e');
      stopDiscovery();
    }
  }

  Future<void> _discoverService(String serviceType) async {
    try {
      await for (final PtrResourceRecord ptr in _client!
          .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(serviceType))) {
        if (!_isDiscovering) break;

        await for (final SrvResourceRecord srv in _client!
            .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName))) {
          if (!_isDiscovering) break;

          // Resolve the hostname to an IPv4 address.
          String? ip;
          await for (final IPAddressResourceRecord ipRecord in _client!
              .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target))) {
            ip = ipRecord.address.address;
            break; // First address is sufficient.
          }

          if (ip == null || ip.isEmpty) continue;

          // TXT records carry device metadata in key=value pairs.
          final metadata = <String, String>{};
          await for (final TxtResourceRecord txt in _client!
              .lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(ptr.domainName))) {
            metadata.addAll(_parseTxtRecord(txt.text));
          }

          final device = DiscoveredDevice(
            ip: ip,
            // 'fn' is the standard Chromecast/Cast TXT key for friendly name.
            // Fall back to the SRV hostname without the domain suffix.
            friendlyName:
            metadata['fn'] ?? srv.target.split('.').first,
            method: DiscoveryMethod.mdns,
            manufacturer: metadata['ma'] ??
                metadata['vendor'] ??
                _inferManufacturer(serviceType),
            modelName: metadata['md'] ?? metadata['model'],
            // Produce a short readable label from the service type string.
            serviceType: _shortServiceLabel(serviceType),
          );

          if (_isDiscovering && _controller?.isClosed == false) {
            _controller?.add(device);
          }
        }
      }
    } catch (e) {
      // Per-service errors are non-fatal; continue with remaining service types.
      _controller?.addError('mDNS service error ($serviceType): $e');
    }
  }

  /// Parses a raw TXT record string into a key-value map.
  /// TXT records are newline-separated "key=value" pairs.
  Map<String, String> _parseTxtRecord(String txt) {
    final result = <String, String>{};
    for (final line in txt.split('\n')) {
      if (line.isEmpty) continue;
      final index = line.indexOf('=');
      if (index < 1) continue;
      result[line.substring(0, index).toLowerCase()] =
          line.substring(index + 1);
    }
    return result;
  }

  /// Returns a short human-readable label for the service type.
  /// e.g. "_googlecast._tcp.local" -> "Googlecast"
  String _shortServiceLabel(String serviceType) {
    final raw = serviceType.split('.').first.replaceAll('_', '');
    return raw[0].toUpperCase() + raw.substring(1);
  }

  /// Infers the manufacturer from the service type as a last resort.
  String _inferManufacturer(String serviceType) {
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
    if (_controller?.isClosed == false) _controller?.close();
  }
}