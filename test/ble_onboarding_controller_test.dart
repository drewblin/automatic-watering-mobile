import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'app_test_composition.dart';
import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/features/ble/ble_constants.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_address_change_models.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_controller.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_state.dart';
import 'package:automatic_watering_mobile/features/onboarding/phone_wifi_service.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/sensors/sensor_metric.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  test('pairing reads Wi-Fi settings without saving a watering hub', () async {
    final storage = InMemoryWateringHubStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
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

    expect(controller.state, isA<WifiCredentialsFormReady>());
    expect(storage.activeHub, isNull);
  });

  test('failed automatic BLE service discovery does not save a hub', () async {
    final storage = InMemoryWateringHubStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(
        hasAutomaticWateringService: false,
      ),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
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

    expect(controller.state, isA<DeviceSelected>());
    expect(
      controller.state.bleError?.message,
      'Не вдалося підключитися до контролера.',
    );
    expect(storage.activeHub, isNull);
  });

  test('bootstrap creates a new active hub for a different BLE device',
      () async {
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
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
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
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(storage.activeHub?.id, 'hub-new-device');
    expect(storage.activeHub?.displayName, 'Automatic Watering Hub');
    expect(storage.activeHub?.bleDeviceId, 'NEW:DEVICE');
    expect(storage.activeHub?.lastKnownIpAddress, '192.168.1.42');
    expect(storage.activeHub?.apiAccessToken, isNull);
    expect(storage.activeHub?.serverDeviceId, isNull);
    expect(storage.activeHub?.onboardingCompletedAt, isNotNull);
    expect(storage.activeHub?.createdAt, isNot(createdAt));
  });

  test('reading Wi-Fi settings keeps controller password out of state',
      () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
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
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();

    expect(controller.state.wifiCredentials.ssid, 'Greenhouse');
    expect(controller.state.wifiCredentials.password, isEmpty);
    expect(controller.state, isA<WifiCredentialsFormReady>());
  });

  test('phone Wi-Fi snapshot fills current SSID and visible networks',
      () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(
        snapshot: PhoneWifiSnapshot(
          currentSsid: 'Garden',
          networks: [
            PhoneWifiNetwork(ssid: 'Garden', signalLevel: -42),
            PhoneWifiNetwork(ssid: 'Greenhouse', signalLevel: -60),
          ],
        ),
      ),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.useCurrentPhoneWifi();

    expect(controller.state, isA<WifiCredentialsFormReady>());
    expect(controller.state.wifiCredentials.ssid, 'Garden');
    final formState = controller.state as WifiCredentialsFormReady;
    expect(
      formState.phoneWifiNetworks.map((network) => network.ssid),
      ['Garden', 'Greenhouse'],
    );
  });

  test('reading Wi-Fi settings times out and returns to the form', () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: diagnosticsLog,
      readCurrentWifiSettingsTimeout: const Duration(milliseconds: 1),
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();

    bleService.hangWifiSettingsRead = true;
    await controller.readCurrentWifiSettings();

    expect(controller.state, isA<WifiCredentialsFormReady>());
    expect(
      controller.state.wifiError?.operation,
      WifiProvisioningOperation.readCurrentSettings,
    );
    expect(
      diagnosticsLog.entries.single.details,
      contains('TimeoutException'),
    );
  });

  test('Wi-Fi validation blocks invalid credentials without saving', () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
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
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );

    expect(bleService.savedWifiCredentials?.ssid, 'Garden');
    expect(bleService.savedWifiCredentials?.password, 'secure123');
    expect(bleService.disconnectCalls, 1);
    expect(bleService.reconnectCalls, 1);
    expect(controller.state, isA<AccessSetupReady>());
    expect(controller.state.wifiCredentials.password, isEmpty);
  });

  test('skipping Wi-Fi settings keeps controller settings unchanged', () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService(
      currentWifi: const WifiCredentials(
        ssid: 'ExistingNetwork',
        password: 'controller-secret',
      ),
    );
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    controller.skipWifiSettings();

    expect(controller.state, isA<AccessSetupReady>());
    expect(controller.state.wifiCredentials.ssid, 'ExistingNetwork');
    expect(controller.state.wifiCredentials.password, isEmpty);
    expect(bleService.savedWifiCredentials, isNull);
  });

  test('accepted Wi-Fi save maps failed reboot reconnect to reconnect state',
      () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService(
      currentWifi: const WifiCredentials(ssid: 'Garden', password: ''),
      failReconnect: true,
    );
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
      maxReconnectAttempts: 1,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );

    expect(bleService.savedWifiCredentials?.ssid, 'Garden');
    expect(controller.state, isA<ReconnectAfterRebootBlocked>());
    expect(
      controller.state.wifiError?.operation,
      WifiProvisioningOperation.reconnectBle,
    );
    expect(
      controller.state.wifiError?.message,
      'Не вдалося повторно підключитися до контролера через BLE.',
    );
  });

  test('rejected Wi-Fi save returns to form with save error', () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService(restartScheduled: false);
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );

    expect(controller.state, isA<WifiCredentialsFormReady>());
    expect(
      controller.state.wifiError?.operation,
      WifiProvisioningOperation.saveSettings,
    );
    expect(
      controller.state.wifiError?.message,
      'Контролер не прийняв Wi-Fi налаштування.',
    );
  });

  test('bootstrap saves IP and secure token then completes onboarding',
      () async {
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final localClient = FakeLocalControllerApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: localClient,
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
      maxControllerAccessAttempts: 1,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
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
    expect(appController.state.startupStatus, AppStartupStatus.onboarding);
    expect(appController.state.activeWateringHub?.apiAccessToken, validToken);
    expect(
      appController.state.activeWateringHub?.onboardingCompletedAt,
      isNotNull,
    );

    await appController.initialize();

    expect(appController.state.startupStatus, AppStartupStatus.ready);
    expect(appController.state.settings?.syncedAt, isNotNull);
  });

  test('bootstrap treats 0.0.0.0 as pending and does not call HTTPS', () async {
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService(
      wifiIpAddress: const ControllerIpAddress('0.0.0.0'),
    );
    final localClient = FakeLocalControllerApiClient();
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
      maxControllerAccessAttempts: 1,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerIpPending>());
    expect(storage.activeHub, isNull);
    expect(tokenStorage.tokens, isEmpty);
    expect(bleService.readApiAccessTokenCalls, 0);
    expect(localClient.checkCalls, 0);
  });

  test('bootstrap retries pending controller IP automatically', () async {
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService(
      wifiIpAddresses: const [
        ControllerIpAddress('0.0.0.0'),
        ControllerIpAddress('192.168.1.42'),
      ],
    );
    final localClient = FakeLocalControllerApiClient();
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
      controllerAccessRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerAccessReady>());
    expect(bleService.readWifiIpAddressCalls, 2);
    expect(localClient.checkCalls, 1);
  });

  test('bootstrap retries temporary HTTPS network errors automatically',
      () async {
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final bleService = FakeBleService();
    final localClient = FakeLocalControllerApiClient(
      exceptions: const [
        LocalControllerApiException(),
      ],
    );
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
      controllerAccessRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerAccessReady>());
    expect(localClient.checkCalls, 2);
  });

  test('bootstrap maps local controller API failures to communication error',
      () async {
    final composition = TestAppComposition(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final appController = composition.appController;
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(
        exception: const LocalControllerApiException(),
      ),
      diagnosticsLog: InMemoryDiagnosticsLog(),
      rebootDelay: Duration.zero,
      reconnectRetryDelay: Duration.zero,
    );

    controller.selectDevice(testDevice);
    await controller.connectSelectedDevice();
    await controller.saveWifiSettings(
      const WifiCredentials(ssid: 'Garden', password: 'secure123'),
    );
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerAccessFailed>());
    expect(
      controller.state.controllerAccessErrorMessage,
      'Помилка комунікації з контролером.',
    );
  });

  test('recovery reconnects saved controller over BLE and refreshes IP',
      () async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
        id: 'hub-aa-bb-cc',
        displayName: 'Saved Hub',
        bleDeviceId: 'AA:BB:CC',
        lastKnownIpAddress: '192.168.1.10',
        apiAccessToken: null,
        serverDeviceId: 'server-device',
        onboardingCompletedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = validToken;
    final localClient = FakeLocalControllerApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: localClient,
    );
    await composition.appController.initialize();
    final bleService = FakeBleService(
      wifiIpAddress: const ControllerIpAddress('192.168.1.42'),
      apiAccessToken: const ControllerApiAccessToken(otherValidToken),
    );
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      controllerAccessRetryDelay: Duration.zero,
      maxControllerAccessAttempts: 1,
    );

    await controller.recoverSavedController(
      composition.appController.state.activeWateringHub!,
    );

    expect(controller.state, isA<ControllerAccessReady>());
    expect(bleService.reconnectCalls, 1);
    expect(storage.activeHub?.id, 'hub-aa-bb-cc');
    expect(storage.activeHub?.lastKnownIpAddress, '192.168.1.42');
    expect(storage.activeHub?.serverDeviceId, 'server-device');
    expect(storage.activeHub?.apiAccessToken, isNull);
    expect(tokenStorage.tokens['hub-aa-bb-cc'], otherValidToken);
    expect(localClient.checkedIpAddress, '192.168.1.42');
    expect(localClient.checkedToken, otherValidToken);
  });

  test('recovery waits for explicit scan when saved controller BLE unavailable',
      () async {
    final createdAt = DateTime.utc(2026);
    final hub = WateringHub(
      id: 'hub-aa-bb-cc',
      displayName: 'Saved Hub',
      bleDeviceId: 'AA:BB:CC',
      lastKnownIpAddress: '192.168.1.10',
      apiAccessToken: validToken,
      serverDeviceId: null,
      onboardingCompletedAt: createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final composition = TestAppComposition(
      localControllerApiClient: FakeLocalControllerApiClient(),
    );
    final bleService = FakeBleService(
      currentWifi: const WifiCredentials(ssid: 'Garden', password: ''),
      failReconnect: true,
    );
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: FakeLocalControllerApiClient(),
      diagnosticsLog: InMemoryDiagnosticsLog(),
      reconnectRetryDelay: Duration.zero,
    );

    await controller.recoverSavedController(hub);

    expect(controller.state, isA<ReadyToScan>());
    expect(controller.state.bleError?.message, contains('Запустіть пошук'));
    expect(controller.state.devices, isEmpty);
    expect(bleService.startScanCalls, 0);

    await controller.startScan();

    expect(controller.state, isA<DiscoveringDevices>());
    expect(bleService.startScanCalls, 1);
  });

  test('recovery keeps existing hub when controller BLE id changed', () async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage()
      ..activeHub = WateringHub(
        id: 'hub-aa-bb-cc',
        displayName: 'Saved Hub',
        bleDeviceId: 'AA:BB:CC',
        lastKnownIpAddress: '192.168.1.10',
        apiAccessToken: null,
        serverDeviceId: 'server-device',
        onboardingCompletedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final tokenStorage = InMemoryWateringHubTokenStorage()
      ..tokens['hub-aa-bb-cc'] = validToken;
    final localClient = FakeLocalControllerApiClient();
    final composition = TestAppComposition(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
      localControllerApiClient: localClient,
    );
    await composition.appController.initialize();
    final bleService = FakeBleService(
      currentWifi: const WifiCredentials(ssid: 'Garden', password: ''),
      failReconnect: true,
    );
    final controller = BleOnboardingController(
      bleService: bleService,
      phoneWifiService: FakePhoneWifiService(),
      onboardingStorage: composition.onboarding,
      localControllerApiClient: localClient,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      reconnectRetryDelay: Duration.zero,
      controllerAccessRetryDelay: Duration.zero,
      maxControllerAccessAttempts: 1,
    );
    const newDevice = BleDiscoveredDevice(
      id: 'DD:EE:FF',
      name: 'Same Controller',
      rssi: -48,
      isLikelyAutomaticWateringHub: true,
      advertisedServiceUuids: {AutomaticWateringBleConstants.serviceUuid},
    );

    await controller.recoverSavedController(
      composition.appController.state.activeWateringHub!,
    );
    bleService.failReconnect = false;
    controller.selectDevice(newDevice);
    await controller.connectSelectedDevice();
    controller.skipWifiSettings();
    await controller.bootstrapControllerAccess();

    expect(controller.state, isA<ControllerAccessReady>());
    expect(storage.activeHub?.id, 'hub-aa-bb-cc');
    expect(storage.activeHub?.displayName, 'Same Controller');
    expect(storage.activeHub?.bleDeviceId, 'DD:EE:FF');
    expect(storage.activeHub?.lastKnownIpAddress, '192.168.1.42');
    expect(storage.activeHub?.serverDeviceId, 'server-device');
    expect(tokenStorage.tokens['hub-aa-bb-cc'], validToken);
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

class FakeBleService implements BleService {
  FakeBleService({
    this.currentWifi = const WifiCredentials(ssid: '', password: ''),
    this.wifiIpAddress = const ControllerIpAddress('192.168.1.42'),
    List<ControllerIpAddress>? wifiIpAddresses,
    this.apiAccessToken = const ControllerApiAccessToken(validToken),
    this.hasAutomaticWateringService = true,
    this.restartScheduled = true,
    this.failReconnect = false,
  }) : wifiIpAddresses = List.of(wifiIpAddresses ?? const []);

  final WifiCredentials currentWifi;
  final ControllerIpAddress wifiIpAddress;
  final List<ControllerIpAddress> wifiIpAddresses;
  final ControllerApiAccessToken apiAccessToken;
  final bool hasAutomaticWateringService;
  final bool restartScheduled;
  bool failReconnect;
  WifiCredentials? savedWifiCredentials;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int reconnectCalls = 0;
  int startScanCalls = 0;
  int readWifiIpAddressCalls = 0;
  int readApiAccessTokenCalls = 0;
  bool hangWifiSettingsRead = false;

  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices =>
      const Stream.empty();

  @override
  Future<BleAvailability> checkAvailability() async => BleAvailability.ready;

  @override
  Future<BleAvailability> requestPermissions() async => BleAvailability.ready;

  @override
  Future<void> startScan() async {
    startScanCalls += 1;
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(BleDiscoveredDevice device) async {
    connectCalls += 1;
  }

  @override
  Future<void> reconnect(BleDiscoveredDevice device) async {
    reconnectCalls += 1;
    if (failReconnect) {
      throw StateError('BLE reconnect failed');
    }
  }

  @override
  Future<BleDeviceServices> pairAndDiscoverServices(
    BleDiscoveredDevice device,
  ) async {
    return BleDeviceServices(
      deviceId: device.id,
      hasAutomaticWateringService: hasAutomaticWateringService,
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
    if (hangWifiSettingsRead) {
      return Completer<WifiCredentials>().future;
    }
    return currentWifi.copyWith(password: '');
  }

  @override
  Future<ControllerIpAddress> readWifiIpAddress(String deviceId) async {
    readWifiIpAddressCalls += 1;
    if (wifiIpAddresses.isNotEmpty) {
      return wifiIpAddresses.removeAt(0);
    }
    return wifiIpAddress;
  }

  @override
  Future<ControllerApiAccessToken> readApiAccessToken(String deviceId) async {
    readApiAccessTokenCalls += 1;
    return apiAccessToken;
  }

  @override
  Future<SaveWifiSettingsResponse> saveWifiSettings({
    required String deviceId,
    required WifiCredentials credentials,
  }) async {
    savedWifiCredentials = credentials;
    return SaveWifiSettingsResponse(restartScheduled: restartScheduled);
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
  Stream<List<int>> subscribeToLogNotifications(String deviceId) {
    return const Stream.empty();
  }

  @override
  Future<void> dispose() async {}
}

class FakePhoneWifiService implements PhoneWifiService {
  FakePhoneWifiService({
    PhoneWifiSnapshot? snapshot,
  }) : snapshot = snapshot ??
            PhoneWifiSnapshot(
              currentSsid: 'Garden',
              networks: const [
                PhoneWifiNetwork(ssid: 'Garden', signalLevel: -45),
                PhoneWifiNetwork(ssid: 'Greenhouse', signalLevel: -63),
              ],
            );

  final PhoneWifiSnapshot snapshot;

  @override
  Future<PhoneWifiSnapshot> readWifiSnapshot() async => snapshot;
}

class FakeLocalControllerApiClient implements LocalControllerApiClient {
  FakeLocalControllerApiClient({
    this.exception,
    List<LocalControllerApiException>? exceptions,
  }) : exceptions = List.of(exceptions ?? const []);

  final LocalControllerApiException? exception;
  final List<LocalControllerApiException> exceptions;
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
    if (exceptions.isNotEmpty) {
      throw exceptions.removeAt(0);
    }
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
