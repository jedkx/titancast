import 'dart:async';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../discovery_model.dart';
import 'qr_payload_model.dart';

/// Opens the device camera, scans for a TitanCast QR code, and emits the
/// discovered device as a [DiscoveredDevice] on the returned stream.
///
/// The stream:
///   - Emits exactly one device on success, then closes.
///   - Emits an error (as a [QrPayloadException]) if the QR content is not a
///     valid TitanCast payload, then closes.
///   - Closes with no events if [stopScanning] is called before a code is read.
///
/// The UI is responsible for showing the camera preview via [MobileScannerController].
/// This service owns the controller lifecycle -- call [stopScanning] when the
/// UI that hosts the preview is disposed.
class QrScannerDiscoveryService {
  MobileScannerController? _scannerController;
  StreamController<DiscoveredDevice>? _controller;
  bool _isScanning = false;

  /// The [MobileScannerController] that drives the camera preview widget.
  ///
  /// The UI should pass this into a [MobileScanner] widget:
  ///   MobileScanner(controller: qrService.scannerController)
  ///
  /// Only valid after [scan] has been called.
  MobileScannerController? get scannerController => _scannerController;

  /// Starts the camera and returns a stream that emits the discovered device.
  Stream<DiscoveredDevice> scan() {
    _cleanup();
    _isScanning = true;
    _controller = StreamController<DiscoveredDevice>();

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    _scannerController!.barcodes.listen(
      _handleBarcode,
      onError: (e) {
        _controller?.addError('Camera error: $e');
        _cleanup();
      },
    );

    _scannerController!.start();
    return _controller!.stream;
  }

  /// Stops the camera and closes the stream.
  void stopScanning() => _cleanup();

  void _handleBarcode(BarcodeCapture capture) {
    if (!_isScanning) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final payload = QrPayloadModel.fromJson(json);
        final device = _payloadToDevice(payload);

        _controller?.add(device);
        // One successful scan ends the session.
        _cleanup();
        return;
      } on QrPayloadException catch (e) {
        // The QR was readable but not a TitanCast payload.
        _controller?.addError(e);
        _cleanup();
        return;
      } catch (_) {
        // Not valid JSON -- not a TitanCast QR code, keep scanning silently.
      }
    }
  }

  /// Converts a parsed QR payload into the unified [DiscoveredDevice] model.
  DiscoveredDevice _payloadToDevice(QrPayloadModel payload) {
    return DiscoveredDevice(
      ip: payload.ip,
      friendlyName: payload.name,
      method: DiscoveryMethod.qr,
      manufacturer: payload.manufacturer,
      modelName: payload.model,
      // serviceType carries the protocol hint so the connection layer can
      // skip negotiation and go straight to the right protocol.
      serviceType: payload.protocol,
      port: payload.port,
    );
  }

  void _cleanup() {
    _isScanning = false;
    _scannerController?.stop();
    _scannerController?.dispose();
    _scannerController = null;
    if (_controller?.isClosed == false) _controller?.close();
  }
}