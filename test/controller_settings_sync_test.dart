import 'package:flutter_test/flutter_test.dart';

import 'app_test_composition.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  test('parses real settings envelope and builds stable device objects',
      () async {
    final data = SettingsResponseData.fromJson(settingsResponseDataJson);

    expect(data.controllerCurrentTimestamp, 1717245600);
    expect(data.settings.valveSettings.single.pin, 17);
    expect(data.settings.pressureSensor?.slaveAddress, 21);
    expect(data.syncedAt, isNotNull);
  });

  test('app controller loads settings during startup', () async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
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
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = 'token';
    final client = FakeSettingsApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      controllerSettingsRepository: ControllerSettingsRepository(
        apiClient: client,
      ),
    );
    final appController = composition.appController;

    await appController.initialize();

    expect(client.ipAddress, '192.168.1.42');
    expect(client.apiAccessToken, 'token');
    expect(appController.state.settings?.syncedAt, isNotNull);
    expect(appController.state.deviceObjects.map((object) => object.id), [
      'hub-aa-bb-cc:valve:17',
      'hub-aa-bb-cc:soil_sensor:11',
      'hub-aa-bb-cc:pressure_sensor:21',
      'hub-aa-bb-cc:water_counter:18',
    ]);
  });
}

const settingsResponseDataJson = {
  'settings': settingsJson,
  'controllerCurrentTimestamp': 1717245600,
  'controllerCurrentTime': '2024-06-01T12:00:00+0300',
};

const settingsJson = {
  'globalSettings': {
    'idleWaterCounterReadIntervalSeconds': 60,
    'wateringWaterCounterReadIntervalSeconds': 10,
    'idlePressureSensorReadIntervalSeconds': 60,
    'wateringPressureSensorReadIntervalSeconds': 10,
    'idleSoilSensorReadIntervalSeconds': 300,
    'wateringSoilSensorReadIntervalSeconds': 30,
    'maximumManualValveOpenTimeSeconds': 600,
    'startWateringBelowHumidityPercent': 35,
    'stopWateringAboveHumidityPercent': 60,
    'wateringStartMode': 'withinWateringWindow',
    'wateringWindowStartTime': {'hour': 6, 'minute': 0},
    'wateringWindowEndTime': {'hour': 9, 'minute': 30},
    'zoneWateringDurationSeconds': 120,
    'zoneWateringRetryDelaySeconds': 300,
  },
  'remoteLogSettings': {
    'url': 'https://api.example.test',
    'token': 'log-token'
  },
  'valveSettings': [
    {'pin': 17, 'name': 'Грядка 1', 'soilSensorSlaveAddress': 11},
  ],
  'pressureSensor': {'slaveAddress': 21, 'name': 'Тиск'},
  'magistralWaterCounterSetting': {
    'pin': 18,
    'name': 'Магістраль',
    'litersPerTick': 1.5,
  },
  'leafWaterCounterSettings': [],
  'soilSensorSettings': [
    {'slaveAddress': 11, 'name': 'Вологість 1'},
  ],
};

class FakeSettingsApiClient implements LocalControllerApiClient {
  String? ipAddress;
  String? apiAccessToken;

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
    this.ipAddress = ipAddress;
    this.apiAccessToken = apiAccessToken;
    return SettingsResponseData.fromJson(settingsResponseDataJson);
  }

  @override
  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {}
}
