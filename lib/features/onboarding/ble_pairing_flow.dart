import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/diagnostics/diagnostics_log.dart';
import 'ble_onboarding_errors.dart';
import 'ble_onboarding_session.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_store.dart';

class BlePairingFlow {
  const BlePairingFlow({
    required BleOnboardingSession session,
    required BleOnboardingStateStore stateStore,
    required BleService bleService,
    required DiagnosticsLog diagnosticsLog,
  })  : _session = session,
        _stateStore = stateStore,
        _bleService = bleService,
        _diagnosticsLog = diagnosticsLog;

  final BleOnboardingSession _session;
  final BleOnboardingStateStore _stateStore;
  final BleService _bleService;
  final DiagnosticsLog _diagnosticsLog;

  Future<BleDiscoveredDevice?> connectSelectedDevice() async {
    final state = _stateStore.state;
    if (state is! DeviceSelected) {
      return null;
    }
    final device = state.device;

    _stateStore.setState(
      ConnectingDevice(foundDevices: _session.devices, device: device),
    );

    try {
      await _bleService.connect(device);
      _stateStore.setState(
        PairingInProgress(foundDevices: _session.devices, device: device),
      );
      final services = await _bleService.pairAndDiscoverServices(device);
      if (!services.hasAutomaticWateringService) {
        throw StateError('Automatic Watering BLE service was not discovered');
      }
      _session.isBleConnected = true;
      return device;
    } catch (error) {
      _session.isBleConnected = false;
      _stateStore.setState(
        DeviceSelected(
          foundDevices: _session.devices,
          device: device,
          error: bleOnboardingBleError(
            message: 'Не вдалося підключитися до контролера.',
            error: error,
            diagnosticsLog: _diagnosticsLog,
          ),
        ),
      );
      return null;
    }
  }
}
