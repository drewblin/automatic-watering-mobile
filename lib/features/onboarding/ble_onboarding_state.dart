import 'package:flutter/foundation.dart';

import '../ble/ble_models.dart';

enum BleOnboardingStep {
  discovery,
  pairing,
  paired,
}

@immutable
class BleOnboardingState {
  const BleOnboardingState({
    required this.step,
    required this.devices,
    required this.selectedDevice,
    required this.connectionStatus,
    required this.lastError,
  });

  factory BleOnboardingState.initial() {
    return const BleOnboardingState(
      step: BleOnboardingStep.discovery,
      devices: [],
      selectedDevice: null,
      connectionStatus: BleConnectionStatus.idle,
      lastError: null,
    );
  }

  final BleOnboardingStep step;
  final List<BleDiscoveredDevice> devices;
  final BleDiscoveredDevice? selectedDevice;
  final BleConnectionStatus connectionStatus;
  final BleConnectionError? lastError;

  bool get canContinue {
    return step == BleOnboardingStep.paired &&
        selectedDevice != null &&
        connectionStatus == BleConnectionStatus.connected;
  }

  BleOnboardingState copyWith({
    BleOnboardingStep? step,
    List<BleDiscoveredDevice>? devices,
    BleDiscoveredDevice? selectedDevice,
    BleConnectionStatus? connectionStatus,
    BleConnectionError? lastError,
    bool clearSelectedDevice = false,
    bool clearLastError = false,
  }) {
    return BleOnboardingState(
      step: step ?? this.step,
      devices: devices ?? this.devices,
      selectedDevice:
          clearSelectedDevice ? null : selectedDevice ?? this.selectedDevice,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}
