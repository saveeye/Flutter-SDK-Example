import 'package:flutter/material.dart';

import 'qr_scan_screen.dart';
import 'search_devices_screen.dart';

class LedStateScreen extends StatelessWidget {
  const LedStateScreen({super.key});

  Future<void> _handleSelect(
    BuildContext context,
    _LedStateOption option,
  ) async {
    switch (option) {
      case _LedStateOption.green:
      case _LedStateOption.red:
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const QrScanScreen(),
          ),
        );
      case _LedStateOption.blue:
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SearchDevicesScreen(),
          ),
        );
      case _LedStateOption.none:
        if (!context.mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('No light'),
              content: const Text(
                'Please wait a few minutes for the device to start. '
                'If the LED still does not turn on, contact customer support.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = <Map<String, Object>>[
      <String, Object>{
        'label': 'Green',
        'subtitle': 'Solid or blinking green light',
        'value': _LedStateOption.green,
        'color': Colors.green,
      },
      <String, Object>{
        'label': 'Blue',
        'subtitle': 'Solid or blinking blue light',
        'value': _LedStateOption.blue,
        'color': Colors.blue,
      },
      <String, Object>{
        'label': 'Red',
        'subtitle': 'Solid or blinking red light',
        'value': _LedStateOption.red,
        'color': Colors.red,
      },
      <String, Object>{
        'label': 'Nothing / No light',
        'subtitle': 'The LED is off or not visible',
        'value': _LedStateOption.none,
        'color': Colors.grey,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('What is the LED doing?'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final ledOption = option['value']! as _LedStateOption;
          final Color color = option['color']! as Color;
          final String label = option['label']! as String;
          final String subtitle = option['subtitle']! as String;

          return Card(
            child: ListTile(
              leading: Icon(
                Icons.circle,
                color: color,
              ),
              title: Text(label),
              subtitle: Text(subtitle),
              onTap: () => _handleSelect(context, ledOption),
            ),
          );
        },
      ),
    );
  }
}

enum _LedStateOption {
  green,
  blue,
  red,
  none,
}

