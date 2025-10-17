import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
import 'onboarding_complete_screen.dart';

class WifiPassphraseScreen extends HookWidget {
  const WifiPassphraseScreen({
    super.key,
    required this.deviceId,
    required this.ssid,
  });

  final String deviceId;
  final String ssid;

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final passphraseController = useTextEditingController();
    final isLoading = useState(false);
    final error = useState<String?>(null);
    final isObscured = useState(true);

    Future<void> connect() async {
      final passphrase = passphraseController.text.trim();
      if (passphrase.isEmpty) {
        error.value = 'Passphrase is required';
        return;
      }
      isLoading.value = true;
      error.value = null;
      try {
        await client.connectToWifi(deviceId, ssid, passphrase);
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingCompleteScreen()),
        );
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Wi‑Fi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Device: $deviceId',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Network: $ssid',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passphraseController,
              obscureText: isObscured.value,
              decoration: InputDecoration(
                labelText: 'Passphrase',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    isObscured.value ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => isObscured.value = !isObscured.value,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (error.value != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: ${error.value}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLoading.value ? null : connect,
                icon: isLoading.value
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi),
                label: Text(isLoading.value ? 'Connecting…' : 'Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
