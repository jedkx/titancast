import 'dart:async';
import 'discovery_model.dart';
import 'ssdp_datasource.dart';
import 'network_probe_datasource.dart';
import 'mdns_datasource.dart';

class DiscoveryManager {
  final _ssdpService = SsdpDiscoveryService();
  final _probeService = NetworkProbeDiscoveryService();
  final _mdnsService = MdnsDiscoveryService();
  
  StreamController<DiscoveredDevice>? _mainController;
  final Map<String, DiscoveredDevice> _deviceCache = {};

  Stream<DiscoveredDevice> startDiscovery({Duration timeout = const Duration(seconds: 15)}) {
    print("Discovery: Starting SSDP-First smart session"); // use log in production
    
    _deviceCache.clear();
    _mainController = StreamController<DiscoveredDevice>();

    // 1. Start SSDP immediately (Highest quality data)
    _ssdpService.discover(timeout: timeout).listen(_processDevice);

    // 2. Fallbacks: Process mDNS and Probing only for devices not yet captured by SSDP
    _mdnsService.discover(timeout: timeout).listen(_processDevice);
    
    // Slight delay for Port Probing to let SSDP capture most devices first
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_mainController?.isClosed == false) {
        _probeService.discover(
          ports: [1925, 1926, 8008, 8080], 
          timeout: timeout
        ).listen(_processDevice);
      }
    });

    Timer(timeout, () {
      if (_mainController?.isClosed == false) _mainController?.close();
    });

    return _mainController!.stream;
  }

  void _processDevice(DiscoveredDevice newDevice) {
    if (_mainController?.isClosed == true) return;

    final existing = _deviceCache[newDevice.ip];

    if (existing == null) {
      // First time finding this IP - Accept it
      _deviceCache[newDevice.ip] = newDevice;
      _mainController?.add(newDevice);
    } else {
      // If we already have a device at this IP, check if the NEW one is better
      // IMPORTANT: If current device is SSDP, we NEVER downgrade it to mDNS or Manual
      if (existing.method == DiscoveryMethod.ssdp) {
        // SSDP is the master record. Only update if friendlyName was a placeholder
        if (existing.friendlyName.contains("...") && !newDevice.friendlyName.contains("...")) {
          _deviceCache[newDevice.ip] = newDevice;
          _mainController?.add(newDevice);
        }
        return; // Don't allow mDNS or Manual to overwrite SSDP
      }

      // If existing was a fallback (mDNS/Manual) and NEW is SSDP, always UPGRADE
      if (newDevice.method == DiscoveryMethod.ssdp) {
        print("Discovery: Upgrading ${newDevice.ip} to rich SSDP data"); // use log in production
        _deviceCache[newDevice.ip] = newDevice;
        _mainController?.add(newDevice);
        return;
      }

      // Fallback-to-Fallback enrichment (e.g., brand found)
      if (existing.manufacturer == null && newDevice.manufacturer != null) {
        _deviceCache[newDevice.ip] = newDevice;
        _mainController?.add(newDevice);
      }
    }
  }

  void stopDiscovery() {
    _ssdpService.stopDiscovery();
    _probeService.stopDiscovery();
    _mdnsService.stopDiscovery();
    if (_mainController?.isClosed == false) _mainController?.close();
  }
}
