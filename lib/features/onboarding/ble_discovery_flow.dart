import 'dart:async';

import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/local_controller/diagnostics_log.dart';
import 'ble_onboarding_errors.dart';
import 'ble_onboarding_session.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_store.dart';

class BleDiscoveryFlow {
  BleDiscoveryFlow({
    required BleOnboardingSession session,
    required BleOnboardingStateStore stateStore,
    required BleService bleService,
    required DiagnosticsLog diagnosticsLog,
  })  : _session = session,
        _stateStore = stateStore,
        _bleService = bleService,
        _diagnosticsLog = diagnosticsLog {
    _devicesSubscription = _bleService.discoveredDevices.listen(
      _syncDiscoveredDevices,
      onError: (Object error) {
        _stateStore.setState(
          ReadyToScan(
            error: bleOnboardingBleError(
              message: 'Не вдалося виконати BLE-пошук.',
              error: error,
              diagnosticsLog: _diagnosticsLog,
            ),
          ),
        );
      },
    );
  }

  final BleOnboardingSession _session;
  final BleOnboardingStateStore _stateStore;
  final BleService _bleService;
  final DiagnosticsLog _diagnosticsLog;
  StreamSubscription<List<BleDiscoveredDevice>>? _devicesSubscription;

  Future<void> checkAvailability() async {
    final requestId = ++_session.availabilityRequestId;
    _stateStore.setState(const CheckingBluetooth());
    final availability = await _bleService.checkAvailability();
    if (requestId != _session.availabilityRequestId) {
      return;
    }
    _setAvailabilityState(availability);
  }

  Future<void> requestPermissions() async {
    final requestId = ++_session.availabilityRequestId;
    _stateStore.setState(const CheckingBluetooth());
    final availability = await _bleService.requestPermissions();
    if (requestId != _session.availabilityRequestId) {
      return;
    }
    _setAvailabilityState(availability);
  }

  Future<void> startScan() async {
    ++_session.availabilityRequestId;
    final availability = await _bleService.checkAvailability();
    if (availability != BleAvailability.ready) {
      _stateStore.setState(BluetoothUnavailable(availability: availability));
      return;
    }

    _session.devices = const [];
    _session.isBleConnected = false;
    _stateStore.setState(const DiscoveringDevices(foundDevices: []));

    try {
      await _bleService.startScan();
    } catch (error) {
      _stateStore.setState(
        ReadyToScan(
          error: bleOnboardingBleError(
            message: 'Не вдалося запустити BLE-пошук.',
            error: error,
            diagnosticsLog: _diagnosticsLog,
          ),
        ),
      );
    }
  }

  void selectDevice(BleDiscoveredDevice device) {
    _stateStore.setState(
      DeviceSelected(foundDevices: _session.devices, device: device),
    );
  }

  Future<void> dispose() async {
    await _devicesSubscription?.cancel();
  }

  void _syncDiscoveredDevices(List<BleDiscoveredDevice> devices) {
    _session.devices = List.unmodifiable(devices);
    final state = _stateStore.state;
    if (state is DiscoveringDevices) {
      _stateStore.setState(DiscoveringDevices(foundDevices: _session.devices));
    } else if (state is DeviceSelected) {
      _stateStore.setState(
        DeviceSelected(
          foundDevices: _session.devices,
          device: state.device,
          error: state.error,
        ),
      );
    }
  }

  void _setAvailabilityState(BleAvailability availability) {
    if (availability == BleAvailability.ready) {
      _stateStore.setState(const ReadyToScan());
      return;
    }
    _stateStore.setState(BluetoothUnavailable(availability: availability));
  }
}
