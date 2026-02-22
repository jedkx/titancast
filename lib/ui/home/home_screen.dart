import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/discovery_manager.dart';
import '../../data/device_repository.dart';
import '../find_tv/find_tv_screen.dart';
import '../common/wifi_info_widget.dart';
// import '../../data/seed_devices.dart'; // TODO: remove before release

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = DeviceRepository();
  final _discoveryManager = DiscoveryManager();

  List<Object> _groupedList = [];
  bool _isLoading = false;
  String? _wifiSsid;

  final List<DiscoveredDevice> _updateBuffer = [];
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _repo.init();
    // await seedDummyDevices(_repo); // TODO: remove before release
    await _fetchWifiSsid();
    if (mounted) setState(() => _groupedList = _repo.buildGroupedList());
  }

  Future<void> _fetchWifiSsid() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) return;
      final wifiInfo = await WifiInfoDatasource().getWifiInfo();
      if (mounted) {
        setState(() => _wifiSsid = wifiInfo?.ssid?.replaceAll('"', ''));
      }
    } catch (_) {}
  }

  Future<void> _openFindTv() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindTvScreen(
          onDiscoveryStarted: _attachDiscoveryStream,
          onDeviceFound: (d) => _bufferUpdate(d.copyWith(ssid: _wifiSsid)),
          isLoading: _isLoading,
        ),
      ),
    );
  }

  void _attachDiscoveryStream(Stream<DiscoveredDevice> stream) {
    setState(() => _isLoading = true);
    stream.listen(
          (d) => _bufferUpdate(d.copyWith(ssid: _wifiSsid)),
      onError: (e) => debugPrint('Discovery error: $e'),
      onDone: () {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _bufferUpdate(DiscoveredDevice device) {
    _updateBuffer.add(device);
    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _updateBuffer.isEmpty) return;
      for (final d in _updateBuffer) {
        if (!_isPlaceholder(d.friendlyName)) await _repo.save(d);
      }
      _updateBuffer.clear();
      if (mounted) setState(() => _groupedList = _repo.buildGroupedList());
    });
  }

  bool _isPlaceholder(String name) =>
      name.startsWith('Identifying') || name.contains('...');

  void _showDeviceMenu(DiscoveredDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DeviceMenuSheet(
        device: device,
        onConnect: () {
          Navigator.pop(context);
          debugPrint('Connect: ${device.ip}');
        },
        onRename: () {
          Navigator.pop(context);
          _showRenameDialog(device);
        },
        onDelete: () async {
          Navigator.pop(context);
          await _repo.delete(device.ip);
          if (mounted) setState(() => _groupedList = _repo.buildGroupedList());
        },
      ),
    );
  }

  void _showRenameDialog(DiscoveredDevice device) {
    final controller =
    TextEditingController(text: device.customName ?? device.friendlyName);

    showDialog(
      context: context,
      builder: (_) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          title: const Text('Rename device'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Device name',
            ),
            onSubmitted: (_) => _commitRename(controller.text, device.ip),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _commitRename(controller.text, device.ip),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _commitRename(String name, String ip) async {
    await _repo.rename(ip, name);
    if (mounted) {
      Navigator.pop(context);
      setState(() => _groupedList = _repo.buildGroupedList());
    }
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
    final deviceCount = _repo.devices.length;

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
              title: _AppBarTitle(wifiSsid: _wifiSsid),
              background: _AppBarBackground(colorScheme: colorScheme),
              collapseMode: CollapseMode.pin,
            ),
          ),

          if (_isLoading)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),

          if (deviceCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  '$deviceCount device${deviceCount == 1 ? '' : 's'}',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          if (_groupedList.isEmpty && !_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(onFindTv: _openFindTv),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList.builder(
                itemCount: _groupedList.length,
                itemBuilder: (context, index) {
                  final item = _groupedList[index];
                  if (item is SsidHeader) {
                    return _SectionHeader(ssid: item.ssid);
                  }
                  final device = item as DiscoveredDevice;
                  return DeviceListItem(
                    device: device,
                    onLongPress: () => _showDeviceMenu(device),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _FindTvFab(
        isLoading: _isLoading,
        onPressed: _openFindTv,
      ),
    );
  }
}

// =============================================================================
// App bar title
// =============================================================================

class _AppBarTitle extends StatelessWidget {
  final String? wifiSsid;
  const _AppBarTitle({required this.wifiSsid});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'TITANCAST',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'My Devices',
          style: textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        WifiInfoWidget(ssid: wifiSsid),
      ],
    );
  }
}

// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String ssid;
  const _SectionHeader({required this.ssid});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.wifi_rounded, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            ssid,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: colorScheme.outlineVariant, height: 1),
          ),
        ],
      ),
    );
  }
}

class _DeviceMenuSheet extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onConnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _DeviceMenuSheet({
    required this.device,
    required this.onConnect,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
  final VoidCallback onFindTv;
  const _EmptyState({required this.onFindTv});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
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
            Text(
              'Scanning...',
              style: textTheme.labelLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
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
      label: Text(
        'Find TV',
        style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// =============================================================================
// Device list item
// =============================================================================

class DeviceListItem extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback? onLongPress;

  const DeviceListItem({super.key, required this.device, this.onLongPress});

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
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

    if (type.contains('tv') ||
        type.contains('renderer') ||
        type.contains('dial') ||
        type.contains('jointspace') ||
        name.contains('tv')) {
      return _DeviceVisuals(
          Icons.tv_rounded, cs.primaryContainer, cs.onPrimaryContainer);
    }
    if (type.contains('audio') ||
        type.contains('speaker') ||
        name.contains('speaker') ||
        name.contains('soundbar')) {
      return _DeviceVisuals(Icons.speaker_group_rounded,
          cs.secondaryContainer, cs.onSecondaryContainer);
    }
    if (type.contains('router') ||
        type.contains('gateway') ||
        name.contains('router')) {
      return _DeviceVisuals(
          Icons.router_rounded, cs.tertiaryContainer, cs.onTertiaryContainer);
    }
    return _DeviceVisuals(Icons.devices_other_rounded,
        cs.surfaceContainerHighest, cs.onSurfaceVariant);
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

class _DeviceVisuals {
  final IconData icon;
  final Color containerColor;
  final Color iconColor;
  const _DeviceVisuals(this.icon, this.containerColor, this.iconColor);
}