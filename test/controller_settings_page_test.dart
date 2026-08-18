import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_form_draft.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_save_controller.dart';
import 'package:automatic_watering_mobile/features/controller_settings/device_objects.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_address_change_models.dart';
import 'package:automatic_watering_mobile/features/sensors/sensor_metric.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_settings_sync_test.dart';

void main() {
  test('builds typed payload for PUT /api/settings', () async {
    final client = RecordingSettingsApiClient();
    final repository = ControllerSettingsRepository(apiClient: client);
    final settings =
        SettingsResponseData.fromJson(settingsResponseDataJson).settings;

    await repository.saveSettings(_hub().readyAccess!, settings);

    expect(client.putIpAddress, '192.168.1.42');
    expect(client.putApiAccessToken, 'token');
    expect(client.savedSettings?.toJson(), settings.toJson());
  });

  test('validates settings form rules', () {
    final draft = ControllerSettingsFormDraft.fromSettings(
      SettingsResponseData.fromJson(settingsResponseDataJson).settings,
    );

    draft.globalSettings.startWateringBelowHumidityPercent = '70';
    draft.globalSettings.stopWateringAboveHumidityPercent = '60';
    draft.valves.first.pin = '18';
    draft.magistralWaterCounter?.pin = '18';
    draft.valves.first.soilSensorSlaveAddress = 99;

    final validation = draft.validate();

    expect(validation.isValid, isFalse);
    expect(
      validation['global.stopWateringAboveHumidityPercent'],
      'Поріг зупинки має бути більшим за поріг старту.',
    );
    expect(validation['valves.0.pin'], 'GPIO pin вже використовується.');
    expect(
      validation['valves.0.soilSensorSlaveAddress'],
      'Оберіть існуючий датчик вологості.',
    );
  });

  test('remote log fields are optional in settings form', () {
    final draft = ControllerSettingsFormDraft.fromSettings(
      SettingsResponseData.fromJson(settingsResponseDataJson).settings,
    );

    draft.remoteLogSettings.url = '';
    draft.remoteLogSettings.token = '';

    final validation = draft.validate();

    expect(validation['remoteLog.url'], isNull);
    expect(validation['remoteLog.token'], isNull);
    expect(validation.isValid, isTrue);
  });

  test('immediate watering mode omits watering window from payload', () {
    final draft = ControllerSettingsFormDraft.fromSettings(
      SettingsResponseData.fromJson(settingsResponseDataJson).settings,
    );

    draft.globalSettings.wateringStartMode = WateringStartMode.immediately;

    final settings = draft.buildSettings();

    expect(settings.globalSettings.wateringWindowStartTime, isNull);
    expect(settings.globalSettings.wateringWindowEndTime, isNull);
  });

  test('successful save waits for reboot and reloads settings', () async {
    final stateStore = AppStateStore()
      ..setState(
        AppState.readyWithHub(
          activeWateringHub: _hub(),
          activePlanSchema: null,
          settings: SettingsResponseData.fromJson(settingsResponseDataJson),
          deviceObjects: buildDeviceObjects(
            wateringHubId: _hub().id,
            settings: SettingsResponseData.fromJson(settingsResponseDataJson)
                .settings,
          ),
        ),
      );
    final client = RecordingSettingsApiClient();
    final controller = ControllerSettingsSaveController(
      stateStore: stateStore,
      repository: ControllerSettingsRepository(apiClient: client),
      rebootDelay: const Duration(milliseconds: 10),
      reconnectAttemptDelay: Duration.zero,
      reconnectTimeout: const Duration(seconds: 1),
    );
    final states = <ControllerSettingsSaveFlowStatus>[];
    controller.states.listen((state) => states.add(state.status));

    final success = await controller.save(
      SettingsResponseData.fromJson(settingsResponseDataJson).settings,
    );

    expect(success, isTrue);
    expect(client.putCalls, 1);
    expect(client.getCalls, 1);
    expect(states, [
      ControllerSettingsSaveFlowStatus.saving,
      ControllerSettingsSaveFlowStatus.rebooting,
      ControllerSettingsSaveFlowStatus.reconnecting,
      ControllerSettingsSaveFlowStatus.reconnected,
    ]);
    expect(stateStore.state.settings?.syncedAt, isNotNull);
  });

  test('save failure does not refresh in-memory settings', () async {
    final initialSettings =
        SettingsResponseData.fromJson(settingsResponseDataJson);
    final stateStore = AppStateStore()
      ..setState(
        AppState.readyWithHub(
          activeWateringHub: _hub(),
          activePlanSchema: null,
          settings: initialSettings,
          deviceObjects: const [],
        ),
      );
    final client = RecordingSettingsApiClient(
      putException: const LocalControllerApiException(),
    );
    final controller = ControllerSettingsSaveController(
      stateStore: stateStore,
      repository: ControllerSettingsRepository(apiClient: client),
      rebootDelay: Duration.zero,
      reconnectAttemptDelay: Duration.zero,
      reconnectTimeout: const Duration(seconds: 1),
    );

    final success = await controller.save(initialSettings.settings);

    expect(success, isFalse);
    expect(client.getCalls, 0);
    expect(stateStore.state.settings, same(initialSettings));
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

class RecordingSettingsApiClient implements LocalControllerApiClient {
  RecordingSettingsApiClient({this.putException});

  final LocalControllerApiException? putException;
  int putCalls = 0;
  int getCalls = 0;
  String? putIpAddress;
  String? putApiAccessToken;
  ControllerSettings? savedSettings;

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
    return SettingsResponseData.fromJson(settingsResponseDataJson);
  }

  @override
  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {
    putCalls += 1;
    putIpAddress = ipAddress;
    putApiAccessToken = apiAccessToken;
    savedSettings = settings;
    final exception = putException;
    if (exception != null) {
      throw exception;
    }
  }

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
