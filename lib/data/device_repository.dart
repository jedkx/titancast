import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_logger.dart';
import '../discovery/discovery_model.dart';
import '../remote/brand_detector.dart';
import '../remote/tv_brand.dart';

const _tag = 'DeviceRepository';

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
    if (raw == null || raw.isEmpty) {
      AppLogger.d(_tag, 'loadFromPrefs: no saved devices found');
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache
        ..clear()
        ..addAll(
          list.map((e) => DiscoveredDevice.fromJson(e as Map<String, dynamic>)),
        );
      _cache.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      AppLogger.i(_tag, 'loadFromPrefs: loaded ${_cache.length} device(s) — '
          '${_cache.map((d) => '${d.friendlyName}(${d.ip})').join(', ')}');
    } catch (e) {
      AppLogger.e(_tag, 'loadFromPrefs: JSON parse failed, clearing storage — $e');
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
    AppLogger.d(_tag, 'save: "${incoming.friendlyName}" ip=${incoming.ip} '
        'incomingBrand=${incoming.detectedBrand?.name ?? 'null'} '
        'manufacturer=${incoming.manufacturer ?? 'null'}');

    final index = _cache.indexWhere((d) => d.ip == incoming.ip);
    final isNew = index == -1;

    // Run brand detection if this device doesn't have a brand yet.
    TvBrand? brand;
    if (incoming.detectedBrand == null || incoming.detectedBrand == TvBrand.unknown) {
      AppLogger.d(_tag, 'save: brand unknown, running BrandDetector for ${incoming.ip}');
      brand = await BrandDetector.detect(incoming);
      AppLogger.i(_tag, 'save: BrandDetector result → ${brand.name} for ${incoming.ip}');
    } else {
      brand = incoming.detectedBrand;
      AppLogger.v(_tag, 'save: brand already set (${brand!.name}), skipping detection');
    }

    final withBrand = incoming.copyWith(detectedBrand: brand);

    if (isNew) {
      AppLogger.i(_tag, 'save: NEW device added — "${incoming.friendlyName}" '
          'ip=${incoming.ip} brand=${brand?.name} '
          'manufacturer=${incoming.manufacturer ?? 'none'}');
      _cache.insert(0, withBrand);
    } else {
      final existing = _cache[index];
      final resolvedBrand = (brand != null && brand != TvBrand.unknown)
          ? brand
          : existing.detectedBrand;
      AppLogger.d(_tag, 'save: UPDATE existing device ${incoming.ip} — '
          'oldBrand=${existing.detectedBrand?.name} newBrand=${resolvedBrand?.name} '
          'oldName="${existing.friendlyName}" newName="${incoming.friendlyName}" '
          'customName=${existing.customName ?? 'none'}');
      _cache[index] = withBrand.copyWith(
        customName: existing.customName,
        addedAt: existing.addedAt,
        ssid: incoming.ssid ?? existing.ssid,
        detectedBrand: resolvedBrand,
      );
    }

    await _persist();
    AppLogger.v(_tag, 'save: persisted — total ${_cache.length} device(s)');
  }

  /// Sets a user-defined name. Pass empty string to revert to the original name.
  Future<void> rename(String ip, String newName) async {
    final index = _cache.indexWhere((d) => d.ip == ip);
    if (index == -1) {
      AppLogger.w(_tag, 'rename: ip=$ip not found in cache');
      return;
    }
    final trimmed = newName.trim();
    final old = _cache[index].displayName;
    _cache[index] = _cache[index].copyWith(
      customName: trimmed.isEmpty ? null : trimmed,
      clearCustomName: trimmed.isEmpty,
    );
    AppLogger.i(_tag, 'rename: $ip "$old" → "${trimmed.isEmpty ? '(cleared)' : trimmed}"');
    await _persist();
  }

  /// Manually overrides the detected brand for a device.
  Future<void> setBrand(String ip, TvBrand brand) async {
    final index = _cache.indexWhere((d) => d.ip == ip);
    if (index == -1) {
      AppLogger.w(_tag, 'setBrand: ip=$ip not found in cache');
      return;
    }
    final old = _cache[index].detectedBrand?.name ?? 'null';
    _cache[index] = _cache[index].copyWith(detectedBrand: brand);
    AppLogger.i(_tag, 'setBrand: $ip $old → ${brand.name} (manual override)');
    await _persist();
  }

  /// Removes a device permanently.
  Future<void> delete(String ip) async {
    final device = _cache.firstWhere((d) => d.ip == ip,
        orElse: () => throw StateError('not found'));
    AppLogger.i(_tag, 'delete: removing "${device.friendlyName}" ($ip)');
    _cache.removeWhere((d) => d.ip == ip);
    await _persist();
    AppLogger.d(_tag, 'delete: done — ${_cache.length} device(s) remaining');
  }

  Future<void> clearAll() async {
    _cache.clear();
    await _prefs?.remove(_key);
  }

  /// Returns a flat list of [SsidHeader] and [DiscoveredDevice] objects
  /// ready to render. Headers are only added when more than one SSID is present.
  List<Object> buildGroupedList() => buildGroupedListFrom(_cache);

  /// Same as [buildGroupedList] but operates on a custom [devices] subset.
  /// Used by the UI to pre-filter modems/unknown devices before grouping.
  List<Object> buildGroupedListFrom(List<DiscoveredDevice> devices) {
    if (devices.isEmpty) return [];

    final ssids = devices.map((d) => d.ssid ?? 'Unknown Network').toSet();

    if (ssids.length <= 1) return List<Object>.from(devices);

    final result = <Object>[];
    for (final ssid in ssids) {
      result.add(SsidHeader(ssid: ssid));
      result.addAll(
        devices.where((d) => (d.ssid ?? 'Unknown Network') == ssid),
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