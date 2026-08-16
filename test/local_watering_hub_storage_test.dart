import 'dart:convert';

import 'package:automatic_watering_mobile/app/app_startup_service.dart';
import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/local_controller/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/sensors/sensor_metric.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';
import 'package:automatic_watering_mobile/storage/local_watering_hub_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'startup records diagnostics and starts onboarding for corrupted hub data',
      () async {
    SharedPreferences.setMockInitialValues({
      'watering_hubs.active': '{"id":"hub-aa-bb-cc","displayName":',
    });
    final preferences = await SharedPreferences.getInstance();
    final stateStore = AppStateStore();
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = validToken;
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = RecordingStartupApiClient();
    final startup = AppStartupService(
      stateStore: stateStore,
      wateringHubStorage: SharedPreferencesWateringHubStorage(preferences),
      tokenStorage: tokenStorage,
      controllerSettingsRepository: ControllerSettingsRepository(
        apiClient: client,
      ),
      diagnosticsLog: diagnosticsLog,
    );

    await startup.initialize();

    expect(stateStore.state.startupStatus, AppStartupStatus.onboarding);
    expect(stateStore.state.activeWateringHub, isNull);
    expect(client.getCalls, 0);
    expect(preferences.getString('watering_hubs.active'), isNull);
    expect(tokenStorage.tokens['hub-aa-bb-cc'], validToken);
    expect(diagnosticsLog.entries.single.message, contains('onboarding'));
    expect(diagnosticsLog.entries.single.details,
        contains('watering_hubs.active'));
  });

  test('startup clears profile and token after corrupted saved plan data',
      () async {
    final hub = _hubWithoutPlainToken();
    SharedPreferences.setMockInitialValues({
      'watering_hubs.active': jsonEncode(hub.toJson()),
      'watering_hubs.plan.hub-aa-bb-cc': '{"id":"plan-1","zoneShapes":',
    });
    final preferences = await SharedPreferences.getInstance();
    final stateStore = AppStateStore();
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = validToken;
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = RecordingStartupApiClient();
    final startup = AppStartupService(
      stateStore: stateStore,
      wateringHubStorage: SharedPreferencesWateringHubStorage(preferences),
      tokenStorage: tokenStorage,
      controllerSettingsRepository: ControllerSettingsRepository(
        apiClient: client,
      ),
      diagnosticsLog: diagnosticsLog,
    );

    await startup.initialize();

    expect(stateStore.state.startupStatus, AppStartupStatus.onboarding);
    expect(stateStore.state.activeWateringHub, isNull);
    expect(client.getCalls, 0);
    expect(preferences.getString('watering_hubs.active'), isNull);
    expect(preferences.getString('watering_hubs.plan.hub-aa-bb-cc'), isNull);
    expect(tokenStorage.tokens['hub-aa-bb-cc'], isNull);
    expect(diagnosticsLog.entries.single.message, contains('onboarding'));
    expect(
      diagnosticsLog.entries.single.details,
      contains('watering_hubs.plan.hub-aa-bb-cc'),
    );
  });
}

const validToken =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

WateringHub _hubWithoutPlainToken() {
  final createdAt = DateTime.utc(2026);
  return WateringHub(
    id: 'hub-aa-bb-cc',
    displayName: 'Automatic Watering Hub',
    bleDeviceId: 'AA:BB:CC',
    lastKnownIpAddress: '192.168.1.42',
    apiAccessToken: null,
    serverDeviceId: null,
    onboardingCompletedAt: createdAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

class RecordingStartupApiClient implements LocalControllerApiClient {
  int getCalls = 0;

  @override
  Future<void> checkSettingsAccess({
    required String ipAddress,
    required String apiAccessToken,
  }) async {}

  @override
  Future<SettingsResponseData> getSettings({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    getCalls += 1;
    return SettingsResponseData(
      settings: ControllerSettings(
        globalSettings: GlobalSettings(
          idleWaterCounterReadIntervalSeconds: 60,
          wateringWaterCounterReadIntervalSeconds: 10,
          idlePressureSensorReadIntervalSeconds: 60,
          wateringPressureSensorReadIntervalSeconds: 10,
          idleSoilSensorReadIntervalSeconds: 300,
          wateringSoilSensorReadIntervalSeconds: 30,
          maximumManualValveOpenTimeSeconds: 600,
          startWateringBelowHumidityPercent: 35,
          stopWateringAboveHumidityPercent: 60,
          wateringStartMode: WateringStartMode.immediately,
          wateringWindowStartTime: null,
          wateringWindowEndTime: null,
          zoneWateringDurationSeconds: 120,
          zoneWateringRetryDelaySeconds: 300,
        ),
        remoteLogSettings: const RemoteLogSettings(url: '', token: ''),
        valveSettings: const [],
        pressureSensor: null,
        magistralWaterCounterSetting: null,
        leafWaterCounterSettings: const [],
        soilSensorSettings: const [],
      ),
      controllerCurrentTimestamp: null,
      controllerCurrentTime: null,
      syncedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {}

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    return const [];
  }

  @override
  Future<void> openValveForTime({
    required String ipAddress,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) async {}
}
