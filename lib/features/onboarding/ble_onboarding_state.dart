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

  String? get controllerAccessErrorMessage => null;
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
  DiscoveringDevices({required List<BleDiscoveredDevice> foundDevices})
      : foundDevices = List<BleDiscoveredDevice>.unmodifiable(foundDevices);

  final List<BleDiscoveredDevice> foundDevices;

  @override
  List<BleDiscoveredDevice> get devices => foundDevices;
}

final class DeviceSelected extends BleOnboardingState {
  DeviceSelected({
    required List<BleDiscoveredDevice> foundDevices,
    required this.device,
    this.error,
  }) : foundDevices = List<BleDiscoveredDevice>.unmodifiable(foundDevices);

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
  ConnectingDevice({
    required List<BleDiscoveredDevice> foundDevices,
    required this.device,
  }) : foundDevices = List<BleDiscoveredDevice>.unmodifiable(foundDevices);

  final List<BleDiscoveredDevice> foundDevices;
  final BleDiscoveredDevice device;

  @override
  List<BleDiscoveredDevice> get devices => foundDevices;

  @override
  BleDiscoveredDevice? get selectedDevice => device;
}

final class AwaitingPairingPasskey extends BleOnboardingState {
  AwaitingPairingPasskey({
    required List<BleDiscoveredDevice> foundDevices,
    required this.device,
    this.error,
  }) : foundDevices = List<BleDiscoveredDevice>.unmodifiable(foundDevices);

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
  PairingInProgress({
    required List<BleDiscoveredDevice> foundDevices,
    required this.device,
  }) : foundDevices = List<BleDiscoveredDevice>.unmodifiable(foundDevices);

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
    Map<String, String> validationErrors = const {},
    List<PhoneWifiNetwork> phoneWifiNetworks = const [],
    this.isLoadingPhoneWifiNetworks = false,
    this.error,
  })  : validationErrors = Map<String, String>.unmodifiable(validationErrors),
        phoneWifiNetworks =
            List<PhoneWifiNetwork>.unmodifiable(phoneWifiNetworks),
        assert(credentials.password == '');

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
    required this.message,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final String message;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  String? get controllerIpAddress => '0.0.0.0';

  @override
  String? get controllerAccessErrorMessage => message;
}

final class ControllerAccessFailed extends BleOnboardingState {
  ControllerAccessFailed({
    required this.device,
    required this.credentials,
    required this.ipAddress,
    required this.message,
  }) : assert(credentials.password == '');

  final BleDiscoveredDevice device;
  final WifiCredentials credentials;
  final String? ipAddress;
  final String message;

  @override
  BleDiscoveredDevice? get selectedDevice => device;

  @override
  WifiCredentials get wifiCredentials => credentials;

  @override
  String? get controllerIpAddress => ipAddress;

  @override
  String? get controllerAccessErrorMessage => message;
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
