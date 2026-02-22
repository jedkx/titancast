import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../discovery/discovery_model.dart';
import '../remote/brand_detector.dart';

/// Persists the device list to SharedPreferences.
/// Data survives app restarts until the user clears app storage.
///
/// Storage format:
///   key  : "titancast_devices"
///   value: JSON-encoded list → "[{...}, {...}]"
class DeviceRepository {
  static const String _key = 'titancast_devices';

  final List<DiscoveredDevice> _cache = [];
  SharedPreferences? _prefs;

  /// Must be called once before any other method, typically in initState.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
  }

  /// Current device list. Sync-readable after [init] completes.
  List<DiscoveredDevice> get devices => List.unmodifiable(_cache);

  void _loadFromPrefs() {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache
        ..clear()
        ..addAll(
          list.map((e) => DiscoveredDevice.fromJson(e as Map<String, dynamic>)),
        );
      _cache.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (_) {
      _prefs?.remove(_key);
    }
  }

  /// Saves a device and runs brand detection if not already detected.
  ///
  /// If the IP already exists:
  ///   - Discovery fields (name, manufacturer, etc.) are updated.
  ///   - [customName] and [addedAt] are preserved.
  ///   - [detectedBrand] is preserved if already set; re-detected if null.
  Future<void> save(DiscoveredDevice incoming) async {
    final index = _cache.indexWhere((d) => d.ip == incoming.ip);

    // Run brand detection if this device doesn't have a brand yet.
    // We run it on the incoming device so fresh manufacturer data is used.
    final TvBrand? brand = (incoming.detectedBrand == null ||
        incoming.detectedBrand == TvBrand.unknown)
        ? await BrandDetector.detect(incoming)
        : incoming.detectedBrand;

    final withBrand = incoming.copyWith(detectedBrand: brand);

    if (index == -1) {
      _cache.insert(0, withBrand);
    } else {
      final existing = _cache[index];
      _cache[index] = withBrand.copyWith(
        customName: existing.customName,
        addedAt: existing.addedAt,
        ssid: incoming.ssid ?? existing.ssid,
        // Keep existing brand if we couldn't improve it
        detectedBrand: (brand != null && brand != TvBrand.unknown)
            ? brand
            : existing.detectedBrand,
      );
    }

    await _persist();
  }

  /// Sets a user-defined name. Pass empty string to revert to the original name.
  Future<void> rename(String ip, String newName) async {
    final index = _cache.indexWhere((d) => d.ip == ip);
    if (index == -1) return;
    final trimmed = newName.trim();
    _cache[index] = _cache[index].copyWith(
      customName: trimmed.isEmpty ? null : trimmed,
      clearCustomName: trimmed.isEmpty,
    );
    await _persist();
  }

  /// Removes a device permanently.
  Future<void> delete(String ip) async {
    _cache.removeWhere((d) => d.ip == ip);
    await _persist();
  }

  Future<void> clearAll() async {
    _cache.clear();
    await _prefs?.remove(_key);
  }

  /// Returns a flat list of [SsidHeader] and [DiscoveredDevice] objects
  /// ready to render. Headers are only added when more than one SSID is present.
  List<Object> buildGroupedList() {
    if (_cache.isEmpty) return [];

    final ssids = _cache.map((d) => d.ssid ?? 'Unknown Network').toSet();

    if (ssids.length <= 1) return List<Object>.from(_cache);

    final result = <Object>[];
    for (final ssid in ssids) {
      result.add(SsidHeader(ssid: ssid));
      result.addAll(
        _cache.where((d) => (d.ssid ?? 'Unknown Network') == ssid),
      );
    }
    return result;
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_cache.map((d) => d.toJson()).toList());
    await _prefs?.setString(_key, encoded);
  }
}

/// Represents a Wi-Fi section header in the grouped device list.
class SsidHeader {
  final String ssid;
  const SsidHeader({required this.ssid});
}