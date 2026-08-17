import 'package:flutter/material.dart';

import '../../app/app_header.dart';
import '../../app/app_state.dart';
import '../controller_settings/controller_settings_save_controller.dart';
import '../controller_settings/controller_settings_screen.dart';
import '../onboarding/ble_onboarding_controller.dart';
import '../onboarding/ble_onboarding_screen.dart';
import '../service_console/service_console_dependencies.dart';
import 'home_dashboard.dart';
import 'home_dashboard_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.state,
    required this.onOnboardingComplete,
    required this.serviceConsoleDependencies,
    required this.bleOnboardingController,
    required this.settingsSaveController,
    required this.homeDashboardController,
    super.key,
  });

  final AppState state;
  final Future<void> Function() onOnboardingComplete;
  final ServiceConsoleDependencies serviceConsoleDependencies;
  final BleOnboardingController bleOnboardingController;
  final ControllerSettingsSaveController settingsSaveController;
  final HomeDashboardController homeDashboardController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Автоматичний полив',
        serviceConsoleDependencies: serviceConsoleDependencies,
        actions: [
          if (state.startupStatus == AppStartupStatus.ready)
            IconButton(
              tooltip: 'Налаштування контролера',
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings),
            ),
        ],
      ),
      body: Center(
        child: switch (state.startupStatus) {
          AppStartupStatus.initializing => const CircularProgressIndicator(),
          AppStartupStatus.onboarding => BleOnboardingScreen(
              controller: bleOnboardingController,
              onCompleted: onOnboardingComplete,
            ),
          AppStartupStatus.ready => HomeDashboard(
              state: state,
              controller: homeDashboardController,
            ),
        },
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ControllerSettingsScreen(
          settings: state.readySettings,
          deviceObjects: state.deviceObjects,
          saveController: settingsSaveController,
          serviceConsoleDependencies: serviceConsoleDependencies,
        ),
      ),
    );
  }
}
