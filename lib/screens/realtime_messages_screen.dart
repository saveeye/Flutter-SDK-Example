import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
import 'package:saveeye_flutter_sdk/src/websocket_manager.dart';
import 'package:saveeye_flutter_sdk/src/realtime_models.dart';

class RealtimeMessagesScreen extends HookWidget {
  final String deviceId;
  final String? title;

  const RealtimeMessagesScreen({super.key, required this.deviceId, this.title});

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();

    final messages = useState<List<RealtimeReading>>([]);
    final error = useState<WebSocketErrorEvent?>(null);
    final connected = useState<bool>(false);

    useEffect(() {
      // Subscribe on mount
      client.subscribeToRealtimeData(deviceId, (data, err) {
        if (err != null) {
          error.value = err;
          connected.value = false;
          return;
        }
        if (data != null) {
          messages.value = [...messages.value, data];
          connected.value = true;
        }
      });

      // Cleanup: unsubscribe on unmount
      return () {
        client.unsubscribeFromRealtimeData();
      };
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Realtime Messages'),
        actions: [
          IconButton(
            tooltip: 'Clear messages',
            onPressed: () => messages.value = [],
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  connected.value ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: connected.value ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  connected.value ? 'Connected' : 'Connecting...',
                  style: TextStyle(
                    color: connected.value
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                if (error.value != null)
                  Text(
                    'Error: ${error.value!.message}',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: messages.value.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.value.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = messages.value[index];
                      return _ReadingTile(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final RealtimeReading reading;
  const _ReadingTile(this.reading);

  @override
  Widget build(BuildContext context) {
    String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                reading.saveEyeDeviceSerialNumber,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              Text(
                reading.timestamp.toLocal().toIso8601String(),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _Chip('Power Factor', _fmt(reading.powerFactor.total)),
              _Chip('WiFi RSSI', reading.wifiRssi.toString()),
              if (reading.pingElapsedTimeMs != null)
                _Chip('Ping (ms)', reading.pingElapsedTimeMs.toString()),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _RowKV('Current Consumption W', reading.currentConsumptionW),
          _RowKV('Current Production W', reading.currentProductionW),
          _RowKV(
            'Reactive Current Cons. W',
            reading.reactiveCurrentConsumptionW,
          ),
          _RowKV(
            'Reactive Current Prod. W',
            reading.reactiveCurrentProductionW,
          ),
          _RowKV('RMS Current', reading.rmsCurrent),
          _RowKV('RMS Voltage', reading.rmsVoltage),
          _RowKV('Total Consumption Wh', reading.totalConsumptionWh),
          _RowKV('Total Production Wh', reading.totalProductionWh),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String label;
  final Consumption c;
  const _RowKV(this.label, this.c);

  @override
  Widget build(BuildContext context) {
    String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _Chip('L1', _fmt(c.l1)),
            _Chip('L2', _fmt(c.l2)),
            _Chip('L3', _fmt(c.l3)),
            if (c.total != null) _Chip('Total', _fmt(c.total)),
          ],
        ),
      ],
    );
  }
}
