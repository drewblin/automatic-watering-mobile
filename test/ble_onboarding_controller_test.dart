import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'app_test_composition.dart';
import 'package:automatic_watering_mobile/features/ble/ble_constants.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_controller.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_state.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub_state.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  test('pairing saves BLE device id in active watering hub', () async {
    final storage = InMemoryWateringHubStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      onboardingStorage: composition.onboarding,
    );
    final device = const BleDiscoveredDevice(
      id: 'AA:BB:CC',
      name: AutomaticWateringBleConstants.deviceName,
      rssi: -54,
      isLikelyAutomaticWateringHub: true,
      advertisedServiceUuids: {AutomaticWateringBleConstants.serviceUuid},
    );

    controller.selectDevice(device);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );

    expect(controller.state, isA<WifiCredentialsFormReady>());
    expect(storage.activeHub?.bleDeviceId, 'AA:BB:CC');
    expect(storage.activeHub?.displayName,
        AutomaticWateringBleConstants.deviceName);
  });

  test('incorrect passkey sets an error and does not save a hub', () async {
    final storage = InMemoryWateringHubStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
    );

    controller.selectDevice(
      const BleDiscoveredDevice(
        id: 'AA:BB:CC',
        name: AutomaticWateringBleConstants.deviceName,
        rssi: null,
        isLikelyAutomaticWateringHub: true,
        advertisedServiceUuids: {AutomaticWateringBleConstants.serviceUuid},
      ),
    );
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice('000000');

    expect(controller.state, isA<AwaitingPairingPasskey>());
    expect(
      controller.state.bleError?.message,
      'Неправильний код сполучення.',
    );
    expect(storage.activeHub, isNull);
  });

  test('pairing a different BLE device creates a new active hub', () async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
        id: 'hub-old-device',
        displayName: 'Existing hub',
        bleDeviceId: 'OLD:DEVICE',
        lastKnownIpAddress: '192.168.1.50',
        apiAccessToken: 'token',
        serverDeviceId: 'server-device',
        onboardingCompletedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
    );
    const newDevice = BleDiscoveredDevice(
      id: 'NEW:DEVICE',
      name: 'Automatic Watering Hub',
      rssi: -49,
      isLikelyAutomaticWateringHub: true,
      advertisedServiceUuids: {AutomaticWateringBleConstants.serviceUuid},
    );

    controller.selectDevice(newDevice);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );

    expect(storage.activeHub?.id, 'hub-new-device');
    expect(storage.activeHub?.displayName, 'Automatic Watering Hub');
    expect(storage.activeHub?.bleDeviceId, 'NEW:DEVICE');
    expect(storage.activeHub?.lastKnownIpAddress, isNull);
    expect(storage.activeHub?.apiAccessToken, isNull);
    expect(storage.activeHub?.serverDeviceId, isNull);
    expect(storage.activeHub?.createdAt, isNot(createdAt));
  });

  test('reading Wi-Fi settings keeps controller password out of state',
      () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService(
      currentWifi: const WifiCredentials(
        ssid: 'Greenhouse',
        password: 'firmware-secret',
      ),
    );
    final controller = BleOnboardingController(
      bleService: bleService,
      onboardingStorage: composition.onboarding,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );

    expect(controller.state.wifiCredentials.ssid, 'Greenhouse');
    expect(controller.state.wifiCredentials.password, isEmpty);
    expect(controller.state, isA<WifiCredentialsFormReady>());
  });

  test('Wi-Fi validation blocks invalid credentials without saving', () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      onboardingStorage: composition.onboarding,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'short'),
    );

    expect(controller.state.wifiValidationErrors['password'], isNotNull);
    expect(bleService.savedWifiCredentials, isNull);
    expect(controller.state.wifiCredentials.password, isEmpty);
  });

  test('saving Wi-Fi settings schedules BLE reconnect and advances flow',
      () async {
    final storage = InMemoryWateringHubStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      onboardingStorage: composition.onboarding,
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );

    expect(bleService.savedWifiCredentials?.ssid, 'Garden');
    expect(bleService.savedWifiCredentials?.password, 'secure123');
    expect(bleService.disconnectCalls, 1);
    expect(bleService.reconnectCalls, 1);
    expect(controller.state, isA<AccessSetupReady>());
    expect(controller.state.wifiCredentials.password, isEmpty);
    expect(
      appController.state.connectionState,
      WateringHubConnectionState.reconnectingBle,
    );
  });

  test('bootstrap saves IP and secure token then marks hub online', () async {
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final localClient = FakeLocalControllerApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      controllerSettingsRepository: ControllerSettingsRepository(
        apiClient: localClient,
      ),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerAccessReady>());
    expect(storage.activeHub?.lastKnownIpAddress, '192.168.1.42');
    expect(storage.activeHub?.apiAccessToken, isNull);
    expect(storage.activeHub?.onboardingCompletedAt, isNotNull);
    expect(tokenStorage.tokens[storage.activeHub!.id], validToken);
    expect(localClient.checkedIpAddress, '192.168.1.42');
    expect(localClient.checkedToken, validToken);
    expect(
      appController.state.connectionState,
      WateringHubConnectionState.online,
    );
    expect(appController.state.activeWateringHub?.apiAccessToken, validToken);
    expect(
      appController.state.activeWateringHub?.onboardingCompletedAt,
      isNotNull,
    );
  });

  test('bootstrap treats 0.0.0.0 as pending and does not call HTTPS', () async {
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService(
      wifiIpAddress: const ControllerIpAddress('0.0.0.0'),
    );
    final localClient = FakeLocalControllerApiClient();
    final controller = BleOnboardingController(
      bleService: bleService,
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerIpPending>());
    expect(storage.activeHub?.lastKnownIpAddress, '0.0.0.0');
    expect(tokenStorage.tokens[storage.activeHub!.id], validToken);
    expect(localClient.checkCalls, 0);
    expect(
      appController.state.connectionState,
      WateringHubConnectionState.ipPending,
    );
  });

  test('bootstrap maps HTTPS 401 to tokenInvalid state', () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      controllerSettingsRepository: testSettingsRepository(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(
        exception: const LocalControllerApiException(
          LocalControllerApiErrorKind.tokenInvalid,
          'Controller rejected API access token',
        ),
      ),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.pairSelectedDevice(
      AutomaticWateringBleConstants.pairingPasskey,
    );
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerAccessFailed>());
    expect(
      controller.state.controllerAccessError?.kind,
      ControllerAccessFailureKind.tokenInvalid,
    );
    expect(
      appController.state.connectionState,
      WateringHubConnectionState.tokenInvalid,
    );
  });

  test('controller IP and token parsing trusts controller values', () {
    expect(
      ControllerIpAddress.fromJson({'ipAddress': 'controller.local'}).value,
      'controller.local',
    );
    expect(
      ControllerIpAddress.fromJson({'ipAddress': '192.168.001.42'}).value,
      '192.168.001.42',
    );
    expect(
      ControllerApiAccessToken.fromJson({'apiAccessToken': 'controller-token'})
          .value,
      'controller-token',
    );
    expect(
      ControllerIpAddress.fromJson({'ipAddress': '0.0.0.0'}).isPending,
      isTrue,
    );
  });

  test('token storage stores controller tokens by watering hub id', () async {
    final tokenStorage = InMemoryWateringHubTokenStorage();

    await tokenStorage.saveApiAccessToken(
      wateringHubId: 'hub-a',
      token: validToken,
    );
    await tokenStorage.saveApiAccessToken(
      wateringHubId: 'hub-b',
      token: otherValidToken,
    );

    expect(await tokenStorage.readApiAccessToken('hub-a'), validToken);
    expect(await tokenStorage.readApiAccessToken('hub-b'), otherValidToken);

    await tokenStorage.deleteApiAccessToken('hub-a');

    expect(await tokenStorage.readApiAccessToken('hub-a'), isNull);
    expect(await tokenStorage.readApiAccessToken('hub-b'), otherValidToken);
  });
}

const validToken =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const otherValidToken =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const testDevice = BleDiscoveredDevice(
  id: 'AA:BB:CC',
  name: AutomaticWateringBleConstants.deviceName,
  rssi: -54,
  isLikelyAutomaticWateringHub: true,
  advertisedServiceUuids: {AutomaticWateringBleConstants.serviceUuid},
);

ControllerSettingsRepository testSettingsRepository() {
  return ControllerSettingsRepository(
      apiClient: FakeLocalControllerApiClient());
}

class FakeBleService implements BleService {
  FakeBleService({
    this.currentWifi = const WifiCredentials(ssid: '', password: ''),
    this.wifiIpAddress = const ControllerIpAddress('192.168.1.42'),
    this.apiAccessToken = const ControllerApiAccessToken(validToken),
  });

  final WifiCredentials currentWifi;
  final ControllerIpAddress wifiIpAddress;
  final ControllerApiAccessToken apiAccessToken;
  WifiCredentials? savedWifiCredentials;
  int disconnectCalls = 0;
  int reconnectCalls = 0;

  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices =>
      const Stream.empty();

  @override
  Future<BleAvailability> checkAvailability() async => BleAvailability.ready;

  @override
  Future<BleAvailability> requestPermissions() async => BleAvailability.ready;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(BleDiscoveredDevice device) async {}

  @override
  Future<void> reconnect(BleDiscoveredDevice device) async {
    reconnectCalls += 1;
  }

  @override
  Future<BleDeviceServices> pairAndDiscoverServices({
    required BleDiscoveredDevice device,
    required String passkey,
  }) async {
    return BleDeviceServices(
      deviceId: device.id,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids:
          AutomaticWateringBleConstants.expectedCharacteristicUuids,
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectCalls += 1;
  }

  @override
  Future<WifiCredentials> readWifiSettings(String deviceId) async {
    return currentWifi.copyWith(password: '');
  }

  @override
  Future<ControllerIpAddress> readWifiIpAddress(String deviceId) async {
    return wifiIpAddress;
  }

  @override
  Future<ControllerApiAccessToken> readApiAccessToken(String deviceId) async {
    return apiAccessToken;
  }

  @override
  Future<SaveWifiSettingsResponse> saveWifiSettings({
    required String deviceId,
    required WifiCredentials credentials,
  }) async {
    savedWifiCredentials = credentials;
    return const SaveWifiSettingsResponse(restartScheduled: true);
  }

  @override
  Future<BleDeviceServices> discoverServices(String deviceId) async {
    return BleDeviceServices(
      deviceId: deviceId,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids:
          AutomaticWateringBleConstants.expectedCharacteristicUuids,
    );
  }

  @override
  Future<void> dispose() async {}
}

class FakeLocalControllerApiClient implements LocalControllerApiClient {
  FakeLocalControllerApiClient({this.exception});

  final LocalControllerApiException? exception;
  int checkCalls = 0;
  String? checkedIpAddress;
  String? checkedToken;

  @override
  Future<void> checkSettingsAccess({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    checkCalls += 1;
    checkedIpAddress = ipAddress;
    checkedToken = apiAccessToken;
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }
  }

  @override
  Future<SettingsResponseData> getSettings({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    await checkSettingsAccess(
      ipAddress: ipAddress,
      apiAccessToken: apiAccessToken,
    );
    return SettingsResponseData.fromJson({
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
    });
  }
}
