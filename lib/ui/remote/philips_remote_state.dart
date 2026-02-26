import 'package:flutter/material.dart';
import 'package:titancast/core/app_logger.dart';
import 'package:titancast/discovery/discovery_model.dart';
import 'package:titancast/remote/remote_controller.dart';
import 'package:titancast/remote/tv_brand.dart';
import 'package:titancast/remote/protocol/philips_protocol.dart';

const _tag = 'PhilipsRemoteState';

/// Mixin that adds all Philips-specific state and logic to RemoteScreen.
///
/// Keeps remote_screen.dart brand-agnostic — it just calls the public
/// methods here and passes the resulting state to BrandMenuSheet.
mixin PhilipsRemoteState<T extends StatefulWidget> on State<T> {
  // ── State ──────────────────────────────────────────────────────────────────

  bool   ambilightOn   = false;
  String ambilightMode = 'FOLLOW_VIDEO';
  String? ambilightSub;
  List<Map<String, dynamic>> philipsApps      = [];
  bool                       philipsAppsLoaded = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Must be provided by the host State.
  RemoteController? get philipsController;
  DiscoveredDevice? get philipsDevice;

  bool get isPhilips {
    final device     = philipsDevice;
    final controller = philipsController;
    if (device == null) return false;
    return device.detectedBrand == TvBrand.philips ||
        controller?.protocol is PhilipsProtocol ||
        (device.detectedBrand == null &&
            device.serviceType?.contains('JointSpace') == true);
  }

  PhilipsProtocol? get _proto {
    final p = philipsController?.protocol;
    return p is PhilipsProtocol ? p : null;
  }

  // ── Init / reset ───────────────────────────────────────────────────────────

  void resetPhilipsState() {
    ambilightOn       = false;
    ambilightMode     = 'FOLLOW_VIDEO';
    ambilightSub      = null;
    philipsApps       = [];
    philipsAppsLoaded = false;
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadPhilipsState() async {
    final proto = _proto;
    if (proto == null) return;
    try {
      final config    = await proto.ambilightGetConfig();
      final styleName = config['styleName'] as String? ?? 'FOLLOW_VIDEO';
      final isOn      = styleName != 'OFF';
      final sub       = config['menuSetting'] as String? ??
          config['algorithm']   as String?;
      if (mounted) setState(() {
        ambilightOn   = isOn;
        if (isOn) {
          ambilightMode = styleName;
          ambilightSub  = sub;
        }
      });
    } catch (e) {
      AppLogger.w(_tag, 'loadPhilipsState: ambilight config failed: $e');
    }
    if (!philipsAppsLoaded) await _fetchApps(proto);
  }

  Future<void> _fetchApps(PhilipsProtocol proto) async {
    try {
      final apps = await proto.getApplications();
      AppLogger.i(_tag, '_fetchApps: loaded ${apps.length} app(s)');
      if (mounted) setState(() { philipsApps = apps; philipsAppsLoaded = true; });
    } catch (e) {
      AppLogger.e(_tag, '_fetchApps: failed: $e');
      if (mounted) setState(() => philipsAppsLoaded = true);
    }
  }

  Future<void> retryLoadPhilipsApps() async {
    final proto = _proto;
    if (proto == null) return;
    setState(() { philipsApps = []; philipsAppsLoaded = false; });
    await _fetchApps(proto);
  }

  // ── Ambilight ──────────────────────────────────────────────────────────────

  Future<void> toggleAmbilight() async {
    final proto = _proto;
    if (proto == null) return;
    final targetOn = !ambilightOn;
    setState(() => ambilightOn = targetOn);
    try {
      await proto.ambilightSetPower(on: targetOn);
      AppLogger.i(_tag, 'Ambilight → ${targetOn ? 'ON' : 'OFF'}');
    } catch (e) {
      setState(() => ambilightOn = !targetOn);
      AppLogger.e(_tag, 'toggleAmbilight failed: $e');
      if (mounted) showPhilipsError('Ambilight could not be changed: $e');
    }
  }

  Future<void> setAmbilightMode(
      String style, {
        String? menuSetting,
        String? algorithm,
      }) async {
    final proto = _proto;
    if (proto == null) return;
    setState(() {
      ambilightOn   = true;
      ambilightMode = style;
      ambilightSub  = menuSetting ?? algorithm;
    });
    try {
      await proto.ambilightSetMode(style,
          menuSetting: menuSetting, algorithm: algorithm);
    } catch (e) {
      if (mounted) showPhilipsError('Could not change Ambilight mode: $e');
    }
  }

  Future<void> setAmbilightColor(int r, int g, int b) async {
    final proto = _proto;
    if (proto == null) return;
    try {
      // Ensure mode is FOLLOW_COLOR before sending color —
      // some firmware ignores color if the mode isn't set first.
      if (ambilightMode != 'FOLLOW_COLOR') {
        await proto.ambilightSetMode('FOLLOW_COLOR');
      }
      await proto.ambilightSetColor(r: r, g: g, b: b);
      if (mounted) setState(() {
        ambilightOn   = true;
        ambilightMode = 'FOLLOW_COLOR';
        ambilightSub  = null;
      });
    } catch (e) {
      if (mounted) showPhilipsError('Could not set Ambilight color: $e');
    }
  }

  // ── Apps ───────────────────────────────────────────────────────────────────

  Future<void> launchPhilipsApp(
      Map<String, dynamic> app, {
        required VoidCallback onSuccess,
      }) async {
    final proto = _proto;
    if (proto == null) return;
    try {
      await proto.launchApplication(app);
      onSuccess();
    } catch (e) {
      if (mounted) showPhilipsError('Could not launch app: $e');
    }
  }

  // ── Pointer (Philips touchpad) ─────────────────────────────────────────────

  Future<void> sendPhilipsPointerMove(int dx, int dy) async {
    await _proto?.sendPointerMove(dx, dy);
  }

  Future<void> sendPhilipsPointerTap({required VoidCallback fallback}) async {
    final proto = _proto;
    if (proto != null) {
      await proto.sendPointerTap();
    } else {
      fallback();
    }
  }

  // ── Pairing dialog ─────────────────────────────────────────────────────────

  void showPhilipsPinDialog(RemoteController ctrl) {
    final pinCtrl = TextEditingController();
    bool confirming = false;
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
                borderRadius: BorderRadius.circular(10),
              ),
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
              controller: pinCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(
                  color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.w700, letterSpacing: 12),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '0000',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.15),
                    fontSize: 28, letterSpacing: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                filled: true,
                fillColor: const Color(0xFF22222A),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: confirming ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8A93))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: confirming
                  ? null
                  : () async {
                final pin = pinCtrl.text.trim();
                if (pin.length != 4) return;
                set(() => confirming = true);
                try {
                  await ctrl.philipsPair(pin);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    set(() => confirming = false);
                    showPhilipsError('Pairing failed: $e');
                  }
                }
              },
              child: confirming
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error helper — implemented by host ────────────────────────────────────

  /// Override in the host State to show a snackbar or other UI.
  void showPhilipsError(String message);
}