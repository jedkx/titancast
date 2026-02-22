import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:titancast/data/active_device.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/remote_controller.dart';
import 'package:titancast/ui/remote/widgets/remote_button.dart';
import 'package:titancast/ui/remote/widgets/dpad_widget.dart';
import 'package:titancast/ui/remote/widgets/volume_channel_row.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  RemoteController? _controller;
  DiscoveredDevice? _device;

  @override
  void initState() {
    super.initState();
    activeDeviceNotifier.addListener(_onDeviceChanged);
    final current = activeDeviceNotifier.value;
    if (current != null) _attachDevice(current);
  }

  @override
  void dispose() {
    activeDeviceNotifier.removeListener(_onDeviceChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onDeviceChanged() {
    final d = activeDeviceNotifier.value;
    if (d != null && d.ip != _device?.ip) _attachDevice(d);
  }

  void _attachDevice(DiscoveredDevice device) {
    final old = _controller;
    _controller = null;
    old?.dispose();

    final ctrl = RemoteController(device);
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _device = device;
      _controller = ctrl;
    });
    unawaited(ctrl.connect());
  }

  void _sendCommand(RemoteCommand cmd) => _controller?.send(cmd);

  void _showAppsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 32),
              const Text('Applications', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AppPopupChip(label: 'Netflix', color: const Color(0xFFE50914), onTap: () { Navigator.pop(context); _sendCommand(RemoteCommand.netflix); }),
                  _AppPopupChip(label: 'YouTube', color: const Color(0xFFFF0000), onTap: () { Navigator.pop(context); _sendCommand(RemoteCommand.youtube); }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0A0A0E);
    final deviceName = _device?.displayName ?? 'No Device';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _device == null
            ? const Center(child: Text('Please connect a device', style: TextStyle(color: Colors.white54, fontSize: 16)))
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TITANCAST', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                      const SizedBox(height: 2),
                      Text(deviceName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.5), blurRadius: 6)]),
                  )
                ],
              ),

              // --- ÜST MENÜ BARI ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RemoteButton.circle(
                    size: 56,
                    color: const Color(0xFF22222A),
                    onTap: () => _sendCommand(RemoteCommand.power),
                    child: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 24),
                  ),
                  RemoteButton(
                    width: 140, height: 56,
                    color: const Color(0xFF22222A),
                    borderRadius: BorderRadius.circular(28),
                    onTap: _showAppsSheet,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drag_indicator_rounded, color: Color(0xFF8A8A93), size: 18),
                        SizedBox(width: 8),
                        Text('MENU', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                  RemoteButton.circle(
                    size: 56,
                    color: const Color(0xFF22222A),
                    onTap: () {},
                    child: const Icon(Icons.keyboard_outlined, color: Color(0xFF8A8A93), size: 22),
                  ),
                ],
              ),

              // --- ORTA PANEL (VOL / CH) ---
              VolumeChannelRow(onCommand: _sendCommand),

              // --- KOMPAKT SAYFA GEÇİŞ KONTROLLERİ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Sol Ok (Daha küçük ve noktaların hemen yanında)
                  RemoteButton.circle(
                    size: 44,
                    color: const Color(0xFF15151A),
                    onTap: () {},
                    child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 24),
                  ),

                  const SizedBox(width: 16),

                  // İndikatör Noktaları
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF3F3F46), shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Container(width: 24, height: 6, decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 12),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF3F3F46), shape: BoxShape.circle)),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Sağ Ok
                  RemoteButton.circle(
                    size: 44,
                    color: const Color(0xFF15151A),
                    onTap: () {},
                    child: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
                  ),
                ],
              ),

              // --- ALT PANEL (D-PAD) ---
              DPadWidget(onCommand: _sendCommand),

              // --- EN ALT (APPS / CHANNELS) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RemoteButton(
                    width: MediaQuery.of(context).size.width * 0.42, height: 64,
                    color: const Color(0xFF15151A),
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showAppsSheet,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded, color: Color(0xFF8A8A93), size: 20),
                        SizedBox(width: 10),
                        Text('APPS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  RemoteButton(
                    width: MediaQuery.of(context).size.width * 0.42, height: 64,
                    color: const Color(0xFF15151A),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {},
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tv_rounded, color: Color(0xFF8A8A93), size: 20),
                        SizedBox(width: 10),
                        Text('CHANNELS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppPopupChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AppPopupChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RemoteButton(
      width: 140, height: 64,
      color: color,
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}