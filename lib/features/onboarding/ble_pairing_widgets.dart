import 'package:flutter/material.dart';

import '../ble/ble_models.dart';
import 'ble_onboarding_state.dart';

class BleSelectedDeviceSummary extends StatelessWidget {
  const BleSelectedDeviceSummary({required this.device, super.key});

  final BleDiscoveredDevice device;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.developer_board),
      title: Text(device.displayName),
      subtitle: Text(
        [
          device.id,
          if (device.rssi != null) 'RSSI ${device.rssi}',
        ].join(' - '),
      ),
    );
  }
}

class BlePairingStep extends StatefulWidget {
  const BlePairingStep({
    required this.state,
    required this.onConnect,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onConnect;

  @override
  State<BlePairingStep> createState() => _BlePairingStepState();
}

class _BlePairingStepState extends State<BlePairingStep> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return switch (state) {
      DeviceSelected() => OutlinedButton.icon(
          onPressed: widget.onConnect,
          icon: const Icon(Icons.bluetooth_connected),
          label: const Text('Підключитися'),
        ),
      ConnectingDevice() => const _PairingStatus(
          text: 'Підключаємось до контролера',
        ),
      PairingInProgress() => const _PairingStatus(
          text: 'Виконуємо сполучення',
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PairingStatus extends StatelessWidget {
  const _PairingStatus({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
