import '../../features/ble/ble_constants.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import 'ble_onboarding_errors.dart';
import 'ble_onboarding_session.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_store.dart';
import 'wifi_provisioning_models.dart';

class BleWifiProvisioningFlow {
  const BleWifiProvisioningFlow({
    required BleOnboardingSession session,
    required BleOnboardingStateStore stateStore,
    required BleService bleService,
    required Duration rebootDelay,
    required Duration reconnectRetryDelay,
    required int maxReconnectAttempts,
  })  : _session = session,
        _stateStore = stateStore,
        _bleService = bleService,
        _rebootDelay = rebootDelay,
        _reconnectRetryDelay = reconnectRetryDelay,
        _maxReconnectAttempts = maxReconnectAttempts;

  final BleOnboardingSession _session;
  final BleOnboardingStateStore _stateStore;
  final BleService _bleService;
  final Duration _rebootDelay;
  final Duration _reconnectRetryDelay;
  final int _maxReconnectAttempts;

  void updateWifiCredentials(WifiCredentials credentials) {
    final state = _stateStore.state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }
    _stateStore.setState(
      WifiCredentialsFormReady(
        device: state.device,
        credentials: credentials.sanitizedForState,
      ),
    );
  }

  Future<void> useCurrentPhoneWifi() async {
    final state = _stateStore.state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }
    _stateStore.setState(
      WifiCredentialsFormReady(
        device: state.device,
        credentials: state.credentials.sanitizedForState,
        error: bleOnboardingWifiError(
          message:
              'Автопідстановка поточної Wi-Fi мережі недоступна на цій платформі.',
          operation: WifiProvisioningOperation.phoneWifiAutofill,
          error: UnsupportedError('Phone Wi-Fi platform API is not configured'),
        ),
      ),
    );
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
      if (!_session.isBleConnected) {
        await _bleService.reconnect(device);
        _session.isBleConnected = true;
      }
      final credentials = await _bleService.readWifiSettings(device.id);
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
      final response = await _bleService.saveWifiSettings(
        deviceId: device.id,
        credentials: normalized,
      );
      if (!response.restartScheduled) {
        throw StateError('Controller did not schedule restart');
      }

      _stateStore.setState(
        WaitingForControllerReboot(
          device: device,
          credentials: publicCredentials,
        ),
      );

      await Future<void>.delayed(_rebootDelay);
      await _bleService.disconnect(device.id);
      _session.isBleConnected = false;
      await reconnectAfterReboot(device, publicCredentials);
    } catch (error) {
      _stateStore.setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: publicCredentials,
          error: bleOnboardingWifiError(
            message: 'Контролер не прийняв Wi-Fi налаштування.',
            operation: WifiProvisioningOperation.saveSettings,
            error: error,
          ),
        ),
      );
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
        await _bleService.pairAndDiscoverServices(
          device: device,
          passkey: AutomaticWateringBleConstants.pairingPasskey,
        );
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
