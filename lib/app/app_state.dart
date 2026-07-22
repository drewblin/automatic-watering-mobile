import 'package:flutter/foundation.dart';

import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';
import '../features/watering_hubs/watering_hub_state.dart';
import '../storage/watering_hub_storage.dart';

enum AppStartupStatus {
  initializing,
  ready,
  failed,
}

class AppState {
  const AppState({
    required this.startupStatus,
    required this.activeWateringHub,
    required this.activePlanSchema,
    required this.connectionState,
    required this.lastError,
  });

  factory AppState.initial() {
    return const AppState(
      startupStatus: AppStartupStatus.initializing,
      activeWateringHub: null,
      activePlanSchema: null,
      connectionState: WateringHubConnectionState.noDevice,
      lastError: null,
    );
  }

  final AppStartupStatus startupStatus;
  final WateringHub? activeWateringHub;
  final PlanSchema? activePlanSchema;
  final WateringHubConnectionState connectionState;
  final Object? lastError;

  AppState copyWith({
    AppStartupStatus? startupStatus,
    WateringHub? activeWateringHub,
    PlanSchema? activePlanSchema,
    WateringHubConnectionState? connectionState,
    Object? lastError,
    bool clearWateringHub = false,
    bool clearPlanSchema = false,
    bool clearLastError = false,
  }) {
    return AppState(
      startupStatus: startupStatus ?? this.startupStatus,
      activeWateringHub:
          clearWateringHub ? null : activeWateringHub ?? this.activeWateringHub,
      activePlanSchema:
          clearPlanSchema ? null : activePlanSchema ?? this.activePlanSchema,
      connectionState: connectionState ?? this.connectionState,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}

class AppController extends ChangeNotifier {
  AppController({
    required WateringHubStorage wateringHubStorage,
    required WateringHubTokenStorage tokenStorage,
  })  : _wateringHubStorage = wateringHubStorage,
        _tokenStorage = tokenStorage;

  final WateringHubStorage _wateringHubStorage;
  final WateringHubTokenStorage _tokenStorage;

  AppState _state = AppState.initial();

  AppState get state => _state;

  Future<void> initialize() async {
    _state = AppState.initial();
    notifyListeners();

    try {
      final hubWithoutToken = await _wateringHubStorage.readActiveWateringHub();
      if (hubWithoutToken == null) {
        _state = _state.copyWith(
          startupStatus: AppStartupStatus.ready,
          connectionState: WateringHubConnectionState.noDevice,
          clearWateringHub: true,
          clearPlanSchema: true,
          clearLastError: true,
        );
        notifyListeners();
        return;
      }

      final token = await _tokenStorage.readApiAccessToken(hubWithoutToken.id);
      final hub = hubWithoutToken.copyWith(apiAccessToken: token);
      final planSchema = await _wateringHubStorage.readPlanSchema(hub.id);

      _state = _state.copyWith(
        startupStatus: AppStartupStatus.ready,
        activeWateringHub: hub,
        activePlanSchema: planSchema,
        connectionState: WateringHubConnectionState.offline,
        clearLastError: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        startupStatus: AppStartupStatus.failed,
        connectionState: WateringHubConnectionState.offline,
        lastError: error,
      );
      notifyListeners();
    }
  }

  Future<void> saveActiveWateringHub(WateringHub hub) async {
    await _wateringHubStorage.saveActiveWateringHub(hub);
    _state = _state.copyWith(
      startupStatus: AppStartupStatus.ready,
      activeWateringHub: hub,
      connectionState: WateringHubConnectionState.offline,
      clearLastError: true,
    );
    notifyListeners();
  }

  Future<void> saveControllerAccess({
    required WateringHub hub,
    required String apiAccessToken,
  }) async {
    final hubWithoutPlainToken = WateringHub(
      id: hub.id,
      displayName: hub.displayName,
      bleDeviceId: hub.bleDeviceId,
      lastKnownIpAddress: hub.lastKnownIpAddress,
      apiAccessToken: null,
      serverDeviceId: hub.serverDeviceId,
      onboardingCompletedAt: hub.onboardingCompletedAt,
      createdAt: hub.createdAt,
      updatedAt: hub.updatedAt,
    );
    final hubWithToken = WateringHub(
      id: hub.id,
      displayName: hub.displayName,
      bleDeviceId: hub.bleDeviceId,
      lastKnownIpAddress: hub.lastKnownIpAddress,
      apiAccessToken: apiAccessToken,
      serverDeviceId: hub.serverDeviceId,
      onboardingCompletedAt: hub.onboardingCompletedAt,
      createdAt: hub.createdAt,
      updatedAt: hub.updatedAt,
    );
    await _wateringHubStorage.saveActiveWateringHub(hubWithoutPlainToken);
    await _tokenStorage.saveApiAccessToken(
      wateringHubId: hub.id,
      token: apiAccessToken,
    );
    _state = _state.copyWith(
      startupStatus: AppStartupStatus.ready,
      activeWateringHub: hubWithToken,
      connectionState: WateringHubConnectionState.offline,
      clearLastError: true,
    );
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final hub = _state.activeWateringHub;
    if (hub == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    final completedHub = hub.copyWith(
      onboardingCompletedAt: now,
      updatedAt: now,
    );
    final completedHubWithoutPlainToken = WateringHub(
      id: completedHub.id,
      displayName: completedHub.displayName,
      bleDeviceId: completedHub.bleDeviceId,
      lastKnownIpAddress: completedHub.lastKnownIpAddress,
      apiAccessToken: null,
      serverDeviceId: completedHub.serverDeviceId,
      onboardingCompletedAt: completedHub.onboardingCompletedAt,
      createdAt: completedHub.createdAt,
      updatedAt: completedHub.updatedAt,
    );
    await _wateringHubStorage.saveActiveWateringHub(
      completedHubWithoutPlainToken,
    );
    _state = _state.copyWith(
      activeWateringHub: completedHub,
      connectionState: WateringHubConnectionState.online,
      clearLastError: true,
    );
    notifyListeners();
  }

  void setConnectionState(WateringHubConnectionState connectionState) {
    _state = _state.copyWith(
      connectionState: connectionState,
      clearLastError: true,
    );
    notifyListeners();
  }
}
