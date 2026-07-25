import 'package:automatic_watering_mobile/app/app_controller.dart';
import 'package:automatic_watering_mobile/app/app_startup_service.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/app/onboarding_app_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

class TestAppComposition {
  TestAppComposition({
    InMemoryWateringHubStorage? wateringHubStorage,
    InMemoryWateringHubTokenStorage? tokenStorage,
    required ControllerSettingsRepository controllerSettingsRepository,
  })  : wateringHubStorage = wateringHubStorage ?? InMemoryWateringHubStorage(),
        tokenStorage = tokenStorage ?? InMemoryWateringHubTokenStorage() {
    final stateStore = AppStateStore();
    final startup = AppStartupService(
      stateStore: stateStore,
      wateringHubStorage: this.wateringHubStorage,
      tokenStorage: this.tokenStorage,
      controllerSettingsRepository: controllerSettingsRepository,
    );
    onboarding = OnboardingAppService(
      stateStore: stateStore,
      wateringHubStorage: this.wateringHubStorage,
      tokenStorage: this.tokenStorage,
    );
    appController = AppController(
      stateStore: stateStore,
      startupService: startup,
    );
  }

  final InMemoryWateringHubStorage wateringHubStorage;
  final InMemoryWateringHubTokenStorage tokenStorage;
  late final AppController appController;
  late final OnboardingAppService onboarding;
}
