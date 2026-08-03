import 'package:flutter/material.dart';

import '../ble/ble_models.dart';
import 'ble_onboarding_state.dart';

class BleScanStep extends StatelessWidget {
  const BleScanStep({
    required this.state,
    required this.onRequestPermissions,
    required this.onScan,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onRequestPermissions;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      CheckingBluetooth() => const _DiscoveryStatus(
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          text: 'Перевіряємо Bluetooth',
        ),
      BluetoothUnavailable(availability: BleAvailability.permissionRequired) =>
        FilledButton.icon(
          onPressed: onRequestPermissions,
          icon: const Icon(Icons.lock_open),
          label: const Text('Дозволити Bluetooth'),
        ),
      BluetoothUnavailable(availability: BleAvailability.bluetoothDisabled) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DiscoveryStatus(
              icon: Icon(Icons.bluetooth_disabled),
              text: 'Увімкніть Bluetooth у налаштуваннях пристрою',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.search),
              label: const Text('Шукати'),
            ),
          ],
        ),
      ReadyToScan() => FilledButton.icon(
          onPressed: onScan,
          icon: const Icon(Icons.search),
          label: const Text('Шукати'),
        ),
      DiscoveringDevices() => const _DiscoveryStatus(
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          text: 'Шукаємо контролер',
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _DiscoveryStatus extends StatelessWidget {
  const _DiscoveryStatus({
    required this.icon,
    required this.text,
  });

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme.merge(
          data: IconThemeData(color: colors.onSurfaceVariant, size: 20),
          child: icon,
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

class BleDeviceSelectionStep extends StatelessWidget {
  const BleDeviceSelectionStep({
    required this.state,
    required this.onSelect,
    super.key,
  });

  final BleOnboardingState state;
  final ValueChanged<BleDiscoveredDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    if (state.devices.isEmpty) {
      return Text(
        state is DiscoveringDevices
            ? 'Контролер ще не знайдено.'
            : 'Контролер не знайдено.',
      );
    }

    return Column(
      children: [
        for (final device in state.devices)
          ListTile(
            selected: state.selectedDevice?.id == device.id,
            onTap: () => onSelect(device),
            leading: Icon(
              state.selectedDevice?.id == device.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(device.displayName),
            subtitle: Text(
              [
                device.id,
                if (device.rssi != null) 'RSSI ${device.rssi}',
              ].join(' - '),
            ),
          ),
      ],
    );
  }
}
