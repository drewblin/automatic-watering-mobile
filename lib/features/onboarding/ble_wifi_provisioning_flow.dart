import 'dart:async';

import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import 'ble_onboarding_errors.dart';
import 'ble_onboarding_session.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_store.dart';
import 'phone_wifi_service.dart';
import 'wifi_provisioning_models.dart';

class BleWifiProvisioningFlow {
  const BleWifiProvisioningFlow({
    required BleOnboardingSession session,
    required BleOnboardingStateStore stateStore,
    required BleService bleService,
    required PhoneWifiService phoneWifiService,
    required Duration rebootDelay,
    required Duration reconnectRetryDelay,
    required int maxReconnectAttempts,
    Duration readCurrentSettingsTimeout = const Duration(seconds: 90),
  })  : _session = session,
        _stateStore = stateStore,
        _bleService = bleService,
        _phoneWifiService = phoneWifiService,
        _rebootDelay = rebootDelay,
        _reconnectRetryDelay = reconnectRetryDelay,
        _maxReconnectAttempts = maxReconnectAttempts,
        _readCurrentSettingsTimeout = readCurrentSettingsTimeout;

  final BleOnboardingSession _session;
  final BleOnboardingStateStore _stateStore;
  final BleService _bleService;
  final PhoneWifiService _phoneWifiService;
  final Duration _rebootDelay;
  final Duration _reconnectRetryDelay;
  final int _maxReconnectAttempts;
  final Duration _readCurrentSettingsTimeout;

  void updateWifiCredentials(WifiCredentials credentials) {
    final state = _stateStore.state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }
    _stateStore.setState(
      WifiCredentialsFormReady(
        device: state.device,
        credentials: credentials.sanitizedForState,
        phoneWifiNetworks: state.phoneWifiNetworks,
      ),
    );
  }

  Future<void> useCurrentPhoneWifi() async {
    final state = _stateStore.state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }
    final previousCredentials = state.credentials.sanitizedForState;
    _stateStore.setState(
      WifiCredentialsFormReady(
        device: state.device,
        credentials: previousCredentials,
        phoneWifiNetworks: state.phoneWifiNetworks,
        isLoadingPhoneWifiNetworks: true,
      ),
    );

    try {
      final snapshot = await _phoneWifiService.readWifiSnapshot();
      final selectedSsid =
          snapshot.currentSsid ?? snapshot.networks.firstOrNull?.ssid;
      _stateStore.setState(
        WifiCredentialsFormReady(
          device: state.device,
          credentials: selectedSsid == null
              ? previousCredentials
              : previousCredentials.copyWith(ssid: selectedSsid),
          phoneWifiNetworks: snapshot.networks,
        ),
      );
    } catch (error) {
      _stateStore.setState(
        WifiCredentialsFormReady(
          device: state.device,
          credentials: previousCredentials,
          phoneWifiNetworks: state.phoneWifiNetworks,
          error: bleOnboardingWifiError(
            message:
                'Не вдалося прочитати Wi-Fi мережі телефону. Перевірте дозволи Wi-Fi/локації і що геолокацію увімкнено.',
            operation: WifiProvisioningOperation.phoneWifiAutofill,
            error: error,
          ),
        ),
      );
    }
  }

  Future<void> readCurrentWifiSettingsFromState() async {
    final state = _stateStore.state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }

    await readCurrentWifiSettings(
      device: state.device,
      previousCredentials: state.credentials.sanitizedForState,
    );
  }

  Future<void> readCurrentWifiSettings({
    required BleDiscoveredDevice device,
    required WifiCredentials previousCredentials,
  }) async {
    _stateStore.setState(ReadingWifiSettings(device: device));

    try {
      final credentials = await _readCurrentWifiSettings(device).timeout(
        _readCurrentSettingsTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Timed out reading controller Wi-Fi settings',
            _readCurrentSettingsTimeout,
          );
        },
      );
      _session.isBleConnected = true;
      _stateStore.setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: credentials.sanitizedForState,
        ),
      );
    } catch (error) {
      _session.isBleConnected = false;
      _stateStore.setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: previousCredentials,
          error: bleOnboardingWifiError(
            message: 'Не вдалося прочитати поточну Wi-Fi мережу контролера.',
            operation: WifiProvisioningOperation.readCurrentSettings,
            error: error,
          ),
        ),
      );
    }
  }

  Future<WifiCredentials> _readCurrentWifiSettings(
    BleDiscoveredDevice device,
  ) async {
    if (!_session.isBleConnected) {
      await _bleService.reconnect(device);
    }
    return _bleService.readWifiSettings(device.id);
  }

  Future<void> saveWifiSettings(WifiCredentials credentials) async {
    final state = _stateStore.state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }

    final device = state.device;
    final normalized = credentials.normalizedForSave;
    final publicCredentials = normalized.sanitizedForState;
    final validationErrors = normalized.validate();
    if (validationErrors.isNotEmpty) {
      _stateStore.setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: publicCredentials,
          validationErrors: validationErrors,
          phoneWifiNetworks: state.phoneWifiNetworks,
          error: const WifiProvisioningError(
            message: 'Перевірте поля Wi-Fi.',
            technicalReason: 'Validation failed',
            operation: WifiProvisioningOperation.validateInput,
          ),
        ),
      );
      return;
    }

    _stateStore.setState(
      SavingWifiSettings(
        device: device,
        credentials: publicCredentials,
      ),
    );

    try {
      await _saveWifiSettingsOnController(
        deviceId: device.id,
        credentials: normalized,
      );
    } catch (error) {
      _stateStore.setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: publicCredentials,
          phoneWifiNetworks: state.phoneWifiNetworks,
          error: bleOnboardingWifiError(
            message: 'Контролер не прийняв Wi-Fi налаштування.',
            operation: WifiProvisioningOperation.saveSettings,
            error: error,
          ),
        ),
      );
      return;
    }

    _stateStore.setState(
      WaitingForControllerReboot(
        device: device,
        credentials: publicCredentials,
      ),
    );

    await Future<void>.delayed(_rebootDelay);
    await _disconnectAfterAcceptedWifiSave(device.id);
    await reconnectAfterReboot(device, publicCredentials);
  }

  void skipWifiSettings() {
    final state = _stateStore.state;
    if (state is! WifiCredentialsFormReady ||
        state.credentials.ssid.trim().isEmpty) {
      return;
    }
    _stateStore.setState(
      AccessSetupReady(
        device: state.device,
        credentials: state.credentials.sanitizedForState,
      ),
    );
  }

  Future<void> _saveWifiSettingsOnController({
    required String deviceId,
    required WifiCredentials credentials,
  }) async {
    final response = await _bleService.saveWifiSettings(
      deviceId: deviceId,
      credentials: credentials,
    );
    if (!response.restartScheduled) {
      throw StateError('Controller did not schedule restart');
    }
  }

  Future<void> _disconnectAfterAcceptedWifiSave(String deviceId) async {
    try {
      await _bleService.disconnect(deviceId);
    } catch (_) {
      // The controller may already be rebooting and have dropped the BLE link.
    } finally {
      _session.isBleConnected = false;
    }
  }

  Future<void> retryWifiReconnect() async {
    final state = _stateStore.state;
    if (state is! ReconnectAfterRebootBlocked) {
      return;
    }
    await reconnectAfterReboot(state.device, state.credentials);
  }

  Future<void> reconnectAfterReboot(
    BleDiscoveredDevice device,
    WifiCredentials credentials,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxReconnectAttempts; ++attempt) {
      _stateStore.setState(
        ReconnectingAfterReboot(
          device: device,
          credentials: credentials,
          attempt: attempt,
        ),
      );
      try {
        await _bleService.reconnect(device);
        await _bleService.pairAndDiscoverServices(device);
        _session.isBleConnected = true;
        _stateStore.setState(
          AccessSetupReady(
            device: device,
            credentials: credentials.sanitizedForState,
          ),
        );
        return;
      } catch (error) {
        lastError = error;
        _session.isBleConnected = false;
        if (attempt < _maxReconnectAttempts) {
          await Future<void>.delayed(_reconnectRetryDelay);
        }
      }
    }

    _stateStore.setState(
      ReconnectAfterRebootBlocked(
        device: device,
        credentials: credentials.sanitizedForState,
        error: bleOnboardingWifiError(
          message: 'Не вдалося повторно підключитися до контролера через BLE.',
          operation: WifiProvisioningOperation.reconnectBle,
          error: lastError ?? StateError('BLE reconnect failed'),
        ),
      ),
    );
  }
}
