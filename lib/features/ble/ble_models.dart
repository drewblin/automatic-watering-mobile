import 'package:flutter/foundation.dart';

import 'ble_constants.dart';

enum BleAvailability {
  ready,
  permissionRequired,
  bluetoothDisabled,
}

@immutable
class BleDiscoveredDevice {
  const BleDiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.isLikelyAutomaticWateringHub,
    required this.advertisedServiceUuids,
  });

  final String id;
  final String name;
  final int? rssi;
  final bool isLikelyAutomaticWateringHub;
  final Set<String> advertisedServiceUuids;

  String get displayName {
    if (name.trim().isEmpty) {
      return AutomaticWateringBleConstants.deviceName;
    }
    return name;
  }
}

@immutable
class BleConnectionError {
  const BleConnectionError({
    required this.message,
    required this.technicalReason,
  });

  final String message;
  final String technicalReason;

  @override
  String toString() => '$message ($technicalReason)';
}

@immutable
class BleDeviceServices {
  const BleDeviceServices({
    required this.deviceId,
    required this.hasAutomaticWateringService,
    required this.discoveredCharacteristicUuids,
  });

  final String deviceId;
  final bool hasAutomaticWateringService;
  final Set<String> discoveredCharacteristicUuids;

  bool get hasExpectedCharacteristics {
    return discoveredCharacteristicUuids.containsAll(
      AutomaticWateringBleConstants.expectedCharacteristicUuids,
    );
  }
}

@immutable
class ControllerIpAddress {
  const ControllerIpAddress(this.value);

  final String value;

  bool get isPending => value == '0.0.0.0';

  factory ControllerIpAddress.fromJson(Object? data) {
    if (data is! Map<String, Object?>) {
      throw FormatException('Expected WifiIpAddress data object');
    }
    final ipAddress = data['ipAddress'];
    if (ipAddress is! String || ipAddress.trim().isEmpty) {
      throw FormatException('Expected non-empty ipAddress');
    }
    return ControllerIpAddress(ipAddress.trim());
  }
}

@immutable
class ControllerApiAccessToken {
  const ControllerApiAccessToken(this.value);

  final String value;

  factory ControllerApiAccessToken.fromJson(Object? data) {
    if (data is! Map<String, Object?>) {
      throw FormatException('Expected ApiAccessToken data object');
    }
    final token = data['apiAccessToken'];
    if (token is! String || token.trim().isEmpty) {
      throw FormatException('Expected non-empty apiAccessToken');
    }
    return ControllerApiAccessToken(token.trim());
  }
}
