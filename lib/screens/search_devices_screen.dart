import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';

import 'provisioning_status_screen.dart';

/// Search for nearby SaveEye devices over BLE. Shown after user selects "Blue"
/// on the LED state screen (Expo-style flow).
class SearchDevicesScreen extends HookWidget {
  const SearchDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final devices = useState<List<String>>([]);
    final loading = useState(true);
    final error = useState<String?>(null);

    Future<void> scan() async {
      loading.value = true;
      error.value = null;
      try {
        final found = await client.getSaveEyeDevicesNearby();
        devices.value = found;
      } catch (e) {
        error.value = e.toString();
        devices.value = [];
      } finally {
        loading.value = false;
      }
    }

    useEffect(() {
      scan();
      return null;
    }, const []);

    void onDeviceTap(String deviceId) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProvisioningStatusScreen(
            qrOrBle: deviceId,
            initialDisplayId: deviceId,
            skipOnlineCheck: true,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Search for devices')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select your device from the list',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "Can't find your device? Try resetting the device, then search again.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: loading.value
                    ? const Center(child: CircularProgressIndicator())
                    : error.value != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.red.shade700),
                              const SizedBox(height: 12),
                              Text(
                                error.value!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ],
                          )
                        : devices.value.isEmpty
                            ? Center(
                                child: Text(
                                  'No devices found. Move closer to the device and try again.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                itemCount: devices.value.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final deviceId = devices.value[index];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.bluetooth,
                                        color: Colors.blue,
                                        size: 28,
                                      ),
                                      title: Text(
                                        deviceId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      onTap: () => onDeviceTap(deviceId),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loading.value ? null : scan,
              icon: loading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                loading.value ? 'Searching...' : 'Search again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
