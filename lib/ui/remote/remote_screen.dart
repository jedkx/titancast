import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:titancast/data/active_device.dart';
import 'package:titancast/data/device_repository.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/remote_command.dart';
import 'package:titancast/remote/remote_controller.dart';
import 'package:titancast/ui/remote/widgets/remote_button.dart';
import 'package:titancast/ui/remote/widgets/dpad_widget.dart';
import 'package:titancast/ui/remote/widgets/touchpad_widget.dart';
import 'package:titancast/ui/remote/widgets/volume_channel_row.dart';
import 'package:titancast/ui/remote/brand_menu_sheet.dart';
import 'package:titancast/ui/remote/widgets/keyboard_input_sheet.dart';
import 'package:titancast/ui/remote/widgets/voice_input_sheet.dart';
import 'package:titancast/ui/remote/philips_remote_state.dart';

const _tag = 'RemoteScreen';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> with PhilipsRemoteState {
  RemoteController? _controller;
  DiscoveredDevice? _device;

  // PhilipsRemoteState required overrides
  @override RemoteController? get philipsController => _controller;
  @override DiscoveredDevice? get philipsDevice      => _device;
  @override void showPhilipsError(String message)    => _showErrorSnack(message);

  bool _keyboardSheetOpen = false;

  // D-Pad / Numpad / Touchpad panel PageView — 3 pages
  final _pageCtrl = PageController();
  int   _panelPage = 0; // 0 = D-Pad, 1 = Numpad, 2 = Touchpad

  @override
  void initState() {
    super.initState();
    activeDeviceNotifier.addListener(_onDeviceChanged);
    final cur = activeDeviceNotifier.value;
    if (cur != null) _attachDevice(cur);
  }

  @override
  void dispose() {
    activeDeviceNotifier.removeListener(_onDeviceChanged);
    _controller?.dispose();
    _pageCtrl.dispose();
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

    resetPhilipsState();

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
        // Load Philips-specific state when connected.
        // Check both the stored brand and the protocol type in case brand
        // detection completed after the device object was created.
        if (isPhilips) {
          loadPhilipsState();
        }
      } else if (ctrl.state == RemoteConnectionState.error) {
        if (ctrl.needsPhilipsPairing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showPhilipsPinDialog(ctrl);
          });
        } else if (ctrl.errorMessage != null) {
          _showErrorSnack(ctrl.errorMessage!);
        }
      }
    });

    setState(() { _device = device; _controller = ctrl; });
    unawaited(ctrl.connect());
  }

  // ── Commands ──────────────────────────────────────────────────────────────

  void _sendCommand(RemoteCommand cmd) {
    _controller?.send(cmd).then((_) {
      if (mounted && _controller?.state == RemoteConnectionState.error) {
        _showErrorSnack(_controller?.errorMessage ?? 'Command failed');
      }
    });
  }

  // ── Power ─────────────────────────────────────────────────────────────────

  Future<void> _confirmPower() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15151A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.power_settings_new_rounded,
                color: Color(0xFFEF4444), size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Turn off TV?',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'The TV will turn off. The remote will disconnect and you will not be able to wake it up from this app.',
          style: TextStyle(color: Color(0xFF8A8A93), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8A93))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn Off'),
          ),
        ],
      ),
    );
    if (confirmed == true) _sendCommand(RemoteCommand.power);
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────

  Future<void> _openKeyboardSheet() async {
    if (_keyboardSheetOpen || !mounted) return;
    _keyboardSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15151A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => KeyboardInputSheet(onSend: _sendKeyboardChars),
    );
    _keyboardSheetOpen = false;
  }

  Future<void> _sendKeyboardChars(String chars) async {
    final proto = _controller?.protocol;
    if (proto == null) return;
    try {
      await proto.sendText(chars);
    } catch (e) {
      if (mounted) _showErrorSnack('Could not send text: $e');
    }
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _openVoiceSheet() async {
    if (!mounted) return;
    await VoiceInputSheet.show(context, onSend: _sendKeyboardChars);
  }

  // ── Brand menu ────────────────────────────────────────────────────────────

  void _openBrandMenu() {
    final device = _device;
    if (device == null) return;
    BrandMenuSheet.show(
      context: context,
      device: device,
      ambilightOn:       ambilightOn,
      ambilightMode:     ambilightMode,
      ambilightSub:      ambilightSub,
      philipsApps:       philipsApps,
      philipsAppsLoaded: philipsAppsLoaded,
      onSendCommand:          _sendCommand,
      onRetryApps:            isPhilips ? retryLoadPhilipsApps : null,
      onAmbilightToggle:      isPhilips ? toggleAmbilight : null,
      onAmbilightModeChanged: isPhilips ? setAmbilightMode : null,
      onAmbilightSetColor:    isPhilips ? setAmbilightColor : null,
      onLaunchPhilipsApp: isPhilips
          ? (app) => launchPhilipsApp(app, onSuccess: () => Navigator.pop(context))
          : null,
      onOpenKeyboard: _openKeyboardSheet,
    );
  }

  // ── Snacks ────────────────────────────────────────────────────────────────

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Panel switching ───────────────────────────────────────────────────────

  static const _kPanelCount = 3; // D-Pad, Numpad, Touchpad

  void _goToPanel(int page) {
    final p = page.clamp(0, _kPanelCount - 1);
    _pageCtrl.animateToPage(p,
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    setState(() => _panelPage = p);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final devName = _device?.displayName ?? 'No Device';
    final state   = _controller?.state ?? RemoteConnectionState.disconnected;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: SafeArea(
        child: _device == null
            ? const _NoDeviceState()
            : state == RemoteConnectionState.connecting
            ? _ConnectingState(deviceName: devName)
            : _RemoteBody(
          devName: devName,
          state: state,
          controller: _controller,
          isPhilips: isPhilips,
          panelPage: _panelPage,
          pageCtrl: _pageCtrl,
          onConfirmPower: _confirmPower,
          onOpenBrandMenu: _openBrandMenu,
          onOpenKeyboard: _openKeyboardSheet,
          onMicTap: _openVoiceSheet,
          onSendCommand: _sendCommand,
          onGoToPanel: _goToPanel,
          onPointerMove: isPhilips ? sendPhilipsPointerMove : null,
          onPointerTap:  isPhilips ? () => sendPhilipsPointerTap(fallback: () => _sendCommand(RemoteCommand.ok)) : null,
        ),
      ),
    );
  }
}

// ── Remote body — extracted to keep build() clean ─────────────────────────────

class _RemoteBody extends StatelessWidget {
  final String devName;
  final RemoteConnectionState state;
  final RemoteController? controller;
  final bool isPhilips;
  final int panelPage;
  final PageController pageCtrl;
  final VoidCallback onConfirmPower;
  final VoidCallback onOpenBrandMenu;
  final Future<void> Function() onOpenKeyboard;
  final VoidCallback onMicTap;
  final void Function(RemoteCommand) onSendCommand;
  final void Function(int) onGoToPanel;
  final Future<void> Function(int dx, int dy)? onPointerMove;
  final Future<void> Function()? onPointerTap;

  const _RemoteBody({
    required this.devName,
    required this.state,
    required this.controller,
    required this.isPhilips,
    required this.panelPage,
    required this.pageCtrl,
    required this.onConfirmPower,
    required this.onOpenBrandMenu,
    required this.onOpenKeyboard,
    required this.onMicTap,
    required this.onSendCommand,
    required this.onGoToPanel,
    this.onPointerMove,
    this.onPointerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TITANCAST',
                    style: TextStyle(color: Color(0xFF8B5CF6),
                        fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                const SizedBox(height: 2),
                Text(devName,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 20, fontWeight: FontWeight.w600)),
              ]),
              _ConnectionStatusBadge(
                state: state,
                errorMessage: controller?.errorMessage,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Top row: Power | Menu | Keyboard ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RemoteButton.circle(
                size: 56,
                color: const Color(0xFF22222A),
                onTap: onConfirmPower,
                child: const Icon(Icons.power_settings_new_rounded,
                    color: Color(0xFFEF4444), size: 24),
              ),
              RemoteButton(
                width: 140, height: 56,
                color: const Color(0xFF22222A),
                borderRadius: BorderRadius.circular(28),
                onTap: onOpenBrandMenu,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.drag_indicator_rounded,
                        color: Color(0xFF8A8A93), size: 18),
                    const SizedBox(width: 8),
                    Text('MENU',
                        style: TextStyle(
                            color: isPhilips
                                ? const Color(0xFF8B5CF6)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
              RemoteButton.circle(
                size: 56,
                color: const Color(0xFF22222A),
                onTap: onOpenKeyboard,
                child: const Icon(Icons.keyboard_outlined,
                    color: Color(0xFF8A8A93), size: 22),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Volume / Channel row ─────────────────────────────────────
          VolumeChannelRow(
            onCommand: onSendCommand,
            onMicTap: onMicTap,
          ),

          const SizedBox(height: 12),

          // ── Panel indicator ──────────────────────────────────────────
          _PanelIndicator(
            page: panelPage,
            onPrev: panelPage > 0 ? () => onGoToPanel(panelPage - 1) : null,
            onNext: panelPage < _RemoteScreenState._kPanelCount - 1
                ? () => onGoToPanel(panelPage + 1)
                : null,
          ),

          const SizedBox(height: 8),

          // ── Panel PageView — fills remaining space ────────────────────
          Expanded(
            child: PageView(
              controller: pageCtrl,
              // Swipe is intentionally disabled — panel changes only via the
              // prev/next buttons in _PanelIndicator (task from README).
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: onGoToPanel,
              children: [
                // Page 0 — D-Pad
                DPadWidget(onCommand: onSendCommand),
                // Page 1 — Numpad
                _NumpadPanel(onCommand: onSendCommand),
                // Page 2 — Touchpad
                TouchpadWidget(
                  onCommand: onSendCommand,
                  onPointerMove: onPointerMove,
                  onPointerTap: onPointerTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Panel indicator ───────────────────────────────────────────────────────────

class _PanelIndicator extends StatelessWidget {
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PanelIndicator({
    required this.page,
    this.onPrev,
    this.onNext,
  });

  static const _labels  = ['D-PAD', 'NUMPAD', 'TOUCHPAD'];
  static const _icons   = [
    Icons.gamepad_outlined,
    Icons.dialpad_rounded,
    Icons.touch_app_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous arrow
        SizedBox(
          width: 32, height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: onPrev != null ? const Color(0xFF8A8A93) : const Color(0xFF2A2A35),
            onPressed: onPrev,
          ),
        ),
        const SizedBox(width: 6),

        // Dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_labels.length, (i) {
            final isActive = i == page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFF3A3A45),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),

        const SizedBox(width: 8),

        // Label + icon
        Icon(_icons[page], color: const Color(0xFF8A8A93), size: 12),
        const SizedBox(width: 4),
        Text(
          _labels[page],
          style: const TextStyle(
            color: Color(0xFF8A8A93),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),

        const SizedBox(width: 6),
        // Next arrow
        SizedBox(
          width: 32, height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: onNext != null ? const Color(0xFF8A8A93) : const Color(0xFF2A2A35),
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

// ── Numpad panel ──────────────────────────────────────────────────────────────

class _NumpadPanel extends StatelessWidget {
  final void Function(RemoteCommand) onCommand;
  const _NumpadPanel({required this.onCommand});

  static const _rows = [
    [RemoteCommand.key1, RemoteCommand.key2, RemoteCommand.key3],
    [RemoteCommand.key4, RemoteCommand.key5, RemoteCommand.key6],
    [RemoteCommand.key7, RemoteCommand.key8, RemoteCommand.key9],
    [null,               RemoteCommand.key0, null              ],
  ];

  static String _label(RemoteCommand? cmd) => switch (cmd) {
    RemoteCommand.key0 => '0',
    RemoteCommand.key1 => '1',
    RemoteCommand.key2 => '2',
    RemoteCommand.key3 => '3',
    RemoteCommand.key4 => '4',
    RemoteCommand.key5 => '5',
    RemoteCommand.key6 => '6',
    RemoteCommand.key7 => '7',
    RemoteCommand.key8 => '8',
    RemoteCommand.key9 => '9',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _rows.map((row) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((cmd) {
              if (cmd == null) return const SizedBox(width: 72, height: 64);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: RemoteButton(
                  width: 72, height: 64,
                  color: const Color(0xFF22222A),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onCommand(cmd),
                  child: Text(_label(cmd),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 22, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Utility widgets ───────────────────────────────────────────────────────────

class _NoDeviceState extends StatelessWidget {
  const _NoDeviceState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF15151A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
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
        const SizedBox(
          width: 48, height: 48,
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 24),
        Text('Connecting to',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        const SizedBox(height: 4),
        Text(deviceName,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Please wait…', style: TextStyle(color: Color(0xFF8A8A93), fontSize: 13)),
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
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.5),
              blurRadius: 6,
            )],
          )),
      RemoteConnectionState.connecting => const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6))),
      RemoteConnectionState.error => GestureDetector(
          onTap: () {
            if (errorMessage != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(errorMessage!),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 6),
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
          child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22)),
      RemoteConnectionState.disconnected => Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: Color(0xFF6B7280), shape: BoxShape.circle)),
    };
  }
}