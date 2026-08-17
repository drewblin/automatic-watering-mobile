import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_controller.dart';
import 'app/app_startup_service.dart';
import 'app/app_state_store.dart';
import 'app/automatic_watering_app.dart';
import 'app/onboarding_app_service.dart';
import 'features/ble/flutter_reactive_ble_service.dart';
import 'features/controller_settings/controller_settings_repository.dart';
import 'features/controller_settings/controller_settings_save_controller.dart';
import 'features/home/home_dashboard_controller.dart';
import 'features/local_controller/diagnostics_log.dart';
import 'features/local_controller/local_controller_api_client.dart';
import 'features/onboarding/ble_onboarding_controller.dart';
import 'features/onboarding/phone_wifi_service.dart';
import 'features/service_console/service_console_dependencies.dart';
import 'storage/local_watering_hub_storage.dart';
import 'storage/secure_watering_hub_token_storage.dart';

Future<void> main() async {
  final fatalError = ValueNotifier<Object?>(null);

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        fatalError.value = details.exception;
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        fatalError.value = error;
        return true;
      };

      final preferences = await SharedPreferences.getInstance();
      final wateringHubStorage = SharedPreferencesWateringHubStorage(
        preferences,
      );
      const tokenStorage = SecureWateringHubTokenStorage(
        FlutterSecureStorage(),
      );
      final diagnosticsLog = InMemoryDiagnosticsLog();
      final localControllerApiClient = HttpLocalControllerApiClient(
        httpClient: HttpLocalControllerApiClient.createPinnedHttpClient(),
        diagnosticsLog: diagnosticsLog,
      );
      final controllerSettingsRepository = ControllerSettingsRepository(
        apiClient: localControllerApiClient,
      );
      final stateStore = AppStateStore();
      final startupService = AppStartupService(
        stateStore: stateStore,
        wateringHubStorage: wateringHubStorage,
        tokenStorage: tokenStorage,
        controllerSettingsRepository: controllerSettingsRepository,
        diagnosticsLog: diagnosticsLog,
      );
      final onboardingService = OnboardingAppService(
        stateStore: stateStore,
        wateringHubStorage: wateringHubStorage,
        tokenStorage: tokenStorage,
      );
      final appController = AppController(
        stateStore: stateStore,
        startupService: startupService,
        serviceConsoleDependencies: ServiceConsoleDependencies(
          diagnosticsLog: diagnosticsLog,
        ),
        settingsSaveController: ControllerSettingsSaveController(
          stateStore: stateStore,
          repository: controllerSettingsRepository,
        ),
        homeDashboardController: HomeDashboardController(
          stateStore: stateStore,
          settingsRepository: controllerSettingsRepository,
          apiClient: localControllerApiClient,
        ),
      );
      final bleOnboardingController = BleOnboardingController(
        bleService: FlutterReactiveBleService(),
        phoneWifiService: PluginPhoneWifiService(),
        onboardingStorage: onboardingService,
        localControllerApiClient: localControllerApiClient,
        diagnosticsLog: diagnosticsLog,
      );

      runApp(
        AutomaticWateringApp(
          appController: appController,
          bleOnboardingController: bleOnboardingController,
          fatalErrorListenable: fatalError,
        ),
      );
    },
    (error, stackTrace) {
      fatalError.value = error;
    },
  );
}
