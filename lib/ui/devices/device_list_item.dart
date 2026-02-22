import 'package:flutter/material.dart';
import '../../../discovery/discovery_model.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;
    final visuals     = _resolveVisuals(device.deviceType, colorScheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: isConnected
            ? RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
            width: 1.5,
          ),
        )
            : null,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _DeviceIcon(visuals: visuals),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _SupportingText(device: device),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isConnected)
                  const _ConnectedBadge()
                else
                  _MethodChip(method: device.method),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DeviceVisuals _resolveVisuals(DeviceType type, ColorScheme cs) {
    return switch (type) {
      DeviceType.tv      => DeviceVisuals(Icons.tv_rounded, cs.primaryContainer, cs.onPrimaryContainer),
      DeviceType.speaker => DeviceVisuals(Icons.speaker_group_rounded, cs.secondaryContainer, cs.onSecondaryContainer),
      DeviceType.other   => DeviceVisuals(Icons.devices_other_rounded, cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
  }
}

class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Connected',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4CAF50),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  final DeviceVisuals visuals;
  const _DeviceIcon({required this.visuals});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: visuals.containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(visuals.icon, color: visuals.iconColor, size: 24),
    );
  }
}

class _SupportingText extends StatelessWidget {
  final DiscoveredDevice device;
  const _SupportingText({required this.device});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;
    final spans       = <InlineSpan>[];

    if (device.manufacturer != null) {
      spans.add(TextSpan(
        text: device.manufacturer!,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ));
      spans.add(TextSpan(
        text: '  ·  ',
        style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
      ));
    }
    spans.add(TextSpan(
      text: device.ip,
      style: textTheme.bodySmall?.copyWith(
        color: colorScheme.outline,
        fontFamily: 'monospace',
      ),
    ));

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MethodChip extends StatelessWidget {
  final DiscoveryMethod method;
  const _MethodChip({required this.method});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        switch (method) {
          DiscoveryMethod.ssdp         => 'SSDP',
          DiscoveryMethod.mdns         => 'mDNS',
          DiscoveryMethod.networkProbe => 'PROBE',
          DiscoveryMethod.manualIp     => 'IP',
          DiscoveryMethod.qr           => 'QR',
        },
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class DeviceVisuals {
  final IconData icon;
  final Color containerColor;
  final Color iconColor;
  const DeviceVisuals(this.icon, this.containerColor, this.iconColor);
}