import 'package:flutter/material.dart';
import '../../../discovery/discovery_model.dart';
import '../../../remote/brand_detector.dart';
import '../../../remote/tv_brand.dart';
import '../../../remote/remote_controller.dart';

class DeviceListItem extends StatelessWidget {
  final DiscoveredDevice device;
  final bool isSelected;
  final RemoteConnectionState connectionState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DeviceListItem({
    super.key,
    required this.device,
    this.isSelected = false,
    this.connectionState = RemoteConnectionState.disconnected,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = _resolveVisuals(device.deviceType);

    // Border rengi gerçek bağlantı durumuna göre belirleniyor.
    final borderColor = switch (connectionState) {
      RemoteConnectionState.connected   => const Color(0xFF10B981),
      RemoteConnectionState.connecting  => const Color(0xFF8B5CF6),
      RemoteConnectionState.error       => const Color(0xFFEF4444),
      RemoteConnectionState.disconnected => Colors.white.withValues(alpha: 0.04),
    };
    final showBorder = isSelected;

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
              color: showBorder ? borderColor : Colors.white.withValues(alpha: 0.04),
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
                decoration: BoxDecoration(
                    color: const Color(0xFF22222A),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(visuals.icon, color: visuals.iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _SupportingText(device: device),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Seçili değilse normal brand/method chip göster.
              // Seçiliyse gerçek bağlantı durumunu badge olarak göster.
              if (!isSelected)
                _BrandOrMethodChip(device: device)
              else
                _ConnectionBadge(state: connectionState),
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
      // TODO: Handle this case.
      DeviceType.modem => const DeviceVisuals(Icons.devices_other_rounded, Color(0xFF8A8A93)),
    };
  }
}

// ---------------------------------------------------------------------------
// Gerçek bağlantı durumu badge'i
// ---------------------------------------------------------------------------

class _ConnectionBadge extends StatelessWidget {
  final RemoteConnectionState state;
  const _ConnectionBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      RemoteConnectionState.connected => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 4)
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text('Connected',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981))),
        ],
      ),
      RemoteConnectionState.connecting => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(
                strokeWidth: 1.8, color: Color(0xFF8B5CF6)),
          ),
          SizedBox(width: 6),
          Text('Connecting',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B5CF6))),
        ],
      ),
      RemoteConnectionState.error => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 14, color: Color(0xFFEF4444)),
          SizedBox(width: 5),
          Text('Failed',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444))),
        ],
      ),
      RemoteConnectionState.disconnected => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio_button_unchecked_rounded,
              size: 10, color: Color(0xFF6B7280)),
          SizedBox(width: 6),
          Text('Selected',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280))),
        ],
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Orijinal chip'ler (seçili olmayan cihazlar için)
// ---------------------------------------------------------------------------

class _BrandOrMethodChip extends StatelessWidget {
  final DiscoveredDevice device;
  const _BrandOrMethodChip({required this.device});

  @override
  Widget build(BuildContext context) {
    final brand = device.detectedBrand;
    final isBrand = brand != null && brand != TvBrand.unknown;
    final label =
    isBrand ? _brandLabel(brand) : _methodLabel(device.method);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isBrand
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
            : const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBrand
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
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
    TvBrand.samsung   => 'Samsung',
    TvBrand.lg        => 'LG',
    TvBrand.sony      => 'Sony',
    TvBrand.philips   => 'Philips',
    TvBrand.hisense   => 'Hisense',
    TvBrand.tcl       => 'TCL',
    TvBrand.panasonic => 'Panasonic',
    TvBrand.sharp     => 'Sharp',
    TvBrand.toshiba   => 'Toshiba',
    TvBrand.google    => 'Google',
    TvBrand.amazon    => 'Amazon',
    TvBrand.apple     => 'Apple',
    TvBrand.roku      => 'Roku',
    TvBrand.torima    => 'Torima',
    TvBrand.androidTv => 'Android TV',
    TvBrand.unknown   => 'Unknown',
  };

  String _methodLabel(DiscoveryMethod method) => switch (method) {
    DiscoveryMethod.ssdp         => 'SSDP',
    DiscoveryMethod.mdns         => 'mDNS',
    DiscoveryMethod.networkProbe => 'PROBE',
    DiscoveryMethod.manualIp     => 'IP',
    DiscoveryMethod.qr           => 'QR',
  };
}

class _SupportingText extends StatelessWidget {
  final DiscoveredDevice device;
  const _SupportingText({required this.device});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    if (device.manufacturer != null) {
      spans.add(TextSpan(
          text: device.manufacturer!,
          style: const TextStyle(
              color: Color(0xFF8A8A93),
              fontWeight: FontWeight.w500,
              fontSize: 12)));
      spans.add(const TextSpan(
          text: '  ·  ', style: TextStyle(color: Color(0xFF3F3F46))));
    }
    spans.add(TextSpan(
        text: device.ip,
        style: const TextStyle(
            color: Color(0xFF8A8A93),
            fontFamily: 'monospace',
            fontSize: 11)));
    return RichText(
        text: TextSpan(children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis);
  }
}

class DeviceVisuals {
  final IconData icon;
  final Color iconColor;
  const DeviceVisuals(this.icon, this.iconColor);
}