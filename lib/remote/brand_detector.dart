import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/app_logger.dart';
import '../discovery/discovery_model.dart';
import 'oui_database.dart';
import 'tv_brand.dart';

const _tag = 'BrandDetector';

/// Detects the brand of a [DiscoveredDevice] using a four-layer waterfall.
///
/// Layer 1 — Brand-specific SSDP service types (highest confidence, no
///            ambiguity).  Samsung uses "urn:samsung.com:*", LG uses
///            "urn:lge-com:*", Sony uses "urn:schemas-sony-com:*".
///            Source: real SSDP packet captures + Home Assistant manifests.
///
/// Layer 2 — UPnP XML manufacturer string.  Exact strings observed in the
///            wild: "Samsung Electronics", "Samsung", "LG Electronics",
///            "Sony Corporation", "Philips", "TP Vision".
///            Source: Home Assistant samsungtv/webostv manifests + real XML.
///
/// Layer 3 — MAC OUI lookup via ARP table (Android only — iOS sandboxes
///            the ARP cache).
///
/// Layer 4 — Heuristic matching on friendlyName + serviceType (last resort).
///
/// First layer that returns a non-unknown result wins.
class BrandDetector {
  BrandDetector._();

  /// Synchronous-only detection: layers 1, 2, and 4 (no async MAC lookup).
  /// Used for a quick name check before kicking off a TCP port probe.
  static TvBrand detectSync(DiscoveredDevice device) {
    final l1 = _fromServiceType(device.serviceType, device.rawHeaders);
    if (l1 != TvBrand.unknown) return l1;
    if (device.manufacturer != null) {
      final l2 = _fromManufacturerString(device.manufacturer!);
      if (l2 != TvBrand.unknown) return l2;
    }
    return _fromHeuristics(device);
  }

  static Future<TvBrand> detect(DiscoveredDevice device) async {
    AppLogger.d(_tag, '── detect() start ─────────────────────────────────────');
    AppLogger.d(_tag, 'device: "${device.friendlyName}" ip=${device.ip} '
        'manufacturer=${device.manufacturer ?? 'null'} '
        'serviceType=${device.serviceType ?? 'null'} '
        'currentBrand=${device.detectedBrand?.name ?? 'null'}');

    // Layer 1: brand-specific service type strings (very reliable)
    AppLogger.v(_tag, 'layer 1: serviceType probe '
        '(st=${device.serviceType}, rawHeaders=${device.rawHeaders.keys.join(',') })');
    final brandFromSt = _fromServiceType(
      device.serviceType,
      device.rawHeaders,
    );
    if (brandFromSt != TvBrand.unknown) {
      AppLogger.i(_tag, 'layer 1 HIT → ${brandFromSt.name}');
      return brandFromSt;
    }
    AppLogger.v(_tag, 'layer 1 miss');

    // Layer 2: manufacturer string from UPnP XML
    if (device.manufacturer != null) {
      AppLogger.v(_tag, 'layer 2: manufacturer string probe ("${device.manufacturer}")');
      final brand = _fromManufacturerString(device.manufacturer!);
      if (brand != TvBrand.unknown) {
        AppLogger.i(_tag, 'layer 2 HIT → ${brand.name} (from "${device.manufacturer}")');
        return brand;
      }
      AppLogger.v(_tag, 'layer 2 miss ("${device.manufacturer}" not recognized)');
    } else {
      AppLogger.v(_tag, 'layer 2 skipped — manufacturer is null');
    }

    // Layer 3: MAC OUI lookup (Android only)
    if (!kIsWeb && Platform.isAndroid) {
      AppLogger.v(_tag, 'layer 3: MAC OUI lookup for ip=${device.ip}');
      final brand = await _fromMacLookup(device.ip);
      if (brand != TvBrand.unknown) {
        AppLogger.i(_tag, 'layer 3 HIT → ${brand.name} (MAC OUI match for ${device.ip})');
        return brand;
      }
      AppLogger.v(_tag, 'layer 3 miss (no OUI match)');
    } else {
      AppLogger.v(_tag, 'layer 3 skipped — ${kIsWeb ? 'web platform' : 'not Android'}');
    }

    // Layer 4: heuristics on name and service type
    AppLogger.v(_tag, 'layer 4: heuristic probe (name="${device.friendlyName}")');
    final result = _fromHeuristics(device);
    if (result != TvBrand.unknown) {
      AppLogger.i(_tag, 'layer 4 HIT → ${result.name} (heuristic on friendlyName)');
    } else {
      AppLogger.w(_tag, 'all 4 layers missed — brand=unknown for ${device.ip} '
          '("${device.friendlyName}")');
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Layer 1 — brand-specific SSDP service type strings
  //
  // These come from SSDP response headers (ST / NT fields) or the rawHeaders
  // map populated by our SSDP scanner. They are vendor-namespaced and
  // therefore far more reliable than the manufacturer string.
  // ---------------------------------------------------------------------------

  static TvBrand _fromServiceType(
      String? serviceType,
      Map<String, dynamic> rawHeaders,
      ) {
    // Collect all candidate strings: serviceType field + relevant raw headers
    final candidates = <String>[
      if (serviceType != null) serviceType,
      rawHeaders['st']?.toString() ?? '',
      rawHeaders['nt']?.toString() ?? '',
      rawHeaders['usn']?.toString() ?? '',
      rawHeaders['server']?.toString() ?? '',
    ].map((s) => s.toLowerCase()).toList();

    for (final s in candidates) {
      // Samsung: "urn:samsung.com:device:RemoteControlReceiver:1"
      //          "urn:samsung.com:service:MainTVAgent2:1"
      //          SERVER header: "SHP, UPnP/1.0, Samsung UPnP SDK/1.0"
      if (s.contains('samsung.com') || s.contains('samsung upnp sdk')) {
        return TvBrand.samsung;
      }

      // LG webOS: "urn:lge-com:service:webos-second-screen:1"
      //           "udap:rootservice" (UDAP is LG's proprietary protocol)
      //           mDNS hostname: "lgsmarttv.lan"
      if (s.contains('lge-com') ||
          s.contains('lge.com') ||
          s.contains('udap') ||
          s.contains('lgsmarttv')) {
        return TvBrand.lg;
      }

      // Sony Bravia: "urn:schemas-sony-com:service:IRCC:1"
      //              SERVER header contains "KDL-" or "BRAVIA"
      if (s.contains('schemas-sony-com') ||
          s.contains('sony-com') ||
          s.contains('bravia')) {
        return TvBrand.sony;
      }

      // Philips JointSpace: port 1925/1926 already sets serviceType to
      // "JointSpace TV" in our probe scanner, so this catches it here too.
      if (s.contains('jointspace') || s.contains('philips')) {
        return TvBrand.philips;
      }

      // Roku: "roku:ecp"
      if (s.contains('roku')) return TvBrand.roku;

      // DIAL (Chromecast, Android TV, Google TV): "urn:dial-multiscreen-org:service:dial:1"
      // All DIAL devices run Android TV/Google TV OS → use ADB-based AndroidTvProtocol.
      if (s.contains('dial-multiscreen') || s.contains('dial:1')) {
        return TvBrand.androidTv;
      }
    }

    return TvBrand.unknown;
  }

  // ---------------------------------------------------------------------------
  // Layer 2 — manufacturer string from UPnP XML
  //
  // Exact strings confirmed from real device captures:
  //   Samsung:  "Samsung Electronics"  or  "Samsung"
  //   LG:       "LG Electronics"
  //   Sony:     "Sony Corporation"
  //   Philips:  "Philips"  or  "TP Vision"  (TP Vision is Philips licensee)
  // ---------------------------------------------------------------------------

  static TvBrand _fromManufacturerString(String raw) {
    final s = raw.toLowerCase();

    if (s.contains('samsung'))                              return TvBrand.samsung;
    if (s.contains('lg electronics') || s == 'lg')         return TvBrand.lg;
    if (s.contains('sony'))                                 return TvBrand.sony;
    if (s.contains('philips') || s.contains('tp vision'))  return TvBrand.philips;
    // These brands use Android TV OS → AndroidTvProtocol (ADB)
    if (s.contains('hisense'))                              return TvBrand.androidTv;
    if (s.contains('tcl'))                                  return TvBrand.androidTv;
    if (s.contains('panasonic'))                            return TvBrand.panasonic;
    if (s.contains('sharp'))                                return TvBrand.androidTv;
    if (s.contains('toshiba'))                              return TvBrand.androidTv;
    if (s.contains('google'))                               return TvBrand.androidTv;
    if (s.contains('amazon') || s.contains('fire'))         return TvBrand.amazon;
    if (s.contains('apple'))                                return TvBrand.apple;
    if (s.contains('roku'))                                 return TvBrand.roku;
    if (s.contains('torima'))                               return TvBrand.torima;
    return TvBrand.unknown;
  }

  // ---------------------------------------------------------------------------
  // Layer 3 — MAC OUI lookup via ARP (Android only)
  // ---------------------------------------------------------------------------

  static Future<TvBrand> _fromMacLookup(String ip) async {
    try {
      // Ping to ensure the device has a fresh ARP cache entry.
      await Process.run('ping', ['-c', '1', '-W', '1', ip]);
      final result = await Process.run('arp', ['-n', ip]);
      final output = result.stdout as String;

      final macMatch = RegExp(
        r'([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}',
      ).firstMatch(output);

      if (macMatch == null) return TvBrand.unknown;

      final mfr = lookupManufacturerByMac(macMatch.group(0)!);
      if (mfr == null) return TvBrand.unknown;
      return _fromManufacturerString(mfr);
    } catch (e) {
      AppLogger.e(_tag, 'MAC lookup failed for $ip: $e');
      return TvBrand.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Layer 4 — heuristics on friendlyName and serviceType
  // ---------------------------------------------------------------------------

  static TvBrand _fromHeuristics(DiscoveredDevice device) {
    final name = device.friendlyName.toLowerCase();
    final type = (device.serviceType ?? '').toLowerCase();

    // Samsung Tizen TVs often advertise hostname "tizen*" over DHCP
    if (name.contains('samsung') ||
        type.contains('samsung') ||
        name.contains('tizen'))      return TvBrand.samsung;

    // LG webOS: "[LG] webOS TV" is the default friendly name
    if (name.contains('webos') ||
        name.contains('[lg]') ||
        name.contains('lg '))        return TvBrand.lg;

    if (name.contains('bravia') ||
        name.contains('sony'))       return TvBrand.sony;

    if (name.contains('philips'))    return TvBrand.philips;
    if (name.contains('panasonic'))  return TvBrand.panasonic;
    if (name.contains('sharp'))      return TvBrand.androidTv;
    if (name.contains('toshiba'))    return TvBrand.androidTv;
    // Android TV / Google TV devices
    if (name.contains('hisense'))    return TvBrand.androidTv;
    if (name.contains('tcl'))        return TvBrand.androidTv;
    if (name.contains('chromecast')) return TvBrand.androidTv;
    if (name.contains('fire tv') ||
        name.contains('firetv'))     return TvBrand.amazon;
    if (name.contains('apple tv'))   return TvBrand.apple;
    if (name.contains('roku'))       return TvBrand.roku;
    if (name.contains('torima')) return TvBrand.torima;
    // Torima projector model numbers: HY300, HY320, HY350, HY350Max, T11, T12, T20
    if (RegExp(r'\bhy3[0-9]{2}\b|\bhy350\b|hy350max|\bt1[1-9]\b|\bt20\b')
        .hasMatch(name)) return TvBrand.torima;
    return TvBrand.unknown;
  }
}