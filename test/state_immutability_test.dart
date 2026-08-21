import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/device_objects.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/onboarding/ble_onboarding_state.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/plan/plan_schema.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_settings_sync_test.dart';

void main() {
  test('AppState defensively copies device objects', () {
    final settings = SettingsResponseData.fromJson(settingsResponseDataJson);
    final deviceObjects = List.of(
      buildDeviceObjects(
        wateringHubId: 'hub-aa-bb-cc',
        settings: settings.settings,
      ),
    );
    final state = AppState.readyWithHub(
      activeWateringHub: _hub(),
      activePlanSchema: null,
      settings: settings,
      deviceObjects: deviceObjects,
    );

    deviceObjects.clear();

    expect(state.deviceObjects, hasLength(4));
    expect(
      () => state.deviceObjects.clear(),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('ControllerSettings defensively copies shared setting lists', () {
    final settings =
        SettingsResponseData.fromJson(settingsResponseDataJson).settings;
    final valves = List.of(settings.valveSettings);
    final leafCounters = List.of(settings.leafWaterCounterSettings);
    final soilSensors = List.of(settings.soilSensorSettings);
    final copied = ControllerSettings(
      globalSettings: settings.globalSettings,
      remoteLogSettings: settings.remoteLogSettings,
      valveSettings: valves,
      pressureSensor: settings.pressureSensor,
      magistralWaterCounterSetting: settings.magistralWaterCounterSetting,
      leafWaterCounterSettings: leafCounters,
      soilSensorSettings: soilSensors,
    );

    valves.clear();
    leafCounters.clear();
    soilSensors.clear();

    expect(copied.valveSettings, hasLength(1));
    expect(copied.leafWaterCounterSettings, isEmpty);
    expect(copied.soilSensorSettings, hasLength(1));
    expect(
      () => copied.valveSettings.clear(),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('PlanSchema defensively copies plan element lists', () {
    final zonePoints = [
      const NormalizedPoint(x: 0.1, y: 0.1),
      const NormalizedPoint(x: 0.2, y: 0.2),
    ];
    final zoneShape = ZoneShapeElement(
      id: 'zone-1',
      points: zonePoints,
      deviceObjectId: 'hub-aa-bb-cc:valve:17',
      style: const ElementStyle(fillColor: '#00aa00'),
    );
    final zoneShapes = [zoneShape];
    final landmarks = <LandmarkElement>[];
    final markers = <DeviceObjectMarker>[];
    final schema = PlanSchema(
      id: 'plan-1',
      wateringHubId: 'hub-aa-bb-cc',
      version: 1,
      canvasSize: CanvasSize.normalized(),
      zoneShapes: zoneShapes,
      landmarks: landmarks,
      deviceMarkers: markers,
    );

    zonePoints.clear();
    zoneShapes.clear();
    landmarks.add(
      LandmarkElement(
        id: 'landmark-1',
        type: LandmarkElementType.landmark,
        label: null,
        geometry: PlanGeometry.position(const NormalizedPoint(x: 0.5, y: 0.5)),
        style: const ElementStyle(),
      ),
    );

    expect(schema.zoneShapes, hasLength(1));
    expect(schema.zoneShapes.single.points, hasLength(2));
    expect(schema.landmarks, isEmpty);
    expect(
      () => schema.zoneShapes.clear(),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('onboarding state defensively copies discovered devices and Wi-Fi data',
      () {
    final devices = [_device()];
    final discovering = DiscoveringDevices(foundDevices: devices);

    devices.clear();

    expect(discovering.devices, hasLength(1));
    expect(
      () => discovering.devices.clear(),
      throwsA(isA<UnsupportedError>()),
    );

    final validationErrors = {'ssid': 'error'};
    final networks = [const PhoneWifiNetwork(ssid: 'Garden')];
    final formReady = WifiCredentialsFormReady(
      device: _device(),
      credentials: const WifiCredentials(ssid: 'Garden', password: ''),
      validationErrors: validationErrors,
      phoneWifiNetworks: networks,
    );
    final snapshot = PhoneWifiSnapshot(networks: networks);

    validationErrors.clear();
    networks.clear();

    expect(formReady.wifiValidationErrors, {'ssid': 'error'});
    expect(formReady.phoneWifiNetworks, hasLength(1));
    expect(snapshot.networks, hasLength(1));
  });
}

WateringHub _hub() {
  final createdAt = DateTime.utc(2026);
  return WateringHub(
    id: 'hub-aa-bb-cc',
    displayName: 'Automatic Watering Hub',
    bleDeviceId: 'AA:BB:CC',
    lastKnownIpAddress: '192.168.1.42',
    lastKnownHostname: 'watering-hub-a1b2c3.local',
    apiAccessToken: 'token',
    serverDeviceId: null,
    onboardingCompletedAt: createdAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

BleDiscoveredDevice _device() {
  return const BleDiscoveredDevice(
    id: 'AA:BB:CC',
    name: 'Automatic Watering Hub',
    rssi: -40,
    isLikelyAutomaticWateringHub: true,
    advertisedServiceUuids: {},
  );
}
