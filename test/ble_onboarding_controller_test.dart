import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/features/ble/ble_constants.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_controller.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_state.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  test('pairing saves BLE device id in active watering hub', () async {
    final storage = InMemoryWateringHubStorage();
    final appController = AppController(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );
    await appController.initialize();
    final bleService = FakeBleService();
    final controller = BleOnboardingController(
      bleService: bleService,
      appController: appController,
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

    expect(controller.state.step, BleOnboardingStep.paired);
    expect(controller.state.connectionStatus, BleConnectionStatus.connected);
    expect(storage.activeHub?.bleDeviceId, 'AA:BB:CC');
    expect(storage.activeHub?.displayName,
        AutomaticWateringBleConstants.deviceName);
  });

  test('incorrect passkey sets an error and does not save a hub', () async {
    final storage = InMemoryWateringHubStorage();
    final appController = AppController(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      appController: appController,
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
    await controller.pairSelectedDevice('000000');

    expect(controller.state.connectionStatus, BleConnectionStatus.error);
    expect(
      controller.state.lastError?.message,
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
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    final appController = AppController(
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );
    await appController.initialize();
    final controller = BleOnboardingController(
      bleService: FakeBleService(),
      appController: appController,
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
}

class FakeBleService implements BleService {
  final _statusController = StreamController<BleConnectionStatus>.broadcast();

  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices =>
      const Stream.empty();

  @override
  Stream<BleConnectionStatus> get connectionStatus => _statusController.stream;

  @override
  Future<BleAvailability> checkAvailability() async => BleAvailability.ready;

  @override
  Future<BleAvailability> requestPermissions() async => BleAvailability.ready;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(BleDiscoveredDevice device) async {
    _statusController.add(BleConnectionStatus.pairingRequired);
  }

  @override
  Future<BleDeviceServices> pairAndDiscoverServices({
    required BleDiscoveredDevice device,
    required String passkey,
  }) async {
    _statusController.add(BleConnectionStatus.connected);
    return BleDeviceServices(
      deviceId: device.id,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids:
          AutomaticWateringBleConstants.expectedCharacteristicUuids,
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {}

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
  Future<void> dispose() async {
    await _statusController.close();
  }
}
