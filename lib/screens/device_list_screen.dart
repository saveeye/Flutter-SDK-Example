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
      } catch (_) {
        // First attempt failed (often a transient timeout on cold start while
        // Firebase refreshes the auth token). Retry once after a short delay.
        try {
          await Future.delayed(const Duration(seconds: 2));
          final devices = await client.getMyDevices();
          myDevices.value = devices;
        } catch (e) {
          myDevicesError.value = e.toString();
        }
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
        builder: (context) => _EditDeviceSettingsDialog(
          deviceId: device.id,
          deviceName: device.alias ?? device.serial,
          currentAlias: device.alias ?? '',
          currentRmsCurrentMax: device.plusDevice?.rmsCurrentMaxPerPhaseAmpere,
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

    Future<void> _showAlarmConfigDialog(Fragment$MyDevice device) async {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _AlarmConfigDialog(
          deviceId: device.id,
          deviceName: device.alias ?? device.serial,
          rmsCurrentMaxPerPhase: device.plusDevice?.rmsCurrentMaxPerPhaseAmpere,
          client: client,
        ),
      );
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Error: ${myDevicesError.value}',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    TextButton(
                      onPressed: fetchMyDevices,
                      child: const Text('Retry'),
                    ),
                  ],
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
                                    Icons.warning_amber_rounded,
                                    size: 20,
                                    color: Colors.orange,
                                  ),
                                  tooltip: 'Advanced Alarms',
                                  onPressed: () => _showAlarmConfigDialog(d),
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

// ─── Advanced Alarm Config Dialog ────────────────────────────────────────────

class _AlarmConfigDialog extends HookWidget {
  final String deviceId;
  final String deviceName;
  final double? rmsCurrentMaxPerPhase;
  final SaveEyeClient client;

  const _AlarmConfigDialog({
    required this.deviceId,
    required this.deviceName,
    this.rmsCurrentMaxPerPhase,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(true);
    final error = useState<String?>(null);
    final successMsg = useState<String?>(null);

    // Current configs
    final energyConfig = useState<
      Query$GetAlarmConfigurations$deviceByIdV2$plusDevice$alarmConfigurations$$PlusDeviceEnergyUsageLimitAlarmConfiguration?
    >(null);
    final fuseConfig = useState<
      Query$GetAlarmConfigurations$deviceByIdV2$plusDevice$alarmConfigurations$$PlusDeviceFuseOverloadAlarmConfiguration?
    >(null);
    final lowPowerConfig = useState<
      Query$GetAlarmConfigurations$deviceByIdV2$plusDevice$alarmConfigurations$$PlusDeviceLowPowerAlarmConfiguration?
    >(null);
    final offlineConfig = useState<
      Query$GetAlarmConfigurations$deviceByIdV2$plusDevice$alarmConfigurations$$PlusDeviceOfflineAlarmConfiguration?
    >(null);

    // Offline alarm controllers
    final offlineThresholdController = useTextEditingController(text: '600');
    final offlineEnabled = useState(true);

    // Energy usage limit alarm controllers
    final energyThresholdController = useTextEditingController(text: '5000');
    final evaluationWindowController = useTextEditingController(text: '60');
    final energyEnabled = useState(true);

    // Fuse overload alarm controllers
    final fuseEnabled = useState(true);
    final fuseTriggerMode = useState(Enum$AlarmTriggerMode.SINGLE_DATAPOINT);
    final fuseCriticalController = useTextEditingController(text: '100');
    final fuseWarningController = useTextEditingController(text: '80');
    final fuseCriticalDpController = useTextEditingController(text: '3');
    final fuseCriticalDurController = useTextEditingController(text: '60');
    final fuseWarningDpController = useTextEditingController(text: '3');
    final fuseWarningDurController = useTextEditingController(text: '60');

    // Low power alarm controllers
    final lowPowerEnabled = useState(true);
    final lowPowerTriggerMode = useState(Enum$AlarmTriggerMode.SINGLE_DATAPOINT);
    final lowPowerThresholdController = useTextEditingController(text: '10');
    final lowPowerDpController = useTextEditingController(text: '3');
    final lowPowerDurController = useTextEditingController(text: '60');

    Future<void> loadConfigs() async {
      isLoading.value = true;
      error.value = null;
      try {
        final e = await client.getEnergyUsageLimitAlarmConfiguration(deviceId);
        final f = await client.getFuseOverloadAlarmConfiguration(deviceId);
        final l = await client.getLowPowerAlarmConfiguration(deviceId);
        final o = await client.getOfflineAlarmConfiguration(deviceId);
        energyConfig.value = e;
        fuseConfig.value = f;
        lowPowerConfig.value = l;
        offlineConfig.value = o;
        if (o != null) {
          offlineThresholdController.text = o.offlineThresholdSeconds.toString();
          offlineEnabled.value = o.isEnabled;
        }
        if (e != null) {
          energyThresholdController.text = e.energyThresholdWh.toString();
          evaluationWindowController.text = e.evaluationWindowMinutes.toString();
          energyEnabled.value = e.isEnabled;
        }
        if (f != null) {
          fuseEnabled.value = f.isEnabled;
          fuseTriggerMode.value = f.triggerMode;
          fuseCriticalController.text = f.criticalThresholdPercent.toString();
          fuseWarningController.text = f.warningThresholdPercent.toString();
          if (f.criticalDatapoints != null) fuseCriticalDpController.text = f.criticalDatapoints.toString();
          if (f.criticalDurationSeconds != null) fuseCriticalDurController.text = f.criticalDurationSeconds.toString();
          if (f.warningDatapoints != null) fuseWarningDpController.text = f.warningDatapoints.toString();
          if (f.warningDurationSeconds != null) fuseWarningDurController.text = f.warningDurationSeconds.toString();
        }
        if (l != null) {
          lowPowerEnabled.value = l.isEnabled;
          lowPowerTriggerMode.value = l.triggerMode;
          lowPowerThresholdController.text = l.powerThresholdW.toString();
          if (l.datapoints != null) lowPowerDpController.text = l.datapoints.toString();
          if (l.durationSeconds != null) lowPowerDurController.text = l.durationSeconds.toString();
        }
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> saveOfflineAlarm() async {
      final threshold = int.tryParse(offlineThresholdController.text.trim());
      if (threshold == null || threshold < 300) {
        error.value = 'Offline threshold must be at least 300 seconds.';
        return;
      }
      error.value = null;
      successMsg.value = null;
      try {
        await client.addOrUpdateOfflineAlarm(
          Input$AddOrUpdatePlusDeviceOfflineAlarmConfigurationInput(
            deviceId: deviceId,
            isEnabled: offlineEnabled.value,
            offlineThresholdSeconds: threshold,
          ),
        );
        successMsg.value = 'Offline alarm saved.';
        await loadConfigs();
      } catch (e) {
        error.value = e.toString();
      }
    }

    Future<void> saveEnergyUsageLimitAlarm() async {
      final threshold = int.tryParse(energyThresholdController.text.trim());
      final window = int.tryParse(evaluationWindowController.text.trim());
      if (threshold == null || threshold <= 0) {
        error.value = 'Energy threshold must be a positive number.';
        return;
      }
      if (window == null || window <= 0) {
        error.value = 'Evaluation window must be a positive number.';
        return;
      }
      error.value = null;
      successMsg.value = null;
      try {
        await client.addOrUpdateEnergyUsageLimitAlarm(
          Input$AddOrUpdateEnergyUsageLimitAlarmConfigurationInput(
            deviceId: deviceId,
            isEnabled: energyEnabled.value,
            energyThresholdWh: threshold,
            evaluationWindowMinutes: window,
          ),
        );
        successMsg.value = 'Energy usage limit alarm saved.';
        await loadConfigs();
      } catch (e) {
        error.value = e.toString();
      }
    }

    Future<void> saveFuseOverloadAlarm() async {
      final critical = int.tryParse(fuseCriticalController.text.trim());
      final warning = int.tryParse(fuseWarningController.text.trim());
      if (critical == null || critical <= 0 || critical > 200) {
        error.value = 'Critical threshold must be between 1 and 200.';
        return;
      }
      if (warning == null || warning <= 0 || warning >= critical) {
        error.value = 'Warning threshold must be positive and less than critical threshold.';
        return;
      }
      int? critDp, critDur, warnDp, warnDur;
      if (fuseTriggerMode.value == Enum$AlarmTriggerMode.CONSECUTIVE_DATAPOINTS) {
        critDp = int.tryParse(fuseCriticalDpController.text.trim());
        warnDp = int.tryParse(fuseWarningDpController.text.trim());
        if (critDp == null || critDp <= 0) { error.value = 'Critical datapoints must be a positive integer.'; return; }
        if (warnDp == null || warnDp <= 0) { error.value = 'Warning datapoints must be a positive integer.'; return; }
      } else if (fuseTriggerMode.value == Enum$AlarmTriggerMode.DURATION) {
        critDur = int.tryParse(fuseCriticalDurController.text.trim());
        warnDur = int.tryParse(fuseWarningDurController.text.trim());
        if (critDur == null || critDur <= 0) { error.value = 'Critical duration must be a positive integer.'; return; }
        if (warnDur == null || warnDur <= 0) { error.value = 'Warning duration must be a positive integer.'; return; }
      }
      error.value = null;
      successMsg.value = null;
      try {
        await client.addOrUpdateFuseOverloadAlarm(
          Input$AddOrUpdatePlusDeviceFuseOverloadAlarmConfigurationInput(
            deviceId: deviceId,
            isEnabled: fuseEnabled.value,
            criticalThresholdPercent: critical,
            warningThresholdPercent: warning,
            triggerMode: fuseTriggerMode.value,
            criticalDatapoints: critDp,
            criticalDurationSeconds: critDur,
            warningDatapoints: warnDp,
            warningDurationSeconds: warnDur,
          ),
        );
        successMsg.value = 'Fuse overload alarm saved.';
        await loadConfigs();
      } catch (e) {
        error.value = e.toString();
      }
    }

    Future<void> saveLowPowerAlarm() async {
      final threshold = int.tryParse(lowPowerThresholdController.text.trim());
      if (threshold == null || threshold <= 0) {
        error.value = 'Power threshold must be a positive number.';
        return;
      }
      int? dp, dur;
      if (lowPowerTriggerMode.value == Enum$AlarmTriggerMode.CONSECUTIVE_DATAPOINTS) {
        dp = int.tryParse(lowPowerDpController.text.trim());
        if (dp == null || dp <= 0) { error.value = 'Datapoints must be a positive integer.'; return; }
      } else if (lowPowerTriggerMode.value == Enum$AlarmTriggerMode.DURATION) {
        dur = int.tryParse(lowPowerDurController.text.trim());
        if (dur == null || dur <= 0) { error.value = 'Duration must be a positive integer.'; return; }
      }
      error.value = null;
      successMsg.value = null;
      try {
        await client.addOrUpdateLowPowerAlarm(
          Input$AddOrUpdatePlusDeviceLowPowerAlarmConfigurationInput(
            deviceId: deviceId,
            isEnabled: lowPowerEnabled.value,
            consumptionThresholdW: threshold,
            triggerMode: lowPowerTriggerMode.value,
            datapoints: dp,
            durationSeconds: dur,
          ),
        );
        successMsg.value = 'Low power alarm saved.';
        await loadConfigs();
      } catch (e) {
        error.value = e.toString();
      }
    }

    useEffect(() {
      loadConfigs();
      return null;
    }, const []);

    return AlertDialog(
      title: Text('Advanced Alarms — $deviceName'),
      content: SizedBox(
        width: double.maxFinite,
        child: isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error.value != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          error.value!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (successMsg.value != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          successMsg.value!,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Offline Alarm ──────────────────────────────────────
                    _AlarmSection(
                      title: 'Offline Alarm',
                      icon: Icons.wifi_off,
                      isActive: offlineConfig.value != null,
                      currentSummary: offlineConfig.value != null
                          ? 'Threshold: ${offlineConfig.value!.offlineThresholdSeconds}s  '
                            '(${offlineConfig.value!.isEnabled ? "enabled" : "disabled"})'
                          : 'Not configured',
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Enabled'),
                            value: offlineEnabled.value,
                            onChanged: (v) => offlineEnabled.value = v,
                            contentPadding: EdgeInsets.zero,
                          ),
                          TextField(
                            controller: offlineThresholdController,
                            decoration: const InputDecoration(
                              labelText: 'Threshold (seconds)',
                              hintText: 'e.g. 600 (min 300)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: saveOfflineAlarm,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Energy Usage Limit Alarm ───────────────────────────
                    _AlarmSection(
                      title: 'Energy Usage Limit Alarm',
                      icon: Icons.bolt,
                      isActive: energyConfig.value != null,
                      currentSummary: energyConfig.value != null
                          ? '${energyConfig.value!.energyThresholdWh} Wh / '
                            '${energyConfig.value!.evaluationWindowMinutes} min  '
                            '(${energyConfig.value!.isEnabled ? "enabled" : "disabled"})'
                          : 'Not configured',
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Enabled'),
                            value: energyEnabled.value,
                            onChanged: (v) => energyEnabled.value = v,
                            contentPadding: EdgeInsets.zero,
                          ),
                          TextField(
                            controller: energyThresholdController,
                            decoration: const InputDecoration(
                              labelText: 'Energy threshold (Wh)',
                              hintText: 'e.g. 5000',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: evaluationWindowController,
                            decoration: const InputDecoration(
                              labelText: 'Evaluation window (minutes)',
                              hintText: 'e.g. 60',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: saveEnergyUsageLimitAlarm,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Fuse Overload Alarm ────────────────────────────────
                    _AlarmSection(
                      title: 'Fuse Overload Alarm',
                      icon: Icons.electrical_services,
                      isActive: fuseConfig.value != null,
                      currentSummary: fuseConfig.value != null
                          ? 'Critical: ${fuseConfig.value!.criticalThresholdPercent}%  '
                            'Warning: ${fuseConfig.value!.warningThresholdPercent}%  '
                            '(${fuseConfig.value!.isEnabled ? "enabled" : "disabled"})'
                          : 'Not configured',
                      child: rmsCurrentMaxPerPhase == null
                          ? Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                border: Border.all(color: Colors.amber.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Max current per phase (A) must be set before configuring the fuse overload alarm. '
                                      'Edit the device settings to set it first.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Enabled'),
                                  value: fuseEnabled.value,
                                  onChanged: (v) => fuseEnabled.value = v,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                DropdownButtonFormField<Enum$AlarmTriggerMode>(
                                  value: fuseTriggerMode.value,
                                  decoration: const InputDecoration(
                                    labelText: 'Trigger mode',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: Enum$AlarmTriggerMode.SINGLE_DATAPOINT,
                                      child: Text('Single datapoint'),
                                    ),
                                    DropdownMenuItem(
                                      value: Enum$AlarmTriggerMode.CONSECUTIVE_DATAPOINTS,
                                      child: Text('Consecutive datapoints'),
                                    ),
                                    DropdownMenuItem(
                                      value: Enum$AlarmTriggerMode.DURATION,
                                      child: Text('Duration'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) fuseTriggerMode.value = v;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: fuseCriticalController,
                                        decoration: const InputDecoration(
                                          labelText: 'Critical threshold (%)',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: fuseWarningController,
                                        decoration: const InputDecoration(
                                          labelText: 'Warning threshold (%)',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                if (fuseTriggerMode.value == Enum$AlarmTriggerMode.CONSECUTIVE_DATAPOINTS) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: fuseCriticalDpController,
                                          decoration: const InputDecoration(
                                            labelText: 'Critical datapoints',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: fuseWarningDpController,
                                          decoration: const InputDecoration(
                                            labelText: 'Warning datapoints',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (fuseTriggerMode.value == Enum$AlarmTriggerMode.DURATION) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: fuseCriticalDurController,
                                          decoration: const InputDecoration(
                                            labelText: 'Critical duration (s)',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: fuseWarningDurController,
                                          decoration: const InputDecoration(
                                            labelText: 'Warning duration (s)',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: saveFuseOverloadAlarm,
                                    child: const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 16),

                    // ── Low Power Alarm ────────────────────────────────────
                    _AlarmSection(
                      title: 'Low Power Alarm',
                      icon: Icons.power_off,
                      isActive: lowPowerConfig.value != null,
                      currentSummary: lowPowerConfig.value != null
                          ? 'Threshold: ${lowPowerConfig.value!.powerThresholdW} W  '
                            '(${lowPowerConfig.value!.isEnabled ? "enabled" : "disabled"})'
                          : 'Not configured',
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Enabled'),
                            value: lowPowerEnabled.value,
                            onChanged: (v) => lowPowerEnabled.value = v,
                            contentPadding: EdgeInsets.zero,
                          ),
                          TextField(
                            controller: lowPowerThresholdController,
                            decoration: const InputDecoration(
                              labelText: 'Power threshold (W)',
                              hintText: 'e.g. 10',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Enum$AlarmTriggerMode>(
                            value: lowPowerTriggerMode.value,
                            decoration: const InputDecoration(
                              labelText: 'Trigger mode',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: Enum$AlarmTriggerMode.SINGLE_DATAPOINT,
                                child: Text('Single datapoint'),
                              ),
                              DropdownMenuItem(
                                value: Enum$AlarmTriggerMode.CONSECUTIVE_DATAPOINTS,
                                child: Text('Consecutive datapoints'),
                              ),
                              DropdownMenuItem(
                                value: Enum$AlarmTriggerMode.DURATION,
                                child: Text('Duration'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) lowPowerTriggerMode.value = v;
                            },
                          ),
                          if (lowPowerTriggerMode.value == Enum$AlarmTriggerMode.CONSECUTIVE_DATAPOINTS) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: lowPowerDpController,
                              decoration: const InputDecoration(
                                labelText: 'Datapoints',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          if (lowPowerTriggerMode.value == Enum$AlarmTriggerMode.DURATION) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: lowPowerDurController,
                              decoration: const InputDecoration(
                                labelText: 'Duration (seconds)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: saveLowPowerAlarm,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AlarmSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final String currentSummary;
  final Widget child;

  const _AlarmSection({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.currentSummary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EditDeviceSettingsDialog extends HookWidget {
  final String deviceId;
  final String deviceName;
  final String currentAlias;
  final double? currentRmsCurrentMax;
  final SaveEyeClient client;

  const _EditDeviceSettingsDialog({
    required this.deviceId,
    required this.deviceName,
    required this.currentAlias,
    required this.currentRmsCurrentMax,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final aliasController = useTextEditingController(text: currentAlias);
    final rmsController = useTextEditingController(
      text: currentRmsCurrentMax?.toStringAsFixed(1) ?? '',
    );
    final isLoading = useState(false);
    final error = useState<String?>(null);

    Future<void> _save() async {
      isLoading.value = true;
      error.value = null;
      try {
        final name = aliasController.text.trim();
        if (name.isEmpty) throw Exception('Alias cannot be empty');

        final rmsText = rmsController.text.trim();
        double? rms;
        if (rmsText.isNotEmpty) {
          rms = double.tryParse(rmsText);
          if (rms == null || rms <= 0) {
            throw Exception('RMS current max must be a positive number (e.g. 16.0)');
          }
        }

        await client.setDeviceAlias(deviceId, name);
        if (rms != null) {
          await client.setRmsCurrentMaxPerPhase(deviceId, rms);
        }

        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    return AlertDialog(
      title: const Text('Edit device settings'),
      content: SingleChildScrollView(
        child: Column(
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rmsController,
              decoration: const InputDecoration(
                labelText: 'Max current per phase (A)',
                hintText: 'e.g. 16.0',
                border: OutlineInputBorder(),
                helperText: 'Leave empty to keep current value',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (error.value != null) ...[
              const SizedBox(height: 12),
              Text(error.value!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
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
