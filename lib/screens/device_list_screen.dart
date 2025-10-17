import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
// Removed unused wifi_networks_screen import after refactor
import 'provisioning_status_screen.dart';
import 'qr_scan_screen.dart';
import 'device_usage_history_screen.dart';

class DeviceListScreen extends HookWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final user = FirebaseAuth.instance.currentUser;

    final myDevices = useState<List<Fragment$MyDevice>>([]);
    final isLoadingMyDevices = useState(false);
    final myDevicesError = useState<String?>(null);

    final nearbyDevices = useState<List<String>>([]);
    final isLoadingNearby = useState(false);
    final nearbyError = useState<String?>(null);

    Future<void> fetchMyDevices() async {
      isLoadingMyDevices.value = true;
      myDevicesError.value = null;
      try {
        final devices = await client.getMyDevices();
        myDevices.value = devices;
      } catch (e) {
        myDevicesError.value = e.toString();
      } finally {
        isLoadingMyDevices.value = false;
      }
    }

    Future<void> fetchNearbyDevices() async {
      isLoadingNearby.value = true;
      nearbyError.value = null;

      try {
        final devices = await client.getSaveEyeDevicesNearby();
        nearbyDevices.value = devices;
        print('Nearby devices found: ${devices.length}');
      } catch (e) {
        nearbyError.value = e.toString();
        print('Error fetching nearby devices: $e');
      } finally {
        isLoadingNearby.value = false;
      }
    }

    Future<void> signOut() async {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Placeholder()),
          );
        }
      }
    }

    Future<void> _startProvisioning(String bleName) async {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProvisioningStatusScreen(
            qrOrBle: bleName,
            initialDisplayId: bleName,
            skipOnlineCheck: true,
          ),
        ),
      );
    }

    void _openUsage(Fragment$MyDevice d) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceUsageHistoryScreen(
            deviceId: d.id,
            title: d.alias ?? d.serial,
          ),
        ),
      );
    }

    useEffect(() {
      fetchMyDevices();
      return null;
    }, const []);

    // No event subscription cleanup needed; handled in ProvisioningStatusScreen

    return Scaffold(
      appBar: AppBar(
        title: const Text('SaveEye Device'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signout') {
                signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    const Icon(Icons.logout),
                    const SizedBox(width: 8),
                    const Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            user?.email ?? 'Signed in',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'My Devices',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (isLoadingMyDevices.value)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (myDevicesError.value != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: ${myDevicesError.value}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            if (!isLoadingMyDevices.value && myDevicesError.value == null)
              if (myDevices.value.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        ...myDevices.value.map(
                          (d) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: () => _openUsage(d),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.flash_on,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(d.alias ?? d.serial),
                                        Text(
                                          d.id,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('No devices found for your account.'),
                    ],
                  ),
                ),
            const SizedBox(height: 24),

            // Provisioning status UI moved to ProvisioningStatusScreen

            // Nearby Devices Section
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Nearby SaveEye Devices',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isLoadingNearby.value ? null : fetchNearbyDevices,
              icon: isLoadingNearby.value
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(
                isLoadingNearby.value
                    ? 'Scanning...'
                    : 'Scan for Nearby Devices',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrScanScreen()),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Add Device via QR Code'),
              ),
            ),
            const SizedBox(height: 16),
            if (nearbyError.value != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: ${nearbyError.value}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            if (nearbyDevices.value.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Found ${nearbyDevices.value.length} device(s)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...nearbyDevices.value.map(
                        (deviceIdStr) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            onTap: () => _startProvisioning(deviceIdStr),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bluetooth,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(deviceIdStr)),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!isLoadingNearby.value && nearbyError.value == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'No nearby devices found. Tap "Scan for Nearby Devices" to search.',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
