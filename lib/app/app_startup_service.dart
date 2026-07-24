import '../features/controller_settings/controller_settings_repository.dart';
import '../features/controller_settings/device_objects.dart';
import '../features/controller_settings/settings_response_data.dart';
import '../features/local_controller/local_controller_api_client.dart';
import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';
import '../features/watering_hubs/watering_hub_state.dart';
import '../storage/watering_hub_storage.dart';
import 'app_state.dart';
import 'app_state_store.dart';
import 'fatal_app_exception.dart';

class AppStartupService {
  const AppStartupService({
    required AppStateStore stateStore,
    required WateringHubStorage wateringHubStorage,
    required WateringHubTokenStorage tokenStorage,
    required ControllerSettingsRepository controllerSettingsRepository,
  })  : _stateStore = stateStore,
        _wateringHubStorage = wateringHubStorage,
        _tokenStorage = tokenStorage,
        _controllerSettingsRepository = controllerSettingsRepository;

  final AppStateStore _stateStore;
  final WateringHubStorage _wateringHubStorage;
  final WateringHubTokenStorage _tokenStorage;
  final ControllerSettingsRepository _controllerSettingsRepository;

  Future<void> initialize() async {
    final currentHub = _stateStore.state.activeWateringHub;
    _stateStore.setState(
      AppState.loading(
        activeWateringHub: currentHub,
        connectionState: currentHub == null
            ? WateringHubConnectionState.noDevice
        // todo такого кейсу не має бути
            : WateringHubConnectionState.checkingLocalHttps,
      ),
    );

    final hubWithoutToken = await _wateringHubStorage.readActiveWateringHub();
    if (hubWithoutToken == null) {
      _stateStore.setState(
        AppState.readyForOnboarding(
          activeWateringHub: null,
          connectionState: WateringHubConnectionState.noDevice,
        ),
      );
      return;
    }

    final token = await _tokenStorage.readApiAccessToken(hubWithoutToken.id);
    final hub = hubWithoutToken.copyWith(apiAccessToken: token);
    if (!hub.isOnboardingComplete) {
      _stateStore.setState(
        AppState.readyForOnboarding(
          activeWateringHub: hub,
          connectionState: WateringHubConnectionState.offline,
        ),
      );
      return;
    }

    final planSchema = await _wateringHubStorage.readPlanSchema(hub.id);
    await _loadReadyHub(
      hub: hub,
      activePlanSchema: planSchema,
    );
  }

  Future<void> _loadReadyHub({
    required WateringHub hub,
    required PlanSchema? activePlanSchema,
  }) async {
    _stateStore.setState(
      AppState.loading(
        activeWateringHub: hub,
        connectionState: WateringHubConnectionState.checkingLocalHttps,
      ),
    );

    final settings = await _loadSettings(hub);
    _stateStore.setState(
      AppState.readyWithHub(
        activeWateringHub: hub,
        activePlanSchema: activePlanSchema,
        settings: settings,
        deviceObjects: buildDeviceObjects(
          wateringHubId: hub.id,
          settings: settings.settings,
        ),
      ),
    );
  }

  Future<SettingsResponseData> _loadSettings(WateringHub hub) async {
    try {
      return await _controllerSettingsRepository.syncSettings(hub);
    } catch (error) {
      _stateStore.setState(
        _stateStore.state.copyWith(
          connectionState: _connectionStateForSettingsLoadError(error),
        ),
      );
      throw FatalAppException(
        'Не вдалося завантажити налаштування контролера',
        error,
      );
    }
  }

  WateringHubConnectionState _connectionStateForSettingsLoadError(
    Object error,
  ) {
    if (error is LocalControllerApiException) {
      return switch (error.kind) {
        LocalControllerApiErrorKind.tokenInvalid =>
          WateringHubConnectionState.tokenInvalid,
        LocalControllerApiErrorKind.controllerUnavailable ||
        LocalControllerApiErrorKind.networkUnavailable =>
          WateringHubConnectionState.offline,
        LocalControllerApiErrorKind.tlsCertificate =>
          WateringHubConnectionState.httpsUnavailable,
        LocalControllerApiErrorKind.unexpectedResponse =>
          WateringHubConnectionState.httpsUnavailable,
      };
    }
    return WateringHubConnectionState.httpsUnavailable;
  }
}
