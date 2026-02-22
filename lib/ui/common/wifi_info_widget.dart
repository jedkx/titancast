import 'package:flutter/material.dart';

/// Compact WiFi indicator that shows the network SSID with an icon.
///
/// When [ssid] is `null` or empty a "Not connected" fallback is rendered
/// together with a crossed-out WiFi icon.
///
/// Usage:
/// ```dart
/// WifiInfoWidget(ssid: _wifiName);
/// WifiInfoWidget(ssid: _wifiName, size: WifiInfoSize.medium);
/// ```
class WifiInfoWidget extends StatelessWidget {
  /// Current WiFi SSID. Pass `null` when the name cannot be determined.
  final String? ssid;

  /// Controls the icon & text sizing preset.
  final WifiInfoSize size;

  const WifiInfoWidget({
    super.key,
    this.ssid,
    this.size = WifiInfoSize.small,
  });

  bool get _isConnected => ssid != null && ssid!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (double iconSize, TextStyle? textStyle) = switch (size) {
      WifiInfoSize.small => (
      14.0,
      textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      ),
      WifiInfoSize.medium => (
      18.0,
      textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      ),
    };

    final iconColor = _isConnected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          size: iconSize,
          color: iconColor,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _isConnected ? _sanitisedSsid! : 'Not connected',
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Android wraps SSID with quotes – strip them for display.
  String? get _sanitisedSsid {
    final raw = ssid;
    if (raw == null) return null;
    if (raw.startsWith('"') && raw.endsWith('"')) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }
}

/// Size presets for [WifiInfoWidget].
enum WifiInfoSize {
  /// 14 px icon, labelSmall text — fits inside app bar titles.
  small,

  /// 18 px icon, bodySmall text — standalone usage.
  medium,
}