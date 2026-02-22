enum DiscoveryMode { network, manualIp, qrScan }

enum DiscoveryMethod { ssdp, mdns, networkProbe, manualIp, qr }

enum DeviceType { tv, speaker, other }

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
  final String? ssid;
  final String? customName;
  final DateTime addedAt;

  DiscoveredDevice({
    required this.ip,
    required this.friendlyName,
    required this.method,
    this.location,
    this.serviceType,
    this.manufacturer,
    this.modelName,
    this.port,
    this.rawHeaders = const {},
    this.ssid,
    this.customName,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  String get displayName => customName ?? friendlyName;

  // Derives device type from serviceType and friendlyName for filtering and
  // icon resolution. Centralised here so UI and filter logic stay in sync.
  DeviceType get deviceType {
    final type = (serviceType ?? '').toLowerCase();
    final name = friendlyName.toLowerCase();

    if (type.contains('tv') ||
        type.contains('renderer') ||
        type.contains('dial') ||
        type.contains('jointspace') ||
        name.contains('tv') ||
        name.contains('chromecast') ||
        name.contains('bravia') ||
        name.contains('fire')) {
      return DeviceType.tv;
    }
    if (type.contains('audio') ||
        type.contains('speaker') ||
        name.contains('speaker') ||
        name.contains('soundbar') ||
        name.contains('sonos') ||
        name.contains('homepod')) {
      return DeviceType.speaker;
    }
    return DeviceType.other;
  }

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
    String? ssid,
    String? customName,
    bool clearCustomName = false,
    DateTime? addedAt,
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
      ssid: ssid ?? this.ssid,
      customName: clearCustomName ? null : (customName ?? this.customName),
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'friendlyName': friendlyName,
    'method': method.name,
    'location': location,
    'serviceType': serviceType,
    'manufacturer': manufacturer,
    'modelName': modelName,
    'port': port,
    'ssid': ssid,
    'customName': customName,
    'addedAt': addedAt.toIso8601String(),
    // rawHeaders intentionally excluded — large and re-fetched on connect
  };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      ip: json['ip'] as String,
      friendlyName: json['friendlyName'] as String,
      method: DiscoveryMethod.values.firstWhere(
            (e) => e.name == json['method'],
        orElse: () => DiscoveryMethod.manualIp,
      ),
      location: json['location'] as String?,
      serviceType: json['serviceType'] as String?,
      manufacturer: json['manufacturer'] as String?,
      modelName: json['modelName'] as String?,
      port: json['port'] as int?,
      ssid: json['ssid'] as String?,
      customName: json['customName'] as String?,
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
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
      'DiscoveredDevice(ip: $ip, name: $displayName, ssid: $ssid, method: ${method.name})';
}