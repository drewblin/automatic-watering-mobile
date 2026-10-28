import 'dart:async';

import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/device_objects.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/home/home_dashboard_controller.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_register_write_models.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_register_read_models.dart';
import 'package:automatic_watering_mobile/features/sensors/sensor_metric.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_settings_sync_test.dart';

void main() {
  test('close all valves tracks progress, credentials and duplicate taps',
      () async {
    final api = RecordingDashboardApiClient()
      ..closeCompletion = Completer<void>();
    final controller = dashboardControllerFor(api);

    final pending = controller.closeAllValves();
    expect(controller.isClosingAllValves, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(api.closeAllCalls, 1);
    expect(api.closeHostname, 'watering-hub-a1b2c3.local');
    expect(api.closeApiAccessToken, 'token');
    expect(await controller.closeAllValves(), isFalse);
    expect(api.closeAllCalls, 1);

    api.closeCompletion!.complete();
    expect(await pending, isTrue);
    expect(controller.isClosingAllValves, isFalse);
    expect(
        controller.closeAllValvesState.status, ManualValveCommandStatus.sent);
    expect(controller.closeAllValvesState.message,
        'Команду закриття всіх клапанів виконано');
  });

  test('close all failure restores controls and permits retry', () async {
    final api = RecordingDashboardApiClient()
      ..closeException = const LocalControllerApiException();
    final controller = dashboardControllerFor(api);

    expect(await controller.closeAllValves(), isFalse);
    expect(controller.isClosingAllValves, isFalse);
    expect(
        controller.closeAllValvesState.status, ManualValveCommandStatus.failed);
    expect(controller.closeAllValvesState.message,
        'Не вдалося закрити клапани. Перевірте з’єднання з контролером і спробуйте ще раз');

    api.closeException = null;
    expect(await controller.closeAllValves(), isTrue);
    expect(api.closeAllCalls, 2);
  });

  for (final openFails in [false, true]) {
    test(
        'close completes independently of pending opening (failure: $openFails)',
        () async {
      final api = RecordingDashboardApiClient()
        ..openCompletion = Completer<void>()
        ..closeCompletion = Completer<void>();
      final controller = dashboardControllerFor(api);
      final settings =
          SettingsResponseData.fromJson(settingsResponseDataJson).settings;
      Future<bool> open() => controller.openValveForTime(
            valve: settings.valveSettings.single,
            seconds: 30,
            settings: settings,
          );

      final opening = open();
      final closing = controller.closeAllValves();
      expect(controller.isClosingAllValves, isTrue);
      expect(api.openValveCalls, 1);
      expect(api.closeAllCalls, 1);

      api.closeCompletion!.complete();
      expect(await closing, isTrue);
      expect(
          controller.manualValveState.status, ManualValveCommandStatus.sending);

      if (openFails) {
        api.openCompletion!.completeError(const LocalControllerApiException());
      } else {
        api.openCompletion!.complete();
      }
      expect(await opening, !openFails);
      expect(
          controller.closeAllValvesState.status, ManualValveCommandStatus.sent);
    });
  }

  test('opening completes while close all request is pending', () async {
    final api = RecordingDashboardApiClient()
      ..closeCompletion = Completer<void>();
    final controller = dashboardControllerFor(api);
    final settings =
        SettingsResponseData.fromJson(settingsResponseDataJson).settings;

    final closing = controller.closeAllValves();
    expect(
        await controller.openValveForTime(
          valve: settings.valveSettings.single,
          seconds: 30,
          settings: settings,
        ),
        isTrue);
    expect(api.openValveCalls, 1);
    expect(api.closeAllCalls, 1);
    expect(controller.isClosingAllValves, isTrue);
    expect(controller.manualValveState.status, ManualValveCommandStatus.sent);

    api.closeCompletion!.complete();
    expect(await closing, isTrue);
  });

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
    lastKnownHostname: 'watering-hub-a1b2c3.local',
    apiAccessToken: 'token',
    serverDeviceId: null,
    onboardingCompletedAt: createdAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

HomeDashboardController dashboardControllerFor(
    RecordingDashboardApiClient api) {
  final hub = _hub();
  final settings = SettingsResponseData.fromJson(settingsResponseDataJson);
  final stateStore = AppStateStore()
    ..setState(AppState.readyWithHub(
      activeWateringHub: hub,
      activePlanSchema: null,
      settings: settings,
      deviceObjects: buildDeviceObjects(
          wateringHubId: hub.id, settings: settings.settings),
    ));
  return HomeDashboardController(
    stateStore: stateStore,
    settingsRepository: ControllerSettingsRepository(apiClient: api),
    apiClient: api,
  );
}

class RecordingDashboardApiClient implements LocalControllerApiClient {
  RecordingDashboardApiClient({this.metricsException});

  final LocalControllerApiException? metricsException;
  final calls = <String>[];
  var openValveCalls = 0;
  int? openValvePin;
  int? openValveSeconds;
  Completer<void>? closeCompletion;
  Completer<void>? openCompletion;
  LocalControllerApiException? closeException;
  int closeAllCalls = 0;
  String? closeHostname;
  String? closeApiAccessToken;

  @override
  Future<void> closeAllValves({
    required String hostname,
    required String apiAccessToken,
  }) async {
    closeAllCalls++;
    closeHostname = hostname;
    closeApiAccessToken = apiAccessToken;
    if (closeException case final error?) throw error;
    await closeCompletion?.future;
  }

  @override
  Future<void> checkSettingsAccess({
    required String hostname,
    required String apiAccessToken,
  }) async {}

  @override
  Future<SettingsResponseData> getSettings({
    required String hostname,
    required String apiAccessToken,
  }) async {
    calls.add('settings');
    return SettingsResponseData.fromJson(settingsResponseDataJson);
  }

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String hostname,
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
    required String hostname,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {}

  @override
  Future<void> openValveForTime({
    required String hostname,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) async {
    openValveCalls += 1;
    openValvePin = pin;
    openValveSeconds = seconds;
    await openCompletion?.future;
  }

  @override
  Future<ModbusRegisterReadResult> readModbusRegisters({
    required String hostname,
    required String apiAccessToken,
    required ModbusRegisterReadRequest request,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ModbusRegisterWriteResult> writeModbusRegister({
    required String hostname,
    required String apiAccessToken,
    required ModbusRegisterWriteRequest request,
  }) async {
    return ModbusRegisterWriteResult(
      status: 0,
      slaveAddress: request.slaveAddress,
      value: request.value,
      registerAddress: request.registerAddress,
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
