enum DiscoveryMode { network, manualIp, qrScan }

enum DiscoveryMethod { ssdp, mdns, networkProbe, manualIp, qr }

class DiscoveredDevice {
  final String ip;
  final String friendlyName;
  final DiscoveryMethod method;
  final String? location;
  final String? serviceType;
  final String? manufacturer;
  final String? modelName;
  final int? port;
  final Map<String, dynamic> rawHeaders;

  const DiscoveredDevice({
    required this.ip,
    required this.friendlyName,
    required this.method,
    this.location,
    this.serviceType,
    this.manufacturer,
    this.modelName,
    this.port,
    this.rawHeaders = const {},
  });

  /// Creates a modified copy of this device with the given fields replaced.
  ///
  /// Used by [DiscoveryManager] to upgrade a placeholder device with richer data
  /// (e.g. probe found the IP, SSDP later provided the friendly name).
  DiscoveredDevice copyWith({
    String? ip,
    String? friendlyName,
    DiscoveryMethod? method,
    String? location,
    String? serviceType,
    String? manufacturer,
    String? modelName,
    int? port,
    Map<String, dynamic>? rawHeaders,
  }) {
    return DiscoveredDevice(
      ip: ip ?? this.ip,
      friendlyName: friendlyName ?? this.friendlyName,
      method: method ?? this.method,
      location: location ?? this.location,
      serviceType: serviceType ?? this.serviceType,
      manufacturer: manufacturer ?? this.manufacturer,
      modelName: modelName ?? this.modelName,
      port: port ?? this.port,
      rawHeaders: rawHeaders ?? this.rawHeaders,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DiscoveredDevice &&
              runtimeType == other.runtimeType &&
              ip == other.ip;

  @override
  int get hashCode => ip.hashCode;

  @override
  String toString() =>
      'DiscoveredDevice(ip: $ip, name: $friendlyName, method: ${method.name})';
}
