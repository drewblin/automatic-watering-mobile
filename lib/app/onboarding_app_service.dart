import '../features/watering_hubs/watering_hub.dart';
import '../features/watering_hubs/watering_hub_state.dart';
import '../storage/watering_hub_storage.dart';
import 'app_startup_service.dart';
import 'app_state.dart';
import 'app_state_store.dart';

class OnboardingAppService {
  const OnboardingAppService({
    required AppStateStore stateStore,
    required WateringHubStorage wateringHubStorage,
    required WateringHubTokenStorage tokenStorage,
    // todo не повинно бути залежності між сервісами
    required AppStartupService startupService,
  })  : _stateStore = stateStore,
        _wateringHubStorage = wateringHubStorage,
        _tokenStorage = tokenStorage,
        _startupService = startupService;

  final AppStateStore _stateStore;
  final WateringHubStorage _wateringHubStorage;
  final WateringHubTokenStorage _tokenStorage;
  final AppStartupService _startupService;

  WateringHub? get activeWateringHub => _stateStore.state.activeWateringHub;

  Future<void> saveActiveWateringHub(WateringHub hub) async {
    await _wateringHubStorage.saveActiveWateringHub(hub);
    _stateStore.setState(
      AppState.readyForOnboarding(
        activeWateringHub: hub,
        connectionState: WateringHubConnectionState.offline,
      ),
    );
  }

  Future<void> saveControllerAccess({
    required WateringHub hub,
    required String apiAccessToken,
  }) async {
    final hubWithoutPlainToken = hub.copyWith(clearApiAccessToken: true);
    final hubWithToken = hub.copyWith(apiAccessToken: apiAccessToken);
    await _wateringHubStorage.saveActiveWateringHub(hubWithoutPlainToken);
    await _tokenStorage.saveApiAccessToken(
      wateringHubId: hub.id,
      token: apiAccessToken,
    );
    _stateStore.setState(
      AppState.readyForOnboarding(
        activeWateringHub: hubWithToken,
        connectionState: WateringHubConnectionState.offline,
      ),
    );
  }

  Future<void> completeOnboarding() async {
    final hub = _stateStore.state.activeWateringHub;
    if (hub == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    final completedHub = hub.copyWith(
      onboardingCompletedAt: now,
      updatedAt: now,
    );
    await _wateringHubStorage.saveActiveWateringHub(
      completedHub.copyWith(clearApiAccessToken: true),
    );

    // todo взагалі це прибрати. після onboarding повертаємо на home-screen який направляє на appController
    await _startupService.initialize();
  }

  void setConnectionState(WateringHubConnectionState connectionState) {
    _stateStore.setState(
      _stateStore.state.copyWith(connectionState: connectionState),
    );
  }
}
