import 'package:flutter/foundation.dart';

import '../../app/onboarding_app_service.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/diagnostics/diagnostics_log.dart';
import '../../features/local_controller/mdns_controller_resolver.dart';
import '../../features/watering_hubs/watering_hub.dart';
import 'ble_controller_access_flow.dart';
import 'ble_discovery_flow.dart';
import 'ble_onboarding_errors.dart';
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
    required MdnsControllerResolver mdnsControllerResolver,
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
      mdnsControllerResolver: mdnsControllerResolver,
      diagnosticsLog: diagnosticsLog,
      retryDelay: controllerAccessRetryDelay,
      maxAttempts: maxControllerAccessAttempts,
    );
    _diagnosticsLog = diagnosticsLog;
    _stateStore.addListener(notifyListeners);
  }

  late final BleOnboardingStateStore _stateStore;
  late final BleOnboardingSession _session;
  late final BleService _bleService;
  late final BleDiscoveryFlow _discovery;
  late final BlePairingFlow _pairing;
  late final BleWifiProvisioningFlow _wifi;
  late final BleControllerAccessFlow _access;
  late final DiagnosticsLog _diagnosticsLog;

  BleOnboardingState get state => _stateStore.state;

  Future<void> checkAvailability() => _discovery.checkAvailability();

  Future<void> start({
    required WateringHub? activeWateringHub,
  }) async {
    if (activeWateringHub?.isOnboardingComplete ?? false) {
      await recoverSavedController(activeWateringHub!);
      return;
    }
    _session.activeWateringHub = activeWateringHub;
    _session.isRecoveringExistingHub = false;
    await checkAvailability();
  }

  Future<void> recoverSavedController(WateringHub hub) async {
    _session.activeWateringHub = hub;
    _session.isRecoveringExistingHub = true;
    final availability = await _bleService.checkAvailability();
    if (availability != BleAvailability.ready) {
      _stateStore.setState(BluetoothUnavailable(availability: availability));
      return;
    }

    final device = BleDiscoveredDevice(
      id: hub.bleDeviceId,
      name: hub.displayName,
      rssi: null,
      isLikelyAutomaticWateringHub: true,
      advertisedServiceUuids: const {},
    );
    _session.devices = [device];
    _stateStore.setState(
      ConnectingDevice(foundDevices: _session.devices, device: device),
    );

    try {
      await _bleService.reconnect(device);
      _stateStore.setState(
        PairingInProgress(foundDevices: _session.devices, device: device),
      );
      final services = await _bleService.pairAndDiscoverServices(device);
      if (!services.hasAutomaticWateringService) {
        throw StateError('Automatic Watering BLE service was not discovered');
      }
      _session.isBleConnected = true;
    } catch (error) {
      _session.isBleConnected = false;
      final bleError = bleOnboardingBleError(
        message:
            'Не вдалося підключитися до збереженого контролера через BLE. Запустіть пошук і виберіть контролер заново.',
        error: error,
        diagnosticsLog: _diagnosticsLog,
      );
      _session.devices = const [];
      _stateStore.setState(ReadyToScan(error: bleError));
      return;
    }

    _stateStore.setState(
      AccessSetupReady(
        device: device,
        credentials: WifiCredentials.empty(),
      ),
    );
    await _access.bootstrapControllerAccess();
  }

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
