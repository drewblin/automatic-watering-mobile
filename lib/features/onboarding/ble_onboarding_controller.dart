import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/app_state.dart';
import '../../features/ble/ble_constants.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/watering_hubs/watering_hub.dart';
import 'ble_onboarding_state.dart';

class BleOnboardingController extends ChangeNotifier {
  BleOnboardingController({
    required BleService bleService,
    required AppController appController,
  })  : _bleService = bleService,
        _appController = appController {
    _devicesSubscription = _bleService.discoveredDevices.listen((devices) {
      _state = _state.copyWith(
        devices: devices,
        connectionStatus: devices.isEmpty
            ? _state.connectionStatus
            : BleConnectionStatus.deviceFound,
        clearLastError: true,
      );
      notifyListeners();
    });
    _statusSubscription = _bleService.connectionStatus.listen((status) {
      _state = _state.copyWith(connectionStatus: status);
      notifyListeners();
    });
  }

  final BleService _bleService;
  final AppController _appController;
  StreamSubscription<List<BleDiscoveredDevice>>? _devicesSubscription;
  StreamSubscription<BleConnectionStatus>? _statusSubscription;

  BleOnboardingState _state = BleOnboardingState.initial();

  BleOnboardingState get state => _state;

  Future<void> checkAvailability() async {
    final availability = await _bleService.checkAvailability();
    _state = _state.copyWith(
      connectionStatus: _statusFromAvailability(availability),
      clearLastError: true,
    );
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    final availability = await _bleService.requestPermissions();
    _state = _state.copyWith(
      connectionStatus: _statusFromAvailability(availability),
      clearLastError: true,
    );
    notifyListeners();
  }

  Future<void> startScan() async {
    _state = _state.copyWith(
      step: BleOnboardingStep.discovery,
      devices: const [],
      connectionStatus: BleConnectionStatus.scanning,
      clearSelectedDevice: true,
      clearLastError: true,
    );
    notifyListeners();

    try {
      await _bleService.startScan();
    } catch (error) {
      _setError('Не вдалося запустити BLE-пошук.', error);
    }
  }

  Future<void> stopScan() async {
    await _bleService.stopScan();
    if (_state.connectionStatus == BleConnectionStatus.scanning) {
      _state = _state.copyWith(connectionStatus: BleConnectionStatus.idle);
      notifyListeners();
    }
  }

  void selectDevice(BleDiscoveredDevice device) {
    _state = _state.copyWith(
      selectedDevice: device,
      connectionStatus: BleConnectionStatus.deviceFound,
      clearLastError: true,
    );
    notifyListeners();
  }

  Future<void> connectSelectedDevice() async {
    final device = _state.selectedDevice;
    if (device == null) {
      return;
    }

    _state = _state.copyWith(
      step: BleOnboardingStep.pairing,
      connectionStatus: BleConnectionStatus.connecting,
      clearLastError: true,
    );
    notifyListeners();

    try {
      await _bleService.connect(device);
    } catch (error) {
      _setError('Не вдалося підключитися до контролера.', error);
    }
  }

  Future<void> pairSelectedDevice(String passkey) async {
    final device = _state.selectedDevice;
    if (device == null) {
      return;
    }

    if (passkey != AutomaticWateringBleConstants.pairingPasskey) {
      _setError(
        'Неправильний код сполучення.',
        ArgumentError('Invalid BLE pairing passkey'),
      );
      return;
    }

    _state = _state.copyWith(
      step: BleOnboardingStep.pairing,
      connectionStatus: BleConnectionStatus.pairing,
      clearLastError: true,
    );
    notifyListeners();

    try {
      final services = await _bleService.pairAndDiscoverServices(
        device: device,
        passkey: passkey,
      );
      if (!services.hasAutomaticWateringService) {
        throw StateError('Automatic Watering BLE service was not discovered');
      }
      await _savePairedHub(device);
      _state = _state.copyWith(
        step: BleOnboardingStep.paired,
        connectionStatus: BleConnectionStatus.connected,
        clearLastError: true,
      );
      notifyListeners();
    } catch (error) {
      _setError('Сполучення не виконано.', error);
    }
  }

  Future<void> disconnect() async {
    final deviceId = _state.selectedDevice?.id;
    if (deviceId == null) {
      return;
    }
    await _bleService.disconnect(deviceId);
  }

  Future<void> _savePairedHub(BleDiscoveredDevice device) async {
    final now = DateTime.now().toUtc();
    final activeHub = _appController.state.activeWateringHub;
    final hub = activeHub?.bleDeviceId == device.id
        ? activeHub!.copyWith(
            displayName: device.displayName,
            updatedAt: now,
          )
        : WateringHub(
            id: _hubIdFromBleDeviceId(device.id),
            displayName: device.displayName,
            bleDeviceId: device.id,
            lastKnownIpAddress: null,
            apiAccessToken: null,
            serverDeviceId: null,
            createdAt: now,
            updatedAt: now,
          );
    await _appController.saveActiveWateringHub(hub);
  }

  void _setError(String message, Object error) {
    _state = _state.copyWith(
      connectionStatus: BleConnectionStatus.error,
      lastError: BleConnectionError(
        message: message,
        technicalReason: _safeTechnicalReason(error),
      ),
    );
    notifyListeners();
  }

  String _safeTechnicalReason(Object error) {
    final raw = error.toString();
    if (raw.length <= 240) {
      return raw;
    }
    return '${raw.substring(0, 240)}...';
  }

  BleConnectionStatus _statusFromAvailability(BleAvailability availability) {
    return switch (availability) {
      BleAvailability.ready => BleConnectionStatus.idle,
      BleAvailability.permissionRequired =>
        BleConnectionStatus.permissionRequired,
      BleAvailability.bluetoothDisabled =>
        BleConnectionStatus.bluetoothDisabled,
    };
  }

  String _hubIdFromBleDeviceId(String bleDeviceId) {
    final normalized = bleDeviceId
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (normalized.isEmpty) {
      return 'hub';
    }
    return 'hub-$normalized';
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}
