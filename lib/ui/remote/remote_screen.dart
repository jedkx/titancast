import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/data/active_device.dart';
import 'package:titancast/data/device_repository.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/remote_controller.dart';
import 'package:titancast/remote/tv_brand.dart';
import 'package:titancast/remote/protocol/philips_protocol.dart';
import 'package:titancast/ui/remote/widgets/remote_button.dart';
import 'package:titancast/ui/remote/widgets/dpad_widget.dart';
import 'package:titancast/ui/remote/widgets/volume_channel_row.dart';
import 'package:titancast/ui/remote/brand_menu_sheet.dart';
import 'package:titancast/ui/remote/widgets/keyboard_input_sheet.dart';

const _tag = 'RemoteScreen';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  RemoteController? _controller;
  DiscoveredDevice? _device;

  bool _ambilightOn     = false;
  String _ambilightMode = 'FOLLOW_VIDEO';
  List<Map<String, dynamic>> _philipsApps = [];
  bool _philipsAppsLoaded = false;
  bool _keyboardSheetOpen = false;

  @override
  void initState() {
    super.initState();
    activeDeviceNotifier.addListener(_onDeviceChanged);
    final current = activeDeviceNotifier.value;
    if (current != null) _attachDevice(current);
  }

  @override
  void dispose() {
    activeDeviceNotifier.removeListener(_onDeviceChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onDeviceChanged() {
    final d = activeDeviceNotifier.value;
    if (d == null) { _detachDevice(); return; }
    if (d.ip != _device?.ip) _attachDevice(d);
  }

  void _detachDevice() {
    final old = _controller;
    setState(() { _controller = null; _device = null; });
    old?.dispose();
  }

  void _attachDevice(DiscoveredDevice device) {
    final old = _controller;
    _controller = null;
    old?.dispose();

    _ambilightOn = false;
    _ambilightMode = 'FOLLOW_VIDEO';
    _philipsApps = [];
    _philipsAppsLoaded = false;

    final ctrl = RemoteController(
      device,
      onBrandResolved: (ip, brand) {
        final repo = DeviceRepository();
        repo.init().then((_) => repo.setBrand(ip, brand));
      },
      onPhilipsKeyboardAppeared: _openKeyboardSheet,
    );

    ctrl.addListener(() {
      if (!mounted) return;
      activeConnectionStateNotifier.value = ctrl.state;
      setState(() {});
      if (ctrl.state == RemoteConnectionState.connected) {
        if (device.detectedBrand == TvBrand.philips) _loadPhilipsState();
      } else if (ctrl.state == RemoteConnectionState.error) {
        if (ctrl.needsPhilipsPairing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showPhilipsPinDialog(ctrl);
          });
        } else if (ctrl.errorMessage != null) {
          _showErrorSnack(ctrl.errorMessage!);
        }
      }
    });

    setState(() { _device = device; _controller = ctrl; });
    unawaited(ctrl.connect());
  }

  Future<void> _loadPhilipsState() async {
    final proto = _controller?.protocol;
    if (proto is! PhilipsProtocol) return;
    try {
      final config = await proto.ambilightGetConfig();
      final styleName = config['styleName'] as String? ?? 'FOLLOW_VIDEO';
      final isOn = styleName != 'OFF';
      if (mounted) setState(() { _ambilightOn = isOn; if (isOn) _ambilightMode = styleName; });
    } catch (_) {}
    if (!_philipsAppsLoaded) {
      try {
        final apps = await proto.getApplications();
        if (mounted) setState(() { _philipsApps = apps; _philipsAppsLoaded = true; });
      } catch (_) {
        if (mounted) setState(() => _philipsAppsLoaded = true);
      }
    }
  }

  void _sendCommand(RemoteCommand cmd) {
    HapticFeedback.lightImpact();
    _controller?.send(cmd).then((_) {
      if (mounted && _controller?.state == RemoteConnectionState.error) {
        _showErrorSnack(_controller?.errorMessage ?? 'Command failed');
      }
    });
  }

  Future<void> _toggleAmbilight() async {
    final proto = _controller?.protocol;
    if (proto is PhilipsProtocol) {
      try { await proto.ambilightSetPower(on: _ambilightOn); } catch (_) {}
    }
  }

  Future<void> _setAmbilightMode(String style,
      {String? menuSetting, String? algorithm}) async {
    final proto = _controller?.protocol;
    if (proto is! PhilipsProtocol) return;
    try {
      await proto.ambilightSetMode(style,
          menuSetting: menuSetting, algorithm: algorithm);
    } catch (e) {
      if (mounted) _showErrorSnack('Could not change Ambilight mode: $e');
    }
  }

  Future<void> _launchPhilipsApp(Map<String, dynamic> app) async {
    final proto = _controller?.protocol;
    if (proto is! PhilipsProtocol) return;
    final intent = app['intent'] as Map<String, dynamic>? ?? app;
    try {
      await proto.launchApplication(intent);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showErrorSnack('Could not launch app: $e');
    }
  }

  Future<void> _openKeyboardSheet() async {
    if (_keyboardSheetOpen || !mounted) return;
    _keyboardSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15151A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => KeyboardInputSheet(
        onSend: _sendKeyboardChars,
      ),
    );
    _keyboardSheetOpen = false;
  }

  Future<void> _sendKeyboardChars(String chars) async {
    final proto = _controller?.protocol;
    if (proto is PhilipsProtocol) {
      try {
        await proto.sendKeyboardInput(chars);
      } catch (e) {
        if (mounted) _showErrorSnack('Could not send text: $e');
      }
    }
  }

  void _openBrandMenu() {
    final device = _device;
    if (device == null) return;
    BrandMenuSheet.show(
      context: context,
      device: device,
      ambilightOn: _ambilightOn,
      ambilightMode: _ambilightMode,
      philipsApps: _philipsApps,
      philipsAppsLoaded: _philipsAppsLoaded,
      onSendCommand: _sendCommand,
      onAmbilightToggle: _isPhilips ? () async {
        final newVal = !_ambilightOn;
        setState(() => _ambilightOn = newVal);
        await _toggleAmbilight();
      } : null,
      onAmbilightModeChanged: _isPhilips ? (style, {String? menuSetting, String? algorithm}) async {
        setState(() => _ambilightMode = style);
        await _setAmbilightMode(style, menuSetting: menuSetting, algorithm: algorithm);
      } : null,
      onLaunchPhilipsApp: _isPhilips ? _launchPhilipsApp : null,
      onOpenKeyboard: _openKeyboardSheet,
    );
  }

  void _showPhilipsPinDialog(RemoteController ctrl) {
    final pinController = TextEditingController();
    bool isConfirming = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF15151A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.pin_outlined, color: Color(0xFF8B5CF6), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Philips Pairing',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter the 4-digit PIN shown on the TV screen.',
                style: TextStyle(color: Color(0xFF8A8A93), fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.w700, letterSpacing: 12),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '0000',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15),
                    fontSize: 28, letterSpacing: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                filled: true, fillColor: const Color(0xFF22222A),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: isConfirming ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8A93))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: isConfirming ? null : () async {
                final pin = pinController.text.trim();
                if (pin.length != 4) return;
                set(() => isConfirming = true);
                try {
                  await ctrl.philipsPair(pin);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    set(() => isConfirming = false);
                    _showErrorSnack('Pairing failed: $e');
                  }
                }
              },
              child: isConfirming
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
    ));
  }

  bool get _isPhilips =>
      _device?.detectedBrand == TvBrand.philips ||
      (_device?.detectedBrand == null &&
          _device?.serviceType?.contains('JointSpace') == true);

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0A0A0E);
    final deviceName = _device?.displayName ?? 'No Device';
    final state = _controller?.state ?? RemoteConnectionState.disconnected;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _device == null
            ? const _NoDeviceState()
            : state == RemoteConnectionState.connecting
                ? _ConnectingState(deviceName: deviceName)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ── HEADER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('TITANCAST', style: TextStyle(color: Color(0xFF8B5CF6),
                                  fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                              const SizedBox(height: 2),
                              Text(deviceName, style: const TextStyle(color: Colors.white,
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                            ]),
                            _ConnectionStatusBadge(state: state, errorMessage: _controller?.errorMessage),
                          ],
                        ),

                        // ── TOP ROW
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RemoteButton.circle(size: 56, color: const Color(0xFF22222A),
                              onTap: () => _sendCommand(RemoteCommand.power),
                              child: const Icon(Icons.power_settings_new_rounded,
                                  color: Color(0xFFEF4444), size: 24)),
                            RemoteButton(width: 140, height: 56, color: const Color(0xFF22222A),
                              borderRadius: BorderRadius.circular(28), onTap: _openBrandMenu,
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.drag_indicator_rounded,
                                    color: Color(0xFF8A8A93), size: 18),
                                const SizedBox(width: 8),
                                Text('MENU', style: TextStyle(
                                    color: _isPhilips ? const Color(0xFF8B5CF6) : Colors.white,
                                    fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                              ])),
                            RemoteButton.circle(size: 56, color: const Color(0xFF22222A),
                              onTap: _openKeyboardSheet,
                              child: const Icon(Icons.keyboard_outlined,
                                  color: Color(0xFF8A8A93), size: 22)),
                          ],
                        ),

                        // ── VOLUME / CHANNEL — mic pos = ambilight for Philips
                        VolumeChannelRow(
                          onCommand: _sendCommand,
                          isPhilips: _isPhilips,
                          onAmbilightTap: _isPhilips ? () async {
                            final newVal = !_ambilightOn;
                            setState(() => _ambilightOn = newVal);
                            await _toggleAmbilight();
                          } : null,
                          ambilightOn: _ambilightOn,
                        ),

                        // ── BACK | COLOR KEYS | GUIDE (always shown)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RemoteButton.circle(size: 44, color: const Color(0xFF15151A),
                              onTap: () => _sendCommand(RemoteCommand.back),
                              child: const Icon(Icons.chevron_left_rounded,
                                  color: Colors.white70, size: 24)),
                            const SizedBox(width: 16),
                            Row(children: [
                              _ColorKey(color: const Color(0xFFEF4444),
                                  onTap: () => _sendCommand(RemoteCommand.colorRed)),
                              const SizedBox(width: 8),
                              _ColorKey(color: const Color(0xFF10B981),
                                  onTap: () => _sendCommand(RemoteCommand.colorGreen)),
                              const SizedBox(width: 8),
                              _ColorKey(color: const Color(0xFFF59E0B),
                                  onTap: () => _sendCommand(RemoteCommand.colorYellow)),
                              const SizedBox(width: 8),
                              _ColorKey(color: const Color(0xFF3B82F6),
                                  onTap: () => _sendCommand(RemoteCommand.colorBlue)),
                            ]),
                            const SizedBox(width: 16),
                            RemoteButton.circle(size: 44, color: const Color(0xFF15151A),
                              onTap: () => _sendCommand(RemoteCommand.guide),
                              child: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white70, size: 24)),
                          ],
                        ),

                        // ── D-PAD
                        DPadWidget(onCommand: _sendCommand),

                        // ── BOTTOM ROW — APPS/AMBILIGHT moved to MENU
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _BottomButton(icon: Icons.info_outline_rounded, label: 'INFO',
                                onTap: () => _sendCommand(RemoteCommand.info)),
                            _BottomButton(icon: Icons.home_rounded, label: 'HOME',
                                onTap: () => _sendCommand(RemoteCommand.home)),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ── Local widgets ─────────────────────────────────────────────────────────────

class _NoDeviceState extends StatelessWidget {
  const _NoDeviceState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: const Color(0xFF15151A), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
          child: const Icon(Icons.cast_rounded, size: 36, color: Color(0xFF8A8A93)),
        ),
        const SizedBox(height: 20),
        const Text('No device connected',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Select a device from the Devices tab',
            style: TextStyle(color: Color(0xFF8A8A93), fontSize: 14)),
      ]),
    );
  }
}

class _ConnectingState extends StatelessWidget {
  final String deviceName;
  const _ConnectingState({required this.deviceName});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 48, height: 48,
            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF8B5CF6))),
        const SizedBox(height: 24),
        Text('Connecting to',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        const SizedBox(height: 4),
        Text(deviceName, style: const TextStyle(color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Please wait...', style: TextStyle(color: Color(0xFF8A8A93), fontSize: 13)),
      ]),
    );
  }
}

class _ConnectionStatusBadge extends StatelessWidget {
  final RemoteConnectionState state;
  final String? errorMessage;
  const _ConnectionStatusBadge({required this.state, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      RemoteConnectionState.connected => Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.5), blurRadius: 6)])),
      RemoteConnectionState.connecting => const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6))),
      RemoteConnectionState.error => GestureDetector(
          onTap: () {
            if (errorMessage != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(errorMessage!), backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 6), behavior: SnackBarBehavior.floating));
            }
          },
          child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22)),
      RemoteConnectionState.disconnected => Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: Color(0xFF6B7280), shape: BoxShape.circle)),
    };
  }
}

class _ColorKey extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _ColorKey({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)]),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BottomButton({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.42;
    return RemoteButton(
      width: w, height: 64,
      color: active ? const Color(0xFF8B5CF6).withValues(alpha: 0.15) : const Color(0xFF15151A),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon,
            color: active ? const Color(0xFF8B5CF6) : const Color(0xFF8A8A93), size: 20),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(
            color: active ? const Color(0xFF8B5CF6) : Colors.white,
            fontSize: label.length > 8 ? 11 : 14, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
