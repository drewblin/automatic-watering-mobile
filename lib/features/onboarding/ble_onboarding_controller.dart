import 'package:flutter/foundation.dart';

import '../../app/onboarding_app_service.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/diagnostics/diagnostics_log.dart';
import '../../features/local_controller/local_controller_api_client.dart';
import 'ble_controller_access_flow.dart';
import 'ble_discovery_flow.dart';
import 'ble_onboarding_session.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_store.dart';
import 'ble_pairing_flow.dart';
import 'ble_wifi_provisioning_flow.dart';
import 'phone_wifi_service.dart';
import 'wifi_provisioning_models.dart';

class BleOnboardingController extends ChangeNotifier {
  BleOnboardingController({
    required BleService bleService,
    required PhoneWifiService phoneWifiService,
    required OnboardingAppService onboardingStorage,
    required LocalControllerApiClient localControllerApiClient,
    required DiagnosticsLog diagnosticsLog,
    Duration rebootDelay = const Duration(seconds: 4),
    Duration reconnectRetryDelay = const Duration(seconds: 2),
    Duration readCurrentWifiSettingsTimeout = const Duration(seconds: 90),
    Duration controllerAccessRetryDelay = const Duration(seconds: 2),
    int maxControllerAccessAttempts = 5,
    int maxReconnectAttempts = 5,
  }) {
    _stateStore = BleOnboardingStateStore();
    _session = BleOnboardingSession();
    _bleService = bleService;
    _discovery = BleDiscoveryFlow(
      session: _session,
      stateStore: _stateStore,
      bleService: _bleService,
      diagnosticsLog: diagnosticsLog,
    );
    _pairing = BlePairingFlow(
      session: _session,
      stateStore: _stateStore,
      bleService: _bleService,
      diagnosticsLog: diagnosticsLog,
    );
    _wifi = BleWifiProvisioningFlow(
      session: _session,
      stateStore: _stateStore,
      bleService: _bleService,
      phoneWifiService: phoneWifiService,
      diagnosticsLog: diagnosticsLog,
      rebootDelay: rebootDelay,
      reconnectRetryDelay: reconnectRetryDelay,
      readCurrentSettingsTimeout: readCurrentWifiSettingsTimeout,
      maxReconnectAttempts: maxReconnectAttempts,
    );
    _access = BleControllerAccessFlow(
      session: _session,
      stateStore: _stateStore,
      bleService: _bleService,
      onboardingStorage: onboardingStorage,
      localControllerApiClient: localControllerApiClient,
      diagnosticsLog: diagnosticsLog,
      retryDelay: controllerAccessRetryDelay,
      maxAttempts: maxControllerAccessAttempts,
    );
    _stateStore.addListener(notifyListeners);
  }

  late final BleOnboardingStateStore _stateStore;
  late final BleOnboardingSession _session;
  late final BleService _bleService;
  late final BleDiscoveryFlow _discovery;
  late final BlePairingFlow _pairing;
  late final BleWifiProvisioningFlow _wifi;
  late final BleControllerAccessFlow _access;

  BleOnboardingState get state => _stateStore.state;

  Future<void> checkAvailability() => _discovery.checkAvailability();

  Future<void> requestPermissions() => _discovery.requestPermissions();

  Future<void> startScan() => _discovery.startScan();

  void selectDevice(BleDiscoveredDevice device) {
    _discovery.selectDevice(device);
  }

  Future<void> connectSelectedDevice() async {
    final device = await _pairing.connectSelectedDevice();
    if (device == null) {
      return;
    }

    await _wifi.readCurrentWifiSettings(
      device: device,
      previousCredentials: WifiCredentials.empty(),
    );
  }

  void updateWifiCredentials(WifiCredentials credentials) {
    _wifi.updateWifiCredentials(credentials);
  }

  Future<void> useCurrentPhoneWifi() => _wifi.useCurrentPhoneWifi();

  Future<void> readCurrentWifiSettings() {
    return _wifi.readCurrentWifiSettingsFromState();
  }

  Future<void> saveWifiSettings(WifiCredentials credentials) {
    return _wifi.saveWifiSettings(credentials);
  }

  void skipWifiSettings() {
    _wifi.skipWifiSettings();
  }

  Future<void> retryWifiReconnect() => _wifi.retryWifiReconnect();

  Future<void> bootstrapControllerAccess() {
    return _access.bootstrapControllerAccess();
  }

  Future<void> returnToWifiProvisioning() {
    return _access.returnToWifiProvisioning();
  }

  Future<void> disconnect() => _access.disconnect();

  @override
  void dispose() {
    _stateStore.removeListener(notifyListeners);
    _session.isDisposed = true;
    _stateStore.close();
    _discovery.dispose();
    _bleService.dispose();
    _stateStore.dispose();
    super.dispose();
  }
}
