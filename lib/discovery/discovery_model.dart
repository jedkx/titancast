import '../remote/tv_brand.dart';

enum DiscoveryMode { network, manualIp, qrScan }

enum DiscoveryMethod { ssdp, mdns, networkProbe, manualIp, qr }

enum DeviceType { tv, speaker, modem, other }

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

  /// Populated by [DeviceRepository.save] after [BrandDetector.detect] runs.
  /// Null for devices that haven't been through detection yet.
  /// Persisted to JSON so detection doesn't re-run on every launch.
  final TvBrand? detectedBrand;

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
    this.detectedBrand,
  }) : addedAt = addedAt ?? DateTime.now();

  String get displayName => customName ?? friendlyName;

  DeviceType get deviceType {
    final type = (serviceType ?? '').toLowerCase();
    final name = friendlyName.toLowerCase();
    final mfr  = (manufacturer ?? '').toLowerCase();

    // ── Modem / Router / Gateway detection ──────────────────────────────────
    // Eliminates false positives like "Archer C6", "Internet Home Gateway Device"
    if (type.contains('internetgateway') ||
        type.contains('gateway') ||
        type.contains('wandevice') ||
        name.contains('router') ||
        name.contains('gateway') ||
        name.contains('modem') ||
        name.contains('archer') ||
        name.contains('dsl') ||
        name.contains('wifi router') ||
        name.contains('wi-fi router') ||
        mfr == 'tp-link' ||
        mfr == 'zte' ||
        mfr == 'huawei' ||
        mfr == 'arris' ||
        mfr == 'technicolor' ||
        mfr == 'sagemcom' ||
        mfr == 'nokia' && type.contains('gateway')) {
      return DeviceType.modem;
    }
    // ── TV detection ─────────────────────────────────────────────────────────
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
    // ── Speaker detection ────────────────────────────────────────────────────
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

  /// True if this device should be shown in the device list.
  /// Modems/routers are hidden by default since they can't be controlled.
  bool get isControllable => deviceType != DeviceType.modem;

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
    TvBrand? detectedBrand,
    bool clearDetectedBrand = false,
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
      detectedBrand: clearDetectedBrand
          ? null
          : (detectedBrand ?? this.detectedBrand),
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
    'detectedBrand': detectedBrand?.name,
  };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    final brandName = json['detectedBrand'] as String?;
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
      detectedBrand: brandName != null
          ? TvBrand.values.firstWhere(
            (e) => e.name == brandName,
        orElse: () => TvBrand.unknown,
      )
          : null,
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
      'DiscoveredDevice(ip: $ip, name: $displayName, brand: ${detectedBrand?.name}, method: ${method.name})';
}