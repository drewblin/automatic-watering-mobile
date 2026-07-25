import '../features/controller_settings/controller_settings.dart';
import '../features/controller_settings/device_objects.dart';
import '../features/controller_settings/settings_response_data.dart';
import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';

enum AppStartupStatus {
  initializing,
  onboarding,
  ready,
}

class AppState {
  const AppState({
    required this.startupStatus,
    required this.activeWateringHub,
    required this.activePlanSchema,
    required this.settings,
    required this.deviceObjects,
  });

  factory AppState.loading() {
    return AppState(
      startupStatus: AppStartupStatus.initializing,
      activeWateringHub: null,
      activePlanSchema: null,
      settings: null,
      deviceObjects: const [],
    );
  }

  factory AppState.readyForOnboarding({
    required WateringHub? activeWateringHub,
  }) {
    return AppState(
      startupStatus: AppStartupStatus.onboarding,
      activeWateringHub: activeWateringHub,
      activePlanSchema: null,
      settings: null,
      deviceObjects: const [],
    );
  }

  factory AppState.readyWithHub({
    required WateringHub activeWateringHub,
    required PlanSchema? activePlanSchema,
    required SettingsResponseData settings,
    required List<DeviceObject> deviceObjects,
  }) {
    return AppState(
      startupStatus: AppStartupStatus.ready,
      activeWateringHub: activeWateringHub,
      activePlanSchema: activePlanSchema,
      settings: settings,
      deviceObjects: deviceObjects,
    );
  }

  final AppStartupStatus startupStatus;
  final WateringHub? activeWateringHub;
  final PlanSchema? activePlanSchema;
  final SettingsResponseData? settings;
  final List<DeviceObject> deviceObjects;

  ControllerSettings? get controllerSettings => settings?.settings;

  WateringHub get readyWateringHub {
    final hub = activeWateringHub;
    if (startupStatus != AppStartupStatus.ready || hub == null) {
      throw StateError('AppState is not ready with a watering hub.');
    }
    return hub;
  }

  SettingsResponseData get readySettings {
    final currentSettings = settings;
    if (startupStatus != AppStartupStatus.ready || currentSettings == null) {
      throw StateError('AppState is not ready with controller settings.');
    }
    return currentSettings;
  }

  AppState copyWith({
    AppStartupStatus? startupStatus,
    WateringHub? activeWateringHub,
    PlanSchema? activePlanSchema,
    SettingsResponseData? settings,
    List<DeviceObject>? deviceObjects,
    bool clearWateringHub = false,
    bool clearPlanSchema = false,
    bool clearSettings = false,
  }) {
    return AppState(
      startupStatus: startupStatus ?? this.startupStatus,
      activeWateringHub:
          clearWateringHub ? null : activeWateringHub ?? this.activeWateringHub,
      activePlanSchema:
          clearPlanSchema ? null : activePlanSchema ?? this.activePlanSchema,
      settings: clearSettings ? null : settings ?? this.settings,
      deviceObjects:
          clearSettings ? const [] : deviceObjects ?? this.deviceObjects,
    );
  }
}
