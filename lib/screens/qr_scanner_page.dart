import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key, this.autoSubmitAttendance = false});

  // If true, this page will handle attendance submission itself (not used by default).
  final bool autoSubmitAttendance;
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionTimeoutMs: 800,
  );
  bool _handled = false;
  bool _closing = false;
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _statusMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final first = codes.firstWhere(
      (b) => (b.rawValue ?? '').isNotEmpty,
      orElse: () => codes.first,
    );
    final raw = first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handled = true;
    if (_closing) return;
    _closing = true;
    try {
      await _controller.stop();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop(raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        try {
          await _controller.stop();
        } catch (_) {}
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan QR Code'),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 32,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text('Camera error: $error'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            try {
                              await _controller.stop();
                            } catch (_) {}
                            if (!mounted) return;
                            navigator.pop();
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Framing overlay
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Align the QR within the frame',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            // Status overlay (used if autoSubmitAttendance is enabled in future)
            if (_isProcessing || _statusMessage != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isProcessing)
                          const CircularProgressIndicator(color: Colors.white),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (!_isProcessing && !_isSuccess)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _handled = false;
                                  _closing = false;
                                  _isProcessing = false;
                                  _isSuccess = false;
                                  _statusMessage = null;
                                });
                              },
                              child: const Text('Scan Again'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
