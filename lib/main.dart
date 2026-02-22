import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'datasource/discovery_manager.dart';
import 'datasource/discovery_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color platinum = Color(0xFFE5E4E2);
    const Color deepBlueBg = Color(0xFF020408);
    const Color surfaceBlue = Color(0xFF0B121F);

    return MaterialApp(
      title: 'TitanCast Platinum Blue',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: platinum,
          brightness: Brightness.dark,
          surface: surfaceBlue,
          background: deepBlueBg,
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: platinum,
        ),
        scaffoldBackgroundColor: deepBlueBg,
        cardTheme: CardThemeData(
          color: surfaceBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w900, 
            letterSpacing: -1, 
            color: Colors.white,
            fontSize: 28,
          ),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 17),
          bodySmall: TextStyle(color: Colors.white54, fontWeight: FontWeight.w400),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<DiscoveredDevice> _devices = [];
  bool _isLoading = false;
  final DiscoveryManager _discoveryManager = DiscoveryManager();
  
  final List<DiscoveredDevice> _updateBuffer = [];
  Timer? _throttleTimer;

  Future<void> _discoverTVs() async {
    final status = await Permission.location.request();
    if (!status.isGranted) return;

    setState(() {
      _isLoading = true;
      _devices.clear();
      _updateBuffer.clear();
    });

    try {
      final stream = _discoveryManager.startDiscovery(timeout: const Duration(seconds: 15));
      await for (final device in stream) {
        if (!mounted) break;
        _bufferUpdate(device);
      }
    } catch (e) {
      debugPrint("Discovery Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _bufferUpdate(DiscoveredDevice device) {
    _updateBuffer.add(device);
    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _updateBuffer.isEmpty) return;
      setState(() {
        for (var newDevice in _updateBuffer) {
          final index = _devices.indexWhere((d) => d.ip == newDevice.ip);
          if (index != -1) {
            if (_devices[index].friendlyName.contains("...") || !newDevice.friendlyName.contains("...")) {
              _devices[index] = newDevice;
            }
          } else {
            _devices.add(newDevice);
          }
        }
        _updateBuffer.clear();
      });
    });
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _discoveryManager.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 1.5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          _devices.isEmpty && !_isLoading
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildDeviceCard(_devices[index]),
                      childCount: _devices.length,
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _discoverTVs,
        backgroundColor: _isLoading ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: _isLoading ? Colors.white24 : Colors.black,
        elevation: 8,
        label: Text(_isLoading ? "SEARCHING..." : "SCAN NETWORK", 
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
        icon: _isLoading 
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2))
          : const Icon(Icons.radar_rounded, size: 22),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar.large(
      expandedHeight: 160,
      backgroundColor: const Color(0xFF020408),
      floating: true,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 20),
        centerTitle: false,
        title: const Text("Discovery", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.5),
                  radius: 1.2,
                  colors: [
                    const Color(0xFF1E3A8A).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.settings_input_antenna_rounded, size: 200, color: Colors.white.withOpacity(0.01)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cast_connected_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          ),
          const SizedBox(height: 32),
          const Text("Ready to Explore", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          const Text("TitanCast is waiting for devices", style: TextStyle(color: Colors.white30, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device) {
    // Akıllı Cihaz Tipi Tespiti
    final String type = (device.serviceType ?? "").toLowerCase();
    final String name = device.friendlyName.toLowerCase();
    
    final bool isTV = type.contains("tv") || name.contains("tv") || type.contains("renderer");
    final bool isAudio = type.contains("audio") || type.contains("speaker") || name.contains("speaker");
    final bool isRouter = type.contains("router") || type.contains("gateway") || name.contains("router");

    IconData deviceIcon = Icons.devices_other_rounded;
    List<Color> gradientColors = [const Color(0xFF1A1A1A), const Color(0xFF2A2A2A)];

    if (isTV) {
      deviceIcon = Icons.tv_rounded;
      gradientColors = [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]; // Platinum Blue
    } else if (isAudio) {
      deviceIcon = Icons.speaker_group_rounded;
      gradientColors = [const Color(0xFF374151), const Color(0xFF4B5563)]; // Slate
    } else if (isRouter) {
      deviceIcon = Icons.router_rounded;
      gradientColors = [const Color(0xFF064E3B), const Color(0xFF059669)]; // Emerald
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B121F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => debugPrint("Connect: ${device.ip}"),
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(deviceIcon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.friendlyName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (device.manufacturer != null) ...[
                            Text(
                              device.manufacturer!.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5), 
                                fontSize: 11, 
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.circle, size: 3, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            device.ip,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3), 
                              fontSize: 12, 
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildMethodBadge(device.method.name.toUpperCase()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.w900, 
          color: Colors.white.withOpacity(0.6),
          letterSpacing: 0.8
        ),
      ),
    );
  }
}
