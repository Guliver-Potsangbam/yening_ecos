import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'device_found_page.dart';
import 'device_lookup_source.dart';

class ScanDevicePage extends StatefulWidget {
  const ScanDevicePage({super.key});

  @override
  State<ScanDevicePage> createState() => _ScanDevicePageState();
}

class _ScanDevicePageState extends State<ScanDevicePage> {
  final MobileScannerController _scannerController = MobileScannerController();

  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcodeDetection(BarcodeCapture capture) {
    if (_hasScanned) {
      return;
    }

    final barcode = capture.barcodes.isEmpty ? null : capture.barcodes.first;

    final value = barcode?.rawValue;

    if (value == null || value.trim().isEmpty) {
      return;
    }

    _hasScanned = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            DeviceFoundPage(deviceCode: value, source: DeviceLookupSource.qr),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Device'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _scannerController.toggleTorch,
            tooltip: 'Toggle flashlight',
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
          IconButton(
            onPressed: _scannerController.switchCamera,
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcodeDetection,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ScannerOverlayPainter(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Place the device QR code inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = size.shortestSide;

    final frameSize = (shortestSide * 0.68).clamp(190.0, 310.0);

    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );

    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(24)));

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(24)),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
