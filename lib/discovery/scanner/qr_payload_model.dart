/// Represents the structured data encoded inside a TitanCast QR code.
///
/// The TV-side app encodes this as a JSON string, which the phone scans and
/// parses via [QrPayloadModel.fromJson].
///
/// Example JSON encoded in the QR:
/// {
///   "v": 1,
///   "ip": "192.168.1.42",
///   "port": 8080,
///   "name": "Living Room TV",
///   "manufacturer": "Samsung",
///   "model": "QN85A",
///   "protocol": "samsung_tizen"
/// }
///
/// The "v" (version) field allows backwards-compatible schema evolution.
/// If a future TV app adds new fields, old phone apps ignore them gracefully.
class QrPayloadModel {
  /// Schema version. Current version is 1.
  final int version;

  /// IPv4 address of the TV on the local network.
  final String ip;

  /// Port the TV's remote control service listens on.
  final int port;

  /// Human-readable display name of the TV (shown in discovery results).
  final String name;

  /// Manufacturer if known (e.g. "Samsung", "LG", "Sony").
  final String? manufacturer;

  /// Model identifier if known.
  final String? model;

  /// Hint for which remote protocol to use after connecting.
  /// The [DiscoveryManager] passes this through as [DiscoveredDevice.serviceType]
  /// so the connection layer can pick the right protocol without probing.
  ///
  /// Known values: "samsung_tizen", "android_tv", "dlna", "webos"
  final String? protocol;

  const QrPayloadModel({
    required this.version,
    required this.ip,
    required this.port,
    required this.name,
    this.manufacturer,
    this.model,
    this.protocol,
  });

  /// Parses a JSON map into a [QrPayloadModel].
  ///
  /// Throws [QrPayloadException] if required fields are missing or malformed.
  factory QrPayloadModel.fromJson(Map<String, dynamic> json) {
    final version = json['v'];
    final ip = json['ip'];
    final port = json['port'];
    final name = json['name'];

    if (version is! int) {
      throw QrPayloadException('Missing or invalid field: "v" (version)');
    }
    if (ip is! String || ip.isEmpty) {
      throw QrPayloadException('Missing or invalid field: "ip"');
    }
    if (port is! int || port <= 0 || port > 65535) {
      throw QrPayloadException('Missing or invalid field: "port"');
    }
    if (name is! String || name.isEmpty) {
      throw QrPayloadException('Missing or invalid field: "name"');
    }

    return QrPayloadModel(
      version: version,
      ip: ip,
      port: port,
      name: name,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      protocol: json['protocol'] as String?,
    );
  }

  @override
  String toString() =>
      'QrPayloadModel(ip: $ip, port: $port, name: $name, protocol: $protocol)';
}

/// Thrown when a scanned QR code cannot be parsed as a valid TitanCast payload.
class QrPayloadException implements Exception {
  final String message;
  const QrPayloadException(this.message);

  @override
  String toString() => 'QrPayloadException: $message';
}