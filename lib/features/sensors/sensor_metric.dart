import '../../core/json_helpers.dart';

enum SensorType {
  pressure,
  waterCounter,
  soilTemperature,
  soilHumidity;

  static SensorType fromJson(Object? value) {
    return switch (value) {
      'pressure' => SensorType.pressure,
      'water_counter' => SensorType.waterCounter,
      'soil_temperature' => SensorType.soilTemperature,
      'soil_humidity' => SensorType.soilHumidity,
      _ => throw FormatException('Unknown sensorType: $value'),
    };
  }

  String toJson() {
    return switch (this) {
      SensorType.pressure => 'pressure',
      SensorType.waterCounter => 'water_counter',
      SensorType.soilTemperature => 'soil_temperature',
      SensorType.soilHumidity => 'soil_humidity',
    };
  }
}

class ControllerSensorMetric {
  const ControllerSensorMetric({
    required this.sensorId,
    required this.sensorType,
    required this.name,
    required this.value,
    required this.uptimeMs,
    required this.receivedAt,
  });

  final int sensorId;
  final SensorType sensorType;
  final String name;
  final double? value;
  final int uptimeMs;
  final DateTime receivedAt;

  factory ControllerSensorMetric.fromJson({
    required Map<String, Object?> json,
    required DateTime receivedAt,
  }) {
    final rawValue = json['value'];
    return ControllerSensorMetric(
      sensorId: readInt(json['sensorId'], 'sensorId'),
      sensorType: SensorType.fromJson(json['sensorType']),
      name: readString(json['name'], 'name'),
      value: rawValue == null ? null : readDouble(rawValue, 'value'),
      uptimeMs: readInt(json['uptimeMs'], 'uptimeMs'),
      receivedAt: receivedAt,
    );
  }
}

class SensorMetric {
  const SensorMetric({
    required this.deviceObjectId,
    required this.sensorId,
    required this.sensorType,
    required this.name,
    required this.value,
    required this.uptimeMs,
    required this.timestamp,
  });

  final String deviceObjectId;
  final int sensorId;
  final SensorType sensorType;
  final String name;
  final double? value;
  final int uptimeMs;
  final DateTime timestamp;

  factory SensorMetric.fromControllerMetric({
    required ControllerSensorMetric metric,
    required String deviceObjectId,
  }) {
    return SensorMetric(
      deviceObjectId: deviceObjectId,
      sensorId: metric.sensorId,
      sensorType: metric.sensorType,
      name: metric.name,
      value: metric.value,
      uptimeMs: metric.uptimeMs,
      timestamp: metric.receivedAt,
    );
  }

  factory SensorMetric.fromJson(Map<String, Object?> json) {
    final rawValue = json['value'];
    return SensorMetric(
      deviceObjectId: readString(json['deviceObjectId'], 'deviceObjectId'),
      sensorId: readInt(json['sensorId'], 'sensorId'),
      sensorType: SensorType.fromJson(json['sensorType']),
      name: readString(json['name'], 'name'),
      value: rawValue == null ? null : readDouble(rawValue, 'value'),
      uptimeMs: readInt(json['uptimeMs'], 'uptimeMs'),
      timestamp: readDateTime(json['timestamp'], 'timestamp'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'deviceObjectId': deviceObjectId,
      'sensorId': sensorId,
      'sensorType': sensorType.toJson(),
      'name': name,
      'value': value,
      'uptimeMs': uptimeMs,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
