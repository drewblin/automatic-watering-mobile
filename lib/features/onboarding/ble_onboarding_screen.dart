import 'package:flutter/material.dart';

import '../ble/ble_constants.dart';
import '../ble/ble_models.dart';
import 'ble_onboarding_controller.dart';
import 'ble_onboarding_state.dart';
import 'wifi_provisioning_models.dart';

class BleOnboardingScreen extends StatefulWidget {
  const BleOnboardingScreen({
    required this.controller,
    required this.onCompleted,
    super.key,
  });

  final BleOnboardingController controller;
  final Future<void> Function() onCompleted;

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
  Type? _lastStateType;
  bool _completionRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.controller.checkAvailability();
    });
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
        _requestCompletionIfReady(state);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Додати контролер',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            const SizedBox(height: 16),
            _ControllerAccessPanel(
              state: state,
              onBootstrap: widget.controller.bootstrapControllerAccess,
              onBackToWifi: widget.controller.returnToWifiProvisioning,
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

    final stateType = state.runtimeType;
    final shouldClearPassword = _lastStateType != stateType &&
        (state is SavingWifiSettings ||
            state is WaitingForControllerReboot ||
            state is ReconnectingAfterReboot ||
            state is ReconnectAfterRebootBlocked ||
            state is AccessSetupReady ||
            state is ReadingControllerAccess ||
            state is CheckingLocalHttpsAccess ||
            state is ControllerIpPending ||
            state is ControllerAccessFailed ||
            state is ControllerAccessReady);
    if (shouldClearPassword) {
      _passwordController.clear();
    }
    _lastStateType = stateType;
  }

  void _requestCompletionIfReady(BleOnboardingState state) {
    if (state is! ControllerAccessReady) {
      _completionRequested = false;
      return;
    }
    if (_completionRequested) {
      return;
    }
    _completionRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await widget.onCompleted();
    });
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
                  if (state.bleError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.bleError!.technicalReason,
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
    return switch (state) {
      CheckingBluetooth() => (
          'Перевірка Bluetooth',
          'Перевіряємо доступність Bluetooth і дозволи.',
          Icons.bluetooth,
        ),
      BluetoothUnavailable(:final availability) => switch (availability) {
          BleAvailability.permissionRequired => (
              'Потрібен дозвіл Bluetooth',
              'Надайте дозвіл Bluetooth, щоб знайти контролер поливу.',
              Icons.lock_outline,
            ),
          BleAvailability.bluetoothDisabled => (
              'Bluetooth вимкнено',
              'Увімкніть Bluetooth перед пошуком контролера.',
              Icons.bluetooth_disabled,
            ),
          BleAvailability.ready => (
              'Готово до пошуку',
              'Запустіть пошук, щоб знайти контролер поливу.',
              Icons.bluetooth,
            ),
        },
      ReadyToScan(:final error) => error == null
          ? (
              'Готово до пошуку',
              'Запустіть пошук, щоб знайти контролер поливу.',
              Icons.bluetooth,
            )
          : (
              'Пошук не запущено',
              error.message,
              Icons.error_outline,
            ),
      DiscoveringDevices() => (
          'Пошук',
          'Шукаємо поблизу контролери поливу.',
          Icons.radar,
        ),
      DeviceSelected(:final error) => error == null
          ? (
              'Контролер вибрано',
              'Підключіться, щоб почати сполучення.',
              Icons.bluetooth_searching,
            )
          : (
              'Помилка підключення',
              error.message,
              Icons.error_outline,
            ),
      ConnectingDevice() => (
          'Підключення',
          'Відкриваємо BLE-з\'єднання з вибраним контролером.',
          Icons.sync,
        ),
      AwaitingPairingPasskey(:final error) => error == null
          ? (
              'Потрібне сполучення',
              'Підтвердьте 6-значний код у системному діалозі сполучення.',
              Icons.pin,
            )
          : (
              'Помилка сполучення',
              error.message,
              Icons.error_outline,
            ),
      PairingInProgress() => (
          'Сполучення',
          'Перевіряємо захищений BLE-сервіс і характеристики.',
          Icons.password,
        ),
      ReadingWifiSettings() => (
          'Читання Wi-Fi',
          'Читаємо поточну Wi-Fi мережу контролера.',
          Icons.wifi,
        ),
      WifiCredentialsFormReady() => (
          'Wi-Fi контролера',
          'Введіть дані Wi-Fi мережі і збережіть їх у контролер.',
          Icons.wifi,
        ),
      SavingWifiSettings() => (
          'Збереження Wi-Fi',
          'Записуємо Wi-Fi налаштування через BLE.',
          Icons.save,
        ),
      WaitingForControllerReboot() => (
          'Перезавантаження контролера',
          'Контролер прийняв налаштування і перезавантажується.',
          Icons.restart_alt,
        ),
      ReconnectingAfterReboot(:final attempt) => (
          'Повторне підключення',
          'Відновлюємо BLE-з\'єднання після перезавантаження. Спроба $attempt.',
          Icons.sync,
        ),
      ReconnectAfterRebootBlocked(:final error) => (
          'Повторне підключення не виконано',
          error.message,
          Icons.error_outline,
        ),
      AccessSetupReady() => (
          'Wi-Fi збережено',
          'Наступний крок - читання IP-адреси та токена доступу.',
          Icons.check_circle_outline,
        ),
      ReadingControllerAccess(:final ipAddress) => (
          'Читання доступу',
          ipAddress == null
              ? 'Читаємо IP-адресу контролера через BLE.'
              : 'IP-адресу отримано: $ipAddress. Читаємо token доступу.',
          Icons.vpn_key,
        ),
      CheckingLocalHttpsAccess(:final ipAddress) => (
          'Перевірка HTTPS',
          'Перевіряємо локальний HTTPS API контролера за адресою $ipAddress.',
          Icons.https,
        ),
      ControllerIpPending(:final error) => (
          'IP-адреса очікується',
          error.message,
          Icons.hourglass_empty,
        ),
      ControllerAccessFailed(:final error) => (
          'Доступ не перевірено',
          error.message,
          Icons.error_outline,
        ),
      ControllerAccessReady(:final ipAddress) => (
          'Контролер доступний',
          'Локальний HTTPS API перевірено за адресою $ipAddress.',
          Icons.check_circle,
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
    return Row(
      children: [
        if (state
            case BluetoothUnavailable(
              availability: BleAvailability.permissionRequired
            ))
          FilledButton.icon(
            onPressed: onRequestPermissions,
            icon: const Icon(Icons.lock_open),
            label: const Text('Дозволити Bluetooth'),
          )
        else
          FilledButton.icon(
            onPressed: _canScan ? onScan : null,
            icon: const Icon(Icons.search),
            label: Text(state.devices.isEmpty ? 'Шукати' : 'Шукати знову'),
          ),
      ],
    );
  }

  bool get _canScan {
    return state is ReadyToScan || state is DeviceSelected;
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
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    if (state.devices.isEmpty) {
      final message = state is DiscoveringDevices
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

  bool get _shouldShow {
    return state is ReadyToScan ||
        state is DiscoveringDevices ||
        state is DeviceSelected ||
        state is ConnectingDevice ||
        state is AwaitingPairingPasskey ||
        state is PairingInProgress;
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
    final shouldShow = switch (state) {
      DeviceSelected() ||
      ConnectingDevice() ||
      AwaitingPairingPasskey() ||
      PairingInProgress() =>
        true,
      _ => false,
    };
    if (!shouldShow) return const SizedBox.shrink();

    final canConnect = state is DeviceSelected;
    final canPair = state is AwaitingPairingPasskey;

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
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    final busy = state is ReadingWifiSettings ||
        state is SavingWifiSettings ||
        state is WaitingForControllerReboot ||
        state is ReconnectingAfterReboot;
    final formReady = state is WifiCredentialsFormReady;
    final openNetwork = state.wifiCredentials.openNetwork;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wi-Fi контролера',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
          enabled: formReady,
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
          onChanged: formReady ? onOpenNetworkChanged : null,
          title: const Text('Відкрита мережа без пароля'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          enabled: formReady && !openNetwork,
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
              onPressed: formReady ? onReadCurrentSettings : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Прочитати з контролера'),
            ),
            OutlinedButton.icon(
              onPressed: formReady ? onUsePhoneWifi : null,
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
        if (state is ReconnectAfterRebootBlocked) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetryReconnect,
            icon: const Icon(Icons.replay),
            label: const Text('Спробувати ще раз'),
          ),
        ],
      ],
    );
  }

  bool get _shouldShow {
    return state is ReadingWifiSettings ||
        state is WifiCredentialsFormReady ||
        state is SavingWifiSettings ||
        state is WaitingForControllerReboot ||
        state is ReconnectingAfterReboot ||
        state is ReconnectAfterRebootBlocked;
  }
}

class _ControllerAccessPanel extends StatelessWidget {
  const _ControllerAccessPanel({
    required this.state,
    required this.onBootstrap,
    required this.onBackToWifi,
  });

  final BleOnboardingState state;
  final VoidCallback onBootstrap;
  final VoidCallback onBackToWifi;

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    final busy =
        state is ReadingControllerAccess || state is CheckingLocalHttpsAccess;
    final canRetry = state is AccessSetupReady ||
        state is ControllerIpPending ||
        state is ControllerAccessFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Доступ до контролера',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _AccessStatusRow(
          icon: Icons.router,
          label: 'IP-адреса',
          value: state.controllerIpAddress ?? 'Ще не прочитано',
        ),
        const SizedBox(height: 8),
        _AccessStatusRow(
          icon: Icons.vpn_key,
          label: 'Token доступу',
          value: _tokenStatus,
        ),
        const SizedBox(height: 8),
        _AccessStatusRow(
          icon: Icons.https,
          label: 'HTTPS API',
          value: _httpsStatus,
        ),
        if (state.controllerAccessError != null) ...[
          const SizedBox(height: 12),
          Text(
            state.controllerAccessError!.technicalReason,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: canRetry ? onBootstrap : null,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(state is AccessSetupReady
                  ? 'Прочитати IP і token'
                  : 'Повторити читання'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onBackToWifi,
              icon: const Icon(Icons.wifi),
              label: const Text('Повернутися до Wi-Fi'),
            ),
          ],
        ),
        if (state is ControllerAccessReady) ...[
          const SizedBox(height: 12),
          const Text('Можна переходити до базового налаштування системи.'),
        ],
      ],
    );
  }

  String get _tokenStatus {
    return switch (state) {
      ReadingControllerAccess(:final ipAddress) =>
        ipAddress == null ? 'Очікує IP-адресу' : 'Читаємо через BLE',
      CheckingLocalHttpsAccess() ||
      ControllerIpPending() ||
      ControllerAccessReady() =>
        'Збережено в захищеному сховищі',
      ControllerAccessFailed(:final error)
          when error.kind == ControllerAccessFailureKind.tokenInvalid =>
        'Контролер відхилив token',
      ControllerAccessFailed() => 'Прочитано, потрібна повторна перевірка',
      _ => 'Ще не прочитано',
    };
  }

  String get _httpsStatus {
    return switch (state) {
      CheckingLocalHttpsAccess() => 'Перевіряємо GET /api/settings',
      ControllerAccessReady() => 'Перевірено',
      ControllerIpPending() => 'Очікує IP-адресу Wi-Fi',
      ControllerAccessFailed(:final error) => switch (error.kind) {
          ControllerAccessFailureKind.tlsCertificate =>
            'Помилка TLS/fingerprint',
          ControllerAccessFailureKind.tokenInvalid => 'Помилка 401',
          ControllerAccessFailureKind.networkUnavailable ||
          ControllerAccessFailureKind.timeout =>
            'Timeout або мережа недоступна',
          ControllerAccessFailureKind.controllerUnavailable =>
            'Контролер недоступний',
          ControllerAccessFailureKind.ipPending => 'Очікує IP-адресу Wi-Fi',
          ControllerAccessFailureKind.unexpectedResponse =>
            'Неочікувана відповідь',
        },
      _ => 'Ще не перевірено',
    };
  }

  bool get _shouldShow {
    return state is AccessSetupReady ||
        state is ReadingControllerAccess ||
        state is CheckingLocalHttpsAccess ||
        state is ControllerIpPending ||
        state is ControllerAccessFailed ||
        state is ControllerAccessReady;
  }
}

class _AccessStatusRow extends StatelessWidget {
  const _AccessStatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$label: $value'),
        ),
      ],
    );
  }
}
