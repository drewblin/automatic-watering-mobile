import 'dart:convert';

import 'controller_settings.dart';

const controllerSettingsCollectionLimit = 32;
const controllerSettingsMaxIntervalSeconds = 2147483;

class ControllerSettingsFormDraft {
  ControllerSettingsFormDraft({
    required this.globalSettings,
    required this.remoteLogSettings,
    required this.valves,
    required this.pressureSensor,
    required this.magistralWaterCounter,
    required this.leafWaterCounters,
    required this.soilSensors,
  });

  factory ControllerSettingsFormDraft.fromSettings(
    ControllerSettings settings,
  ) {
    return ControllerSettingsFormDraft(
      globalSettings: GlobalSettingsDraft.fromSettings(settings.globalSettings),
      remoteLogSettings:
          RemoteLogSettingsDraft.fromSettings(settings.remoteLogSettings),
      valves: settings.valveSettings
          .map((setting) => ValveSettingDraft.fromSettings(setting))
          .toList(),
      pressureSensor: settings.pressureSensor == null
          ? null
          : PressureSensorSettingDraft.fromSettings(settings.pressureSensor!),
      magistralWaterCounter: settings.magistralWaterCounterSetting == null
          ? null
          : WaterCounterSettingDraft.fromSettings(
              settings.magistralWaterCounterSetting!,
            ),
      leafWaterCounters: settings.leafWaterCounterSettings
          .map((setting) => WaterCounterSettingDraft.fromSettings(setting))
          .toList(),
      soilSensors: settings.soilSensorSettings
          .map((setting) => SoilSensorSettingDraft.fromSettings(setting))
          .toList(),
    );
  }

  final GlobalSettingsDraft globalSettings;
  final RemoteLogSettingsDraft remoteLogSettings;
  final List<ValveSettingDraft> valves;
  PressureSensorSettingDraft? pressureSensor;
  WaterCounterSettingDraft? magistralWaterCounter;
  final List<WaterCounterSettingDraft> leafWaterCounters;
  final List<SoilSensorSettingDraft> soilSensors;

  ControllerSettings buildSettings() {
    return ControllerSettings(
      globalSettings: globalSettings.buildSettings(),
      remoteLogSettings: remoteLogSettings.buildSettings(),
      valveSettings: valves.map((setting) => setting.buildSettings()).toList(),
      pressureSensor: pressureSensor?.buildSettings(),
      magistralWaterCounterSetting: magistralWaterCounter?.buildSettings(),
      leafWaterCounterSettings:
          leafWaterCounters.map((setting) => setting.buildSettings()).toList(),
      soilSensorSettings:
          soilSensors.map((setting) => setting.buildSettings()).toList(),
    );
  }

  bool differsFrom(ControllerSettings settings) {
    try {
      return jsonEncode(buildSettings().toJson()) !=
          jsonEncode(settings.toJson());
    } catch (_) {
      return true;
    }
  }

  ControllerSettingsValidationResult validate() {
    final errors = <String, String>{};

    globalSettings.addErrors(errors);
    remoteLogSettings.addErrors(errors);

    if (valves.length > controllerSettingsCollectionLimit) {
      errors['valves'] = 'Кількість клапанів не має перевищувати 32.';
    }
    if (soilSensors.length > controllerSettingsCollectionLimit) {
      errors['soilSensors'] =
          'Кількість датчиків вологості не має перевищувати 32.';
    }
    if (leafWaterCounters.length > controllerSettingsCollectionLimit) {
      errors['leafWaterCounters'] =
          'Кількість лічильників гілок не має перевищувати 32.';
    }

    for (var i = 0; i < soilSensors.length; i += 1) {
      soilSensors[i].addErrors(errors, 'soilSensors.$i');
    }
    pressureSensor?.addErrors(errors, 'pressureSensor');
    magistralWaterCounter?.addErrors(errors, 'magistralWaterCounter');
    for (var i = 0; i < leafWaterCounters.length; i += 1) {
      leafWaterCounters[i].addErrors(errors, 'leafWaterCounters.$i');
    }
    for (var i = 0; i < valves.length; i += 1) {
      valves[i].addErrors(errors, 'valves.$i');
    }

    final soilAddresses = <int, String>{};
    for (var i = 0; i < soilSensors.length; i += 1) {
      final address = soilSensors[i].parsedSlaveAddress;
      if (address != null) {
        final previous = soilAddresses[address];
        if (previous != null) {
          errors['soilSensors.$i.slaveAddress'] =
              'Modbus address вже використовується датчиком вологості.';
          errors[previous] =
              'Modbus address вже використовується датчиком вологості.';
        } else {
          soilAddresses[address] = 'soilSensors.$i.slaveAddress';
        }
      }
    }
    final pressureAddress = pressureSensor?.parsedSlaveAddress;
    if (pressureAddress != null && soilAddresses.containsKey(pressureAddress)) {
      errors['pressureSensor.slaveAddress'] =
          'Modbus address конфліктує з датчиком вологості.';
    }

    final pins = <int, String>{};
    void addPin(int? pin, String key) {
      if (pin == null) {
        return;
      }
      final previous = pins[pin];
      if (previous != null) {
        errors[key] = 'GPIO pin вже використовується.';
        errors[previous] = 'GPIO pin вже використовується.';
      } else {
        pins[pin] = key;
      }
    }

    for (var i = 0; i < valves.length; i += 1) {
      addPin(valves[i].parsedPin, 'valves.$i.pin');
    }
    addPin(magistralWaterCounter?.parsedPin, 'magistralWaterCounter.pin');
    for (var i = 0; i < leafWaterCounters.length; i += 1) {
      addPin(leafWaterCounters[i].parsedPin, 'leafWaterCounters.$i.pin');
    }

    final validSoilAddresses = soilSensors
        .map((sensor) => sensor.parsedSlaveAddress)
        .whereType<int>()
        .toSet();
    for (var i = 0; i < valves.length; i += 1) {
      final address = valves[i].soilSensorSlaveAddress;
      if (address == null || !validSoilAddresses.contains(address)) {
        errors['valves.$i.soilSensorSlaveAddress'] =
            'Оберіть існуючий датчик вологості.';
      }
    }

    return ControllerSettingsValidationResult(errors);
  }
}

class ControllerSettingsValidationResult {
  const ControllerSettingsValidationResult(this.errors);

  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;

  String? operator [](String key) => errors[key];
}

class GlobalSettingsDraft {
  GlobalSettingsDraft({
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
    required this.wateringWindowStartHour,
    required this.wateringWindowStartMinute,
    required this.wateringWindowEndHour,
    required this.wateringWindowEndMinute,
    required this.zoneWateringDurationSeconds,
    required this.zoneWateringRetryDelaySeconds,
  });

  factory GlobalSettingsDraft.fromSettings(GlobalSettings settings) {
    return GlobalSettingsDraft(
      idleWaterCounterReadIntervalSeconds:
          settings.idleWaterCounterReadIntervalSeconds.toString(),
      wateringWaterCounterReadIntervalSeconds:
          settings.wateringWaterCounterReadIntervalSeconds.toString(),
      idlePressureSensorReadIntervalSeconds:
          settings.idlePressureSensorReadIntervalSeconds.toString(),
      wateringPressureSensorReadIntervalSeconds:
          settings.wateringPressureSensorReadIntervalSeconds.toString(),
      idleSoilSensorReadIntervalSeconds:
          settings.idleSoilSensorReadIntervalSeconds.toString(),
      wateringSoilSensorReadIntervalSeconds:
          settings.wateringSoilSensorReadIntervalSeconds.toString(),
      maximumManualValveOpenTimeSeconds:
          settings.maximumManualValveOpenTimeSeconds.toString(),
      startWateringBelowHumidityPercent:
          settings.startWateringBelowHumidityPercent.toString(),
      stopWateringAboveHumidityPercent:
          settings.stopWateringAboveHumidityPercent.toString(),
      wateringStartMode: settings.wateringStartMode,
      wateringWindowStartHour:
          settings.wateringWindowStartTime?.hour.toString(),
      wateringWindowStartMinute:
          settings.wateringWindowStartTime?.minute.toString(),
      wateringWindowEndHour: settings.wateringWindowEndTime?.hour.toString(),
      wateringWindowEndMinute:
          settings.wateringWindowEndTime?.minute.toString(),
      zoneWateringDurationSeconds:
          settings.zoneWateringDurationSeconds.toString(),
      zoneWateringRetryDelaySeconds:
          settings.zoneWateringRetryDelaySeconds.toString(),
    );
  }

  String idleWaterCounterReadIntervalSeconds;
  String wateringWaterCounterReadIntervalSeconds;
  String idlePressureSensorReadIntervalSeconds;
  String wateringPressureSensorReadIntervalSeconds;
  String idleSoilSensorReadIntervalSeconds;
  String wateringSoilSensorReadIntervalSeconds;
  String maximumManualValveOpenTimeSeconds;
  String startWateringBelowHumidityPercent;
  String stopWateringAboveHumidityPercent;
  WateringStartMode wateringStartMode;
  String? wateringWindowStartHour;
  String? wateringWindowStartMinute;
  String? wateringWindowEndHour;
  String? wateringWindowEndMinute;
  String zoneWateringDurationSeconds;
  String zoneWateringRetryDelaySeconds;

  GlobalSettings buildSettings() {
    return GlobalSettings(
      idleWaterCounterReadIntervalSeconds:
          int.parse(idleWaterCounterReadIntervalSeconds),
      wateringWaterCounterReadIntervalSeconds:
          int.parse(wateringWaterCounterReadIntervalSeconds),
      idlePressureSensorReadIntervalSeconds:
          int.parse(idlePressureSensorReadIntervalSeconds),
      wateringPressureSensorReadIntervalSeconds:
          int.parse(wateringPressureSensorReadIntervalSeconds),
      idleSoilSensorReadIntervalSeconds:
          int.parse(idleSoilSensorReadIntervalSeconds),
      wateringSoilSensorReadIntervalSeconds:
          int.parse(wateringSoilSensorReadIntervalSeconds),
      maximumManualValveOpenTimeSeconds:
          int.parse(maximumManualValveOpenTimeSeconds),
      startWateringBelowHumidityPercent:
          int.parse(startWateringBelowHumidityPercent),
      stopWateringAboveHumidityPercent:
          int.parse(stopWateringAboveHumidityPercent),
      wateringStartMode: wateringStartMode,
      wateringWindowStartTime:
          wateringStartMode == WateringStartMode.withinWateringWindow
              ? _buildTime(
                  wateringWindowStartHour,
                  wateringWindowStartMinute,
                )
              : null,
      wateringWindowEndTime:
          wateringStartMode == WateringStartMode.withinWateringWindow
              ? _buildTime(
                  wateringWindowEndHour,
                  wateringWindowEndMinute,
                )
              : null,
      zoneWateringDurationSeconds: int.parse(zoneWateringDurationSeconds),
      zoneWateringRetryDelaySeconds: int.parse(zoneWateringRetryDelaySeconds),
    );
  }

  void addErrors(Map<String, String> errors) {
    _readInterval(
      idleWaterCounterReadIntervalSeconds,
      'global.idleWaterCounterReadIntervalSeconds',
      errors,
    );
    _readInterval(
      wateringWaterCounterReadIntervalSeconds,
      'global.wateringWaterCounterReadIntervalSeconds',
      errors,
    );
    _readInterval(
      idlePressureSensorReadIntervalSeconds,
      'global.idlePressureSensorReadIntervalSeconds',
      errors,
    );
    _readInterval(
      wateringPressureSensorReadIntervalSeconds,
      'global.wateringPressureSensorReadIntervalSeconds',
      errors,
    );
    _readInterval(
      idleSoilSensorReadIntervalSeconds,
      'global.idleSoilSensorReadIntervalSeconds',
      errors,
    );
    _readInterval(
      wateringSoilSensorReadIntervalSeconds,
      'global.wateringSoilSensorReadIntervalSeconds',
      errors,
    );
    _readInterval(
      maximumManualValveOpenTimeSeconds,
      'global.maximumManualValveOpenTimeSeconds',
      errors,
    );
    final start = _readIntRange(
      startWateringBelowHumidityPercent,
      'global.startWateringBelowHumidityPercent',
      0,
      100,
      'Значення має бути від 0 до 100.',
      errors,
    );
    final stop = _readIntRange(
      stopWateringAboveHumidityPercent,
      'global.stopWateringAboveHumidityPercent',
      0,
      100,
      'Значення має бути від 0 до 100.',
      errors,
    );
    if (start != null && stop != null && stop <= start) {
      errors['global.stopWateringAboveHumidityPercent'] =
          'Поріг зупинки має бути більшим за поріг старту.';
    }
    _readInterval(
      zoneWateringDurationSeconds,
      'global.zoneWateringDurationSeconds',
      errors,
    );
    _readInterval(
      zoneWateringRetryDelaySeconds,
      'global.zoneWateringRetryDelaySeconds',
      errors,
    );
    if (wateringStartMode == WateringStartMode.withinWateringWindow) {
      _readTime(
        wateringWindowStartHour,
        wateringWindowStartMinute,
        'global.wateringWindowStartTime',
        errors,
      );
      _readTime(
        wateringWindowEndHour,
        wateringWindowEndMinute,
        'global.wateringWindowEndTime',
        errors,
      );
    }
  }
}

class RemoteLogSettingsDraft {
  RemoteLogSettingsDraft({required this.url, required this.token});

  factory RemoteLogSettingsDraft.fromSettings(RemoteLogSettings settings) {
    return RemoteLogSettingsDraft(url: settings.url, token: settings.token);
  }

  String url;
  String token;

  RemoteLogSettings buildSettings() =>
      RemoteLogSettings(url: url, token: token);

  void addErrors(Map<String, String> errors) {}
}

class ValveSettingDraft {
  ValveSettingDraft({
    required this.pin,
    required this.name,
    required this.soilSensorSlaveAddress,
  });

  factory ValveSettingDraft.fromSettings(ValveSetting setting) {
    return ValveSettingDraft(
      pin: setting.pin.toString(),
      name: setting.name,
      soilSensorSlaveAddress: setting.soilSensorSlaveAddress,
    );
  }

  String pin;
  String name;
  int? soilSensorSlaveAddress;

  int? get parsedPin => int.tryParse(pin);

  ValveSetting buildSettings() {
    return ValveSetting(
      pin: int.parse(pin),
      name: name.trim(),
      soilSensorSlaveAddress: soilSensorSlaveAddress!,
    );
  }

  void addErrors(Map<String, String> errors, String prefix) {
    _readInt(pin, '$prefix.pin', 'GPIO pin має бути цілим числом.', errors);
    _readRequiredName(name, '$prefix.name', errors);
  }
}

class PressureSensorSettingDraft {
  PressureSensorSettingDraft({required this.slaveAddress, required this.name});

  factory PressureSensorSettingDraft.fromSettings(
    PressureSensorSetting setting,
  ) {
    return PressureSensorSettingDraft(
      slaveAddress: setting.slaveAddress.toString(),
      name: setting.name,
    );
  }

  String slaveAddress;
  String name;

  int? get parsedSlaveAddress => int.tryParse(slaveAddress);

  PressureSensorSetting buildSettings() {
    return PressureSensorSetting(
      slaveAddress: int.parse(slaveAddress),
      name: name.trim(),
    );
  }

  void addErrors(Map<String, String> errors, String prefix) {
    _readModbusAddress(slaveAddress, '$prefix.slaveAddress', errors);
    _readRequiredName(name, '$prefix.name', errors);
  }
}

class SoilSensorSettingDraft {
  SoilSensorSettingDraft({required this.slaveAddress, required this.name});

  factory SoilSensorSettingDraft.fromSettings(SoilSensorSetting setting) {
    return SoilSensorSettingDraft(
      slaveAddress: setting.slaveAddress.toString(),
      name: setting.name,
    );
  }

  String slaveAddress;
  String name;

  int? get parsedSlaveAddress => int.tryParse(slaveAddress);

  SoilSensorSetting buildSettings() {
    return SoilSensorSetting(
      slaveAddress: int.parse(slaveAddress),
      name: name.trim(),
    );
  }

  void addErrors(Map<String, String> errors, String prefix) {
    _readModbusAddress(slaveAddress, '$prefix.slaveAddress', errors);
    _readRequiredName(name, '$prefix.name', errors);
  }
}

class WaterCounterSettingDraft {
  WaterCounterSettingDraft({
    required this.pin,
    required this.name,
    required this.litersPerTick,
  });

  factory WaterCounterSettingDraft.fromSettings(WaterCounterSetting setting) {
    return WaterCounterSettingDraft(
      pin: setting.pin.toString(),
      name: setting.name,
      litersPerTick: setting.litersPerTick.toString(),
    );
  }

  String pin;
  String name;
  String litersPerTick;

  int? get parsedPin => int.tryParse(pin);

  WaterCounterSetting buildSettings() {
    return WaterCounterSetting(
      pin: int.parse(pin),
      name: name.trim(),
      litersPerTick: double.parse(litersPerTick),
    );
  }

  void addErrors(Map<String, String> errors, String prefix) {
    _readInt(pin, '$prefix.pin', 'GPIO pin має бути цілим числом.', errors);
    _readRequiredName(name, '$prefix.name', errors);
    final value = double.tryParse(litersPerTick);
    if (value == null || !value.isFinite || value <= 0) {
      errors['$prefix.litersPerTick'] =
          'Літрів за імпульс має бути додатним числом.';
    }
  }
}

TimeOfDaySetting? _buildTime(String? hour, String? minute) {
  if ((hour == null || hour.isEmpty) && (minute == null || minute.isEmpty)) {
    return null;
  }
  return TimeOfDaySetting(hour: int.parse(hour!), minute: int.parse(minute!));
}

int? _readInterval(String value, String key, Map<String, String> errors) {
  return _readIntRange(
    value,
    key,
    1,
    controllerSettingsMaxIntervalSeconds,
    'Значення має бути від 1 до 2147483 секунд.',
    errors,
  );
}

int? _readModbusAddress(
  String value,
  String key,
  Map<String, String> errors,
) {
  return _readIntRange(
    value,
    key,
    1,
    247,
    'Modbus address має бути від 1 до 247.',
    errors,
  );
}

int? _readIntRange(
  String value,
  String key,
  int min,
  int max,
  String message,
  Map<String, String> errors,
) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < min || parsed > max) {
    errors[key] = message;
    return null;
  }
  return parsed;
}

int? _readInt(
  String value,
  String key,
  String message,
  Map<String, String> errors,
) {
  final parsed = int.tryParse(value);
  if (parsed == null) {
    errors[key] = message;
  }
  return parsed;
}

void _readRequiredName(
  String value,
  String key,
  Map<String, String> errors,
) {
  if (value.trim().isEmpty) {
    errors[key] = 'Назва не має бути порожньою.';
  }
}

void _readTime(
  String? hour,
  String? minute,
  String key,
  Map<String, String> errors,
) {
  final parsedHour = int.tryParse(hour ?? '');
  final parsedMinute = int.tryParse(minute ?? '');
  if (parsedHour == null ||
      parsedHour < 0 ||
      parsedHour > 23 ||
      parsedMinute == null ||
      parsedMinute < 0 ||
      parsedMinute > 59) {
    errors[key] = 'Вкажіть час у межах 00:00-23:59.';
  }
}
