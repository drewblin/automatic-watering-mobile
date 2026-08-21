import '../features/controller_settings/controller_settings_repository.dart';
import '../features/controller_settings/device_objects.dart';
import '../features/controller_settings/settings_response_data.dart';
import '../features/diagnostics/diagnostics_log.dart';
import '../features/local_controller/local_controller_api_client.dart';
import '../features/local_controller/mdns_controller_resolver.dart';
import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';
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
    required MdnsControllerResolver mdnsControllerResolver,
    required DiagnosticsLog diagnosticsLog,
  })  : _stateStore = stateStore,
        _wateringHubStorage = wateringHubStorage,
        _tokenStorage = tokenStorage,
        _controllerSettingsRepository = controllerSettingsRepository,
        _mdnsControllerResolver = mdnsControllerResolver,
        _diagnosticsLog = diagnosticsLog;

  final AppStateStore _stateStore;
  final WateringHubStorage _wateringHubStorage;
  final WateringHubTokenStorage _tokenStorage;
  final ControllerSettingsRepository _controllerSettingsRepository;
  final MdnsControllerResolver _mdnsControllerResolver;
  final DiagnosticsLog _diagnosticsLog;

  Future<void> initialize() async {
    _stateStore.setState(AppState.loading());

    final WateringHub? hubWithoutToken;
    try {
      hubWithoutToken = await _wateringHubStorage.readActiveWateringHub();
    } on WateringHubStorageCorruptionException catch (error) {
      await _resetCorruptedPersistence(error);
      return;
    }
    if (hubWithoutToken == null) {
      _stateStore.setState(
        AppState.readyForOnboarding(
          activeWateringHub: null,
        ),
      );
      return;
    }

    final token = await _tokenStorage.readApiAccessToken(hubWithoutToken.id);
    final hub = hubWithoutToken.copyWith(apiAccessToken: token);
    _stateStore.setState(AppState.loading(activeWateringHub: hub));
    if (!hub.isOnboardingComplete || hub.readyAccess == null) {
      _stateStore.setState(
        AppState.readyForOnboarding(
          activeWateringHub: hub,
        ),
      );
      return;
    }

    final PlanSchema? planSchema;
    try {
      planSchema = await _wateringHubStorage.readPlanSchema(hub.id);
    } on WateringHubStorageCorruptionException catch (error) {
      await _resetCorruptedPersistence(error);
      return;
    }
    final resolvedHub = await _resolveStartupAccess(hub);
    if (!identical(resolvedHub, hub)) {
      _stateStore.setState(AppState.loading(activeWateringHub: resolvedHub));
    }
    await _loadReadyHub(
      hub: resolvedHub,
      activePlanSchema: planSchema,
    );
  }

  Future<WateringHub> _resolveStartupAccess(WateringHub hub) async {
    final resolvedIpAddress = await _mdnsControllerResolver.resolve(
      hostname: hub.lastKnownHostname,
      localHostname: hub.lastKnownHostname,
    );
    if (resolvedIpAddress == null) {
      recordDiagnosticsIssue(
        diagnosticsLog: _diagnosticsLog,
        message: 'Використовуємо збережену IP-адресу контролера.',
        details:
            'ipAddress=${hub.lastKnownIpAddress}; host=${hub.lastKnownHostname}',
      );
      return hub;
    }
    if (resolvedIpAddress == hub.lastKnownIpAddress) {
      return hub;
    }
    final updatedHub = hub.copyWith(
      lastKnownIpAddress: resolvedIpAddress,
      updatedAt: DateTime.now().toUtc(),
    );
    await _wateringHubStorage.saveActiveWateringHub(updatedHub);
    return updatedHub;
  }

  Future<void> _loadReadyHub({
    required WateringHub hub,
    required PlanSchema? activePlanSchema,
  }) async {
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
      final access = hub.readyAccess;
      if (access == null) {
        throw const LocalControllerApiException();
      }
      return await _controllerSettingsRepository.syncSettings(access);
    } catch (error) {
      throw FatalAppException(
        'Не вдалося завантажити налаштування контролера',
        error,
      );
    }
  }

  Future<void> _resetCorruptedPersistence(
    WateringHubStorageCorruptionException error,
  ) async {
    recordDiagnosticsIssue(
      diagnosticsLog: _diagnosticsLog,
      message:
          'Пошкоджені збережені дані контролера. Повертаємося до onboarding.',
      error: error.sourceError,
      details: error.toString(),
    );

    final wateringHubId = error.wateringHubId;
    if (wateringHubId != null) {
      // todo Подумати, щоб не чистити. Коли onboarding навчиться працювати "частково"
      await _wateringHubStorage.clearWateringHubProfile(wateringHubId);
      await _tokenStorage.deleteApiAccessToken(wateringHubId);
    }

    _stateStore.setState(
      AppState.readyForOnboarding(activeWateringHub: null),
    );
  }
}
