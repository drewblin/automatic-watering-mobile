import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/status_panel.dart';
import '../controller_settings/controller_settings_save_controller.dart';
import '../controller_settings/controller_settings_screen.dart';
import '../onboarding/ble_onboarding_controller.dart';
import '../onboarding/ble_onboarding_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.state,
    required this.onOnboardingComplete,
    required this.bleOnboardingController,
    required this.settingsSaveController,
    super.key,
  });

  final AppState state;
  final Future<void> Function() onOnboardingComplete;
  final BleOnboardingController bleOnboardingController;
  final ControllerSettingsSaveController settingsSaveController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Автоматичний полив')),
      body: Center(
        child: switch (state.startupStatus) {
          AppStartupStatus.initializing => const CircularProgressIndicator(),
          AppStartupStatus.onboarding => BleOnboardingScreen(
              controller: bleOnboardingController,
              onCompleted: onOnboardingComplete,
            ),
          AppStartupStatus.ready => _ReadyStatePanel(
              state: state,
              settingsSaveController: settingsSaveController,
            ),
        },
      ),
    );
  }
}

class _ReadyStatePanel extends StatelessWidget {
  const _ReadyStatePanel({
    required this.state,
    required this.settingsSaveController,
  });

  final AppState state;
  final ControllerSettingsSaveController settingsSaveController;

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
            subtitle: 'Контролер доступний',
          ),
          const SizedBox(height: 16),
          _ReadyHubActions(
            state: state,
            settingsSaveController: settingsSaveController,
          ),
        ],
      ),
    );
  }
}

class _ReadyHubActions extends StatelessWidget {
  const _ReadyHubActions({
    required this.state,
    required this.settingsSaveController,
  });

  final AppState state;
  final ControllerSettingsSaveController settingsSaveController;

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
                  saveController: settingsSaveController,
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
