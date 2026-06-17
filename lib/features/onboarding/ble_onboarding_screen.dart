import 'package:flutter/material.dart';

import '../ble/ble_constants.dart';
import '../ble/ble_models.dart';
import 'ble_onboarding_controller.dart';
import 'ble_onboarding_state.dart';

class BleOnboardingScreen extends StatefulWidget {
  const BleOnboardingScreen({
    required this.controller,
    super.key,
  });

  final BleOnboardingController controller;

  @override
  State<BleOnboardingScreen> createState() => _BleOnboardingScreenState();
}

class _BleOnboardingScreenState extends State<BleOnboardingScreen> {
  final _passkeyController = TextEditingController(
    text: AutomaticWateringBleConstants.pairingPasskey,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.checkAvailability();
  }

  @override
  void dispose() {
    _passkeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Додати контролер',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _StateBanner(state: state),
            const SizedBox(height: 16),
            _ActionRow(
              state: state,
              onRequestPermissions: widget.controller.requestPermissions,
              onScan: widget.controller.startScan,
            ),
            const SizedBox(height: 16),
            _DeviceList(
              state: state,
              onSelect: widget.controller.selectDevice,
            ),
            const SizedBox(height: 16),
            _PairingPanel(
              state: state,
              passkeyController: _passkeyController,
              onConnect: widget.controller.connectSelectedDevice,
              onPair: () {
                widget.controller.pairSelectedDevice(
                  _passkeyController.text.trim(),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.canContinue ? () {} : null,
              child: const Text('Продовжити'),
            ),
          ],
        );
      },
    );
  }
}

class _StateBanner extends StatelessWidget {
  const _StateBanner({required this.state});

  final BleOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (title, message, icon) = _copyForState(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message),
                  if (state.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.lastError!.technicalReason,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, String, IconData) _copyForState(BleOnboardingState state) {
    return switch (state.connectionStatus) {
      BleConnectionStatus.permissionRequired => (
          'Потрібен дозвіл Bluetooth',
          'Надайте дозвіл Bluetooth, щоб знайти контролер поливу.',
          Icons.lock_outline,
        ),
      BleConnectionStatus.bluetoothDisabled => (
          'Bluetooth вимкнено',
          'Увімкніть Bluetooth перед пошуком контролера.',
          Icons.bluetooth_disabled,
        ),
      BleConnectionStatus.scanning => (
          'Пошук',
          'Шукаємо поблизу контролери поливу.',
          Icons.radar,
        ),
      BleConnectionStatus.deviceFound => (
          'Контролер знайдено',
          'Виберіть контролер і підключіться, щоб почати сполучення.',
          Icons.bluetooth_searching,
        ),
      BleConnectionStatus.connecting => (
          'Підключення',
          'Відкриваємо BLE-з\'єднання з вибраним контролером.',
          Icons.sync,
        ),
      BleConnectionStatus.pairingRequired => (
          'Потрібне сполучення',
          'Підтвердьте 6-значний код у системному діалозі сполучення.',
          Icons.pin,
        ),
      BleConnectionStatus.pairing => (
          'Сполучення',
          'Перевіряємо захищений BLE-сервіс і характеристики.',
          Icons.password,
        ),
      BleConnectionStatus.connected => (
          'Сполучення виконано',
          'BLE-ідентифікатор контролера збережено локально.',
          Icons.check_circle_outline,
        ),
      BleConnectionStatus.disconnected => (
          'Відключено',
          'Підключіться повторно, щоб продовжити сполучення.',
          Icons.link_off,
        ),
      BleConnectionStatus.error => (
          'Помилка BLE',
          state.lastError?.message ?? 'BLE-операція не виконана.',
          Icons.error_outline,
        ),
      BleConnectionStatus.idle => (
          'Готово до пошуку',
          'Запустіть пошук, щоб знайти контролер поливу.',
          Icons.bluetooth,
        ),
    };
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.state,
    required this.onRequestPermissions,
    required this.onScan,
  });

  final BleOnboardingState state;
  final VoidCallback onRequestPermissions;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scanBusy = state.connectionStatus == BleConnectionStatus.scanning ||
        state.connectionStatus == BleConnectionStatus.connecting ||
        state.connectionStatus == BleConnectionStatus.pairing;
    return Row(
      children: [
        if (state.connectionStatus == BleConnectionStatus.permissionRequired)
          FilledButton.icon(
            onPressed: onRequestPermissions,
            icon: const Icon(Icons.lock_open),
            label: const Text('Дозволити Bluetooth'),
          )
        else
          FilledButton.icon(
            onPressed: scanBusy ? null : onScan,
            icon: const Icon(Icons.search),
            label: Text(state.devices.isEmpty ? 'Шукати' : 'Шукати знову'),
          ),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.state,
    required this.onSelect,
  });

  final BleOnboardingState state;
  final ValueChanged<BleDiscoveredDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    if (state.devices.isEmpty) {
      final message = state.connectionStatus == BleConnectionStatus.scanning
          ? 'Контролер ще не знайдено.'
          : 'Контролер не знайдено.';
      return Text(message);
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

class _PairingPanel extends StatelessWidget {
  const _PairingPanel({
    required this.state,
    required this.passkeyController,
    required this.onConnect,
    required this.onPair,
  });

  final BleOnboardingState state;
  final TextEditingController passkeyController;
  final VoidCallback onConnect;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedDevice != null;
    final canConnect = selected &&
        (state.connectionStatus == BleConnectionStatus.deviceFound ||
            state.connectionStatus == BleConnectionStatus.disconnected ||
            state.connectionStatus == BleConnectionStatus.error);
    final canPair = selected &&
        state.connectionStatus == BleConnectionStatus.pairingRequired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: canConnect ? onConnect : null,
          icon: const Icon(Icons.bluetooth_connected),
          label: const Text('Підключитися'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passkeyController,
          enabled: canPair,
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
          onPressed: canPair ? onPair : null,
          icon: const Icon(Icons.pin),
          label: const Text('Виконати сполучення'),
        ),
      ],
    );
  }
}
