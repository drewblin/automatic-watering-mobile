import 'package:flutter/foundation.dart';

import '../ble/ble_models.dart';
import 'wifi_provisioning_models.dart';

@immutable
sealed class BleOnboardingState {
  const BleOnboardingState();

  List<BleDiscoveredDevice> get devices => const [];

  BleDiscoveredDevice? get selectedDevice => null;

  BleConnectionError? get bleError => null;

  WifiProvisioningError? get wifiError => null;

  WifiCredentials get wifiCredentials => WifiCredentials.empty();

  Map<String, String> get wifiValidationErrors => const {};

  bool get canSaveWifi => false;

  String? get controllerIpAddress => null;

  ControllerAccessError? get controllerAccessError => null;
}

final class CheckingBluetooth extends BleOnboardingState {
  const CheckingBluetooth();
}

final class BluetoothUnavailable extends BleOnboardingState {
  const BluetoothUnavailable({required this.availability});

  final BleAvailability availability;
}

final class ReadyToScan extends BleOnboardingState {
  const ReadyToScan({this.error});

  final BleConnectionError? error;

  @override
  BleConnectionError? get bleError => error;
}

final class DiscoveringDevices extends BleOnboardingState {
  const DiscoveringDevices({required this.foundDevices});

  final List<BleDiscoveredDevice> foundDevices;

  @override
  List<BleDiscoveredDevice> get devices => foundDevices;
}

final class DeviceSelected extends BleOnboardingState {
  const DeviceSelected({
    required this.foundDevices,
    required this.device,
    this.error,
  });

  final List<BleDiscoveredDevice> foundDevices;
  final BleDiscoveredDevice device;
  final BleConnectionError? error;

  @override
  List<BleDiscoveredDevice> get devices => foundDevices;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  BleConnectionError? get bleError => error;
}

final class ConnectingDevice extends BleOnboardingState {
  const ConnectingDevice({
    required this.foundDevices,
    required this.device,
  });

  final List<BleDiscoveredDevice> foundDevices;
  final BleDiscoveredDevice device;

  @override
  List<BleDiscoveredDevice> get devices => foundDevices;

  @override
  BleDiscoveredDevice? get selectedDevice => device;
}

final class AwaitingPairingPasskey extends BleOnboardingState {
  const AwaitingPairingPasskey({
    required this.foundDevices,
    required this.device,
    this.error,
  });

  final List<BleDiscoveredDevice> foundDevices;
  final BleDiscoveredDevice device;
  final BleConnectionError? error;

  @override
  List<BleDiscoveredDevice> get devices => foundDevices;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  BleConnectionError? get bleError => error;
}

final class PairingInProgress extends BleOnboardingState {
  const PairingInProgress({
    required this.foundDevices,
    required this.device,
  });

  final List<BleDiscoveredDevice> foundDevices;
  final BleDiscoveredDevice device;

  @override
  List<BleDiscoveredDevice> get devices => foundDevices;

  @override
  BleDiscoveredDevice? get selectedDevice => device;
}

final class ReadingWifiSettings extends BleOnboardingState {
  const ReadingWifiSettings({required this.device});

  final BleDiscoveredDevice device;

  @override
  BleDiscoveredDevice? get selectedDevice => device;
}

final class WifiCredentialsFormReady extends BleOnboardingState {
  WifiCredentialsFormReady({
    required this.device,
    required this.credentials,
    this.validationErrors = const {},
    this.phoneWifiNetworks = const [],
    this.isLoadingPhoneWifiNetworks = false,
    this.error,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final Map<String, String> validationErrors;
  final List<PhoneWifiNetwork> phoneWifiNetworks;
  final bool isLoadingPhoneWifiNetworks;
  final WifiProvisioningError? error;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  Map<String, String> get wifiValidationErrors => validationErrors;

  @override
  WifiProvisioningError? get wifiError => error;

  @override
  bool get canSaveWifi => true;
}

final class SavingWifiSettings extends BleOnboardingState {
  SavingWifiSettings({
    required this.device,
    required this.credentials,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;
}

final class WaitingForControllerReboot extends BleOnboardingState {
  WaitingForControllerReboot({
    required this.device,
    required this.credentials,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;
}

final class ReconnectingAfterReboot extends BleOnboardingState {
  ReconnectingAfterReboot({
    required this.device,
    required this.credentials,
    required this.attempt,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final int attempt;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;
}

final class ReconnectAfterRebootBlocked extends BleOnboardingState {
  ReconnectAfterRebootBlocked({
    required this.device,
    required this.credentials,
    required this.error,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final WifiProvisioningError error;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  WifiProvisioningError? get wifiError => error;
}

final class AccessSetupReady extends BleOnboardingState {
  AccessSetupReady({
    required this.device,
    required this.credentials,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;
}

enum ControllerAccessFailureKind {
  ipPending,
  tokenInvalid,
  timeout,
  tlsCertificate,
  networkUnavailable,
  controllerUnavailable,
  unexpectedResponse,
}

@immutable
class ControllerAccessError {
  const ControllerAccessError({
    required this.kind,
    required this.message,
    required this.technicalReason,
  });

  final ControllerAccessFailureKind kind;
  final String message;
  final String technicalReason;
}

final class ReadingControllerAccess extends BleOnboardingState {
  ReadingControllerAccess({
    required this.device,
    required this.credentials,
    this.ipAddress,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final String? ipAddress;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  String? get controllerIpAddress => ipAddress;
}

final class CheckingLocalHttpsAccess extends BleOnboardingState {
  CheckingLocalHttpsAccess({
    required this.device,
    required this.credentials,
    required this.ipAddress,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final String ipAddress;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  String? get controllerIpAddress => ipAddress;
}

final class ControllerIpPending extends BleOnboardingState {
  ControllerIpPending({
    required this.device,
    required this.credentials,
    required this.error,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final ControllerAccessError error;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  String? get controllerIpAddress => '0.0.0.0';

  @override
  ControllerAccessError? get controllerAccessError => error;
}

final class ControllerAccessFailed extends BleOnboardingState {
  ControllerAccessFailed({
    required this.device,
    required this.credentials,
    required this.ipAddress,
    required this.error,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final String? ipAddress;
  final ControllerAccessError error;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  String? get controllerIpAddress => ipAddress;

  @override
  ControllerAccessError? get controllerAccessError => error;
}

final class ControllerAccessReady extends BleOnboardingState {
  ControllerAccessReady({
    required this.device,
    required this.credentials,
    required this.ipAddress,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final String ipAddress;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  String? get controllerIpAddress => ipAddress;
}
