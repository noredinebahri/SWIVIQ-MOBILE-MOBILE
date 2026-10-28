import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'clock_repo.dart';

/// Caméra plein écran : rend le jeton dès qu'un QR de pointage est lu.
class ClockScanScreen extends StatefulWidget {
  const ClockScanScreen({super.key});

  @override
  State<ClockScanScreen> createState() => _ClockScanScreenState();
}

class _ClockScanScreenState extends State<ClockScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final token = ClockRepo.tokenFromScan(b.rawValue ?? '');
      if (token != null) {
        _done = true;
        Navigator.of(context).pop(token);
        return;
      }
    }
    setState(() => _hint = 'Ce QR n’est pas celui du pointage. Visez l’écran de l’accueil.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner le QR'),
        actions: [
          IconButton(
            tooltip: 'Lampe',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Cadre de visée
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Column(
              children: [
                if (_hint != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_hint!, style: const TextStyle(color: Colors.white)),
                  ),
                const Text(
                  'Visez le QR affiché à l’accueil.\nIl se renouvelle tout seul : pas besoin d’attendre.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
