import 'package:flutter_test/flutter_test.dart';

import 'app_test_composition.dart';
import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/automatic_watering_app.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/mdns_controller_resolver.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_address_change_models.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_controller.dart';
import 'package:automatic_watering_mobile/features/onboarding/phone_wifi_service.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/sensors/sensor_metric.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  testWidgets('shows BLE onboarding after startup without a device',
      (tester) async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      mdnsControllerResolver: const FakeMdnsControllerResolver(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Автоматичний полив'), findsOneWidget);
    expect(find.text('Додати контролер'), findsOneWidget);
    expect(find.text('Готово до пошуку'), findsOneWidget);
    expect(find.byTooltip('Сервісна консоль'), findsOneWidget);

    await tester.tap(find.byTooltip('Сервісна консоль'));
    await tester.pumpAndSettle();

    expect(find.text('Сервісна консоль'), findsOneWidget);
    expect(find.text('Діагностика'), findsOneWidget);
  });

  testWidgets('search button retries BLE availability when Bluetooth was off',
      (tester) async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );
    final bleService = FakeBleService(
      availability: BleAvailability.bluetoothDisabled,
    );
    final bleOnboardingController = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      mdnsControllerResolver: const FakeMdnsControllerResolver(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: composition.appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Увімкніть Bluetooth у налаштуваннях пристрою'),
      findsOneWidget,
    );
    expect(find.text('Шукати'), findsOneWidget);

    bleService.availability = BleAvailability.ready;
    await tester.tap(find.text('Шукати'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Шукаємо контролер'), findsOneWidget);
  });

  testWidgets('keeps onboarding visible until controller access is complete',
      (tester) async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final client = FakeSettingsApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: client,
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      mdnsControllerResolver: const FakeMdnsControllerResolver(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pump();
    await tester.pump();

    final incompleteHub = WateringHub(
      id: 'hub-aa-bb-cc',
      displayName: 'Automatic Watering Hub',
      bleDeviceId: 'AA:BB:CC',
      lastKnownIpAddress: null,
      lastKnownHostname: '',
      apiAccessToken: null,
      serverDeviceId: null,
      onboardingCompletedAt: null,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    await composition.onboarding.saveActiveWateringHub(incompleteHub);
    await tester.pump();

    expect(find.text('Додати контролер'), findsOneWidget);
    expect(find.text('Automatic Watering Hub'), findsNothing);

    final completeHub = incompleteHub.copyWith(
      lastKnownIpAddress: '192.168.1.42',
      lastKnownHostname: 'watering-hub-a1b2c3.local',
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await composition.onboarding
        .saveControllerAccess(
          hub: completeHub,
          apiAccessToken: validToken,
        )
        .then(composition.onboarding.completeOnboarding);
    await appController.initialize();
    await tester.pump();

    expect(find.text('Додати контролер'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
    expect(find.text('Контролер доступний'), findsOneWidget);
    expect(find.byTooltip('Сервісна консоль'), findsOneWidget);
  });

  testWidgets('starts on main screen when saved controller access exists',
      (tester) async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
        id: 'hub-aa-bb-cc',
        displayName: 'Automatic Watering Hub',
        bleDeviceId: 'AA:BB:CC',
        lastKnownIpAddress: '192.168.1.42',
        lastKnownHostname: 'watering-hub-a1b2c3.local',
        apiAccessToken: null,
        serverDeviceId: null,
        onboardingCompletedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = validToken;
    final client = FakeSettingsApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: client,
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      mdnsControllerResolver: const FakeMdnsControllerResolver(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Додати контролер'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
    expect(find.text('Контролер доступний'), findsOneWidget);
    expect(find.byTooltip('Сервісна консоль'), findsOneWidget);

    await tester.tap(find.byTooltip('Налаштування контролера'));
    await tester.pumpAndSettle();

    expect(find.text('Налаштування контролера'), findsOneWidget);
    expect(find.byTooltip('Сервісна консоль'), findsOneWidget);

    await tester.tap(find.byTooltip('Сервісна консоль'));
    await tester.pumpAndSettle();

    expect(find.text('Сервісна консоль'), findsOneWidget);
    expect(find.text('Діагностика'), findsOneWidget);
  });

  testWidgets('manually restarts onboarding after saved IP failure',
      (tester) async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
        id: 'hub-aa-bb-cc',
        displayName: 'Automatic Watering Hub',
        bleDeviceId: 'AA:BB:CC',
        lastKnownIpAddress: '192.168.1.42',
        lastKnownHostname: 'watering-hub-a1b2c3.local',
        apiAccessToken: null,
        serverDeviceId: null,
        onboardingCompletedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = validToken;
    final client = FlakySettingsApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: client,
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      mdnsControllerResolver: const FakeMdnsControllerResolver(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNotNull);
    expect(find.text('Помилка запуску'), findsOneWidget);
    expect(find.text('Повторити'), findsOneWidget);
    expect(find.text('Повторити onboarding'), findsOneWidget);
    expect(find.byTooltip('Сервісна консоль'), findsOneWidget);
    expect(find.text('Налаштування контролера'), findsNothing);

    await tester.tap(find.text('Повторити onboarding'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Помилка запуску'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
    expect(find.byTooltip('Налаштування контролера'), findsOneWidget);
  });

  testWidgets('starts onboarding when saved controller access is incomplete',
      (tester) async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
        id: 'hub-aa-bb-cc',
        displayName: 'Automatic Watering Hub',
        bleDeviceId: 'AA:BB:CC',
        lastKnownIpAddress: null,
        lastKnownHostname: '',
        apiAccessToken: null,
        serverDeviceId: null,
        onboardingCompletedAt: null,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      mdnsControllerResolver: const FakeMdnsControllerResolver(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Додати контролер'), findsOneWidget);
  });

  testWidgets('recovers completed hub when saved token is missing',
      (tester) async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
        id: 'hub-aa-bb-cc',
        displayName: 'Automatic Watering Hub',
        bleDeviceId: 'AA:BB:CC',
        lastKnownIpAddress: '192.168.1.42',
        lastKnownHostname: 'watering-hub-a1b2c3.local',
        apiAccessToken: null,
        serverDeviceId: null,
        onboardingCompletedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final client = FakeSettingsApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: client,
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      mdnsControllerResolver: const FakeMdnsControllerResolver(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pump();
    await tester.pump();

    expect(appController.state.startupStatus, AppStartupStatus.ready);
    expect(client.getCalls, greaterThanOrEqualTo(1));
    expect(find.text('Додати контролер'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
  });
}

const validToken =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const settingsResponseDataJson = {
  'settings': {
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
      'wateringStartMode': 'immediately',
      'wateringWindowStartTime': null,
      'wateringWindowEndTime': null,
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
  },
  'controllerCurrentTimestamp': 1717245600,
  'controllerCurrentTime': '2024-06-01T12:00:00+0300',
};

class FakeSettingsApiClient implements LocalControllerApiClient {
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
    return SettingsResponseData.fromJson(settingsResponseDataJson);
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
    final receivedAt = DateTime.utc(2026, 8, 3, 10);
    return [
      ControllerSensorMetric.fromJson(
        json: const {
          'sensorId': 21,
          'sensorType': 'pressure',
          'name': 'Тиск',
          'value': 2.4,
          'uptimeMs': 1000,
        },
        receivedAt: receivedAt,
      ),
      ControllerSensorMetric.fromJson(
        json: const {
          'sensorId': 18,
          'sensorType': 'water_counter',
          'name': 'Магістраль',
          'value': 15.5,
          'uptimeMs': 1000,
        },
        receivedAt: receivedAt,
      ),
      ControllerSensorMetric.fromJson(
        json: const {
          'sensorId': 11,
          'sensorType': 'soil_humidity',
          'name': 'Вологість 1',
          'value': 64.2,
          'uptimeMs': 1000,
        },
        receivedAt: receivedAt,
      ),
      ControllerSensorMetric.fromJson(
        json: const {
          'sensorId': 11,
          'sensorType': 'soil_temperature',
          'name': 'Вологість 1',
          'value': 21.8,
          'uptimeMs': 1000,
        },
        receivedAt: receivedAt,
      ),
    ];
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
      registerAddress: request.registerAddress,
    );
  }
}

class FakeMdnsControllerResolver implements MdnsControllerResolver {
  const FakeMdnsControllerResolver();

  @override
  Future<String?> resolve({
    required String hostname,
    required String localHostname,
  }) async {
    return null;
  }
}

class FlakySettingsApiClient extends FakeSettingsApiClient {
  var _calls = 0;

  @override
  Future<SettingsResponseData> getSettings({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    _calls += 1;
    if (_calls == 1) {
      throw const LocalControllerApiException();
    }
    return super.getSettings(
      ipAddress: ipAddress,
      apiAccessToken: apiAccessToken,
    );
  }
}

class FakeBleService implements BleService {
  FakeBleService({this.availability = BleAvailability.ready});

  BleAvailability availability;

  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices =>
      const Stream.empty();

  @override
  Future<BleAvailability> checkAvailability() async => availability;

  @override
  Future<BleAvailability> requestPermissions() async => BleAvailability.ready;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(BleDiscoveredDevice device) async {}

  @override
  Future<void> reconnect(BleDiscoveredDevice device) async {}

  @override
  Future<BleDeviceServices> pairAndDiscoverServices(
    BleDiscoveredDevice device,
  ) async {
    return BleDeviceServices(
      deviceId: device.id,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids: const {},
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<BleDeviceServices> discoverServices(String deviceId) async {
    return BleDeviceServices(
      deviceId: deviceId,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids: const {},
    );
  }

  @override
  Future<WifiCredentials> readWifiSettings(String deviceId) async {
    return WifiCredentials.empty();
  }

  @override
  Future<ControllerIpAddress> readWifiIpAddress(String deviceId) async {
    return const ControllerIpAddress(
      '192.168.1.42',
      hostname: 'watering-hub-a1b2c3',
      localHostname: 'watering-hub-a1b2c3.local',
    );
  }

  @override
  Future<ControllerApiAccessToken> readApiAccessToken(String deviceId) async {
    return const ControllerApiAccessToken(validToken);
  }

  @override
  Future<SaveWifiSettingsResponse> saveWifiSettings({
    required String deviceId,
    required WifiCredentials credentials,
  }) async {
    return const SaveWifiSettingsResponse(restartScheduled: true);
  }

  @override
  Stream<List<int>> subscribeToLogNotifications(String deviceId) {
    return const Stream.empty();
  }

  @override
  Future<void> dispose() async {}
}

class FakePhoneWifiService implements PhoneWifiService {
  @override
  Future<PhoneWifiSnapshot> readWifiSnapshot() async {
    return PhoneWifiSnapshot(
      currentSsid: 'Garden',
      networks: [
        PhoneWifiNetwork(ssid: 'Garden', signalLevel: -45),
        PhoneWifiNetwork(ssid: 'Greenhouse', signalLevel: -63),
      ],
    );
  }
}
