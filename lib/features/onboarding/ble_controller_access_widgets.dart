import 'package:flutter/material.dart';

import 'ble_onboarding_state.dart';

class BleControllerAccessStep extends StatelessWidget {
  const BleControllerAccessStep({
    required this.state,
    required this.onBootstrap,
    required this.onBackToWifi,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onBootstrap;
  final VoidCallback onBackToWifi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Доступ до контролера',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _AccessDetails(state: state),
        const SizedBox(height: 12),
        switch (state) {
          AccessSetupReady() => _AccessProgressStatus(
              text: 'Починаємо читання даних доступу',
            ),
          ReadingControllerAccess() => _AccessProgressStatus(
              text: 'Читаємо дані доступу через BLE',
            ),
          CheckingLocalHttpsAccess() => _AccessProgressStatus(
              text: 'Перевіряємо локальний HTTPS доступ',
            ),
          ControllerIpPending() => _AccessActions(
              primaryLabel: 'Повторити читання',
              onPrimary: onBootstrap,
              onBackToWifi: onBackToWifi,
            ),
          ControllerAccessFailed() => _AccessActions(
              primaryLabel: 'Повторити читання',
              onPrimary: onBootstrap,
              onBackToWifi: onBackToWifi,
            ),
          ControllerAccessReady() => const Text(
              'Можна переходити до базового налаштування системи.',
            ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _AccessDetails extends StatelessWidget {
  const _AccessDetails({required this.state});

  final BleOnboardingState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccessStatusRow(
          icon: Icons.router,
          label: 'IP-адреса',
          value: state.controllerIpAddress ?? 'Ще не прочитано',
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
      ],
    );
  }

  String get _httpsStatus {
    return switch (state) {
      CheckingLocalHttpsAccess() => 'Перевіряємо локальний доступ',
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
}

class _AccessActions extends StatelessWidget {
  const _AccessActions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBackToWifi,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onBackToWifi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onPrimary,
          icon: const Icon(Icons.refresh),
          label: Text(primaryLabel),
        ),
        _BackToWifiButton(onPressed: onBackToWifi),
      ],
    );
  }
}

class _AccessProgressStatus extends StatelessWidget {
  const _AccessProgressStatus({required this.text});

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

class _BackToWifiButton extends StatelessWidget {
  const _BackToWifiButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.wifi),
      label: const Text('Повернутися до вибору Wi-Fi'),
    );
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
        Expanded(child: Text('$label: $value')),
      ],
    );
  }
}
