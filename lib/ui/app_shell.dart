import 'package:flutter/material.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/data/active_device.dart';
import 'package:titancast/remote/remote_controller.dart';
import 'devices/devices_screen.dart';
import 'logs/logs_screen.dart';
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
    LogsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AppLogger.i('AppShell', 'TitanCast started');
    activeDeviceNotifier.addListener(_onDeviceConnected);
    activeConnectionStateNotifier.addListener(_onConnectionStateChanged);
  }

  @override
  void dispose() {
    activeDeviceNotifier.removeListener(_onDeviceConnected);
    activeConnectionStateNotifier.removeListener(_onConnectionStateChanged);
    super.dispose();
  }

  void _onConnectionStateChanged() {
    final state = activeConnectionStateNotifier.value;
    AppLogger.d('AppShell', 'connection state changed: ${state.name}');
    if (state == RemoteConnectionState.connected && _navIndex != 1) {
      AppLogger.i('AppShell', 'connected → switching to Remote tab');
      setState(() => _navIndex = 1);
    }
  }

  void _onDeviceConnected() {
    // Cihaz seçildi ama bağlantı henüz tamamlanmadı — sekme geçişi yapmıyoruz.
    // Geçiş yalnızca bağlantı başarılı olunca _onConnectionStateChanged'dan yapılır.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: _screens,
      ),
      bottomNavigationBar: ValueListenableBuilder<List<LogEntry>>(
        valueListenable: AppLogger.entries,
        builder: (_, entries, __) {
          // Son entry'de hata varsa log ikonunda kırmızı badge göster
          final hasRecentError = entries.isNotEmpty &&
              entries.last.level == LogLevel.error &&
              DateTime.now().difference(entries.last.time).inSeconds < 10;
          return NavigationBar(
            selectedIndex: _navIndex,
            onDestinationSelected: (i) => setState(() => _navIndex = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.devices_outlined),
                selectedIcon: Icon(Icons.devices),
                label: 'Devices',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_remote_outlined),
                selectedIcon: Icon(Icons.settings_remote),
                label: 'Remote',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: hasRecentError,
                  backgroundColor: const Color(0xFFF87171),
                  child: const Icon(Icons.terminal_outlined),
                ),
                selectedIcon: const Icon(Icons.terminal),
                label: 'Logs',
              ),
            ],
          );
        },
      ),
    );
  }
}
