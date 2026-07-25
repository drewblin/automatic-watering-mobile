import 'package:flutter/material.dart';

import '../ble/ble_models.dart';
import 'ble_onboarding_state.dart';

class BleOnboardingStateBanner extends StatelessWidget {
  const BleOnboardingStateBanner({required this.state, super.key});

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
          'Наступний крок - читання даних доступу контролера.',
          Icons.check_circle_outline,
        ),
      ReadingControllerAccess(:final ipAddress) => (
          'Читання доступу',
          ipAddress == null
              ? 'Читаємо IP-адресу контролера через BLE.'
              : 'IP-адресу отримано: $ipAddress. Читаємо дані доступу.',
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
