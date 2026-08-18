import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/device_objects.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/home/home_dashboard_controller.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_address_change_models.dart';
import 'package:automatic_watering_mobile/features/sensors/sensor_metric.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_settings_sync_test.dart';

void main() {
  test('dashboard refresh syncs settings before metrics and maps objects',
      () async {
    final stateStore = AppStateStore();
    final hub = _hub();
    final initialSettings = SettingsResponseData.fromJson(
      settingsResponseDataJson,
    );
    stateStore.setState(
      AppState.readyWithHub(
        activeWateringHub: hub,
        activePlanSchema: null,
        settings: initialSettings,
        deviceObjects: buildDeviceObjects(
          wateringHubId: hub.id,
          settings: initialSettings.settings,
        ),
      ),
    );
    final apiClient = RecordingDashboardApiClient();
    final controller = HomeDashboardController(
      stateStore: stateStore,
      settingsRepository: ControllerSettingsRepository(apiClient: apiClient),
      apiClient: apiClient,
    );

    await controller.refresh();

    expect(apiClient.calls, ['settings', 'metrics']);
    expect(controller.refreshStatus, DashboardRefreshStatus.loaded);
    expect(stateStore.state.deviceObjects, hasLength(4));
    expect(controller.metrics, hasLength(4));
    expect(
      controller.metrics
          .firstWhere((metric) => metric.sensorType == SensorType.soilHumidity)
          .deviceObjectId,
      'hub-aa-bb-cc:soil_sensor:11',
    );
  });

  test('manual valve command validates max duration and sends pin payload',
      () async {
    final stateStore = AppStateStore();
    final hub = _hub();
    final settings = SettingsResponseData.fromJson(settingsResponseDataJson);
    stateStore.setState(
      AppState.readyWithHub(
        activeWateringHub: hub,
        activePlanSchema: null,
        settings: settings,
        deviceObjects: buildDeviceObjects(
          wateringHubId: hub.id,
          settings: settings.settings,
        ),
      ),
    );
    final apiClient = RecordingDashboardApiClient();
    final controller = HomeDashboardController(
      stateStore: stateStore,
      settingsRepository: ControllerSettingsRepository(apiClient: apiClient),
      apiClient: apiClient,
    );
    final valve = settings.settings.valveSettings.single;

    final tooLong = await controller.openValveForTime(
      valve: valve,
      seconds: 601,
      settings: settings.settings,
    );

    expect(tooLong, isFalse);
    expect(apiClient.openValveCalls, 0);
    expect(
      controller.manualValveState.message,
      'Час відкриття не може перевищувати 600 с.',
    );

    final success = await controller.openValveForTime(
      valve: valve,
      seconds: 60,
      settings: settings.settings,
    );

    expect(success, isTrue);
    expect(apiClient.openValveCalls, 1);
    expect(apiClient.openValvePin, 17);
    expect(apiClient.openValveSeconds, 60);
  });

  test('dashboard refresh shows generic communication error', () async {
    final stateStore = AppStateStore();
    final hub = _hub();
    final settings = SettingsResponseData.fromJson(settingsResponseDataJson);
    stateStore.setState(
      AppState.readyWithHub(
        activeWateringHub: hub,
        activePlanSchema: null,
        settings: settings,
        deviceObjects: buildDeviceObjects(
          wateringHubId: hub.id,
          settings: settings.settings,
        ),
      ),
    );
    final apiClient = RecordingDashboardApiClient(
      metricsException: const LocalControllerApiException(),
    );
    final controller = HomeDashboardController(
      stateStore: stateStore,
      settingsRepository: ControllerSettingsRepository(apiClient: apiClient),
      apiClient: apiClient,
    );

    await controller.refresh();

    expect(controller.refreshStatus, DashboardRefreshStatus.failed);
    expect(
      controller.refreshErrorMessage,
      'Помилка комунікації з контролером.',
    );
  });
}

WateringHub _hub() {
  final createdAt = DateTime.utc(2026);
  return WateringHub(
    id: 'hub-aa-bb-cc',
    displayName: 'Automatic Watering Hub',
    bleDeviceId: 'AA:BB:CC',
    lastKnownIpAddress: '192.168.1.42',
    apiAccessToken: 'token',
    serverDeviceId: null,
    onboardingCompletedAt: createdAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

class RecordingDashboardApiClient implements LocalControllerApiClient {
  RecordingDashboardApiClient({this.metricsException});

  final LocalControllerApiException? metricsException;
  final calls = <String>[];
  var openValveCalls = 0;
  int? openValvePin;
  int? openValveSeconds;

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
    calls.add('settings');
    return SettingsResponseData.fromJson(settingsResponseDataJson);
  }

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    calls.add('metrics');
    final exception = metricsException;
    if (exception != null) {
      throw exception;
    }
    final receivedAt = DateTime.utc(2026, 8, 3, 10);
    return [
      _metric(
        sensorId: 21,
        sensorType: SensorType.pressure,
        value: 2.4,
        receivedAt: receivedAt,
      ),
      _metric(
        sensorId: 18,
        sensorType: SensorType.waterCounter,
        value: 15.5,
        receivedAt: receivedAt,
      ),
      _metric(
        sensorId: 11,
        sensorType: SensorType.soilHumidity,
        value: 64.2,
        receivedAt: receivedAt,
      ),
      _metric(
        sensorId: 11,
        sensorType: SensorType.soilTemperature,
        value: 21.8,
        receivedAt: receivedAt,
      ),
    ];
  }

  @override
  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {}

  @override
  Future<void> openValveForTime({
    required String ipAddress,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) async {
    openValveCalls += 1;
    openValvePin = pin;
    openValveSeconds = seconds;
  }

  @override
  Future<ModbusAddressChangeResult> changeModbusAddress({
    required String ipAddress,
    required String apiAccessToken,
    required ModbusAddressChangeRequest request,
  }) async {
    return ModbusAddressChangeResult(
      currentAddress: request.currentAddress,
      newAddress: request.newAddress,
    );
  }
}

ControllerSensorMetric _metric({
  required int sensorId,
  required SensorType sensorType,
  required double value,
  required DateTime receivedAt,
}) {
  return ControllerSensorMetric(
    sensorId: sensorId,
    sensorType: sensorType,
    name: sensorType.toJson(),
    value: value,
    uptimeMs: 1000,
    receivedAt: receivedAt,
  );
}
