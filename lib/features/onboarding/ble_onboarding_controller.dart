import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/app_state.dart';
import '../../features/ble/ble_constants.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/watering_hubs/watering_hub.dart';
import '../../features/watering_hubs/watering_hub_state.dart';
import 'ble_onboarding_state.dart';
import 'wifi_provisioning_models.dart';

class BleOnboardingController extends ChangeNotifier {
  BleOnboardingController({
    required BleService bleService,
    required AppController appController,
    Duration rebootDelay = const Duration(seconds: 3),
    Duration reconnectRetryDelay = const Duration(seconds: 2),
    int maxReconnectAttempts = 5,
  })  : _bleService = bleService,
        _appController = appController,
        _rebootDelay = rebootDelay,
        _reconnectRetryDelay = reconnectRetryDelay,
        _maxReconnectAttempts = maxReconnectAttempts {
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
  final Duration _rebootDelay;
  final Duration _reconnectRetryDelay;
  final int _maxReconnectAttempts;
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
        step: BleOnboardingStep.wifiProvisioning,
        connectionStatus: BleConnectionStatus.connected,
        clearLastError: true,
      );
      notifyListeners();
      await readCurrentWifiSettings();
    } catch (error) {
      _setError('Сполучення не виконано.', error);
    }
  }

  void updateWifiCredentials(WifiCredentials credentials) {
    _state = _state.copyWith(
      wifiCredentials: credentials,
      clearWifiValidationErrors: true,
      clearWifiError: true,
    );
    notifyListeners();
  }

  Future<void> useCurrentPhoneWifi() async {
    _setWifiError(
      message:
          'Автопідстановка поточної Wi-Fi мережі недоступна на цій платформі.',
      operation: WifiProvisioningOperation.phoneWifiAutofill,
      error: UnsupportedError('Phone Wi-Fi platform API is not configured'),
    );
  }

  Future<void> readCurrentWifiSettings() async {
    final device = _state.selectedDevice;
    if (device == null) {
      return;
    }
    if (_state.connectionStatus != BleConnectionStatus.connected) {
      _state = _state.copyWith(
        connectionStatus: BleConnectionStatus.reconnecting,
        wifiStatus: WifiProvisioningStatus.reconnecting,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      step: BleOnboardingStep.wifiProvisioning,
      wifiStatus: WifiProvisioningStatus.reading,
      clearWifiError: true,
      clearWifiValidationErrors: true,
    );
    notifyListeners();

    try {
      final credentials = await _bleService.readWifiSettings(device.id);
      _state = _state.copyWith(
        wifiCredentials: credentials.copyWith(password: ''),
        wifiStatus: WifiProvisioningStatus.ready,
        clearWifiError: true,
      );
      notifyListeners();
    } catch (error) {
      _setWifiError(
        message: 'Не вдалося прочитати поточну Wi-Fi мережу контролера.',
        operation: WifiProvisioningOperation.readCurrentSettings,
        error: error,
        status: WifiProvisioningStatus.ready,
      );
    }
  }

  Future<void> saveWifiSettings(WifiCredentials credentials) async {
    final device = _state.selectedDevice;
    if (device == null) {
      return;
    }

    final normalized = credentials.normalizedForSave;
    final validationErrors = normalized.validate();
    if (validationErrors.isNotEmpty) {
      _state = _state.copyWith(
        wifiCredentials: normalized.copyWith(password: ''),
        wifiValidationErrors: validationErrors,
        wifiStatus: WifiProvisioningStatus.ready,
        wifiError: const WifiProvisioningError(
          message: 'Перевірте поля Wi-Fi.',
          technicalReason: 'Validation failed',
          operation: WifiProvisioningOperation.validateInput,
        ),
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      wifiCredentials: normalized,
      wifiStatus: WifiProvisioningStatus.saving,
      clearWifiError: true,
      clearWifiValidationErrors: true,
    );
    notifyListeners();

    try {
      final response = await _bleService.saveWifiSettings(
        deviceId: device.id,
        credentials: normalized,
      );
      if (!response.restartScheduled) {
        throw StateError('Controller did not schedule restart');
      }
      _state = _state.copyWith(
        wifiCredentials: normalized.copyWith(password: ''),
        wifiStatus: WifiProvisioningStatus.rebooting,
      );
      _appController.setConnectionState(
        WateringHubConnectionState.reconnectingBle,
      );
      notifyListeners();

      await Future<void>.delayed(_rebootDelay);
      await _bleService.disconnect(device.id);
      await _reconnectAfterReboot(device);
    } catch (error) {
      _setWifiError(
        message: 'Контролер не прийняв Wi-Fi налаштування.',
        operation: WifiProvisioningOperation.saveSettings,
        error: error,
        status: WifiProvisioningStatus.ready,
        credentials: normalized.copyWith(password: ''),
      );
    }
  }

  Future<void> retryWifiReconnect() async {
    final device = _state.selectedDevice;
    if (device == null) {
      return;
    }
    await _reconnectAfterReboot(device);
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

  Future<void> _reconnectAfterReboot(BleDiscoveredDevice device) async {
    _state = _state.copyWith(
      connectionStatus: BleConnectionStatus.reconnecting,
      wifiStatus: WifiProvisioningStatus.reconnecting,
      clearWifiError: true,
    );
    notifyListeners();

    Object? lastError;
    for (var attempt = 0; attempt < _maxReconnectAttempts; attempt += 1) {
      try {
        await _bleService.reconnect(device);
        await _bleService.pairAndDiscoverServices(
          device: device,
          passkey: AutomaticWateringBleConstants.pairingPasskey,
        );
        _state = _state.copyWith(
          step: BleOnboardingStep.accessBootstrap,
          connectionStatus: BleConnectionStatus.connected,
          wifiStatus: WifiProvisioningStatus.completed,
          wifiCredentials: _state.wifiCredentials.copyWith(password: ''),
          clearWifiError: true,
          clearLastError: true,
        );
        notifyListeners();
        return;
      } catch (error) {
        lastError = error;
        if (attempt + 1 < _maxReconnectAttempts) {
          await Future<void>.delayed(_reconnectRetryDelay);
        }
      }
    }

    _setWifiError(
      message: 'Не вдалося повторно підключитися до контролера через BLE.',
      operation: WifiProvisioningOperation.reconnectBle,
      error: lastError ?? StateError('BLE reconnect failed'),
      status: WifiProvisioningStatus.ready,
      credentials: _state.wifiCredentials.copyWith(password: ''),
    );
  }

  void _setWifiError({
    required String message,
    required WifiProvisioningOperation operation,
    required Object error,
    WifiProvisioningStatus? status,
    WifiCredentials? credentials,
  }) {
    _state = _state.copyWith(
      wifiCredentials:
          credentials ?? _state.wifiCredentials.copyWith(password: ''),
      wifiStatus: status ?? _state.wifiStatus,
      wifiError: WifiProvisioningError(
        message: message,
        technicalReason: error.runtimeType.toString(),
        operation: operation,
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
