import 'package:flutter/material.dart';

import '../ble/ble_constants.dart';
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
    required this.onPair,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onConnect;
  final ValueChanged<String> onPair;

  @override
  State<BlePairingStep> createState() => _BlePairingStepState();
}

class _BlePairingStepState extends State<BlePairingStep> {
  final _passkeyController = TextEditingController(
    text: AutomaticWateringBleConstants.pairingPasskey,
  );

  @override
  void dispose() {
    _passkeyController.dispose();
    super.dispose();
  }

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
      AwaitingPairingPasskey() => _PasskeyForm(
          controller: _passkeyController,
          onPair: _pairSelectedDevice,
        ),
      PairingInProgress() => const _PairingStatus(
          text: 'Виконуємо сполучення',
        ),
      _ => const SizedBox.shrink(),
    };
  }

  void _pairSelectedDevice() {
    widget.onPair(_passkeyController.text.trim());
  }
}

class _PasskeyForm extends StatelessWidget {
  const _PasskeyForm({
    required this.controller,
    required this.onPair,
  });

  final TextEditingController controller;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Код сполучення',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPair,
          icon: const Icon(Icons.pin),
          label: const Text('Виконати сполучення'),
        ),
      ],
    );
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
