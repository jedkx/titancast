import 'package:flutter/material.dart';
import '../../../discovery/discovery_model.dart';
import '../../../remote/brand_detector.dart';

class DeviceListItem extends StatelessWidget {
  final DiscoveredDevice device;
  final bool isConnected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DeviceListItem({
    super.key,
    required this.device,
    this.isConnected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = _resolveVisuals(device.deviceType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF15151A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isConnected ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.04),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: const Color(0xFF22222A), borderRadius: BorderRadius.circular(16)),
                child: Icon(visuals.icon, color: visuals.iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _SupportingText(device: device),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isConnected) const _ConnectedBadge() else _BrandOrMethodChip(device: device),
            ],
          ),
        ),
      ),
    );
  }

  DeviceVisuals _resolveVisuals(DeviceType type) {
    return switch (type) {
      DeviceType.tv      => const DeviceVisuals(Icons.tv_rounded, Color(0xFFE2E2E6)),
      DeviceType.speaker => const DeviceVisuals(Icons.speaker_group_rounded, Color(0xFFE2E2E6)),
      DeviceType.other   => const DeviceVisuals(Icons.devices_other_rounded, Color(0xFF8A8A93)),
    };
  }
}

class _BrandOrMethodChip extends StatelessWidget {
  final DiscoveredDevice device;
  const _BrandOrMethodChip({required this.device});

  @override
  Widget build(BuildContext context) {
    final brand = device.detectedBrand;
    final isBrand = brand != null && brand != TvBrand.unknown;
    final label = isBrand ? _brandLabel(brand) : _methodLabel(device.method);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isBrand ? const Color(0xFF8B5CF6).withValues(alpha: 0.1) : const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isBrand ? const Color(0xFF8B5CF6).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isBrand ? const Color(0xFF8B5CF6) : const Color(0xFF8A8A93),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  String _brandLabel(TvBrand brand) => switch (brand) {
    TvBrand.samsung => 'Samsung', TvBrand.lg => 'LG', TvBrand.sony => 'Sony',
    TvBrand.philips => 'Philips', TvBrand.hisense => 'Hisense', TvBrand.tcl => 'TCL',
    TvBrand.panasonic => 'Panasonic', TvBrand.sharp => 'Sharp', TvBrand.toshiba => 'Toshiba',
    TvBrand.google => 'Google', TvBrand.amazon => 'Amazon', TvBrand.apple => 'Apple',
    TvBrand.roku => 'Roku', TvBrand.torima => 'Torima', TvBrand.unknown => 'Unknown',
  };

  String _methodLabel(DiscoveryMethod method) => switch (method) {
    DiscoveryMethod.ssdp => 'SSDP', DiscoveryMethod.mdns => 'mDNS',
    DiscoveryMethod.networkProbe => 'PROBE', DiscoveryMethod.manualIp => 'IP',
    DiscoveryMethod.qr => 'QR',
  };
}

class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 4)]),
        ),
        const SizedBox(width: 6),
        const Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
      ],
    );
  }
}

class _SupportingText extends StatelessWidget {
  final DiscoveredDevice device;
  const _SupportingText({required this.device});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    if (device.manufacturer != null) {
      spans.add(TextSpan(text: device.manufacturer!, style: const TextStyle(color: Color(0xFF8A8A93), fontWeight: FontWeight.w500, fontSize: 12)));
      spans.add(const TextSpan(text: '  ·  ', style: TextStyle(color: Color(0xFF3F3F46))));
    }
    spans.add(TextSpan(text: device.ip, style: const TextStyle(color: Color(0xFF8A8A93), fontFamily: 'monospace', fontSize: 11)));
    return RichText(text: TextSpan(children: spans), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

class DeviceVisuals {
  final IconData icon;
  final Color iconColor;
  const DeviceVisuals(this.icon, this.iconColor);
}