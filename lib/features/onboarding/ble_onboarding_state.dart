import 'package:flutter/foundation.dart';

import '../ble/ble_models.dart';
import 'wifi_provisioning_models.dart';

enum BleOnboardingStep {
  discovery,
  pairing,
  paired,
  wifiProvisioning,
  accessBootstrap,
}

enum WifiProvisioningStatus {
  idle,
  reading,
  ready,
  saving,
  rebooting,
  reconnecting,
  completed,
}

@immutable
class BleOnboardingState {
  const BleOnboardingState({
    required this.step,
    required this.devices,
    required this.selectedDevice,
    required this.connectionStatus,
    required this.lastError,
    required this.wifiCredentials,
    required this.wifiValidationErrors,
    required this.wifiStatus,
    required this.wifiError,
  });

  factory BleOnboardingState.initial() {
    return const BleOnboardingState(
      step: BleOnboardingStep.discovery,
      devices: [],
      selectedDevice: null,
      connectionStatus: BleConnectionStatus.idle,
      lastError: null,
      wifiCredentials: WifiCredentials(ssid: '', password: ''),
      wifiValidationErrors: {},
      wifiStatus: WifiProvisioningStatus.idle,
      wifiError: null,
    );
  }

  final BleOnboardingStep step;
  final List<BleDiscoveredDevice> devices;
  final BleDiscoveredDevice? selectedDevice;
  final BleConnectionStatus connectionStatus;
  final BleConnectionError? lastError;
  final WifiCredentials wifiCredentials;
  final Map<String, String> wifiValidationErrors;
  final WifiProvisioningStatus wifiStatus;
  final WifiProvisioningError? wifiError;

  bool get canContinue {
    return step == BleOnboardingStep.paired &&
        selectedDevice != null &&
        connectionStatus == BleConnectionStatus.connected;
  }

  bool get canSaveWifi {
    return step == BleOnboardingStep.wifiProvisioning &&
        connectionStatus == BleConnectionStatus.connected &&
        wifiStatus != WifiProvisioningStatus.reading &&
        wifiStatus != WifiProvisioningStatus.saving &&
        wifiStatus != WifiProvisioningStatus.rebooting &&
        wifiStatus != WifiProvisioningStatus.reconnecting;
  }

  BleOnboardingState copyWith({
    BleOnboardingStep? step,
    List<BleDiscoveredDevice>? devices,
    BleDiscoveredDevice? selectedDevice,
    BleConnectionStatus? connectionStatus,
    BleConnectionError? lastError,
    WifiCredentials? wifiCredentials,
    Map<String, String>? wifiValidationErrors,
    WifiProvisioningStatus? wifiStatus,
    WifiProvisioningError? wifiError,
    bool clearSelectedDevice = false,
    bool clearLastError = false,
    bool clearWifiValidationErrors = false,
    bool clearWifiError = false,
  }) {
    return BleOnboardingState(
      step: step ?? this.step,
      devices: devices ?? this.devices,
      selectedDevice:
          clearSelectedDevice ? null : selectedDevice ?? this.selectedDevice,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      wifiCredentials: wifiCredentials ?? this.wifiCredentials,
      wifiValidationErrors: clearWifiValidationErrors
          ? const {}
          : wifiValidationErrors ?? this.wifiValidationErrors,
      wifiStatus: wifiStatus ?? this.wifiStatus,
      wifiError: clearWifiError ? null : wifiError ?? this.wifiError,
    );
  }
}
