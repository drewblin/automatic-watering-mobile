import 'package:flutter/foundation.dart';

import '../../core/json_helpers.dart';
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
  });

  final String message;

  @override
  String toString() => message;
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
  const ControllerIpAddress(
    this.ipAddress, {
    required this.hostname,
    required this.localHostname,
  });

  final String ipAddress;
  final String hostname;
  final String localHostname;

  String get value => preferredHost;

  String get preferredHost => localHostname;

  bool get isPending => ipAddress == '0.0.0.0';

  factory ControllerIpAddress.fromJson(Object? data) {
    final json = readObject(data, 'WifiIpAddress data');
    return ControllerIpAddress(
      readString(json['ipAddress'], 'ipAddress'),
      hostname: readString(json['hostname'], 'hostname'),
      localHostname: readString(json['localHostname'], 'localHostname'),
    );
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
