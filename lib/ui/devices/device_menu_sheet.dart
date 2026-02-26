import 'package:flutter/material.dart';
import '../../../discovery/discovery_model.dart';
import '../../../remote/brand_detector.dart';
import '../../../remote/tv_brand.dart';

class DeviceMenuSheet extends StatelessWidget {
  final DiscoveredDevice device;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(TvBrand) onSetBrand;

  const DeviceMenuSheet({
    super.key,
    required this.device,
    this.isConnected = false,
    required this.onConnect,
    this.onDisconnect,
    required this.onRename,
    required this.onDelete,
    required this.onSetBrand,
  });

  static Future<void> show({
    required BuildContext context,
    required DiscoveredDevice device,
    bool isConnected = false,
    required VoidCallback onConnect,
    VoidCallback? onDisconnect,
    required VoidCallback onRename,
    required VoidCallback onDelete,
    required void Function(TvBrand) onSetBrand,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DeviceMenuSheet(
        device: device,
        isConnected: isConnected,
        onConnect: onConnect,
        onDisconnect: onDisconnect,
        onRename: onRename,
        onDelete: onDelete,
        onSetBrand: onSetBrand,
      ),
    );
  }

  static String brandLabel(TvBrand b) => switch (b) {
    TvBrand.philips   => 'Philips',
    TvBrand.samsung   => 'Samsung',
    TvBrand.lg        => 'LG',
    TvBrand.sony      => 'Sony',
    TvBrand.androidTv => 'Android TV / Google TV',
    TvBrand.hisense   => 'Hisense',
    TvBrand.tcl       => 'TCL',
    TvBrand.panasonic => 'Panasonic',
    TvBrand.sharp     => 'Sharp',
    TvBrand.toshiba   => 'Toshiba',
    TvBrand.torima    => 'Torima (ADB)',
    TvBrand.unknown   => '⚠ Bilinmiyor',
    _                 => b.name,
  };

  void _showBrandPicker(BuildContext context) {
    Navigator.pop(context);
    final brands = [
      TvBrand.philips,
      TvBrand.samsung,
      TvBrand.lg,
      TvBrand.sony,
      TvBrand.androidTv,
      TvBrand.hisense,
      TvBrand.tcl,
      TvBrand.panasonic,
      TvBrand.sharp,
      TvBrand.toshiba,
      TvBrand.torima,
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15151A),
        title: const Text('Select Brand', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: brands.length,
            itemBuilder: (_, i) {
              final b = brands[i];
              final isSelected = device.detectedBrand == b;
              return ListTile(
                title: Text(
                  brandLabel(b),
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.white,
                    fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded,
                    color: Color(0xFF8B5CF6))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onSetBrand(b);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8A8A93))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tv_rounded,
                      size: 20, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        device.ip,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (device.detectedBrand != null)
                        Text(
                          brandLabel(device.detectedBrand!),
                          style: textTheme.bodySmall?.copyWith(
                            color: device.detectedBrand == TvBrand.unknown
                                ? colorScheme.error
                                : colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: colorScheme.outlineVariant,
            height: 1,
            indent: 24,
            endIndent: 24,
          ),
          const SizedBox(height: 8),
          if (isConnected)
            _MenuAction(
              icon: Icons.cast_rounded,
              label: 'Disconnect',
              color: colorScheme.error,
              onTap: onDisconnect ?? () {},
            )
          else
            _MenuAction(
              icon: Icons.cast_rounded,
              label: 'Connect',
              color: colorScheme.primary,
              onTap: onConnect,
            ),
          _MenuAction(
            icon: Icons.edit_rounded,
            label: 'Rename',
            color: colorScheme.onSurface,
            onTap: onRename,
          ),
          _MenuAction(
            icon: Icons.devices_other_rounded,
            label: 'Set Brand',
            color: colorScheme.secondary,
            onTap: () => _showBrandPicker(context),
          ),
          _MenuAction(
            icon: Icons.delete_outline_rounded,
            label: 'Remove',
            color: colorScheme.error,
            onTap: onDelete,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}