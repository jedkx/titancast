import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:titancast/ui/shared/wifi_info_widget.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/discovery_manager.dart';

class NetworkScanScreen extends StatefulWidget {
  final void Function(Stream<DiscoveredDevice>) onDiscoveryStarted;

  const NetworkScanScreen({super.key, required this.onDiscoveryStarted});

  @override
  State<NetworkScanScreen> createState() => _NetworkScanScreenState();
}

class _NetworkScanScreenState extends State<NetworkScanScreen> with SingleTickerProviderStateMixin {
  final DiscoveryManager _manager = DiscoveryManager();
  bool _isScanning = false;
  bool _permissionDenied = false;
  String _statusMessage = 'Preparing scan...';
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _navigatedBack = false;
  String? _wifiName;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
    _initScan();
  }

  Future<void> _initScan() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _statusMessage = 'Location permission is required to read Wi-Fi info.';
        });
      }
      return;
    }

    try {
      final wifiName = await NetworkInfo().getWifiName();
      if (mounted) setState(() => _wifiName = wifiName?.replaceAll('"', ''));
    } catch (_) {}

    _startScan();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Searching for devices...';
    });

    // HATA 1 ÇÖZÜMÜ: Orijinalindeki mode ve timeout parametreleri eklendi
    final stream = _manager.startDiscovery(
      mode: DiscoveryMode.network,
      timeout: const Duration(seconds: 15),
    );

    widget.onDiscoveryStarted(stream);

    stream.listen((device) {
      if (!_navigatedBack && mounted) {
        _navigatedBack = true;
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (!_navigatedBack) _manager.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0A0A0E);
    const Color accentColor = Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 1.0 - (_pulseAnimation.value - 0.8) / 0.7),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 60),

              Text(_statusMessage, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              if (_wifiName != null) ...[
                const Text('Scanning on network:', style: TextStyle(color: Color(0xFF8A8A93), fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 8),
                    Text(_wifiName!, style: const TextStyle(color: accentColor, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ],
                ),
              ],

              const Spacer(),

              if (_isScanning)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      _manager.stopDiscovery();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text('Cancel Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}