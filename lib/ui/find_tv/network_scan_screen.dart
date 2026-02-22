import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:titancast/ui/common/wifi_info_widget.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/discovery_manager.dart';

/// Starts network scan immediately on mount.
/// As soon as the first real device arrives, navigates back to HomeScreen
/// so the user sees results live.
class NetworkScanScreen extends StatefulWidget {
  final void Function(Stream<DiscoveredDevice>) onDiscoveryStarted;

  const NetworkScanScreen({super.key, required this.onDiscoveryStarted});

  @override
  State<NetworkScanScreen> createState() => _NetworkScanScreenState();
}

class _NetworkScanScreenState extends State<NetworkScanScreen>
    with SingleTickerProviderStateMixin {
  final DiscoveryManager _manager = DiscoveryManager();
  bool _isScanning = false;
  bool _permissionDenied = false;
  String _statusMessage = 'Preparing scan...';
  int _deviceCount = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _navigatedBack = false;
  String? _wifiName;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Scan başlatıldığında izin zaten istenecek (_startScan içinde).
    // WiFi adını oradan sonra çekeceğiz — izin garantili olunca.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  /// İzin verildikten SONRA WiFi adını çeker.
  /// _startScan() içinden çağrılır, böylece izin garantilidir.
  Future<void> _fetchWifiName() async {
    try {
      final info = await NetworkInfo().getWifiName().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      // Android'de SSID tırnak içinde gelebilir: "MyWiFi" → MyWiFi
      final cleaned = info?.replaceAll('"', '');
      if (mounted) setState(() => _wifiName = cleaned);
    } catch (_) {
      if (mounted) setState(() => _wifiName = null);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 1. İzni iste
    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _statusMessage = 'Location permission required.';
        });
      }
      return;
    }

    // 2. İzin alındı → artık WiFi adını güvenle çekebiliriz
    await _fetchWifiName();

    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _permissionDenied = false;
      _navigatedBack = false;
      _statusMessage = 'Scanning your network...';
    });
    _pulseController.repeat(reverse: true);

    // 3. Discovery stream'i oluştur ve HomeScreen'e ilet
    final stream = _manager.startDiscovery(
      mode: DiscoveryMode.network,
      timeout: const Duration(seconds: 15),
    );
    widget.onDiscoveryStarted(stream);

    // 4. Lokal sayaç — gerçek cihazları say
    stream.listen(
          (device) {
        if (!mounted) return;
        if (device.friendlyName.startsWith('Identifying')) return;
        setState(() => _deviceCount++);
      },
      onDone: () {
        if (!mounted) return;
        _pulseController.stop();
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scan complete.';
        });
        _navigateBackToResults();
      },
    );
  }

  void _navigateBackToResults() {
    if (_navigatedBack || !mounted) return;
    _navigatedBack = true;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Network Scan'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // WiFi info widget — null iken skeleton gösterir
              WifiInfoWidget(ssid: _wifiName),
              const SizedBox(height: 16),

              // Animated radar
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color:
                    colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.radar_rounded,
                    size: 68,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                _statusMessage,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                _isScanning
                    ? 'Scanning...\nFound: $_deviceCount device(s)\nScan will finish in 15 seconds.'
                    : _permissionDenied
                    ? 'TitanCast needs location permission to scan the local network.'
                    : 'Taking you to results...',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),
              Text(
                'Your TV must be on the same WiFi network',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              if (_permissionDenied) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Open Settings'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_isScanning)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _manager.stopDiscovery();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text('Cancel'),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}