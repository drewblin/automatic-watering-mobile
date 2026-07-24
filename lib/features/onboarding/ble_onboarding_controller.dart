import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/fatal_app_exception.dart';
import '../../app/onboarding_app_service.dart';
import '../../features/ble/ble_constants.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/local_controller/local_controller_api_client.dart';
import '../../features/watering_hubs/watering_hub.dart';
import '../../features/watering_hubs/watering_hub_state.dart';
import 'ble_onboarding_state.dart';
import 'wifi_provisioning_models.dart';

class BleOnboardingController extends ChangeNotifier {
  BleOnboardingController({
    required BleService bleService,
    required OnboardingAppService onboardingStorage,
    LocalControllerApiClient? localControllerApiClient,
    Duration rebootDelay = const Duration(seconds: 3),
    Duration reconnectRetryDelay = const Duration(seconds: 2),
    int maxReconnectAttempts = 5,
  })  : _bleService = bleService,
        _onboardingStorage = onboardingStorage,
        _localControllerApiClient =
            localControllerApiClient ?? HttpLocalControllerApiClient(),
        _rebootDelay = rebootDelay,
        _reconnectRetryDelay = reconnectRetryDelay,
        _maxReconnectAttempts = maxReconnectAttempts {
    _devicesSubscription = _bleService.discoveredDevices.listen(
      (devices) {
        _devices = List.unmodifiable(devices);
        final state = _state;
        if (state is DiscoveringDevices) {
          _setState(DiscoveringDevices(foundDevices: _devices));
        } else if (state is DeviceSelected) {
          _setState(
            DeviceSelected(
              foundDevices: _devices,
              device: state.device,
              error: state.error,
            ),
          );
        }
      },
      onError: (Object error) {
        _setState(
          ReadyToScan(
            error: _bleError('Не вдалося виконати BLE-пошук.', error),
          ),
        );
      },
    );
  }

  final BleService _bleService;
  final OnboardingAppService _onboardingStorage;
  final LocalControllerApiClient _localControllerApiClient;
  final Duration _rebootDelay;
  final Duration _reconnectRetryDelay;
  final int _maxReconnectAttempts;
  StreamSubscription<List<BleDiscoveredDevice>>? _devicesSubscription;
  List<BleDiscoveredDevice> _devices = const [];
  bool _isBleConnected = false;
  bool _isDisposed = false;
  int _availabilityRequestId = 0;

  BleOnboardingState _state = const CheckingBluetooth();

  BleOnboardingState get state => _state;

  Future<void> checkAvailability() async {
    final requestId = ++_availabilityRequestId;
    _setState(const CheckingBluetooth());
    final availability = await _bleService.checkAvailability();
    if (requestId != _availabilityRequestId) {
      return;
    }
    _setAvailabilityState(availability);
  }

  Future<void> requestPermissions() async {
    final requestId = ++_availabilityRequestId;
    _setState(const CheckingBluetooth());
    final availability = await _bleService.requestPermissions();
    if (requestId != _availabilityRequestId) {
      return;
    }
    _setAvailabilityState(availability);
  }

  Future<void> startScan() async {
    _availabilityRequestId += 1;
    final availability = await _bleService.checkAvailability();
    if (availability != BleAvailability.ready) {
      _setState(BluetoothUnavailable(availability: availability));
      return;
    }

    _devices = const [];
    _isBleConnected = false;
    _setState(const DiscoveringDevices(foundDevices: []));

    try {
      await _bleService.startScan();
    } catch (error) {
      _setState(
        ReadyToScan(
          error: _bleError('Не вдалося запустити BLE-пошук.', error),
        ),
      );
    }
  }

  Future<void> stopScan() async {
    await _bleService.stopScan();
    if (_state is DiscoveringDevices) {
      _setState(const ReadyToScan());
    }
  }

  void selectDevice(BleDiscoveredDevice device) {
    _setState(DeviceSelected(foundDevices: _devices, device: device));
  }

  Future<void> connectSelectedDevice() async {
    final state = _state;
    if (state is! DeviceSelected) {
      return;
    }
    final device = state.device;

    _setState(ConnectingDevice(foundDevices: _devices, device: device));

    try {
      await _bleService.connect(device);
      _isBleConnected = true;
      _setState(AwaitingPairingPasskey(foundDevices: _devices, device: device));
    } catch (error) {
      _isBleConnected = false;
      _setState(
        DeviceSelected(
          foundDevices: _devices,
          device: device,
          error: _bleError('Не вдалося підключитися до контролера.', error),
        ),
      );
    }
  }

  Future<void> pairSelectedDevice(String passkey) async {
    final state = _state;
    if (state is! AwaitingPairingPasskey) {
      return;
    }
    final device = state.device;

    if (passkey != AutomaticWateringBleConstants.pairingPasskey) {
      _setState(
        AwaitingPairingPasskey(
          foundDevices: _devices,
          device: device,
          error: _bleError(
            'Неправильний код сполучення.',
            ArgumentError('Invalid BLE pairing passkey'),
          ),
        ),
      );
      return;
    }

    _setState(PairingInProgress(foundDevices: _devices, device: device));

    try {
      final services = await _bleService.pairAndDiscoverServices(
        device: device,
        passkey: passkey,
      );
      if (!services.hasAutomaticWateringService) {
        throw StateError('Automatic Watering BLE service was not discovered');
      }
      _isBleConnected = true;
      await _savePairedHub(device);
      await _readCurrentWifiSettings(
        device: device,
        previousCredentials: WifiCredentials.empty(),
      );
    } catch (error) {
      _setState(
        AwaitingPairingPasskey(
          foundDevices: _devices,
          device: device,
          error: _bleError('Сполучення не виконано.', error),
        ),
      );
    }
  }

  void updateWifiCredentials(WifiCredentials credentials) {
    final state = _state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }
    _setState(
      WifiCredentialsFormReady(
        device: state.device,
        credentials: credentials.sanitizedForState,
      ),
    );
  }

  Future<void> useCurrentPhoneWifi() async {
    final state = _state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }
    _setState(
      WifiCredentialsFormReady(
        device: state.device,
        credentials: state.credentials.sanitizedForState,
        error: _wifiError(
          message:
              'Автопідстановка поточної Wi-Fi мережі недоступна на цій платформі.',
          operation: WifiProvisioningOperation.phoneWifiAutofill,
          error: UnsupportedError('Phone Wi-Fi platform API is not configured'),
        ),
      ),
    );
  }

  Future<void> readCurrentWifiSettings() async {
    final state = _state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }

    await _readCurrentWifiSettings(
      device: state.device,
      previousCredentials: state.credentials.sanitizedForState,
    );
  }

  Future<void> _readCurrentWifiSettings({
    required BleDiscoveredDevice device,
    required WifiCredentials previousCredentials,
  }) async {
    _setState(ReadingWifiSettings(device: device));

    try {
      if (!_isBleConnected) {
        await _bleService.reconnect(device);
        _isBleConnected = true;
      }
      final credentials = await _bleService.readWifiSettings(device.id);
      _setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: credentials.sanitizedForState,
        ),
      );
    } catch (error) {
      _isBleConnected = false;
      _setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: previousCredentials,
          error: _wifiError(
            message: 'Не вдалося прочитати поточну Wi-Fi мережу контролера.',
            operation: WifiProvisioningOperation.readCurrentSettings,
            error: error,
          ),
        ),
      );
    }
  }

  Future<void> saveWifiSettings(WifiCredentials credentials) async {
    final state = _state;
    if (state is! WifiCredentialsFormReady) {
      return;
    }

    final device = state.device;
    final normalized = credentials.normalizedForSave;
    final publicCredentials = normalized.sanitizedForState;
    final validationErrors = normalized.validate();
    if (validationErrors.isNotEmpty) {
      _setState(
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

    _setState(
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

      _setState(
        WaitingForControllerReboot(
          device: device,
          credentials: publicCredentials,
        ),
      );
      _onboardingStorage.setConnectionState(
        WateringHubConnectionState.reconnectingBle,
      );

      await Future<void>.delayed(_rebootDelay);
      await _bleService.disconnect(device.id);
      _isBleConnected = false;
      await _reconnectAfterReboot(device, publicCredentials);
    } catch (error) {
      _setState(
        WifiCredentialsFormReady(
          device: device,
          credentials: publicCredentials,
          error: _wifiError(
            message: 'Контролер не прийняв Wi-Fi налаштування.',
            operation: WifiProvisioningOperation.saveSettings,
            error: error,
          ),
        ),
      );
    }
  }

  Future<void> retryWifiReconnect() async {
    final state = _state;
    if (state is! ReconnectAfterRebootBlocked) {
      return;
    }
    await _reconnectAfterReboot(state.device, state.credentials);
  }

  Future<void> bootstrapControllerAccess() async {
    final state = _state;
    switch (state) {
      case AccessSetupReady(:final device, :final credentials):
      case ControllerIpPending(:final device, :final credentials):
      case ControllerAccessFailed(:final device, :final credentials):
        await _bootstrapControllerAccess(
          device: device,
          credentials: credentials.sanitizedForState,
        );
      default:
        return;
    }
  }

  Future<void> _bootstrapControllerAccess({
    required BleDiscoveredDevice device,
    required WifiCredentials credentials,
  }) async {
    _setState(
      ReadingControllerAccess(
        device: device,
        credentials: credentials,
      ),
    );

    try {
      if (!_isBleConnected) {
        _onboardingStorage.setConnectionState(
          WateringHubConnectionState.reconnectingBle,
        );
        await _bleService.reconnect(device);
        await _bleService.pairAndDiscoverServices(
          device: device,
          passkey: AutomaticWateringBleConstants.pairingPasskey,
        );
        _isBleConnected = true;
      }

      final ipAddress = await _bleService.readWifiIpAddress(device.id);
      _setState(
        ReadingControllerAccess(
          device: device,
          credentials: credentials,
          ipAddress: ipAddress.value,
        ),
      );
      final token = await _bleService.readApiAccessToken(device.id);

      final activeHub = _onboardingStorage.activeWateringHub;
      if (activeHub == null || activeHub.bleDeviceId != device.id) {
        await _savePairedHub(device);
      }
      final hub = (_onboardingStorage.activeWateringHub ??
              _newHubForDevice(device, DateTime.now().toUtc()))
          .copyWith(
        lastKnownIpAddress: ipAddress.value,
        updatedAt: DateTime.now().toUtc(),
      );
      await _onboardingStorage.saveControllerAccess(
        hub: hub,
        apiAccessToken: token.value,
      );

      if (ipAddress.isPending) {
        _onboardingStorage
            .setConnectionState(WateringHubConnectionState.ipPending);
        _setState(
          ControllerIpPending(
            device: device,
            credentials: credentials,
            error: const ControllerAccessError(
              kind: ControllerAccessFailureKind.ipPending,
              message:
                  'Контролер ще не отримав IP-адресу Wi-Fi. Зачекайте або поверніться до Wi-Fi налаштувань.',
              technicalReason: 'BLE WifiIpAddress returned 0.0.0.0',
            ),
          ),
        );
        return;
      }

      _onboardingStorage.setConnectionState(
        WateringHubConnectionState.checkingLocalHttps,
      );
      _setState(
        CheckingLocalHttpsAccess(
          device: device,
          credentials: credentials,
          ipAddress: ipAddress.value,
        ),
      );

      await _localControllerApiClient.checkSettingsAccess(
        ipAddress: ipAddress.value,
        apiAccessToken: token.value,
      );

      await _onboardingStorage.completeOnboarding();
      _setState(
        ControllerAccessReady(
          device: device,
          credentials: credentials,
          ipAddress: ipAddress.value,
        ),
      );
    } on FatalAppException {
      rethrow;
    } on LocalControllerApiException catch (error) {
      _handleLocalControllerError(device, credentials, error);
    } catch (error) {
      _isBleConnected = false;
      _onboardingStorage.setConnectionState(
        WateringHubConnectionState.requiresBleRecovery,
      );
      _setState(
        ControllerAccessFailed(
          device: device,
          credentials: credentials,
          ipAddress: _state.controllerIpAddress,
          error: ControllerAccessError(
            kind: ControllerAccessFailureKind.unexpectedResponse,
            message:
                'Не вдалося прочитати IP-адресу або токен доступу через BLE.',
            technicalReason: _safeTechnicalReason(error),
          ),
        ),
      );
    }
  }

  Future<void> returnToWifiProvisioning() async {
    final state = _state;
    switch (state) {
      case AccessSetupReady(:final device, :final credentials):
      case ReadingControllerAccess(:final device, :final credentials):
      case CheckingLocalHttpsAccess(:final device, :final credentials):
      case ControllerIpPending(:final device, :final credentials):
      case ControllerAccessFailed(:final device, :final credentials):
      case ControllerAccessReady(:final device, :final credentials):
        _setState(
          WifiCredentialsFormReady(
            device: device,
            credentials: credentials.sanitizedForState,
          ),
        );
      default:
        return;
    }
  }

  Future<void> disconnect() async {
    final deviceId = _state.selectedDevice?.id;
    if (deviceId == null) {
      return;
    }
    await _bleService.disconnect(deviceId);
    _isBleConnected = false;
  }

  Future<void> _reconnectAfterReboot(
    BleDiscoveredDevice device,
    WifiCredentials credentials,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxReconnectAttempts; attempt += 1) {
      _setState(
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
        _isBleConnected = true;
        _setState(
          AccessSetupReady(
            device: device,
            credentials: credentials.sanitizedForState,
          ),
        );
        return;
      } catch (error) {
        lastError = error;
        _isBleConnected = false;
        if (attempt < _maxReconnectAttempts) {
          await Future<void>.delayed(_reconnectRetryDelay);
        }
      }
    }

    _setState(
      ReconnectAfterRebootBlocked(
        device: device,
        credentials: credentials.sanitizedForState,
        error: _wifiError(
          message: 'Не вдалося повторно підключитися до контролера через BLE.',
          operation: WifiProvisioningOperation.reconnectBle,
          error: lastError ?? StateError('BLE reconnect failed'),
        ),
      ),
    );
  }

  Future<void> _savePairedHub(BleDiscoveredDevice device) async {
    final now = DateTime.now().toUtc();
    final activeHub = _onboardingStorage.activeWateringHub;
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
            onboardingCompletedAt: null,
            createdAt: now,
            updatedAt: now,
          );
    await _onboardingStorage.saveActiveWateringHub(hub);
  }

  WateringHub _newHubForDevice(BleDiscoveredDevice device, DateTime now) {
    return WateringHub(
      id: _hubIdFromBleDeviceId(device.id),
      displayName: device.displayName,
      bleDeviceId: device.id,
      lastKnownIpAddress: null,
      apiAccessToken: null,
      serverDeviceId: null,
      onboardingCompletedAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _handleLocalControllerError(
    BleDiscoveredDevice device,
    WifiCredentials credentials,
    LocalControllerApiException error,
  ) {
    final kind = switch (error.kind) {
      LocalControllerApiErrorKind.networkUnavailable =>
        ControllerAccessFailureKind.networkUnavailable,
      LocalControllerApiErrorKind.tlsCertificate =>
        ControllerAccessFailureKind.tlsCertificate,
      LocalControllerApiErrorKind.tokenInvalid =>
        ControllerAccessFailureKind.tokenInvalid,
      LocalControllerApiErrorKind.controllerUnavailable =>
        ControllerAccessFailureKind.controllerUnavailable,
      LocalControllerApiErrorKind.unexpectedResponse =>
        ControllerAccessFailureKind.unexpectedResponse,
    };
    final connectionState = switch (error.kind) {
      LocalControllerApiErrorKind.tokenInvalid =>
        WateringHubConnectionState.tokenInvalid,
      LocalControllerApiErrorKind.networkUnavailable ||
      LocalControllerApiErrorKind.tlsCertificate ||
      LocalControllerApiErrorKind.controllerUnavailable =>
        WateringHubConnectionState.httpsUnavailable,
      LocalControllerApiErrorKind.unexpectedResponse =>
        WateringHubConnectionState.httpsUnavailable,
    };
    _onboardingStorage.setConnectionState(connectionState);
    _setState(
      ControllerAccessFailed(
        device: device,
        credentials: credentials,
        ipAddress: _state.controllerIpAddress,
        error: ControllerAccessError(
          kind: kind,
          message: _controllerAccessMessage(kind),
          technicalReason: error.message,
        ),
      ),
    );
  }

  String _controllerAccessMessage(ControllerAccessFailureKind kind) {
    return switch (kind) {
      ControllerAccessFailureKind.ipPending =>
        'Контролер ще не отримав IP-адресу Wi-Fi. Зачекайте або поверніться до Wi-Fi налаштувань.',
      ControllerAccessFailureKind.tokenInvalid =>
        'Контролер відхилив токен доступу. Потрібно повторно прочитати token через BLE.',
      ControllerAccessFailureKind.timeout ||
      ControllerAccessFailureKind.networkUnavailable =>
        'Не вдалося підключитися до локального HTTPS API. Перевірте, що телефон у тій самій Wi-Fi мережі.',
      ControllerAccessFailureKind.tlsCertificate =>
        'TLS-сертифікат контролера не пройшов перевірку fingerprint.',
      ControllerAccessFailureKind.controllerUnavailable =>
        'Контролер тимчасово недоступний через HTTPS API.',
      ControllerAccessFailureKind.unexpectedResponse =>
        'Контролер повернув неочікувану відповідь на GET /api/settings.',
    };
  }

  void _setAvailabilityState(BleAvailability availability) {
    if (availability == BleAvailability.ready) {
      _setState(const ReadyToScan());
      return;
    }
    _setState(BluetoothUnavailable(availability: availability));
  }

  void _setState(BleOnboardingState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  BleConnectionError _bleError(String message, Object error) {
    return BleConnectionError(
      message: message,
      technicalReason: _safeTechnicalReason(error),
    );
  }

  WifiProvisioningError _wifiError({
    required String message,
    required WifiProvisioningOperation operation,
    required Object error,
  }) {
    return WifiProvisioningError(
      message: message,
      technicalReason: _safeTechnicalReason(error),
      operation: operation,
    );
  }

  String _safeTechnicalReason(Object error) {
    final raw = error.toString();
    if (raw.length <= 240) {
      return raw;
    }
    return '${raw.substring(0, 240)}...';
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
    _isDisposed = true;
    _devicesSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}
