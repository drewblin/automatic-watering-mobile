import 'package:flutter/material.dart';

import 'ble_onboarding_state.dart';
import 'wifi_provisioning_models.dart';

class BleWifiProvisioningStep extends StatelessWidget {
  const BleWifiProvisioningStep({
    required this.state,
    required this.onUsePhoneWifi,
    required this.onReadCurrentSettings,
    required this.onSave,
    required this.onCredentialsChanged,
    required this.onRetryReconnect,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onUsePhoneWifi;
  final VoidCallback onReadCurrentSettings;
  final ValueChanged<WifiCredentials> onSave;
  final ValueChanged<WifiCredentials> onCredentialsChanged;
  final VoidCallback onRetryReconnect;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ReadingWifiSettings() => const _WifiProgressStatus(
          text: 'Читаємо поточну Wi-Fi мережу контролера',
        ),
      WifiCredentialsFormReady formState => _WifiCredentialsForm(
          state: formState,
          onUsePhoneWifi: onUsePhoneWifi,
          onReadCurrentSettings: onReadCurrentSettings,
          onSave: onSave,
          onCredentialsChanged: onCredentialsChanged,
        ),
      SavingWifiSettings() => const _WifiProgressStatus(
          text: 'Зберігаємо Wi-Fi налаштування на контролері',
        ),
      WaitingForControllerReboot() => const _WifiProgressStatus(
          text: 'Очікуємо перезапуск контролера',
        ),
      ReconnectingAfterReboot(:final attempt) => _WifiProgressStatus(
          text: 'Повторно підключаємось до контролера. Спроба $attempt',
        ),
      ReconnectAfterRebootBlocked() => _ReconnectBlockedActions(
          onRetryReconnect: onRetryReconnect,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _WifiCredentialsForm extends StatefulWidget {
  const _WifiCredentialsForm({
    required this.state,
    required this.onUsePhoneWifi,
    required this.onReadCurrentSettings,
    required this.onSave,
    required this.onCredentialsChanged,
  });

  final WifiCredentialsFormReady state;
  final VoidCallback onUsePhoneWifi;
  final VoidCallback onReadCurrentSettings;
  final ValueChanged<WifiCredentials> onSave;
  final ValueChanged<WifiCredentials> onCredentialsChanged;

  @override
  State<_WifiCredentialsForm> createState() => _WifiCredentialsFormState();
}

class _WifiCredentialsFormState extends State<_WifiCredentialsForm> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ssidController.text = widget.state.wifiCredentials.ssid;
  }

  @override
  void didUpdateWidget(_WifiCredentialsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousSsid = oldWidget.state.wifiCredentials.ssid;
    final nextSsid = widget.state.wifiCredentials.ssid;
    if (nextSsid.isNotEmpty && nextSsid != previousSsid) {
      _ssidController.text = nextSsid;
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final openNetwork = state.wifiCredentials.openNetwork;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Wi-Fi контролера',
            style: Theme.of(context).textTheme.titleMedium),
        if (state.wifiError != null) ...[
          const SizedBox(height: 8),
          Text(
            state.wifiError!.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _ssidController,
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
          onChanged: _setOpenNetwork,
          title: const Text('Відкрита мережа без пароля'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          enabled: !openNetwork,
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
              onPressed: widget.onReadCurrentSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('Прочитати з контролера'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onUsePhoneWifi,
              icon: const Icon(Icons.wifi),
              label: const Text('Використати поточну Wi-Fi мережу телефону'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saveWifiCredentials,
          icon: const Icon(Icons.save),
          label: const Text('Зберегти Wi-Fi налаштування'),
        ),
      ],
    );
  }

  void _saveWifiCredentials() => widget.onSave(_credentialsFromFields());

  void _setOpenNetwork(bool value) {
    widget.onCredentialsChanged(
      _credentialsFromFields().copyWith(
        password: value ? '' : _passwordController.text,
        openNetwork: value,
      ),
    );
    if (value) _passwordController.clear();
  }

  WifiCredentials _credentialsFromFields() {
    return WifiCredentials(
      ssid: _ssidController.text,
      password: _passwordController.text,
      openNetwork: widget.state.wifiCredentials.openNetwork,
    );
  }
}

class _WifiProgressStatus extends StatelessWidget {
  const _WifiProgressStatus({required this.text});

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

class _ReconnectBlockedActions extends StatelessWidget {
  const _ReconnectBlockedActions({required this.onRetryReconnect});

  final VoidCallback onRetryReconnect;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onRetryReconnect,
      icon: const Icon(Icons.replay),
      label: const Text('Спробувати ще раз'),
    );
  }
}
