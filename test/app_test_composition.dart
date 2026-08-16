import 'package:automatic_watering_mobile/app/app_controller.dart';
import 'package:automatic_watering_mobile/app/app_startup_service.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/app/onboarding_app_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_save_controller.dart';
import 'package:automatic_watering_mobile/features/home/home_dashboard_controller.dart';
import 'package:automatic_watering_mobile/features/local_controller/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

class TestAppComposition {
  TestAppComposition({
    InMemoryWateringHubStorage? wateringHubStorage,
    InMemoryWateringHubTokenStorage? tokenStorage,
    InMemoryDiagnosticsLog? diagnosticsLog,
    required LocalControllerApiClient localControllerApiClient,
  })  : wateringHubStorage = wateringHubStorage ?? InMemoryWateringHubStorage(),
        tokenStorage = tokenStorage ?? InMemoryWateringHubTokenStorage(),
        diagnosticsLog = diagnosticsLog ?? InMemoryDiagnosticsLog() {
    final stateStore = AppStateStore();
    final controllerSettingsRepository = ControllerSettingsRepository(
      apiClient: localControllerApiClient,
    );
    final startup = AppStartupService(
      stateStore: stateStore,
      wateringHubStorage: this.wateringHubStorage,
      tokenStorage: this.tokenStorage,
      controllerSettingsRepository: controllerSettingsRepository,
      diagnosticsLog: this.diagnosticsLog,
    );
    onboarding = OnboardingAppService(
      stateStore: stateStore,
      wateringHubStorage: this.wateringHubStorage,
      tokenStorage: this.tokenStorage,
    );
    appController = AppController(
      stateStore: stateStore,
      startupService: startup,
      settingsSaveController: ControllerSettingsSaveController(
        stateStore: stateStore,
        repository: controllerSettingsRepository,
        rebootDelay: Duration.zero,
        reconnectAttemptDelay: Duration.zero,
        reconnectTimeout: const Duration(seconds: 1),
      ),
      homeDashboardController: HomeDashboardController(
        stateStore: stateStore,
        settingsRepository: controllerSettingsRepository,
        apiClient: localControllerApiClient,
      ),
    );
  }

  final InMemoryWateringHubStorage wateringHubStorage;
  final InMemoryWateringHubTokenStorage tokenStorage;
  final InMemoryDiagnosticsLog diagnosticsLog;
  late final AppController appController;
  late final OnboardingAppService onboarding;
}
