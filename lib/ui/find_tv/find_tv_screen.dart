import 'package:flutter/material.dart';
import '../../discovery/discovery_model.dart';
import 'network_scan_screen.dart';
import 'ip_input_screen.dart';
import 'qr_scan_screen.dart';

/// Entry screen showing 3 discovery method cards.
/// Each card shows only a title + short subtitle initially.
/// Tapping expands it to reveal numbered steps + action button.
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
  // Which card is currently expanded. null = all collapsed.
  _MethodType? _expanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            surfaceTintColor: colorScheme.surfaceTint,
            shadowColor: Colors.transparent,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 16,
              ),
              centerTitle: false,
              title: Text(
                'Find TV',
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              collapseMode: CollapseMode.pin,
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 4),
                  child: Text(
                    'Choose how to connect',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                _MethodCard(
                  type: _MethodType.network,
                  icon: Icons.radar_rounded,
                  title: 'Network Scan',
                  subtitle: 'Automatically find all TVs on your Wi-Fi.',
                  steps: const [
                    'Make sure your phone and TV are on the same Wi-Fi.',
                    'Tap "Start Scan" — discovery runs for up to 15 seconds.',
                    'Your TV appears in the list as it is found.',
                  ],
                  containerColor: colorScheme.primaryContainer,
                  iconColor: colorScheme.onPrimaryContainer,
                  isExpanded: _expanded == _MethodType.network,
                  onToggle: () => _toggle(_MethodType.network),
                  onAction: () => _openNetworkScan(context),
                  actionLabel: 'Start Scan',
                  actionIcon: Icons.radar_rounded,
                ),

                const SizedBox(height: 12),

                _MethodCard(
                  type: _MethodType.ip,
                  icon: Icons.lan_rounded,
                  title: 'Enter IP Address',
                  subtitle: 'Connect directly with your TV\'s IP address.',
                  steps: const [
                    'On your TV go to Settings > Network > IP Address.',
                    'Type the address shown (e.g. 192.168.1.100).',
                    'Tap "Connect" — TitanCast will identify your TV.',
                  ],
                  containerColor: colorScheme.secondaryContainer,
                  iconColor: colorScheme.onSecondaryContainer,
                  isExpanded: _expanded == _MethodType.ip,
                  onToggle: () => _toggle(_MethodType.ip),
                  onAction: () => _openIpInput(context),
                  actionLabel: 'Enter IP',
                  actionIcon: Icons.link_rounded,
                ),

                const SizedBox(height: 12),

                _MethodCard(
                  type: _MethodType.qr,
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scan QR Code',
                  subtitle: 'Fastest setup — scan the code on your TV screen.',
                  steps: const [
                    'Open TitanCast on your TV and select "Connect Phone".',
                    'A QR code will appear on your TV screen.',
                    'Tap "Open Camera" and point it at the QR code.',
                  ],
                  containerColor: colorScheme.tertiaryContainer,
                  iconColor: colorScheme.onTertiaryContainer,
                  isExpanded: _expanded == _MethodType.qr,
                  onToggle: () => _toggle(_MethodType.qr),
                  onAction: () => _openQrScan(context),
                  actionLabel: 'Open Camera',
                  actionIcon: Icons.camera_alt_rounded,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(_MethodType type) {
    setState(() => _expanded = _expanded == type ? null : type);
  }

  Future<void> _openNetworkScan(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NetworkScanScreen(
          onDiscoveryStarted: widget.onDiscoveryStarted,
        ),
      ),
    );
  }

  Future<void> _openIpInput(BuildContext context) async {
    final device = await Navigator.push<DiscoveredDevice>(
      context,
      MaterialPageRoute(builder: (_) => const IpInputScreen()),
    );
    if (device != null) {
      widget.onDeviceFound(device);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _openQrScan(BuildContext context) async {
    final device = await Navigator.push<DiscoveredDevice>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (device != null) {
      widget.onDeviceFound(device);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

enum _MethodType { network, ip, qr }

// =============================================================================
// Expandable method card
// =============================================================================

class _MethodCard extends StatelessWidget {
  final _MethodType type;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> steps;
  final Color containerColor;
  final Color iconColor;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAction;
  final String actionLabel;
  final IconData actionIcon;

  const _MethodCard({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.containerColor,
    required this.iconColor,
    required this.isExpanded,
    required this.onToggle,
    required this.onAction,
    required this.actionLabel,
    required this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Always visible: icon + title + subtitle + chevron
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: containerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Expanded: divider + numbered steps + action button
                if (isExpanded) ...[
                  const SizedBox(height: 20),
                  Divider(color: colorScheme.outlineVariant, height: 1),
                  const SizedBox(height: 20),

                  // Numbered steps
                  ...steps.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: containerColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 8),

                  // Action button -- full width, tap triggers the real action
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: containerColor,
                        foregroundColor: iconColor,
                      ),
                      icon: Icon(actionIcon, size: 18),
                      label: Text(actionLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}