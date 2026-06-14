import 'controller_settings.dart';

enum DeviceObjectType {
  valve,
  soilSensor,
  pressureSensor,
  waterCounter;

  String get storageName {
    return switch (this) {
      DeviceObjectType.valve => 'valve',
      DeviceObjectType.soilSensor => 'soil_sensor',
      DeviceObjectType.pressureSensor => 'pressure_sensor',
      DeviceObjectType.waterCounter => 'water_counter',
    };
  }
}

sealed class DeviceObject {
  const DeviceObject({
    required this.id,
    required this.wateringHubId,
    required this.type,
    required this.displayName,
  });

  final String id;
  final String wateringHubId;
  final DeviceObjectType type;
  final String displayName;
}

class ValveObject extends DeviceObject {
  ValveObject({
    required super.wateringHubId,
    required this.setting,
  }) : super(
          id: '$wateringHubId:${DeviceObjectType.valve.storageName}:${setting.pin}',
          type: DeviceObjectType.valve,
          displayName: '${setting.name} (GPIO ${setting.pin})',
        );

  final ValveSetting setting;
}

class SoilSensorObject extends DeviceObject {
  SoilSensorObject({
    required super.wateringHubId,
    required this.setting,
  }) : super(
          id: '$wateringHubId:${DeviceObjectType.soilSensor.storageName}:${setting.slaveAddress}',
          type: DeviceObjectType.soilSensor,
          displayName: '${setting.name} (#${setting.slaveAddress})',
        );

  final SoilSensorSetting setting;
}

class PressureSensorObject extends DeviceObject {
  PressureSensorObject({
    required super.wateringHubId,
    required this.setting,
  }) : super(
          id: '$wateringHubId:${DeviceObjectType.pressureSensor.storageName}:${setting.slaveAddress}',
          type: DeviceObjectType.pressureSensor,
          displayName: '${setting.name} (#${setting.slaveAddress})',
        );

  final PressureSensorSetting setting;
}

class WaterCounterObject extends DeviceObject {
  WaterCounterObject({
    required super.wateringHubId,
    required this.setting,
  }) : super(
          id: '$wateringHubId:${DeviceObjectType.waterCounter.storageName}:${setting.pin}',
          type: DeviceObjectType.waterCounter,
          displayName: '${setting.name} (GPIO ${setting.pin})',
        );

  final WaterCounterSetting setting;
}

List<DeviceObject> buildDeviceObjects({
  required String wateringHubId,
  required ControllerSettings settings,
}) {
  return List<DeviceObject>.unmodifiable([
    ...settings.valveSettings.map(
      (setting) => ValveObject(wateringHubId: wateringHubId, setting: setting),
    ),
    ...settings.soilSensorSettings.map(
      (setting) =>
          SoilSensorObject(wateringHubId: wateringHubId, setting: setting),
    ),
    if (settings.pressureSensor case final pressureSensor?)
      PressureSensorObject(
        wateringHubId: wateringHubId,
        setting: pressureSensor,
      ),
    if (settings.magistralWaterCounterSetting case final counter?)
      WaterCounterObject(
        wateringHubId: wateringHubId,
        setting: counter,
      ),
    ...settings.leafWaterCounterSettings.map(
      (setting) => WaterCounterObject(
        wateringHubId: wateringHubId,
        setting: setting,
      ),
    ),
  ]);
}
