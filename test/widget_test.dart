import 'package:flutter_test/flutter_test.dart';

import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/automatic_watering_app.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_controller.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
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
    await tester.pump();
    await tester.pump();

    expect(find.text('Автоматичний полив'), findsOneWidget);
    expect(find.text('Додати контролер'), findsOneWidget);
    expect(find.text('Готово до пошуку'), findsOneWidget);
  });

  testWidgets('keeps onboarding visible until controller access is complete',
      (tester) async {
    final createdAt = DateTime.utc(2026);
    final storage = InMemoryWateringHubStorage();
    final tokenStorage = InMemoryWateringHubTokenStorage();
    final appController = AppController(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
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
    await appController.saveActiveWateringHub(incompleteHub);
    await tester.pump();

    expect(find.text('Додати контролер'), findsOneWidget);
    expect(find.text('Automatic Watering Hub'), findsNothing);

    final completeHub = incompleteHub.copyWith(
      lastKnownIpAddress: '192.168.1.42',
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await appController.saveControllerAccess(
      hub: completeHub,
      apiAccessToken: validToken,
    );
    await appController.completeOnboarding();
    await tester.pump();

    expect(find.text('Додати контролер'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
    expect(find.text('Стан контролера: онлайн'), findsOneWidget);
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
    final appController = AppController(
      wateringHubStorage: storage,
      tokenStorage: tokenStorage,
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
    await tester.pump();
    await tester.pump();

    expect(find.text('Додати контролер'), findsNothing);
    expect(find.text('Automatic Watering Hub'), findsOneWidget);
    expect(find.text('Стан контролера: офлайн'), findsOneWidget);
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
    final appController = AppController(
      wateringHubStorage: storage,
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
    await tester.pump();
    await tester.pump();

    expect(find.text('Додати контролер'), findsOneWidget);
  });
}

const validToken =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

class FakeBleService implements BleService {
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
  Future<void> reconnect(BleDiscoveredDevice device) async {}

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
