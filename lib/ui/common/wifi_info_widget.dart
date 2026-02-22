import 'dart:async';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// =============================================================================
// Veri Modeli
// =============================================================================

class WifiNetworkInfo {
  final String ip;
  final String subnet;
  final String broadcastAddress;
  final String? ssid;
  final String? bssid;

  const WifiNetworkInfo({
    required this.ip,
    required this.subnet,
    required this.broadcastAddress,
    this.ssid,
    this.bssid,
  });

  @override
  String toString() =>
      'WifiNetworkInfo(ip: $ip, broadcast: $broadcastAddress, ssid: $ssid)';
}

// =============================================================================
// Hata Sınıfları
// =============================================================================

class WifiPermissionDeniedException implements Exception {
  final String message;
  WifiPermissionDeniedException(this.message);
}

class WifiInfoException implements Exception {
  final String message;
  WifiInfoException(this.message);
}

// =============================================================================
// Datasource — WiFi bilgisini güvenli şekilde okur
// =============================================================================

class WifiInfoDatasource {
  final _networkInfo = NetworkInfo();

  Future<WifiNetworkInfo?> getWifiInfo() async {
    // 1. Önce izni kontrol et / iste
    final status = await Permission.locationWhenInUse.request();

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      throw WifiPermissionDeniedException(
        'Konum izni kalıcı olarak reddedildi. Ayarlardan açın.',
      );
    }

    if (!status.isGranted) {
      throw WifiPermissionDeniedException(
        'Cihaz keşfi için konum izni gerekli.',
      );
    }

    // 2. WiFi bilgisini paralel oku, 5 saniye timeout
    try {
      final results = await Future.wait([
        _networkInfo.getWifiIP(),
        _networkInfo.getWifiSubmask(),
        _networkInfo.getWifiBSSID(),
        _networkInfo.getWifiName(),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [null, null, null, null],
      );

      final ip     = results[0];
      final subnet = results[1];
      final bssid  = results[2];
      final ssid   = results[3];

      // 3. IP null / boş ise WiFi bağlı değil
      if (ip == null || ip.isEmpty) return null;

      final finalSubnet =
      (subnet == null || subnet.isEmpty) ? '255.255.255.0' : subnet;

      return WifiNetworkInfo(
        ip: ip,
        subnet: finalSubnet,
        broadcastAddress: _computeBroadcast(ip, finalSubnet),
        ssid: ssid,
        bssid: bssid,
      );
    } on TimeoutException {
      return null;
    } catch (e) {
      if (e is WifiPermissionDeniedException) rethrow;
      throw WifiInfoException('WiFi bilgisi alınamadı: $e');
    }
  }

  /// Subnet mask'tan broadcast adresini hesaplar.
  /// Örnek: ip=192.168.1.50, mask=255.255.255.0 → 192.168.1.255
  String _computeBroadcast(String ip, String mask) {
    try {
      final ipParts   = ip.split('.').map(int.parse).toList();
      final maskParts = mask.split('.').map(int.parse).toList();
      if (ipParts.length != 4 || maskParts.length != 4) {
        return '255.255.255.255';
      }
      return List<int>.generate(4, (i) {
        return (ipParts[i] & maskParts[i]) | (~maskParts[i] & 0xFF);
      }).join('.');
    } catch (_) {
      return '255.255.255.255';
    }
  }
}

// =============================================================================
// WifiInfoWidget — UI widget (ssid string ile çağrılır)
// home_screen.dart ve network_scan_screen.dart bunu import eder
// =============================================================================

class WifiInfoWidget extends StatelessWidget {
  /// Gösterilecek WiFi ağ adı. null ise skeleton / "Connecting..." gösterilir.
  final String? ssid;

  const WifiInfoWidget({super.key, required this.ssid});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    // SSID hâlâ yükleniyorsa skeleton animasyonu göster
    if (ssid == null) {
      return _WifiSkeleton(colorScheme: colorScheme);
    }

    // SSID tırnak içinde geliyorsa temizle: "MyWiFi" → MyWiFi
    final cleanSsid = ssid!.replaceAll('"', '');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.wifi_rounded,
          size: 14,
          color: Colors.white,
        ),
        const SizedBox(width: 4),
        Text(
          cleanSsid.isEmpty ? 'Not connected' : cleanSsid,
          style: textTheme.labelSmall?.copyWith(
            color: cleanSsid.isEmpty
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// Yükleniyor animasyonu — SSID null iken gösterilir
class _WifiSkeleton extends StatefulWidget {
  final ColorScheme colorScheme;
  const _WifiSkeleton({required this.colorScheme});

  @override
  State<_WifiSkeleton> createState() => _WifiSkeletonState();
}

class _WifiSkeletonState extends State<_WifiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_rounded, size: 14,
              color: widget.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}