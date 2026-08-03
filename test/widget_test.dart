import 'package:flutter_test/flutter_test.dart';

import 'app_test_composition.dart';
import 'package:automatic_watering_mobile/app/automatic_watering_app.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_controller.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  testWidgets('shows BLE onboarding after startup without a device',
      (tester) async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeSettingsApiClient(),
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
  });

  testWidgets('search button retries BLE availability when Bluetooth was off',
      (tester) async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final bleService = FakeBleService(
      availability: BleAvailability.bluetoothDisabled,
    );
    final bleOnboardingController = BleOnboardingController(
      bleService: bleService,
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeSettingsApiClient(),
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
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      controllerSettingsRepository: ControllerSettingsRepository(
        apiClient: FakeSettingsApiClient(),
      ),
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeSettingsApiClient(),
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
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await composition.onboarding.saveControllerAccess(
      hub: completeHub,
      apiAccessToken: validToken,
    );
    await composition.onboarding.completeOnboarding(completeHub);
    await appController.initialize();
    await tester.pump();

    expect(find.text('Додати контролер'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
    expect(find.text('Контролер доступний'), findsOneWidget);
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
        apiAccessToken: null,
        serverDeviceId: null,
        onboardingCompletedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = validToken;
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      controllerSettingsRepository: ControllerSettingsRepository(
        apiClient: FakeSettingsApiClient(),
      ),
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeSettingsApiClient(),
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
  });

  testWidgets('retries startup settings load after fatal error',
      (tester) async {
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
      ..tokens['hub-aa-bb-cc'] = validToken;
    final client = FlakySettingsApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      controllerSettingsRepository: ControllerSettingsRepository(
        apiClient: client,
      ),
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeSettingsApiClient(),
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
    expect(find.text('Налаштування контролера'), findsNothing);

    await tester.tap(find.text('Повторити'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Помилка запуску'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
    expect(find.text('Налаштування контролера'), findsOneWidget);
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
        apiAccessToken: null,
        serverDeviceId: null,
        onboardingCompletedAt: null,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeSettingsApiClient(),
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
}

const validToken =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

ControllerSettingsRepository testSettingsRepository() {
  return ControllerSettingsRepository(apiClient: FakeSettingsApiClient());
}

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
    return SettingsResponseData.fromJson(settingsResponseDataJson);
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
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller network is unavailable',
      );
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
    return const ControllerIpAddress('192.168.1.42');
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
  Future<void> dispose() async {}
}
