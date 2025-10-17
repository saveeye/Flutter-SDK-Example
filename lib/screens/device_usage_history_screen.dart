import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
import 'package:saveeye_flutter_sdk/gql/queries/getEnergyUsageHistory.graphql.dart';
import 'package:saveeye_flutter_sdk/gql/queries/getPowerUsageHistory.graphql.dart';
import 'package:saveeye_flutter_sdk/gql/schema.graphql.dart';
import 'package:saveeye_flutter_sdk_example/screens/realtime_messages_screen.dart';

class DeviceUsageHistoryScreen extends HookWidget {
  final String deviceId;
  final String? title;
  const DeviceUsageHistoryScreen({
    super.key,
    required this.deviceId,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();

    final isLoading = useState(true);
    final error = useState<String?>(null);

    final energy = useState<Query$EnergyUsageHistory?>(null);
    final power = useState<Query$PowerUsageHistory?>(null);

    // Filters
    final endUtc = useState<DateTime>(DateTime.now().toUtc());
    final startUtc = useState<DateTime>(
      DateTime.now().toUtc().subtract(const Duration(days: 7)),
    );
    final interval = useState<Enum$IntervalType>(Enum$IntervalType.DAY);

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        // Basic validation
        if (startUtc.value.isAfter(endUtc.value)) {
          throw Exception('Start date must be before or equal to end date');
        }

        final results = await Future.wait([
          client.getEnergyUsageHistory(
            deviceId,
            startUtc.value,
            endUtc.value,
            interval.value,
          ),
          client.getPowerUsageHistory(
            deviceId,
            startUtc.value,
            endUtc.value,
            interval.value,
          ),
        ]);
        energy.value = results[0] as Query$EnergyUsageHistory?;
        power.value = results[1] as Query$PowerUsageHistory?;
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Usage History')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Realtime messages entry
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Realtime messages',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open a live view of websocket updates for this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.wifi),
                      label: const Text('Open Realtime Messages'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RealtimeMessagesScreen(
                              deviceId: deviceId,
                              title:
                                  'Realtime (${deviceId.substring(0, deviceId.length > 6 ? 6 : deviceId.length)})',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Filters UI
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Interval dropdown
                        _Labeled(
                          label: 'Interval',
                          child: DropdownButton<Enum$IntervalType>(
                            value: interval.value,
                            onChanged: (v) {
                              if (v == null) return;
                              interval.value = v;
                            },
                            items: Enum$IntervalType.values
                                .where((e) => e != Enum$IntervalType.$unknown)
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.name),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        // Start date selector
                        _Labeled(
                          label: 'Start',
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startUtc.value.toLocal(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                startUtc.value = DateTime.utc(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                );
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(_dateLabel(startUtc.value.toLocal())),
                          ),
                        ),
                        // End date selector
                        _Labeled(
                          label: 'End',
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endUtc.value.toLocal(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                endUtc.value = DateTime.utc(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                );
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(_dateLabel(endUtc.value.toLocal())),
                          ),
                        ),
                        // Apply button
                        ElevatedButton.icon(
                          onPressed: () => load(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Apply'),
                        ),
                      ],
                    ),
                    if (startUtc.value.isAfter(endUtc.value)) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Start date must be before or equal to end date',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isLoading.value)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!isLoading.value && error.value != null)
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
            if (!isLoading.value && error.value == null) ...[
              _EnergyCard(energy.value),
              const SizedBox(height: 16),
              _PowerCard(power.value),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  final Query$EnergyUsageHistory? data;
  const _EnergyCard(this.data);

  @override
  Widget build(BuildContext context) {
    final h = data?.energyUsageHistory;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Energy Usage (kWh)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (h != null) Chip(label: Text(h.intervalType.name)),
              ],
            ),
            const SizedBox(height: 12),
            if (h == null)
              const Text('No data')
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatTile(
                    'Total Consumed',
                    _fmt(h.totalEnergyConsumedKWh, 'kWh'),
                  ),
                  _StatTile(
                    'Total Produced',
                    _fmt(h.totalEnergyProducedKWh, 'kWh'),
                  ),
                  _StatTile(
                    'Peak Cons.',
                    _fmt(h.peakEnergyConsumptionKWh, 'kWh'),
                  ),
                  _StatTile(
                    'Peak Prod.',
                    _fmt(h.peakEnergyProductionKWh, 'kWh'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Summaries (${h.energyUsageSummaries.length})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...h.energyUsageSummaries
                  .take(20)
                  .map(
                    (s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_dateLabel(s.aggregationPeriod)),
                      subtitle: Text(
                        'Consumed: ${s.energyConsumedKWh.toStringAsFixed(3)} kWh, Produced: ${s.energyProducedKWh.toStringAsFixed(3)} kWh',
                      ),
                    ),
                  ),
              if (h.energyUsageSummaries.length > 20)
                Text(
                  '+${h.energyUsageSummaries.length - 20} more...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PowerCard extends StatelessWidget {
  final Query$PowerUsageHistory? data;
  const _PowerCard(this.data);

  @override
  Widget build(BuildContext context) {
    final h = data?.powerUsageHistory;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.electrical_services, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Power Usage (W)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (h != null) Chip(label: Text(h.intervalType.name)),
              ],
            ),
            const SizedBox(height: 12),
            if (h == null)
              const Text('No data')
            else ...[
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Summaries (${h.powerUsageSummaries.length})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...h.powerUsageSummaries
                  .take(20)
                  .map(
                    (s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_dateLabel(s.aggregationPeriod)),
                      subtitle: Text(
                        'Avg: ${s.averageConsumptionWatt.toStringAsFixed(1)} W, Max: ${s.maxConsumptionWatt.toStringAsFixed(1)} W, Min: ${s.minConsumptionWatt.toStringAsFixed(1)} W',
                      ),
                    ),
                  ),
              if (h.powerUsageSummaries.length > 20)
                Text(
                  '+${h.powerUsageSummaries.length - 20} more...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        child,
      ],
    );
  }
}

String _fmt(double? v, String unit) {
  if (v == null) return '—';
  return '${v.toStringAsFixed(3)} $unit';
}

String _dateLabel(DateTime dt) {
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
}

String _two(int n) => n < 10 ? '0$n' : '$n';
