import 'package:flutter/material.dart';
import '../../../discovery/discovery_model.dart';

class DeviceMenuSheet extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onConnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const DeviceMenuSheet({
    super.key,
    required this.device,
    required this.onConnect,
    required this.onRename,
    required this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required DiscoveredDevice device,
    required VoidCallback onConnect,
    required VoidCallback onRename,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DeviceMenuSheet(
        device: device,
        onConnect: onConnect,
        onRename: onRename,
        onDelete: onDelete,
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