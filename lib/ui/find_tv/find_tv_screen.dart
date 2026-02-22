import 'package:flutter/material.dart';
import '../../discovery/discovery_model.dart';
import 'network_scan_screen.dart';
import 'ip_input_screen.dart';
import 'qr_scan_screen.dart';

enum _MethodType { network, manualIp, qr }

class FindTvScreen extends StatefulWidget {
  final void Function(Stream<DiscoveredDevice>) onDiscoveryStarted;
  final void Function(DiscoveredDevice) onDeviceFound;
  final bool isLoading;

  const FindTvScreen({
    super.key,
    required this.onDiscoveryStarted,
    required this.onDeviceFound,
    required this.isLoading,
  });

  @override
  State<FindTvScreen> createState() => _FindTvScreenState();
}

class _FindTvScreenState extends State<FindTvScreen> {
  _MethodType? _expanded;

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0A0A0E);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Device',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          const Text(
            'Select Connection Method',
            style: TextStyle(color: Color(0xFF8A8A93), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),

          _MethodCard(
            type: _MethodType.network,
            title: 'Auto Scan',
            subtitle: 'Find TVs on your current Wi-Fi network',
            icon: Icons.wifi_find_rounded,
            isExpanded: _expanded == _MethodType.network,
            onTap: () => setState(() => _expanded = _expanded == _MethodType.network ? null : _MethodType.network),
            actionLabel: 'Start Scanning',
            actionIcon: Icons.search_rounded,
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NetworkScanScreen(onDiscoveryStarted: widget.onDiscoveryStarted)),
              );
            },
            steps: const {
              '1': 'Ensure your phone and TV are on the same Wi-Fi.',
              '2': 'Tap scan and wait for your TV to appear.',
            },
          ),
          const SizedBox(height: 16),

          _MethodCard(
            type: _MethodType.manualIp,
            title: 'IP Address',
            subtitle: 'Enter your TV\'s IP address directly',
            icon: Icons.settings_ethernet_rounded,
            isExpanded: _expanded == _MethodType.manualIp,
            onTap: () => setState(() => _expanded = _expanded == _MethodType.manualIp ? null : _MethodType.manualIp),
            actionLabel: 'Enter IP',
            actionIcon: Icons.keyboard_rounded,
            onAction: () async {
              final device = await Navigator.push<DiscoveredDevice>(
                context,
                MaterialPageRoute(builder: (_) => const IpInputScreen()),
              );
              if (device != null && mounted) {
                widget.onDeviceFound(device);
                Navigator.pop(context);
              }
            },
            steps: const {
              '1': 'Go to your TV\'s Network Settings.',
              '2': 'Find the IPv4 Address (e.g., 192.168.1.50).',
              '3': 'Enter it on the next screen.',
            },
          ),
          const SizedBox(height: 16),

          _MethodCard(
            type: _MethodType.qr,
            title: 'Scan QR Code',
            subtitle: 'Use your camera to scan a TV code',
            icon: Icons.qr_code_scanner_rounded,
            isExpanded: _expanded == _MethodType.qr,
            onTap: () => setState(() => _expanded = _expanded == _MethodType.qr ? null : _MethodType.qr),
            actionLabel: 'Open Camera',
            actionIcon: Icons.camera_alt_rounded,
            onAction: () async {
              final device = await Navigator.push<DiscoveredDevice>(
                context,
                MaterialPageRoute(builder: (_) => const QrScanScreen()),
              );
              if (device != null && mounted) {
                widget.onDeviceFound(device);
                Navigator.pop(context);
              }
            },
            steps: const {
              '1': 'Open the TitanCast app on your TV.',
              '2': 'Select "Connect Phone".',
              '3': 'Scan the QR code displayed on the screen.',
            },
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final _MethodType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final Map<String, String> steps;

  const _MethodCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    const Color panelColor = Color(0xFF15151A);
    const Color accentColor = Color(0xFF8B5CF6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? accentColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: isExpanded
            ? [BoxShadow(color: accentColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: const Color(0xFF22222A), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: isExpanded ? accentColor : Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(color: Color(0xFF8A8A93), fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8A8A93),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 24),
                const Divider(color: Color(0xFF22222A), height: 1),
                const SizedBox(height: 16),
                ...steps.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Center(child: Text(e.key, style: const TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 13, height: 1.4))),
                    ],
                  ),
                )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onAction,
                    icon: Icon(actionIcon, size: 18, color: Colors.white),
                    label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}