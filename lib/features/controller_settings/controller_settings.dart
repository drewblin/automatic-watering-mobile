import '../../core/json_helpers.dart';

enum WateringStartMode {
  immediately,
  withinWateringWindow;

  static WateringStartMode fromJson(Object? value) {
    if (value is String) {
      for (final mode in WateringStartMode.values) {
        if (mode.name == value) {
          return mode;
        }
      }
    }
    throw FormatException('Missing or invalid wateringStartMode: $value');
  }

  String toJson() => name;
}

class TimeOfDaySetting {
  const TimeOfDaySetting({
    required this.hour,
    required this.minute,
  });

  final int hour;
  final int minute;

  factory TimeOfDaySetting.fromJson(Map<String, Object?> json) {
    return TimeOfDaySetting(
      hour: readInt(json['hour'], 'hour'),
      minute: readInt(json['minute'], 'minute'),
    );
  }

  Map<String, Object?> toJson() => {'hour': hour, 'minute': minute};
}

class GlobalSettings {
  const GlobalSettings({
    required this.idleWaterCounterReadIntervalSeconds,
    required this.wateringWaterCounterReadIntervalSeconds,
    required this.idlePressureSensorReadIntervalSeconds,
    required this.wateringPressureSensorReadIntervalSeconds,
    required this.idleSoilSensorReadIntervalSeconds,
    required this.wateringSoilSensorReadIntervalSeconds,
    required this.maximumManualValveOpenTimeSeconds,
    required this.startWateringBelowHumidityPercent,
    required this.stopWateringAboveHumidityPercent,
    required this.wateringStartMode,
    required this.wateringWindowStartTime,
    required this.wateringWindowEndTime,
    required this.zoneWateringDurationSeconds,
    required this.zoneWateringRetryDelaySeconds,
  });

  final int idleWaterCounterReadIntervalSeconds;
  final int wateringWaterCounterReadIntervalSeconds;
  final int idlePressureSensorReadIntervalSeconds;
  final int wateringPressureSensorReadIntervalSeconds;
  final int idleSoilSensorReadIntervalSeconds;
  final int wateringSoilSensorReadIntervalSeconds;
  final int maximumManualValveOpenTimeSeconds;
  final int startWateringBelowHumidityPercent;
  final int stopWateringAboveHumidityPercent;
  final WateringStartMode wateringStartMode;
  final TimeOfDaySetting? wateringWindowStartTime;
  final TimeOfDaySetting? wateringWindowEndTime;
  final int zoneWateringDurationSeconds;
  final int zoneWateringRetryDelaySeconds;

  factory GlobalSettings.fromJson(Map<String, Object?> json) {
    return GlobalSettings(
      idleWaterCounterReadIntervalSeconds: readInt(
        json['idleWaterCounterReadIntervalSeconds'],
        'idleWaterCounterReadIntervalSeconds',
      ),
      wateringWaterCounterReadIntervalSeconds: readInt(
        json['wateringWaterCounterReadIntervalSeconds'],
        'wateringWaterCounterReadIntervalSeconds',
      ),
      idlePressureSensorReadIntervalSeconds: readInt(
        json['idlePressureSensorReadIntervalSeconds'],
        'idlePressureSensorReadIntervalSeconds',
      ),
      wateringPressureSensorReadIntervalSeconds: readInt(
        json['wateringPressureSensorReadIntervalSeconds'],
        'wateringPressureSensorReadIntervalSeconds',
      ),
      idleSoilSensorReadIntervalSeconds: readInt(
        json['idleSoilSensorReadIntervalSeconds'],
        'idleSoilSensorReadIntervalSeconds',
      ),
      wateringSoilSensorReadIntervalSeconds: readInt(
        json['wateringSoilSensorReadIntervalSeconds'],
        'wateringSoilSensorReadIntervalSeconds',
      ),
      maximumManualValveOpenTimeSeconds: readInt(
        json['maximumManualValveOpenTimeSeconds'],
        'maximumManualValveOpenTimeSeconds',
      ),
      startWateringBelowHumidityPercent: readInt(
        json['startWateringBelowHumidityPercent'],
        'startWateringBelowHumidityPercent',
      ),
      stopWateringAboveHumidityPercent: readInt(
        json['stopWateringAboveHumidityPercent'],
        'stopWateringAboveHumidityPercent',
      ),
      wateringStartMode: WateringStartMode.fromJson(
        json['wateringStartMode'],
      ),
      wateringWindowStartTime: json['wateringWindowStartTime'] == null
          ? null
          : TimeOfDaySetting.fromJson(
              readObject(
                  json['wateringWindowStartTime'], 'wateringWindowStartTime'),
            ),
      wateringWindowEndTime: json['wateringWindowEndTime'] == null
          ? null
          : TimeOfDaySetting.fromJson(
              readObject(
                  json['wateringWindowEndTime'], 'wateringWindowEndTime'),
            ),
      zoneWateringDurationSeconds: readInt(
        json['zoneWateringDurationSeconds'],
        'zoneWateringDurationSeconds',
      ),
      zoneWateringRetryDelaySeconds: readInt(
        json['zoneWateringRetryDelaySeconds'],
        'zoneWateringRetryDelaySeconds',
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'idleWaterCounterReadIntervalSeconds':
          idleWaterCounterReadIntervalSeconds,
      'wateringWaterCounterReadIntervalSeconds':
          wateringWaterCounterReadIntervalSeconds,
      'idlePressureSensorReadIntervalSeconds':
          idlePressureSensorReadIntervalSeconds,
      'wateringPressureSensorReadIntervalSeconds':
          wateringPressureSensorReadIntervalSeconds,
      'idleSoilSensorReadIntervalSeconds': idleSoilSensorReadIntervalSeconds,
      'wateringSoilSensorReadIntervalSeconds':
          wateringSoilSensorReadIntervalSeconds,
      'maximumManualValveOpenTimeSeconds': maximumManualValveOpenTimeSeconds,
      'startWateringBelowHumidityPercent': startWateringBelowHumidityPercent,
      'stopWateringAboveHumidityPercent': stopWateringAboveHumidityPercent,
      'wateringStartMode': wateringStartMode.toJson(),
      'wateringWindowStartTime': wateringWindowStartTime?.toJson(),
      'wateringWindowEndTime': wateringWindowEndTime?.toJson(),
      'zoneWateringDurationSeconds': zoneWateringDurationSeconds,
      'zoneWateringRetryDelaySeconds': zoneWateringRetryDelaySeconds,
    };
  }
}

class RemoteLogSettings {
  const RemoteLogSettings({required this.url, required this.token});

  final String url;
  final String token;

  factory RemoteLogSettings.fromJson(Map<String, Object?> json) {
    return RemoteLogSettings(
      url: readString(json['url'], 'url'),
      token: readString(json['token'], 'token'),
    );
  }

  Map<String, Object?> toJson() => {'url': url, 'token': token};
}

class ValveSetting {
  const ValveSetting({
    required this.pin,
    required this.name,
    required this.soilSensorSlaveAddress,
  });

  final int pin;
  final String name;
  final int soilSensorSlaveAddress;

  factory ValveSetting.fromJson(Map<String, Object?> json) {
    return ValveSetting(
      pin: readInt(json['pin'], 'pin'),
      name: readString(json['name'], 'name'),
      soilSensorSlaveAddress: readInt(
        json['soilSensorSlaveAddress'],
        'soilSensorSlaveAddress',
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'pin': pin,
      'name': name,
      'soilSensorSlaveAddress': soilSensorSlaveAddress,
    };
  }
}

class PressureSensorSetting {
  const PressureSensorSetting({
    required this.slaveAddress,
    required this.name,
  });

  final int slaveAddress;
  final String name;

  factory PressureSensorSetting.fromJson(Map<String, Object?> json) {
    return PressureSensorSetting(
      slaveAddress: readInt(json['slaveAddress'], 'slaveAddress'),
      name: readString(json['name'], 'name'),
    );
  }

  Map<String, Object?> toJson() => {
        'slaveAddress': slaveAddress,
        'name': name,
      };
}

class WaterCounterSetting {
  const WaterCounterSetting({
    required this.pin,
    required this.name,
    required this.litersPerTick,
  });

  final int pin;
  final String name;
  final double litersPerTick;

  factory WaterCounterSetting.fromJson(Map<String, Object?> json) {
    return WaterCounterSetting(
      pin: readInt(json['pin'], 'pin'),
      name: readString(json['name'], 'name'),
      litersPerTick: readDouble(json['litersPerTick'], 'litersPerTick'),
    );
  }

  Map<String, Object?> toJson() => {
        'pin': pin,
        'name': name,
        'litersPerTick': litersPerTick,
      };
}

class SoilSensorSetting {
  const SoilSensorSetting({
    required this.slaveAddress,
    required this.name,
  });

  final int slaveAddress;
  final String name;

  factory SoilSensorSetting.fromJson(Map<String, Object?> json) {
    return SoilSensorSetting(
      slaveAddress: readInt(json['slaveAddress'], 'slaveAddress'),
      name: readString(json['name'], 'name'),
    );
  }

  Map<String, Object?> toJson() => {
        'slaveAddress': slaveAddress,
        'name': name,
      };
}

class ControllerSettings {
  ControllerSettings({
    required this.globalSettings,
    required this.remoteLogSettings,
    required List<ValveSetting> valveSettings,
    required this.pressureSensor,
    required this.magistralWaterCounterSetting,
    required List<WaterCounterSetting> leafWaterCounterSettings,
    required List<SoilSensorSetting> soilSensorSettings,
  })  : valveSettings = List<ValveSetting>.unmodifiable(valveSettings),
        leafWaterCounterSettings =
            List<WaterCounterSetting>.unmodifiable(leafWaterCounterSettings),
        soilSensorSettings =
            List<SoilSensorSetting>.unmodifiable(soilSensorSettings);

  final GlobalSettings globalSettings;
  final RemoteLogSettings remoteLogSettings;
  final List<ValveSetting> valveSettings;
  final PressureSensorSetting? pressureSensor;
  final WaterCounterSetting? magistralWaterCounterSetting;
  final List<WaterCounterSetting> leafWaterCounterSettings;
  final List<SoilSensorSetting> soilSensorSettings;

  factory ControllerSettings.fromJson(Map<String, Object?> json) {
    return ControllerSettings(
      globalSettings: GlobalSettings.fromJson(
        readObject(json['globalSettings'], 'globalSettings'),
      ),
      remoteLogSettings: RemoteLogSettings.fromJson(
        readObject(json['remoteLogSettings'], 'remoteLogSettings'),
      ),
      valveSettings: readList(
        json['valveSettings'],
        'valveSettings',
        (item) => ValveSetting.fromJson(readObject(item, 'valveSettings[]')),
      ),
      pressureSensor: json['pressureSensor'] == null
          ? null
          : PressureSensorSetting.fromJson(
              readObject(json['pressureSensor'], 'pressureSensor'),
            ),
      magistralWaterCounterSetting: json['magistralWaterCounterSetting'] == null
          ? null
          : WaterCounterSetting.fromJson(
              readObject(
                json['magistralWaterCounterSetting'],
                'magistralWaterCounterSetting',
              ),
            ),
      leafWaterCounterSettings: readList(
        json['leafWaterCounterSettings'],
        'leafWaterCounterSettings',
        (item) => WaterCounterSetting.fromJson(
          readObject(item, 'leafWaterCounterSettings[]'),
        ),
      ),
      soilSensorSettings: readList(
        json['soilSensorSettings'],
        'soilSensorSettings',
        (item) => SoilSensorSetting.fromJson(
          readObject(item, 'soilSensorSettings[]'),
        ),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'globalSettings': globalSettings.toJson(),
      'remoteLogSettings': remoteLogSettings.toJson(),
      'valveSettings':
          valveSettings.map((setting) => setting.toJson()).toList(),
      'pressureSensor': pressureSensor?.toJson(),
      'magistralWaterCounterSetting': magistralWaterCounterSetting?.toJson(),
      'leafWaterCounterSettings':
          leafWaterCounterSettings.map((setting) => setting.toJson()).toList(),
      'soilSensorSettings':
          soilSensorSettings.map((setting) => setting.toJson()).toList(),
    };
  }
}
