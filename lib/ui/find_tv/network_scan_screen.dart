import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:network_info_plus/network_info_plus.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/discovery_manager.dart';
import '../../core/app_logger.dart';

class NetworkScanScreen extends StatefulWidget {
  final void Function(Stream<DiscoveredDevice>) onDiscoveryStarted;

  const NetworkScanScreen({super.key, required this.onDiscoveryStarted});

  @override
  State<NetworkScanScreen> createState() => _NetworkScanScreenState();
}

enum ScanState { preparing, scanning, completed }

class _NetworkScanScreenState extends State<NetworkScanScreen> with SingleTickerProviderStateMixin {
  final DiscoveryManager _manager = DiscoveryManager();
  ScanState _scanState = ScanState.preparing;
  String _statusMessage = 'Preparing scan...';
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  String? _wifiName;
  
  // Collected devices during scan
  final List<DiscoveredDevice> _foundDevices = [];
  StreamSubscription<DiscoveredDevice>? _discoverySubscription;
  Timer? _scanTimer;

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
          _statusMessage = 'Location permission is required to read Wi-Fi info.';
        });
      }
      return;
    }

    try {
      final wifiName = await NetworkInfo().getWifiName();
      if (mounted) setState(() => _wifiName = wifiName?.replaceAll('"', ''));
    } catch (e) {
      AppLogger.w('NetworkScan', 'Failed to get wifi name: $e');
    }

    _startScan();
  }

  void _startScan() {
    if (!mounted) return;
    
    setState(() {
      _scanState = ScanState.scanning;
      _statusMessage = 'Searching for devices...';
      _foundDevices.clear();
    });

    const scanDuration = Duration(seconds: 15);
    
    final stream = _manager.startDiscovery(
      mode: DiscoveryMode.network,
      timeout: scanDuration,
    );

    widget.onDiscoveryStarted(stream);

    // Listen for discovered devices
    _discoverySubscription = stream.listen(
      (device) {
        if (mounted && _scanState == ScanState.scanning) {
          setState(() {
            // Filter out router/modem devices and avoid duplicates by IP
            if (device.isControllable && !_foundDevices.any((d) => d.ip == device.ip)) {
              _foundDevices.add(device);
              _statusMessage = 'Found ${_foundDevices.length} device${_foundDevices.length != 1 ? 's' : ''}...';
            }
          });
        }
      },
      onError: (error) {
        AppLogger.e('NetworkScan', 'Discovery error: $error');
      },
      onDone: () {
        _completeScan();
      },
    );

    // Set timeout timer
    _scanTimer = Timer(scanDuration, () {
      _completeScan();
    });
  }

  void _completeScan() {
    if (!mounted || _scanState == ScanState.completed) return;
    
    _discoverySubscription?.cancel();
    _scanTimer?.cancel();
    
    setState(() {
      _scanState = ScanState.completed;
      if (_foundDevices.isEmpty) {
        _statusMessage = 'No controllable devices found';
      } else {
        _statusMessage = 'Found ${_foundDevices.length} controllable device${_foundDevices.length != 1 ? 's' : ''}';
      }
    });

    AppLogger.i('NetworkScan', 'Network scan completed - controllable devices found: ${_foundDevices.length} (routers filtered out)');
  }

  void _retryScan() {
    AppLogger.i('NetworkScan', 'Retrying network scan');
    setState(() {
      _scanState = ScanState.scanning;
      _statusMessage = 'Preparing scan...';
      _foundDevices.clear();
    });
    
    // Small delay to show preparing state
    Future.delayed(const Duration(milliseconds: 500), () {
      _startScan();
    });
  }

  void _goToMyDevices() {
    AppLogger.i('NetworkScan', 'Navigating to My Devices from scan results');
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _discoverySubscription?.cancel();
    _scanTimer?.cancel();
    if (_scanState == ScanState.scanning) {
      _manager.stopDiscovery();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0A0A0E);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _scanState == ScanState.completed ? 'Scan Results' : 'Network Scan',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _scanState == ScanState.completed ? _buildResults() : _buildScanningUI(),
    );
  }

  Widget _buildScanningUI() {
    const Color accentColor = Color(0xFF8B5CF6);
    
    return Center(
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

            Text(_statusMessage, 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
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

            if (_scanState == ScanState.scanning)
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
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    const Color accentColor = Color(0xFF8B5CF6);
    const Color cardColor = Color(0xFF1E1E26);
    
    return Column(
      children: [
        // Results summary
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              Icon(
                _foundDevices.isEmpty ? Icons.search_off_rounded : Icons.check_circle_rounded,
                size: 48,
                color: _foundDevices.isEmpty ? const Color(0xFF6B7280) : const Color(0xFF10B981),
              ),
              const SizedBox(height: 16),
              Text(
                _foundDevices.isEmpty ? 'Scan Complete' : 'Scan Complete',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_foundDevices.isEmpty) 
                const Text(
                  'No controllable devices found on your network.\nMake sure your TV and phone are connected\nto the same Wi-Fi network.',
                  style: TextStyle(color: Color(0xFF8A8A93), fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  '${_foundDevices.length} device${_foundDevices.length == 1 ? '' : 's'} discovered and ready to add',
                  style: const TextStyle(color: Color(0xFF8A8A93), fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        
        // Device list
        if (_foundDevices.isNotEmpty) ...[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _foundDevices.length,
              itemBuilder: (context, index) {
                final device = _foundDevices[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(Icons.tv, size: 16, color: const Color(0xFF8A8A93)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.friendlyName,
                              style: const TextStyle(color: Color(0xFF8A8A93), fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              device.ip,
                              style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (device.detectedBrand != null)
                        Text(
                          device.detectedBrand!.name.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF666666), fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else ...[
          const Spacer(),
        ],
        
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _goToMyDevices,
                  icon: const Icon(Icons.devices_rounded, size: 20),
                  label: Text(
                    _foundDevices.isEmpty ? 'Continue to My Devices' : 'Go to My Devices',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _retryScan,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Retry Scan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}