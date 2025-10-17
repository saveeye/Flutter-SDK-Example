import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';

import 'wifi_networks_screen.dart';
import 'onboarding_complete_screen.dart';

class ProvisioningStatusScreen extends HookWidget {
  const ProvisioningStatusScreen({
    super.key,
    required this.qrOrBle,
    this.initialDisplayId,
    this.skipOnlineCheck = false,
  });

  final String qrOrBle;
  final String? initialDisplayId;
  final bool skipOnlineCheck;

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final user = FirebaseAuth.instance.currentUser;

    final isProvisioning = useState(true);
    final statusMessage = useState<String>('Starting provisioning...');
    final error = useState<String?>(null);
    final provisionSub = useRef<StreamSubscription?>(null);

    Future<void> startProvisioning() async {
      error.value = null;
      isProvisioning.value = true;
      statusMessage.value = 'Starting provisioning...';

      if (!skipOnlineCheck) {
        statusMessage.value = 'Checking device online status...';
        final online = await client.isDeviceOnline(qrOrBle);
        print("Online: $online");
        if (online) {
          final paired = await client.pairDevice(qrOrBle, user?.uid);
          print("Paired: $paired");
          if (paired) {
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const OnboardingCompleteScreen(),
              ),
            );
            return;
          }
        }
      }

      provisionSub.value?.cancel();
      provisionSub.value = client.events.listen((event) {
        if (event.topic != SaveEyeClient.deviceStatusTopic) return;
        switch (event.stage) {
          case ConnectionStage.fetchingDeviceConfig:
            statusMessage.value = 'Fetching device config...';
            break;
          case ConnectionStage.fetchedDeviceConfig:
            statusMessage.value = 'Device config fetched.';
            break;
          case ConnectionStage.searching:
            statusMessage.value = 'Searching for device over BLE...';
            break;
          case ConnectionStage.connected:
            statusMessage.value = 'Connected to device.';
            break;
          case ConnectionStage.pairing:
            statusMessage.value = 'Pairing with device...';
            break;
          case ConnectionStage.paired:
            statusMessage.value = 'Provisioning successful.';
            break;
          case ConnectionStage.error:
          case ConnectionStage.errorAlreadyPaired:
            statusMessage.value = 'Provisioning failed.';
            break;
          case ConnectionStage.none:
          case ConnectionStage.connecting:
            break;
        }
      });

      try {
        final networks = await client.provisionDevice(qrOrBle, user?.uid);

        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WifiNetworksScreen(
              deviceId: qrOrBle,
              ssids: networks ?? const [],
            ),
          ),
        );
      } catch (e) {
        error.value = e.toString();
        isProvisioning.value = false;
      }
    }

    useEffect(() {
      startProvisioning();
      return () {
        provisionSub.value?.cancel();
      };
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const Text('Provisioning')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (isProvisioning.value)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.info_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusMessage.value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProvisioning.value
                        ? null
                        : () {
                            Navigator.of(context).maybePop();
                          },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProvisioning.value
                        ? null
                        : () {
                            startProvisioning();
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
