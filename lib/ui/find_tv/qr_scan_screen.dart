import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../discovery/discovery_model.dart';
import '../../discovery/scanner/qr_scanner_discovery.dart';

const double _kSheetHeight = 220.0;

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
      _errorMessage = 'Invalid QR Code';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _errorMessage = null);
        _startListening();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_qrService.scannerController != null)
            MobileScanner(controller: _qrService.scannerController!),

          Positioned.fill(
            bottom: _kSheetHeight,
            child: Container(
              decoration: ShapeDecoration(
                shape: _ScannerOverlayShape(
                  borderColor: const Color(0xFF8B5CF6),
                  borderRadius: 24,
                  borderLength: 40,
                  borderWidth: 6,
                  cutOutSize: 260,
                  overlayColor: Colors.black.withOpacity(0.7),
                ),
              ),
              child: _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)))
                  : null,
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Positioned(
            left: 0, right: 0, bottom: 0,
            height: _kSheetHeight,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF15151A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan TV Code', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Text('1. Open TitanCast on TV', style: TextStyle(color: Colors.white70)),
                  Text('2. Select Connect Phone', style: TextStyle(color: Colors.white70)),
                  Text('3. Scan the QR code', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const _ScannerOverlayShape({
    required this.borderColor,
    required this.borderWidth,
    required this.overlayColor,
    required this.borderRadius,
    required this.borderLength,
    required this.cutOutSize,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final size = cutOutSize;
    final cutOutRect = Rect.fromLTWH((width - size) / 2, (height - size) / 2, size, size);

    final backgroundPaint = Paint()..color = overlayColor..style = PaintingStyle.fill;
    final backgroundPath = Path()..addRect(rect)..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)))..fillType = PathFillType.evenOdd;
    canvas.drawPath(backgroundPath, backgroundPaint);

    final borderPaint = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = borderWidth..strokeCap = StrokeCap.round;

    final path = Path();
    // Top Left
    path.moveTo(cutOutRect.left, cutOutRect.top + borderLength);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.top, cutOutRect.left + borderLength, cutOutRect.top);
    // Top Right
    path.moveTo(cutOutRect.right - borderLength, cutOutRect.top);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.top, cutOutRect.right, cutOutRect.top + borderLength);
    // Bottom Right
    path.moveTo(cutOutRect.right, cutOutRect.bottom - borderLength);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.bottom, cutOutRect.right - borderLength, cutOutRect.bottom);
    // Bottom Left
    path.moveTo(cutOutRect.left + borderLength, cutOutRect.bottom);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.bottom, cutOutRect.left, cutOutRect.bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) => this; // Missing concrete implementation fixed
}