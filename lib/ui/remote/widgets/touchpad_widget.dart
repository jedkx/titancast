import 'dart:async';
import 'package:flutter/material.dart';
import 'package:titancast/remote/remote_command.dart';

/// Full-screen swipe touchpad that maps gestures to D-pad commands.
///
/// - Swipe up/down/left/right  → corresponding direction key
/// - Single tap                → OK
/// - Double tap                → Back
/// - Long press                → Home
///
/// Pointer mode (Philips): when [onPointerMove] is provided the touchpad
/// behaves like a laptop trackpad — continuous movement events are sent,
/// throttled to at most one per [_kPointerIntervalMs] ms to prevent
/// flooding the TV's HTTP server with Digest-authenticated requests.
class TouchpadWidget extends StatefulWidget {
  final void Function(RemoteCommand) onCommand;

  /// Optional callbacks for pointer-mode (mouse cursor on TV).
  /// When provided, the touchpad sends continuous pointer events instead of
  /// discrete D-pad commands — mimicking a laptop trackpad.
  /// Set by RemoteScreen when a Philips TV is connected.
  ///
  /// Pointer events are rate-limited to prevent HTTP request flooding.
  /// Philips Digest-auth requests are sequential; sending one per pan-update
  /// event (~16 ms) saturates the TV's request queue.
  final Future<void> Function(int dx, int dy)? onPointerMove;
  final Future<void> Function()? onPointerTap;

  const TouchpadWidget({
    super.key,
    required this.onCommand,
    this.onPointerMove,
    this.onPointerTap,
  });

  @override
  State<TouchpadWidget> createState() => _TouchpadWidgetState();
}

class _TouchpadWidgetState extends State<TouchpadWidget>
    with SingleTickerProviderStateMixin {
  // Drag tracking
  Offset? _dragStart;
  static const double _swipeThreshold = 30.0;

  // Visual feedback
  Offset? _ripplePos;
  RemoteCommand? _lastCmd;
  late AnimationController _feedbackCtrl;
  late Animation<double> _feedbackAnim;

  // Pointer mode: accumulated sub-pixel movement for smooth cursor control
  double _pointerAccX = 0;
  double _pointerAccY = 0;

  // Pointer throttle — prevents HTTP flood on Philips Digest-auth TVs.
  // Philips /input/pointer requires a full Digest handshake per request
  // (401 → parse WWW-Authenticate → retry with Authorization header).
  // Sending one request per Flutter pan-update (≈60 Hz) causes the TV to
  // rotate nonces faster than we can keep up, resulting in 401 loops.
  // Reference: observed in production logs (postWithDigest retry spam).
  static const int _kPointerIntervalMs = 50; // ~20 Hz max send rate
  int _lastPointerSendMs = 0;
  bool _pointerInFlight  = false;
  int _pendingDx = 0;
  int _pendingDy = 0;
  Timer? _pointerFlushTimer;

  @override
  void initState() {
    super.initState();
    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _feedbackAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pointerFlushTimer?.cancel();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _send(RemoteCommand cmd, Offset pos) {
    widget.onCommand(cmd);
    setState(() {
      _ripplePos = pos;
      _lastCmd   = cmd;
    });
    _feedbackCtrl.forward(from: 0.0);
  }

  /// Accumulates pointer delta and sends to TV at a rate-limited cadence.
  ///
  /// Instead of firing one HTTP request per flutter pan-update frame, we
  /// accumulate movement and flush at most every [_kPointerIntervalMs] ms.
  /// While a request is in-flight we continue accumulating — the next flush
  /// will include all movement that happened during the round-trip.
  void _sendPointer(Offset delta, Offset pos) {
    if (widget.onPointerMove == null) return;

    // Accumulate with sensitivity multiplier (2.5× feels like a laptop pad).
    _pointerAccX += delta.dx * 2.5;
    _pointerAccY += delta.dy * 2.5;
    final ix = _pointerAccX.round();
    final iy = _pointerAccY.round();

    if (ix == 0 && iy == 0) return;
    _pointerAccX -= ix;
    _pointerAccY -= iy;

    // Accumulate pending movement regardless of in-flight state.
    _pendingDx += ix;
    _pendingDy += iy;

    setState(() { _ripplePos = pos; _lastCmd = null; });

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - _lastPointerSendMs;

    if (!_pointerInFlight && elapsed >= _kPointerIntervalMs) {
      _flushPointer();
    } else {
      // Schedule a deferred flush so movement during in-flight is not lost.
      _pointerFlushTimer?.cancel();
      _pointerFlushTimer = Timer(
        Duration(milliseconds: _kPointerIntervalMs),
        _flushPointer,
      );
    }
  }

  void _flushPointer() {
    if (_pointerInFlight || (_pendingDx == 0 && _pendingDy == 0)) return;
    final dx = _pendingDx;
    final dy = _pendingDy;
    _pendingDx = 0;
    _pendingDy = 0;
    _pointerInFlight = true;
    _lastPointerSendMs = DateTime.now().millisecondsSinceEpoch;

    widget.onPointerMove!(dx, dy).then((_) {
      _pointerInFlight = false;
      // If more movement accumulated while in-flight, send immediately.
      if (_pendingDx != 0 || _pendingDy != 0) _flushPointer();
    }).catchError((_) {
      _pointerInFlight = false;
    });
  }

  String _cmdLabel(RemoteCommand? cmd) => switch (cmd) {
    RemoteCommand.up    => '▲',
    RemoteCommand.down  => '▼',
    RemoteCommand.left  => '◀',
    RemoteCommand.right => '▶',
    RemoteCommand.ok    => '●',
    RemoteCommand.back  => '↩',
    RemoteCommand.home  => '⌂',
    _                   => '',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Touchpad area
        Expanded(
          child: GestureDetector(
            onTapDown: (d) => setState(() => _ripplePos = d.localPosition),
            onTap: () {
              if (widget.onPointerTap != null) {
                widget.onPointerTap!();
                _feedbackCtrl.forward(from: 0.0);
                return;
              }
              if (_ripplePos != null) _send(RemoteCommand.ok, _ripplePos!);
            },
            onDoubleTap: () {
              if (_ripplePos != null) _send(RemoteCommand.back, _ripplePos!);
            },
            onLongPress: () {
              if (_ripplePos != null) _send(RemoteCommand.home, _ripplePos!);
            },
            onPanStart: (d) => _dragStart = d.localPosition,
            onPanUpdate: (d) {
              // Pointer mode (Philips mouse): throttled continuous movement
              if (widget.onPointerMove != null) {
                _sendPointer(d.delta, d.localPosition);
                return;
              }
              // D-pad swipe mode
              final start = _dragStart;
              if (start == null) return;
              final dx = d.localPosition.dx - start.dx;
              final dy = d.localPosition.dy - start.dy;
              if (dx.abs() < _swipeThreshold && dy.abs() < _swipeThreshold) return;
              _dragStart = null;
              if (dx.abs() > dy.abs()) {
                _send(dx > 0 ? RemoteCommand.right : RemoteCommand.left,
                    d.localPosition);
              } else {
                _send(dy > 0 ? RemoteCommand.down : RemoteCommand.up,
                    d.localPosition);
              }
            },
            onPanEnd: (_) {
              _dragStart = null;
              // Flush any remaining accumulated pointer movement on finger lift.
              if (_pendingDx != 0 || _pendingDy != 0) _flushPointer();
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15151A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Grid pattern background
                    CustomPaint(painter: _GridPainter()),

                    // Center hint
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: Colors.white.withValues(alpha: 0.08),
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Swipe to navigate · Tap to select',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.1),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Double tap: Back · Long press: Home',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.07),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Ripple + label feedback
                    if (_ripplePos != null)
                      AnimatedBuilder(
                        animation: _feedbackAnim,
                        builder: (_, __) {
                          final opacity = _feedbackAnim.value;
                          final scale   = 1.0 + (1.0 - _feedbackAnim.value) * 1.5;
                          return Positioned(
                            left:  _ripplePos!.dx - 40,
                            top:   _ripplePos!.dy - 40,
                            child: Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.25),
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.6),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _cmdLabel(_lastCmd),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: opacity),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Pointer mode badge
        if (widget.onPointerMove != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.mouse_outlined, color: Color(0xFF8B5CF6), size: 12),
              const SizedBox(width: 4),
              const Text('POINTER MODE',
                  style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            ]),
          ),

        // Back / Home row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickBtn(
              icon: Icons.arrow_back_rounded,
              onTap: () => widget.onCommand(RemoteCommand.back),
            ),
            _QuickBtn(
              icon: Icons.home_outlined,
              onTap: () => widget.onCommand(RemoteCommand.home),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF22222A),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Center(
          child: Icon(icon, color: const Color(0xFFD4D4D8), size: 22),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
