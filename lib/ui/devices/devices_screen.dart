import 'dart:async';
import 'package:titancast/data/active_device.dart';
import 'package:titancast/remote/remote_controller.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/device_repository.dart';
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
  String? _connectedIp;        // seçili cihaz IP'si
  RemoteConnectionState _connectionState = RemoteConnectionState.disconnected;

  final List<DiscoveredDevice> _updateBuffer = [];
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    _init();
    activeConnectionStateNotifier.addListener(_onConnectionStateChanged);
  }

  void _onConnectionStateChanged() {
    if (!mounted) return;
    setState(() => _connectionState = activeConnectionStateNotifier.value);
  }

  Future<void> _init() async {
    await _repo.init();
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

    final filtered = _repo.devices.where((d) => d.deviceType == _activeFilter).toList();
    if (filtered.isEmpty) return [];

    final ssids = filtered.map((d) => d.ssid ?? 'Unknown Network').toSet();
    if (ssids.length <= 1) return List<Object>.from(filtered);

    final result = <Object>[];
    for (final ssid in ssids) {
      result.add(SsidHeader(ssid: ssid));
      result.addAll(filtered.where((d) => (d.ssid ?? 'Unknown Network') == ssid));
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
    if (_connectedIp == device.ip) {
      // Tapping the already-connected device → disconnect
      _disconnectDevice();
      return;
    }
    setState(() {
      _connectedIp     = device.ip;
      _connectionState = RemoteConnectionState.connecting;
    });
    activeDeviceNotifier.value = device;
  }

  void _disconnectDevice() {
    setState(() {
      _connectedIp     = null;
      _connectionState = RemoteConnectionState.disconnected;
    });
    // Setting notifier to null signals RemoteScreen to detach its controller.
    activeDeviceNotifier.value = null;
    activeConnectionStateNotifier.value = RemoteConnectionState.disconnected;
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

  bool _isPlaceholder(String name) => name.startsWith('Identifying') || name.contains('...');

  void _showDeviceMenu(DiscoveredDevice device) {
    final isConnected = _connectedIp == device.ip;
    DeviceMenuSheet.show(
      context: context,
      device: device,
      isConnected: isConnected,
      onConnect: () {
        Navigator.pop(context);
        _connectToDevice(device);
      },
      onDisconnect: isConnected ? () {
        Navigator.pop(context);
        _disconnectDevice();
      } : null,
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
      onSetBrand: (brand) async {
        await _repo.setBrand(device.ip, brand);
        if (mounted) setState(() => _groupedList = _buildFilteredList());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${device.displayName} → ${DeviceMenuSheet.brandLabel(brand)}'),
            backgroundColor: const Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
    );
  }

  void _showRenameDialog(DiscoveredDevice device) {
    final controller = TextEditingController(text: device.customName ?? device.friendlyName);
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF15151A),
          title: const Text('Rename device', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Device name',
              labelStyle: TextStyle(color: Color(0xFF8A8A93)),
            ),
            onSubmitted: (_) => _commitRename(controller.text, device.ip),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8A93))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
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
    activeConnectionStateNotifier.removeListener(_onConnectionStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceCount = _repo.devices.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E), // Derin Antrasit
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _openFindDevice,
        backgroundColor: const Color(0xFF8B5CF6), // Neon Mor Vurgu
        foregroundColor: Colors.white,
        elevation: 8,
        icon: _isLoading
            ? const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.add_rounded),
        label: Text(
          _isLoading ? 'Scanning...' : 'Find Device',
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140.0,
            collapsedHeight: 66.0,
            backgroundColor: const Color(0xFF0A0A0E),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final top = constraints.biggest.height;
                final safeAreaTop = MediaQuery.of(context).padding.top;
                final minHeight = 66.0 + safeAreaTop;
                final maxHeight = 140.0 + safeAreaTop;
                final expandRatio = ((top - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // AÇIK DURUM (Expanded)
                    Positioned(
                      left: 24,
                      bottom: 16,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: expandRatio > 0.4 ? 1.0 : 0.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TITANCAST',
                              style: TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                fontSize: 10.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'My Devices',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 24.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            WifiInfoWidget(ssid: _wifiSsid),
                          ],
                        ),
                      ),
                    ),

                    // KAPALI DURUM (Collapsed)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 18,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: expandRatio < 0.4 ? 1.0 : 0.0,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'My Devices',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'TITANCAST',
                              style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0),
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
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),

          if (deviceCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$deviceCount device${deviceCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF8A8A93),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
                  if (item is SsidHeader) return _SectionHeader(ssid: item.ssid);
                  final device = item as DiscoveredDevice;
                  final isSelected = _connectedIp == device.ip;
                  return DeviceListItem(
                    device: device,
                    isSelected: isSelected,
                    connectionState: isSelected
                        ? _connectionState
                        : RemoteConnectionState.disconnected,
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

class _SectionHeader extends StatelessWidget {
  final String ssid;
  const _SectionHeader({required this.ssid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8, right: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF8A8A93)),
          const SizedBox(width: 8),
          Text(
            ssid,
            style: const TextStyle(color: Color(0xFF8A8A93), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0xFF22222A), height: 1)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: const Color(0xFF15151A), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
              child: const Icon(Icons.cast_rounded, size: 40, color: Color(0xFF8A8A93)),
            ),
            const SizedBox(height: 24),
            const Text('No devices yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Tap "Find Device" to discover TVs on your network.', style: TextStyle(color: Color(0xFF8A8A93), height: 1.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}