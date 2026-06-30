import 'package:flutter/material.dart';

import '../ble/ble_constants.dart';
import '../ble/ble_models.dart';
import 'ble_onboarding_controller.dart';
import 'ble_onboarding_state.dart';
import 'wifi_provisioning_models.dart';

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
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _lastSyncedSsid;
  WifiProvisioningStatus? _lastWifiStatus;

  @override
  void initState() {
    super.initState();
    widget.controller.checkAvailability();
  }

  @override
  void dispose() {
    _passkeyController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        _syncWifiFields(state);
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
            _WifiProvisioningPanel(
              state: state,
              ssidController: _ssidController,
              passwordController: _passwordController,
              onUsePhoneWifi: widget.controller.useCurrentPhoneWifi,
              onReadCurrentSettings: widget.controller.readCurrentWifiSettings,
              onSave: () {
                widget.controller.saveWifiSettings(
                  WifiCredentials(
                    ssid: _ssidController.text,
                    password: _passwordController.text,
                    openNetwork: state.wifiCredentials.openNetwork,
                  ),
                );
              },
              onOpenNetworkChanged: (value) {
                widget.controller.updateWifiCredentials(
                  state.wifiCredentials.copyWith(
                    ssid: _ssidController.text,
                    password: value ? '' : _passwordController.text,
                    openNetwork: value,
                  ),
                );
                if (value) {
                  _passwordController.clear();
                }
              },
              onRetryReconnect: widget.controller.retryWifiReconnect,
            ),
          ],
        );
      },
    );
  }

  void _syncWifiFields(BleOnboardingState state) {
    final ssid = state.wifiCredentials.ssid;
    if (_lastSyncedSsid != ssid && ssid.isNotEmpty) {
      _ssidController.text = ssid;
      _lastSyncedSsid = ssid;
    }
    final status = state.wifiStatus;
    if (_lastWifiStatus != status &&
        (status == WifiProvisioningStatus.rebooting ||
            status == WifiProvisioningStatus.reconnecting ||
            status == WifiProvisioningStatus.completed)) {
      _passwordController.clear();
    }
    _lastWifiStatus = status;
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
      BleConnectionStatus.reconnecting => (
          'Повторне підключення',
          'Очікуємо перезавантаження контролера та відновлюємо BLE-з\'єднання.',
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
        state.connectionStatus == BleConnectionStatus.reconnecting ||
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

class _WifiProvisioningPanel extends StatelessWidget {
  const _WifiProvisioningPanel({
    required this.state,
    required this.ssidController,
    required this.passwordController,
    required this.onUsePhoneWifi,
    required this.onReadCurrentSettings,
    required this.onSave,
    required this.onOpenNetworkChanged,
    required this.onRetryReconnect,
  });

  final BleOnboardingState state;
  final TextEditingController ssidController;
  final TextEditingController passwordController;
  final VoidCallback onUsePhoneWifi;
  final VoidCallback onReadCurrentSettings;
  final VoidCallback onSave;
  final ValueChanged<bool> onOpenNetworkChanged;
  final VoidCallback onRetryReconnect;

  @override
  Widget build(BuildContext context) {
    if (state.step.index < BleOnboardingStep.wifiProvisioning.index) {
      return const SizedBox.shrink();
    }

    final busy = state.wifiStatus == WifiProvisioningStatus.reading ||
        state.wifiStatus == WifiProvisioningStatus.saving ||
        state.wifiStatus == WifiProvisioningStatus.rebooting ||
        state.wifiStatus == WifiProvisioningStatus.reconnecting;
    final openNetwork = state.wifiCredentials.openNetwork;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wi-Fi контролера',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(_statusText(state.wifiStatus)),
        if (state.wifiError != null) ...[
          const SizedBox(height: 8),
          Text(
            state.wifiError!.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: ssidController,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: 'Назва Wi-Fi мережі',
            hintText: 'Наприклад Домашня мережа',
            errorText: state.wifiValidationErrors['ssid'],
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: openNetwork,
          onChanged: busy ? null : onOpenNetworkChanged,
          title: const Text('Відкрита мережа без пароля'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          enabled: !busy && !openNetwork,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Пароль Wi-Fi',
            hintText: openNetwork ? 'Пароль не потрібен' : 'Введіть пароль',
            errorText: state.wifiValidationErrors['password'],
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : onReadCurrentSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('Прочитати з контролера'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onUsePhoneWifi,
              icon: const Icon(Icons.wifi),
              label: const Text('Використати поточну Wi-Fi мережу телефону'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: state.canSaveWifi ? onSave : null,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Зберегти Wi-Fi налаштування'),
        ),
        if (state.wifiStatus == WifiProvisioningStatus.ready &&
            state.connectionStatus == BleConnectionStatus.reconnecting) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetryReconnect,
            icon: const Icon(Icons.replay),
            label: const Text('Спробувати ще раз'),
          ),
        ],
        if (state.step == BleOnboardingStep.accessBootstrap) ...[
          const SizedBox(height: 12),
          const Text(
            'Wi-Fi збережено. Наступний крок - читання IP-адреси та токена доступу.',
          ),
        ],
      ],
    );
  }

  String _statusText(WifiProvisioningStatus status) {
    return switch (status) {
      WifiProvisioningStatus.idle => 'Готово до читання Wi-Fi налаштувань.',
      WifiProvisioningStatus.reading =>
        'Читаємо поточну Wi-Fi мережу контролера.',
      WifiProvisioningStatus.ready =>
        'Введіть дані Wi-Fi мережі і збережіть їх у контролер.',
      WifiProvisioningStatus.saving =>
        'Записуємо Wi-Fi налаштування через BLE.',
      WifiProvisioningStatus.rebooting =>
        'Контролер прийняв налаштування і перезавантажується.',
      WifiProvisioningStatus.reconnecting =>
        'Повторно підключаємося до контролера через BLE.',
      WifiProvisioningStatus.completed => 'Повторне BLE-підключення виконано.',
    };
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
