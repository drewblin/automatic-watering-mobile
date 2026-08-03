import 'package:flutter/foundation.dart';

@immutable
class AutomaticWateringBleCharacteristic {
  const AutomaticWateringBleCharacteristic({
    required this.name,
    required this.uuid,
    required this.properties,
  });

  final String name;
  final String uuid;
  final Set<BleCharacteristicProperty> properties;
}

enum BleCharacteristicProperty {
  read,
  write,
  notify,
}

abstract final class AutomaticWateringBleConstants {
  static const deviceName = 'Automatic Watering Hub';

  static const serviceUuid = '4d42b2d0-35ba-4b70-b8a2-d1cf01e904c1';

  static const wifiSettings = AutomaticWateringBleCharacteristic(
    name: 'WifiSettings',
    uuid: '4d42b2d1-35ba-4b70-b8a2-d1cf01e904c1',
    properties: {BleCharacteristicProperty.read},
  );

  static const saveWifiSettings = AutomaticWateringBleCharacteristic(
    name: 'SaveWifiSettings',
    uuid: '4d42b2d2-35ba-4b70-b8a2-d1cf01e904c1',
    properties: {
      BleCharacteristicProperty.read,
      BleCharacteristicProperty.write,
    },
  );

  static const wifiIpAddress = AutomaticWateringBleCharacteristic(
    name: 'WifiIpAddress',
    uuid: '4d42b2d3-35ba-4b70-b8a2-d1cf01e904c1',
    properties: {BleCharacteristicProperty.read},
  );

  static const apiAccessToken = AutomaticWateringBleCharacteristic(
    name: 'ApiAccessToken',
    uuid: '4d42b2d4-35ba-4b70-b8a2-d1cf01e904c1',
    properties: {BleCharacteristicProperty.read},
  );

  static const logNotifications = AutomaticWateringBleCharacteristic(
    name: 'LogNotifications',
    uuid: '4d42b2d5-35ba-4b70-b8a2-d1cf01e904c1',
    properties: {
      BleCharacteristicProperty.read,
      BleCharacteristicProperty.notify,
    },
  );

  static const expectedCharacteristics = [
    wifiSettings,
    saveWifiSettings,
    wifiIpAddress,
    apiAccessToken,
    logNotifications,
  ];

  static const expectedCharacteristicUuids = {
    '4d42b2d1-35ba-4b70-b8a2-d1cf01e904c1',
    '4d42b2d2-35ba-4b70-b8a2-d1cf01e904c1',
    '4d42b2d3-35ba-4b70-b8a2-d1cf01e904c1',
    '4d42b2d4-35ba-4b70-b8a2-d1cf01e904c1',
    '4d42b2d5-35ba-4b70-b8a2-d1cf01e904c1',
  };
}
