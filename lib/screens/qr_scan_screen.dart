import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'provisioning_status_screen.dart';

class QrScanScreen extends HookWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Client/user not needed here; provisioning handled in ProvisioningStatusScreen

    final handledScan = useRef(false);
    final controller = useMemoized(() => MobileScannerController());
    final isProvisioning = useState(false);
    final error = useState<String?>(null);

    useEffect(() {
      return () {
        controller.dispose();
      };
    }, const []);

    // No extraction helpers needed in this screen

    Future<void> handleQr(String value) async {
      if (handledScan.value) return;
      handledScan.value = true;
      error.value = null;
      isProvisioning.value = true;
      // No longer handle status here; delegate to ProvisioningStatusScreen

      try {
        await controller.stop();
      } catch (_) {}

      try {
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProvisioningStatusScreen(qrOrBle: value),
          ),
        );
      } catch (e) {
        error.value = e.toString();
        isProvisioning.value = false;
        handledScan.value = false;
        try {
          await controller.start();
        } catch (_) {}
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final value = barcodes.first.rawValue;
              if (value == null || value.isEmpty) return;
              handleQr(value);
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error.value != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error: ' + (error.value ?? ''),
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Align QR within the frame to scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
