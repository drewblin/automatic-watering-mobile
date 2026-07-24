import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/status_panel.dart';
import '../controller_settings/controller_settings_screen.dart';
import '../onboarding/ble_onboarding_controller.dart';
import '../onboarding/ble_onboarding_screen.dart';
import '../watering_hubs/watering_hub_connection_state_label.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.state,
    required this.bleOnboardingController,
    super.key,
  });

  final AppState state;
  final BleOnboardingController bleOnboardingController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Автоматичний полив')),
      body: Center(
        child: switch (state.startupStatus) {
          AppStartupStatus.initializing => const CircularProgressIndicator(),
          AppStartupStatus.onboarding => BleOnboardingScreen(
              controller: bleOnboardingController,
            ),
          AppStartupStatus.ready => _ReadyStatePanel(
              state: state,
            ),
        },
      ),
    );
  }
}

class _ReadyStatePanel extends StatelessWidget {
  const _ReadyStatePanel({
    required this.state,
  });

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hub = state.readyWateringHub;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPanel(
            title: hub.displayName,
            subtitle: 'Стан контролера: ${state.connectionState.label}',
          ),
          const SizedBox(height: 16),
          _ReadyHubActions(state: state),
        ],
      ),
    );
  }
}

class _ReadyHubActions extends StatelessWidget {
  const _ReadyHubActions({
    required this.state,
  });

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.readySettings;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ControllerSettingsScreen(
                  settings: settings,
                  deviceObjects: state.deviceObjects,
                  connectionState: state.connectionState,
                ),
              ),
            );
          },
          icon: const Icon(Icons.tune),
          label: const Text('Налаштування контролера'),
        ),
      ],
    );
  }
}
