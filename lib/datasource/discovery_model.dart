enum DiscoveryMethod { ssdp, mdns, manual }

class DiscoveredDevice {
  final String ip;
  final String? location; // SSDP XML URL
  final String? serviceType; // urn:schemas-upnp-org:device:MediaRenderer:1 vb.
  final String friendlyName;
  final String? manufacturer;
  final String? modelName;
  final DiscoveryMethod method;
  final Map<String, dynamic> rawHeaders;

  DiscoveredDevice({
    required this.ip,
    required this.friendlyName,
    required this.method,
    this.location,
    this.serviceType,
    this.manufacturer,
    this.modelName,
    this.rawHeaders = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          (ip == other.ip && friendlyName == other.friendlyName);

  @override
  int get hashCode => ip.hashCode ^ friendlyName.hashCode;
}
