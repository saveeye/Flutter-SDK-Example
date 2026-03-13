import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
import 'device_usage_history_screen.dart';
import 'led_state_screen.dart';

class DeviceListScreen extends HookWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final user = FirebaseAuth.instance.currentUser;

    final myDevices = useState<List<Fragment$MyDevice>>([]);
    final isLoadingMyDevices = useState(false);
    final myDevicesError = useState<String?>(null);

    final healthOk = useState<bool?>(null);

    Future<void> _startAddDeviceFlow() async {
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const LedStateScreen(),
        ),
      );
    }

    Future<void> checkHealth() async {
      try {
        healthOk.value = await client.healthCheck();
      } catch (_) {
        healthOk.value = false;
      }
    }

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

    Future<void> _showEditDeviceDialog(Fragment$MyDevice device) async {
      if (!context.mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => _EditAliasDialog(
          deviceId: device.id,
          deviceName: device.alias ?? device.serial,
          currentAlias: device.alias ?? '',
          client: client,
        ),
      );
      if (result == true) fetchMyDevices();
    }

    Future<void> _showAlarmThresholdDialog(Fragment$MyDevice device) async {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => _AlarmThresholdDialog(
          deviceId: device.id,
          deviceName: device.alias ?? device.serial,
          currentMaxWh: device.plusDevice?.consumptionAlarmMaxWh,
          currentMinWh: null,
          client: client,
        ),
      );
      // Refresh device list if thresholds were updated
      if (result == true) {
        fetchMyDevices();
      }
    }

    Future<void> _unpairDevice(Fragment$MyDevice device) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unpair Device'),
          content: Text(
            'Are you sure you want to unpair "${device.alias ?? device.serial}"? '
            'This will remove the device from your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Unpair'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Unpairing device...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await client.unpairDevice(device.id);
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Device "${device.alias ?? device.serial}" unpaired successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh device list
          fetchMyDevices();
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error unpairing device: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    useEffect(() {
      fetchMyDevices();
      checkHealth();
      return null;
    }, const []);

    // No event subscription cleanup needed; handled in ProvisioningStatusScreen

    return Scaffold(
      appBar: AppBar(
        title: const Text('SaveEye Device'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (healthOk.value != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 14),
              child: Icon(
                healthOk.value! ? Icons.cloud_done : Icons.cloud_off,
                color: healthOk.value! ? Colors.greenAccent : Colors.orangeAccent,
                size: 22,
              ),
            ),
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
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _startAddDeviceFlow,
                icon: const Icon(Icons.add),
                label: const Text('Add device'),
              ),
            ),
            const SizedBox(height: 16),
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
                            child: Row(
                              children: [
                                Expanded(
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
                                              if (d.plusDevice?.errorCode != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    top: 4,
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      const Icon(
                                                        Icons.warning,
                                                        size: 14,
                                                        color: Colors.red,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              _getDeviceErrorMessage(
                                                                d.plusDevice!
                                                                    .errorCode!,
                                                              ),
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .red
                                                                    .shade700,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Error code: ${d.plusDevice!.errorCode}',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[600],
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (d
                                                      .plusDevice
                                                      ?.consumptionAlarmMaxWh !=
                                                  null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Chip(
                                                    label: Text(
                                                      'Max: ${d.plusDevice?.consumptionAlarmMaxWh} Wh',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    visualDensity:
                                                        const VisualDensity(
                                                          horizontal: -4,
                                                          vertical: -4,
                                                        ),
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
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 20,
                                  ),
                                  tooltip: 'Edit alias & settings',
                                  onPressed: () => _showEditDeviceDialog(d),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.notifications_active,
                                    size: 20,
                                  ),
                                  tooltip: 'Set Alarm Thresholds',
                                  onPressed: () => _showAlarmThresholdDialog(d),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.link_off,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Unpair Device',
                                  onPressed: () => _unpairDevice(d),
                                ),
                              ],
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
          ],
        ),
      ),
    );
  }
}

String _getDeviceErrorMessage(String errorCode) {
  // Reuse the same error messages as the onboarding wait screen,
  // but keep the implementation minimal for this example app.
  switch (errorCode) {
    case 'DecryptionError':
    case 'AuthenticationFailure':
    case 'SecurityError':
      return 'There was a security or decryption issue while talking to the meter.';
    case 'ACKError':
      return 'Error connecting to the device. Try reconnecting the device to the meter.';
    case 'Timeout':
      return 'No response from meter. The port might be closed or the device is not properly connected.';
    case 'LengthMismatch':
    case 'SequenceError':
    case 'InvalidData':
      return 'Invalid message received from meter. If the error persists it could be a connection or hardware issue.';
    case 'CRCError':
      return "Invalid data received from meter. Try removing the splitter if you're using one.";
    case 'IdentificationError':
      return 'Error communicating with the meter. If the error persists contact customer support.';
    case 'NegotiateError':
      return 'The device had trouble negotiating with the meter. Try adjusting the placement of the device.';
    case 'LogonError':
      return 'Error while communicating with the meter. If the error persists it could be a hardware issue.';
    case 'ReadError':
      return 'Error reading data from the meter.';
    case 'InvalidDeviceID':
    case 'InitializationError':
    case 'AssociationError':
      return "Couldn't read data from meter. Contact customer support.";
    default:
      return 'The device reported an error. If this persists, contact customer support.';
  }
}


class _AlarmThresholdDialog extends HookWidget {
  final String deviceId;
  final String deviceName;
  final int? currentMaxWh;
  final int? currentMinWh;
  final SaveEyeClient client;

  const _AlarmThresholdDialog({
    required this.deviceId,
    required this.deviceName,
    this.currentMaxWh,
    this.currentMinWh,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final maxWhController = useTextEditingController(
      text: currentMaxWh?.toString() ?? '',
    );
    final minWhController = useTextEditingController(
      text: currentMinWh?.toString() ?? '',
    );
    final isLoading = useState(false);
    final error = useState<String?>(null);
    final success = useState(false);

    Future<void> _saveThresholds() async {
      isLoading.value = true;
      error.value = null;
      success.value = false;

      try {
        final maxWh = maxWhController.text.trim().isEmpty
            ? null
            : int.tryParse(maxWhController.text.trim());
        final minWh = minWhController.text.trim().isEmpty
            ? null
            : int.tryParse(minWhController.text.trim());

        if (maxWhController.text.trim().isNotEmpty && maxWh == null) {
          throw Exception('Maximum threshold must be a valid number');
        }
        if (minWhController.text.trim().isNotEmpty && minWh == null) {
          throw Exception('Minimum threshold must be a valid number');
        }

        await client.setDeviceAlarmThresholds(
          deviceId,
          alarmMaxWh: maxWh,
          alarmMinWh: minWh,
        );
        success.value = true;
        await Future.delayed(const Duration(seconds: 1));
        if (context.mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    return AlertDialog(
      title: const Text('Set Alarm Threshold'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device: $deviceName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (currentMaxWh != null || currentMinWh != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current thresholds:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Max: ${currentMaxWh ?? '—'} Wh, Min: ${currentMinWh ?? '—'} Wh'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: maxWhController,
              decoration: InputDecoration(
                labelText: 'Maximum Alarm (Wh)',
                hintText: 'e.g., 5000',
                border: const OutlineInputBorder(),
                helperText: 'Leave empty to clear',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minWhController,
              decoration: const InputDecoration(
                labelText: 'Minimum Alarm (Wh)',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            if (error.value != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error.value!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (success.value) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Alarm threshold updated successfully!',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading.value
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading.value ? null : _saveThresholds,
          child: isLoading.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _EditAliasDialog extends HookWidget {
  final String deviceId;
  final String deviceName;
  final String currentAlias;
  final SaveEyeClient client;

  const _EditAliasDialog({
    required this.deviceId,
    required this.deviceName,
    required this.currentAlias,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final aliasController = useTextEditingController(text: currentAlias);
    final isLoading = useState(false);
    final error = useState<String?>(null);

    Future<void> _save() async {
      isLoading.value = true;
      error.value = null;
      try {
        final name = aliasController.text.trim();
        if (name.isEmpty) {
          throw Exception('Alias cannot be empty');
        }
        await client.setDeviceAlias(deviceId, name);
        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    return AlertDialog(
      title: const Text('Edit device alias'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device: $deviceName', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: aliasController,
            decoration: const InputDecoration(
              labelText: 'Alias',
              hintText: 'e.g. Living room',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
          ),
          if (error.value != null) ...[
            const SizedBox(height: 12),
            Text(error.value!, style: TextStyle(color: Colors.red.shade700)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading.value ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading.value ? null : _save,
          child: isLoading.value
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
