import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'wifi_passphrase_screen.dart';

class WifiNetworksScreen extends HookWidget {
  const WifiNetworksScreen({
    super.key,
    required this.deviceId,
    required this.ssids,
  });

  final String deviceId;
  final List<String> ssids;

  @override
  Widget build(BuildContext context) {
    final networks = useMemoized(() => ssids, [ssids]);

    return Scaffold(
      appBar: AppBar(title: const Text('Available Wi‑Fi Networks')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Device: $deviceId',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (networks.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(child: Text('No Wi‑Fi networks found nearby.')),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: networks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ssid = networks[index];
                    return ListTile(
                      leading: const Icon(Icons.wifi),
                      title: Text(ssid),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WifiPassphraseScreen(
                              deviceId: deviceId,
                              ssid: ssid,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
