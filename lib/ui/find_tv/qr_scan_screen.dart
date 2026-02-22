import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/scanner/qr_scanner_discovery.dart';

// Top-level const so both QrScanScreen and _InstructionSheet can reference it
// without cross-class private access issues.
const double _kSheetHeight = 200.0;

/// Full-screen QR code scanner.
///
/// Layout strategy (industry standard):
///   - Camera fills the entire screen background.
///   - A dark overlay masks everything OUTSIDE the viewfinder rectangle.
///   - Corner bracket decorations mark the scan area.
///   - A fixed-height instruction sheet is anchored to the bottom.
///   - The viewfinder is centered in the space ABOVE the sheet,
///     so text is never clipped by the panel.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _qrService = QrScannerDiscoveryService();
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _qrService.scan().listen(_onDeviceFound, onError: _onError);
  }

  @override
  void dispose() {
    _qrService.stopScanning();
    super.dispose();
  }

  void _onDeviceFound(DiscoveredDevice device) {
    if (!mounted || _isProcessing) return;
    setState(() => _isProcessing = true);
    Navigator.pop(context, device);
  }

  void _onError(Object error) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage = error.toString().contains('QrPayloadException')
          ? 'Not a TitanCast QR code.\nOpen TitanCast on your TV to get the correct code.'
          : 'Camera error. Tap to try again.';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Space available for the camera area (above the instruction sheet)
    final cameraAreaHeight = size.height - _kSheetHeight - bottomPadding;

    // Viewfinder size: 55% of camera area, clamped to reasonable bounds
    final vfSize = (cameraAreaHeight * 0.55).clamp(180.0, 280.0);

    // Position: horizontally centered, vertically centered in camera area
    final vfLeft = (size.width - vfSize) / 2;
    final vfTop = (cameraAreaHeight - vfSize) / 2;
    final vfRect = Rect.fromLTWH(vfLeft, vfTop, vfSize, vfSize);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan QR Code',
            style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera preview
          if (_qrService.scannerController != null)
            MobileScanner(controller: _qrService.scannerController!),

          // 2. Dark overlay with transparent viewfinder cutout
          CustomPaint(
            size: size,
            painter: _OverlayPainter(viewfinderRect: vfRect),
          ),

          // 3. Corner brackets
          Positioned(
            left: vfLeft,
            top: vfTop,
            child: _CornerBrackets(size: vfSize, color: colorScheme.primary),
          ),

          // 4. "Aim here" hint label -- sits just below the viewfinder
          Positioned(
            top: vfTop + vfSize + 20,
            left: 0,
            right: 0,
            child: Text(
              _isProcessing ? 'Connecting...' : 'Aim at the QR code on your TV',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 5. Error toast -- appears below the hint label
          if (_errorMessage != null)
            Positioned(
              top: vfTop + vfSize + 56,
              left: 32,
              right: 32,
              child: Material(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 18, color: colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Full-screen processing overlay
          if (_isProcessing)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
              child:
              Center(child: CircularProgressIndicator(color: colorScheme.primary)),
            ),

          // 7. Instruction sheet -- fixed to bottom, height matches _kSheetHeight
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _InstructionSheet(
              colorScheme: colorScheme,
              textTheme: textTheme,
              bottomPadding: bottomPadding,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dark overlay with a transparent rectangular cutout for the viewfinder
// =============================================================================

class _OverlayPainter extends CustomPainter {
  final Rect viewfinderRect;
  const _OverlayPainter({required this.viewfinderRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    // Four rectangles surrounding the transparent cutout
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, viewfinderRect.top), paint);
    canvas.drawRect(
        Rect.fromLTWH(0, viewfinderRect.bottom, size.width,
            size.height - viewfinderRect.bottom),
        paint);
    canvas.drawRect(
        Rect.fromLTWH(
            0, viewfinderRect.top, viewfinderRect.left, viewfinderRect.height),
        paint);
    canvas.drawRect(
        Rect.fromLTWH(viewfinderRect.right, viewfinderRect.top,
            size.width - viewfinderRect.right, viewfinderRect.height),
        paint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.viewfinderRect != viewfinderRect;
}

// =============================================================================
// Corner bracket decorations -- four L-shapes with rounded corners
// =============================================================================

class _CornerBrackets extends StatelessWidget {
  final double size;
  final Color color;
  const _CornerBrackets({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CornerPainter(color: color)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 28.0;
    const r = 10.0;
    final cr = const Radius.circular(r);

    // Top-left
    canvas.drawPath(
        Path()
          ..moveTo(0, arm)
          ..lineTo(0, r)
          ..arcToPoint(Offset(r, 0), radius: cr, clockwise: true)
          ..lineTo(arm, 0),
        paint);
    // Top-right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - arm, 0)
          ..lineTo(size.width - r, 0)
          ..arcToPoint(Offset(size.width, r), radius: cr, clockwise: true)
          ..lineTo(size.width, arm),
        paint);
    // Bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - arm)
          ..lineTo(0, size.height - r)
          ..arcToPoint(Offset(r, size.height), radius: cr, clockwise: false)
          ..lineTo(arm, size.height),
        paint);
    // Bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - arm, size.height)
          ..lineTo(size.width - r, size.height)
          ..arcToPoint(Offset(size.width, size.height - r),
              radius: cr, clockwise: false)
          ..lineTo(size.width, size.height - arm),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// =============================================================================
// Bottom instruction sheet -- height is fixed, referenced in layout above
// =============================================================================

class _InstructionSheet extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final double bottomPadding;

  const _InstructionSheet({
    required this.colorScheme,
    required this.textTheme,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kSheetHeight + bottomPadding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to get the QR code',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          _StepRow(n: '1', text: 'Open TitanCast on your TV.',
              cs: colorScheme, tt: textTheme),
          const SizedBox(height: 8),
          _StepRow(n: '2', text: 'Select "Connect Phone" from the menu.',
              cs: colorScheme, tt: textTheme),
          const SizedBox(height: 8),
          _StepRow(
              n: '3',
              text: 'A QR code will appear — point this camera at it.',
              cs: colorScheme,
              tt: textTheme),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String n;
  final String text;
  final ColorScheme cs;
  final TextTheme tt;

  const _StepRow({
    required this.n,
    required this.text,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration:
          BoxDecoration(color: cs.tertiaryContainer, shape: BoxShape.circle),
          child: Center(
            child: Text(n,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cs.onTertiaryContainer)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.45)),
        ),
      ],
    );
  }
}