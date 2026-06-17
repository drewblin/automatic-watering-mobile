import 'package:flutter_test/flutter_test.dart';

import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/automatic_watering_app.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_controller.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  testWidgets('shows BLE onboarding after startup without a device',
      (tester) async {
    final appController = AppController(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );
    final bleOnboardingController = BleOnboardingController(
      bleService: FakeBleService(),
      appController: appController,
    );

    await tester.pumpWidget(
      AutomaticWateringApp(
        appController: appController,
        bleOnboardingController: bleOnboardingController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Автоматичний полив'), findsOneWidget);
    expect(find.text('Додати контролер'), findsOneWidget);
    expect(find.text('Готово до пошуку'), findsOneWidget);
  });
}

class FakeBleService implements BleService {
  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices =>
      const Stream.empty();

  @override
  Stream<BleConnectionStatus> get connectionStatus => const Stream.empty();

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
  Future<BleDeviceServices> pairAndDiscoverServices({
    required BleDiscoveredDevice device,
    required String passkey,
  }) async {
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
  Future<void> dispose() async {}
}
