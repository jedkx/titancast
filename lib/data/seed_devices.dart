import '../discovery/discovery_model.dart';
import 'device_repository.dart';


Future<void> seedDummyDevices(DeviceRepository repo) async {
  if (repo.devices.isNotEmpty) return;

  final now = DateTime.now();

  final devices = [
    DiscoveredDevice(
      ip: '192.168.1.101',
      friendlyName: 'Samsung Living Room',
      method: DiscoveryMethod.ssdp,
      manufacturer: 'Samsung',
      modelName: 'QN85A',
      serviceType: 'MediaRenderer TV',
      port: 8001,
      ssid: 'HomeNetwork',
      addedAt: now.subtract(const Duration(days: 2)),
    ),
    DiscoveredDevice(
      ip: '192.168.1.102',
      friendlyName: 'LG Bedroom',
      method: DiscoveryMethod.mdns,
      manufacturer: 'LG',
      modelName: 'C2 OLED',
      serviceType: 'DIAL TV',
      port: 3000,
      ssid: 'HomeNetwork',
      addedAt: now.subtract(const Duration(days: 1)),
    ),
    DiscoveredDevice(
      ip: '192.168.1.103',
      friendlyName: 'Philips Hue Bridge',
      method: DiscoveryMethod.networkProbe,
      manufacturer: 'Philips',
      modelName: 'BSB002',
      serviceType: 'JointSpace TV',
      port: 1925,
      ssid: 'HomeNetwork',
      addedAt: now.subtract(const Duration(hours: 5)),
    ),
    // Second SSID — triggers grouped list view
    DiscoveredDevice(
      ip: '10.0.0.55',
      friendlyName: 'Sony Bravia Office',
      method: DiscoveryMethod.ssdp,
      manufacturer: 'Sony',
      modelName: 'XR-55A80K',
      serviceType: 'MediaRenderer TV',
      port: 10000,
      ssid: 'OfficeWiFi',
      addedAt: now.subtract(const Duration(hours: 2)),
    ),
    DiscoveredDevice(
      ip: '10.0.0.56',
      friendlyName: 'Chromecast Ultra',
      method: DiscoveryMethod.mdns,
      manufacturer: 'Google',
      serviceType: 'DIAL TV',
      port: 8008,
      ssid: 'OfficeWiFi',
      addedAt: now.subtract(const Duration(hours: 1)),
    ),
  ];

  for (final d in devices) {
    await repo.save(d);
  }
}