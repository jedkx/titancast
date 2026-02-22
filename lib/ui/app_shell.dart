import 'package:flutter/material.dart';
import 'package:titancast/data/active_device.dart';
import 'devices/devices_screen.dart';
import 'remote/remote_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _navIndex = 0;

  static const _screens = [
    DevicesScreen(),
    RemoteScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Automatically switch to the Remote tab when a device is connected.
    activeDeviceNotifier.addListener(_onDeviceConnected);
  }

  @override
  void dispose() {
    activeDeviceNotifier.removeListener(_onDeviceConnected);
    super.dispose();
  }

  void _onDeviceConnected() {
    if (activeDeviceNotifier.value != null && _navIndex != 1) {
      setState(() => _navIndex = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_remote_outlined),
            selectedIcon: Icon(Icons.settings_remote),
            label: 'Remote',
          ),
        ],
      ),
    );
  }
}