import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/device_repository.dart';
import '../../../data/seed_devices.dart';
import '../../../discovery/discovery_model.dart';
import '../../../discovery/discovery_manager.dart';
import '../find_tv/find_tv_screen.dart';
import '../shared/wifi_info_widget.dart';
import 'device_list_item.dart';
import 'device_filter_chips.dart';
import 'device_menu_sheet.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _repo             = DeviceRepository();
  final _discoveryManager = DiscoveryManager();

  List<Object> _groupedList = [];
  bool _isLoading           = false;
  String? _wifiSsid;
  DeviceType? _activeFilter;
  String? _connectedIp;

  final List<DiscoveredDevice> _updateBuffer = [];
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _repo.init();
    if (kDebugMode) await seedDummyDevices(_repo);
    await _fetchWifiSsid();
    if (mounted) setState(() => _groupedList = _buildFilteredList());
  }

  Future<void> _fetchWifiSsid() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) return;
      final info = await WifiInfoDatasource().getWifiInfo();
      if (mounted) setState(() => _wifiSsid = info?.ssid);
    } catch (_) {}
  }

  List<Object> _buildFilteredList() {
    if (_activeFilter == null) return _repo.buildGroupedList();

    final filtered = _repo.devices
        .where((d) => d.deviceType == _activeFilter)
        .toList();

    if (filtered.isEmpty) return [];

    final ssids = filtered.map((d) => d.ssid ?? 'Unknown Network').toSet();
    if (ssids.length <= 1) return List<Object>.from(filtered);

    final result = <Object>[];
    for (final ssid in ssids) {
      result.add(SsidHeader(ssid: ssid));
      result.addAll(
        filtered.where((d) => (d.ssid ?? 'Unknown Network') == ssid),
      );
    }
    return result;
  }

  void _setFilter(DeviceType? type) {
    setState(() {
      _activeFilter = (_activeFilter == type) ? null : type;
      _groupedList  = _buildFilteredList();
    });
  }

  void _connectToDevice(DiscoveredDevice device) {
    setState(() => _connectedIp = device.ip);
    debugPrint('Connected: ${device.ip}');
  }

  Future<void> _openFindDevice() async {
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
      onError: (Object e) => debugPrint('Discovery error: $e'),
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
      if (mounted) setState(() => _groupedList = _buildFilteredList());
    });
  }

  bool _isPlaceholder(String name) =>
      name.startsWith('Identifying') || name.contains('...');

  void _showDeviceMenu(DiscoveredDevice device) {
    DeviceMenuSheet.show(
      context: context,
      device: device,
      onConnect: () {
        Navigator.pop(context);
        _connectToDevice(device);
      },
      onRename: () {
        Navigator.pop(context);
        _showRenameDialog(device);
      },
      onDelete: () async {
        Navigator.pop(context);
        if (_connectedIp == device.ip) setState(() => _connectedIp = null);
        await _repo.delete(device.ip);
        if (mounted) setState(() => _groupedList = _buildFilteredList());
      },
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
      setState(() => _groupedList = _buildFilteredList());
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
    final textTheme   = Theme.of(context).textTheme;
    final deviceCount = _repo.devices.length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _openFindDevice,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        icon: _isLoading
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.onPrimaryContainer,
          ),
        )
            : const Icon(Icons.add_rounded),
        label: Text(
          _isLoading ? 'Scanning...' : 'Find Device',
          style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160.0,
            collapsedHeight: 66.0,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            surfaceTintColor: colorScheme.surfaceTint,
            shadowColor: Colors.transparent,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final top = constraints.biggest.height;
                final safeAreaTop = MediaQuery.of(context).padding.top;
                final minHeight = 66.0 + safeAreaTop;
                final maxHeight = 160.0 + safeAreaTop;
                final expandRatio = ((top - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _AppBarBackground(colorScheme: colorScheme),

                    // AÇIK DURUM (Remote ile pikseli pikseline aynı fontlar)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: expandRatio > 0.4 ? 1.0 : 0.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TITANCAST',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                fontSize: 25.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'My Devices',
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w400, // Remote ile eşitlendi
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            WifiInfoWidget(ssid: _wifiSsid),
                          ],
                        ),
                      ),
                    ),

                    // KAPALI DURUM
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: expandRatio < 0.4 ? 1.0 : 0.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'My Devices',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'TITANCAST',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
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
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$deviceCount device${deviceCount == 1 ? '' : 's'}',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DeviceFilterChips(
                      activeFilter: _activeFilter,
                      onChanged: _setFilter,
                    ),
                  ],
                ),
              ),
            ),

          if (_groupedList.isEmpty && !_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(onFindDevice: _openFindDevice),
            ),

          if (_groupedList.isNotEmpty || _isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              sliver: SliverList.builder(
                itemCount: _groupedList.length,
                itemBuilder: (context, index) {
                  final item = _groupedList[index];
                  if (item is SsidHeader) {
                    return _SectionHeader(ssid: (item as SsidHeader).ssid);
                  }
                  final device = item as DiscoveredDevice;
                  return DeviceListItem(
                    device: device,
                    isConnected: _connectedIp == device.ip,
                    onTap: () => _connectToDevice(device),
                    onLongPress: () => _showDeviceMenu(device),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Private widgets — scoped to this screen
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

class _SectionHeader extends StatelessWidget {
  final String ssid;
  const _SectionHeader({required this.ssid});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

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

class _EmptyState extends StatelessWidget {
  final VoidCallback onFindDevice;
  const _EmptyState({required this.onFindDevice});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

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
              'Tap "Find Device" to discover devices on your network.',
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