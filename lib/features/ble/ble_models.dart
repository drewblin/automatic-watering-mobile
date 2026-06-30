import 'package:flutter/foundation.dart';

import 'ble_constants.dart';

enum BleAvailability {
  ready,
  permissionRequired,
  bluetoothDisabled,
}

enum BleConnectionStatus {
  idle,
  scanning,
  deviceFound,
  connecting,
  reconnecting,
  pairingRequired,
  pairing,
  connected,
  disconnected,
  permissionRequired,
  bluetoothDisabled,
  error,
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
