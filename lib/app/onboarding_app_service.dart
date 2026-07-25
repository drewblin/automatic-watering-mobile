import '../features/watering_hubs/watering_hub.dart';
import '../storage/watering_hub_storage.dart';
import 'app_state.dart';
import 'app_state_store.dart';

class OnboardingAppService {
  const OnboardingAppService({
    required AppStateStore stateStore,
    required WateringHubStorage wateringHubStorage,
    required WateringHubTokenStorage tokenStorage,
  })  : _stateStore = stateStore,
        _wateringHubStorage = wateringHubStorage,
        _tokenStorage = tokenStorage;

  final AppStateStore _stateStore;
  final WateringHubStorage _wateringHubStorage;
  final WateringHubTokenStorage _tokenStorage;

  Future<void> saveActiveWateringHub(WateringHub hub) async {
    await _wateringHubStorage.saveActiveWateringHub(hub);
  }

  Future<WateringHub> saveControllerAccess({
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
    return hubWithToken;
  }

  Future<void> completeOnboarding(WateringHub hub) async {
    final now = DateTime.now().toUtc();
    final completedHub = hub.copyWith(
      onboardingCompletedAt: now,
      updatedAt: now,
    );
    await _wateringHubStorage.saveActiveWateringHub(
      completedHub.copyWith(clearApiAccessToken: true),
    );

    _stateStore.setState(
      AppState.readyForOnboarding(
        activeWateringHub: completedHub,
      ),
    );
  }
}
