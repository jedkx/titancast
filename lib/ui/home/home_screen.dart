import 'package:network_info_plus/network_info_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/discovery_manager.dart';
import '../find_tv/find_tv_screen.dart';
import 'package:titancast/ui/common/wifi_info_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
    String? _wifiName;
    @override
    void initState() {
      super.initState();
      _fetchWifiName();
    }

    Future<void> _fetchWifiName() async {
      try {
        final info = await NetworkInfo().getWifiName();
        if (mounted) setState(() => _wifiName = info);
      } catch (_) {
        if (mounted) setState(() => _wifiName = null);
      }
    }
  final List<DiscoveredDevice> _devices = [];
  bool _isLoading = false;
  final DiscoveryManager _discoveryManager = DiscoveryManager();

  final List<DiscoveredDevice> _updateBuffer = [];
  Timer? _throttleTimer;

  Future<void> _openFindTv() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindTvScreen(
          onDiscoveryStarted: _attachDiscoveryStream,
          onDeviceFound: _bufferUpdate,
          isLoading: _isLoading,
        ),
      ),
    );
  }

  void _attachDiscoveryStream(Stream<DiscoveredDevice> stream) {
    setState(() => _isLoading = true);

    stream.listen(
      _bufferUpdate,
      onError: (e) => debugPrint('Discovery error: $e'),
      onDone: () {
        if (mounted) setState(() => _isLoading = false);
      },
    );

  }

  void _bufferUpdate(DiscoveredDevice device) {
    _updateBuffer.add(device);
    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _updateBuffer.isEmpty) return;
      setState(() {
        for (final incoming in _updateBuffer) {
          final index = _devices.indexWhere((d) => d.ip == incoming.ip);
          if (index != -1) {
            _devices[index] = incoming;
          } else {
            _devices.add(incoming);
          }
        }
        _updateBuffer.clear();
      });
    });
  }

  void _clearDevices() {
    setState(() {
      _devices.clear();
      _updateBuffer.clear();
    });
    _discoveryManager.stopDiscovery();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _discoveryManager.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'My Devices',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  WifiInfoWidget(ssid: _wifiName),
                ],
              ),
              background: _AppBarBackground(colorScheme: colorScheme),
              collapseMode: CollapseMode.pin,
            ),
            actions: [
              if (_devices.isNotEmpty)
                IconButton(
                  onPressed: _clearDevices,
                  icon: const Icon(Icons.clear_all_rounded),
                  tooltip: 'Clear list',
                  padding: const EdgeInsets.all(12),
                ),
              const SizedBox(width: 4),
            ],
          ),

          if (_isLoading)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor:
                AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),

          if (_devices.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '${_devices.length} device${_devices.length == 1 ? '' : 's'} found',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

          if (_devices.isEmpty && !_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                colorScheme: colorScheme,
                textTheme: textTheme,
                onFindTv: _openFindTv,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) =>
                    DeviceListItem(device: _devices[index]),
              ),
            ),
        ],
      ),

      // Single FAB -- only in home screen, not duplicated
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _FindTvFab(
        isLoading: _isLoading,
        onPressed: _openFindTv,
      ),
    );
  }
}

// =============================================================================
// Widgets
// =============================================================================

class _AppBarBackground extends StatelessWidget {
  final ColorScheme colorScheme;
  const _AppBarBackground({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surfaceContainerHigh, colorScheme.surface],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.9, -0.3),
        child: Icon(
          Icons.settings_input_antenna_rounded,
          size: 180,
          color: colorScheme.primary.withValues(alpha: 0.06),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onFindTv;

  const _EmptyState({
    required this.colorScheme,
    required this.textTheme,
    required this.onFindTv,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cast_rounded,
                  size: 48, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              'No devices yet',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap "Find TV" to discover devices on your network.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FindTvFab extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _FindTvFab({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        label: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text('Scanning...',
                style: textTheme.labelLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 3,
      icon: const Icon(Icons.tv_rounded),
      label: Text('Find TV',
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

// =============================================================================
// Device list item -- public, reusable
// =============================================================================

class DeviceListItem extends StatelessWidget {
  final DiscoveredDevice device;
  const DeviceListItem({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final visuals = _resolveVisuals(device, colorScheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          onTap: () => debugPrint('Connect: ${device.ip}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: visuals.containerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(visuals.icon, color: visuals.iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.friendlyName,
                        style: textTheme.titleMedium?.copyWith(
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
                _MethodChip(method: device.method),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _DeviceVisuals _resolveVisuals(DiscoveredDevice d, ColorScheme cs) {
    final type = (d.serviceType ?? '').toLowerCase();
    final name = d.friendlyName.toLowerCase();

    final bool isTV = type.contains('tv') ||
        type.contains('renderer') ||
        type.contains('dial') ||
        type.contains('jointspace') ||
        name.contains('tv');

    final bool isAudio = type.contains('audio') ||
        type.contains('speaker') ||
        name.contains('speaker') ||
        name.contains('soundbar');

    final bool isRouter =
        type.contains('router') || type.contains('gateway') || name.contains('router');

    if (isTV) return _DeviceVisuals(Icons.tv_rounded, cs.primaryContainer, cs.onPrimaryContainer);
    if (isAudio) return _DeviceVisuals(Icons.speaker_group_rounded, cs.secondaryContainer, cs.onSecondaryContainer);
    if (isRouter) return _DeviceVisuals(Icons.router_rounded, cs.tertiaryContainer, cs.onTertiaryContainer);
    return _DeviceVisuals(Icons.devices_other_rounded, cs.surfaceContainerHighest, cs.onSurfaceVariant);
  }
}

class _SupportingText extends StatelessWidget {
  final DiscoveredDevice device;
  const _SupportingText({required this.device});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spans = <InlineSpan>[];

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
      style: textTheme.bodySmall
          ?.copyWith(color: colorScheme.outline, fontFamily: 'monospace'),
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        _label(method),
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  String _label(DiscoveryMethod m) => switch (m) {
    DiscoveryMethod.ssdp         => 'SSDP',
    DiscoveryMethod.mdns         => 'mDNS',
    DiscoveryMethod.networkProbe => 'PROBE',
    DiscoveryMethod.manualIp     => 'IP',
    DiscoveryMethod.qr           => 'QR',
  };
}

class _DeviceVisuals {
  final IconData icon;
  final Color containerColor;
  final Color iconColor;
  const _DeviceVisuals(this.icon, this.containerColor, this.iconColor);
}