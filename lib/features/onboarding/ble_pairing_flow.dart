import '../../features/ble/ble_constants.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import 'ble_onboarding_errors.dart';
import 'ble_onboarding_session.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_store.dart';

class BlePairingFlow {
  const BlePairingFlow({
    required BleOnboardingSession session,
    required BleOnboardingStateStore stateStore,
    required BleService bleService,
  })  : _session = session,
        _stateStore = stateStore,
        _bleService = bleService;

  final BleOnboardingSession _session;
  final BleOnboardingStateStore _stateStore;
  final BleService _bleService;

  Future<void> connectSelectedDevice() async {
    final state = _stateStore.state;
    if (state is! DeviceSelected) {
      return;
    }
    final device = state.device;

    _stateStore.setState(
      ConnectingDevice(foundDevices: _session.devices, device: device),
    );

    try {
      await _bleService.connect(device);
      _session.isBleConnected = true;
      _stateStore.setState(
        AwaitingPairingPasskey(
          foundDevices: _session.devices,
          device: device,
        ),
      );
    } catch (error) {
      _session.isBleConnected = false;
      _stateStore.setState(
        DeviceSelected(
          foundDevices: _session.devices,
          device: device,
          error: bleOnboardingBleError(
            'Не вдалося підключитися до контролера.',
            error,
          ),
        ),
      );
    }
  }

  Future<BleDiscoveredDevice?> pairSelectedDevice(String passkey) async {
    final state = _stateStore.state;
    if (state is! AwaitingPairingPasskey) {
      return null;
    }
    final device = state.device;

    if (passkey != AutomaticWateringBleConstants.pairingPasskey) {
      _stateStore.setState(
        AwaitingPairingPasskey(
          foundDevices: _session.devices,
          device: device,
          error: bleOnboardingBleError(
            'Неправильний код сполучення.',
            ArgumentError('Invalid BLE pairing passkey'),
          ),
        ),
      );
      return null;
    }

    _stateStore.setState(
      PairingInProgress(foundDevices: _session.devices, device: device),
    );

    try {
      final services = await _bleService.pairAndDiscoverServices(
        device: device,
        passkey: passkey,
      );
      if (!services.hasAutomaticWateringService) {
        throw StateError('Automatic Watering BLE service was not discovered');
      }
      _session.isBleConnected = true;
      return device;
    } catch (error) {
      _stateStore.setState(
        AwaitingPairingPasskey(
          foundDevices: _session.devices,
          device: device,
          error: bleOnboardingBleError('Сполучення не виконано.', error),
        ),
      );
      return null;
    }
  }
}
