import 'package:flutter/material.dart';
import 'package:titancast/remote/remote_controller.dart';

/// Slim status pill shown below the app bar to communicate connection state.
class ConnectionBanner extends StatelessWidget {
  final RemoteConnectionState state;
  final String? errorMessage;
  final VoidCallback onRetry;

  const ConnectionBanner({
    super.key,
    required this.state,
    this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (state) {
      RemoteConnectionState.connecting => _Banner(
        color: colorScheme.secondaryContainer,
        textColor: colorScheme.onSecondaryContainer,
        icon: Icons.bluetooth_searching_rounded,
        label: 'Connecting…',
      ),
      RemoteConnectionState.connected => _Banner(
        color: colorScheme.primaryContainer,
        textColor: colorScheme.onPrimaryContainer,
        icon: Icons.cast_connected_rounded,
        label: 'Connected',
      ),
      RemoteConnectionState.error => _Banner(
        color: colorScheme.errorContainer,
        textColor: colorScheme.onErrorContainer,
        icon: Icons.error_outline_rounded,
        label: errorMessage ?? 'Connection failed',
        trailing: TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),
      ),
      RemoteConnectionState.disconnected => const SizedBox.shrink(),
    };
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _Banner({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}