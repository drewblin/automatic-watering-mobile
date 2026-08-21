import '../../app/fatal_app_exception.dart';
import '../../app/onboarding_app_service.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/diagnostics/diagnostics_log.dart';
import '../../features/local_controller/mdns_controller_resolver.dart';
import '../../features/watering_hubs/watering_hub.dart';
import 'ble_onboarding_session.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_store.dart';
import 'wifi_provisioning_models.dart';

class BleControllerAccessFlow {
  const BleControllerAccessFlow({
    required BleOnboardingSession session,
    required BleOnboardingStateStore stateStore,
    required BleService bleService,
    required OnboardingAppService onboardingStorage,
    required MdnsControllerResolver mdnsControllerResolver,
    required DiagnosticsLog diagnosticsLog,
    Duration retryDelay = const Duration(seconds: 2),
    int maxAttempts = 5,
  })  : _session = session,
        _stateStore = stateStore,
        _bleService = bleService,
        _onboardingStorage = onboardingStorage,
        _mdnsControllerResolver = mdnsControllerResolver,
        _diagnosticsLog = diagnosticsLog,
        _retryDelay = retryDelay,
        _maxAttempts = maxAttempts;

  final BleOnboardingSession _session;
  final BleOnboardingStateStore _stateStore;
  final BleService _bleService;
  final OnboardingAppService _onboardingStorage;
  final MdnsControllerResolver _mdnsControllerResolver;
  final DiagnosticsLog _diagnosticsLog;
  final Duration _retryDelay;
  final int _maxAttempts;

  Future<void> bootstrapControllerAccess() async {
    final state = _stateStore.state;
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

  Future<void> returnToWifiProvisioning() async {
    final state = _stateStore.state;
    final device = state.selectedDevice;
    if (device == null) {
      return;
    }
    _stateStore.setState(
      WifiCredentialsFormReady(
        device: device,
        credentials: state.wifiCredentials.sanitizedForState,
      ),
    );
  }

  Future<void> disconnect() async {
    final deviceId = _stateStore.state.selectedDevice?.id;
    if (deviceId == null) {
      return;
    }
    await _bleService.disconnect(deviceId);
    _session.isBleConnected = false;
  }

  Future<void> _bootstrapControllerAccess({
    required BleDiscoveredDevice device,
    required WifiCredentials credentials,
  }) async {
    Object? lastUnexpectedError;
    String? lastIpPendingMessage;
    String? fixedAccessIpAddress;

    for (var attempt = 1; attempt <= _maxAttempts; ++attempt) {
      _stateStore.setState(
        ReadingControllerAccess(
          device: device,
          credentials: credentials,
        ),
      );

      try {
        if (!_session.isBleConnected) {
          await _bleService.reconnect(device);
          await _bleService.pairAndDiscoverServices(device);
          _session.isBleConnected = true;
        }

        final wifiAddress = await _bleService.readWifiIpAddress(device.id);
        _stateStore.setState(
          ReadingControllerAccess(
            device: device,
            credentials: credentials,
            ipAddress: wifiAddress.value,
          ),
        );

        if (wifiAddress.isPending) {
          lastIpPendingMessage =
              'Контролер ще не отримав IP-адресу Wi-Fi. Зачекайте або поверніться до Wi-Fi налаштувань.';
          recordDiagnosticsIssue(
            diagnosticsLog: _diagnosticsLog,
            message: lastIpPendingMessage,
            details: 'BLE WifiIpAddress returned 0.0.0.0',
          );
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(_retryDelay);
            continue;
          }
          _stateStore.setState(
            ControllerIpPending(
              device: device,
              credentials: credentials,
              message: lastIpPendingMessage,
            ),
          );
          return;
        }

        final token = await _bleService.readApiAccessToken(device.id);

        await _savePairedHub(device);
        fixedAccessIpAddress = await _resolveLocalAccessIpAddress(
          wifiAddress: wifiAddress,
          fixedAccessIpAddress: fixedAccessIpAddress,
        );
        final hub = _session.activeWateringHub!.copyWith(
          lastKnownIpAddress: fixedAccessIpAddress,
          lastKnownHostname: wifiAddress.localHostname,
          updatedAt: DateTime.now().toUtc(),
        );
        _session.activeWateringHub =
            await _onboardingStorage.saveControllerAccess(
          hub: hub,
          apiAccessToken: token.value,
        );

        _stateStore.setState(
          CheckingLocalHttpsAccess(
            device: device,
            credentials: credentials,
            ipAddress: fixedAccessIpAddress,
          ),
        );

        await _onboardingStorage.completeOnboarding(
          _session.activeWateringHub!,
        );
        _stateStore.setState(
          ControllerAccessReady(
            device: device,
            credentials: credentials,
            ipAddress: fixedAccessIpAddress,
          ),
        );
        return;
      } on FatalAppException {
        rethrow;
      } catch (error) {
        lastUnexpectedError = error;
        _session.isBleConnected = false;
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        break;
      }
    }

    if (lastIpPendingMessage != null) {
      _stateStore.setState(
        ControllerIpPending(
          device: device,
          credentials: credentials,
          message: lastIpPendingMessage,
        ),
      );
      return;
    }

    final error = lastUnexpectedError ?? StateError('Controller access failed');
    recordDiagnosticsIssue(
      diagnosticsLog: _diagnosticsLog,
      message: 'Не вдалося прочитати IP-адресу або токен доступу через BLE.',
      error: error,
    );
    _stateStore.setState(
      ControllerAccessFailed(
        device: device,
        credentials: credentials,
        ipAddress: _stateStore.state.controllerIpAddress,
        message: 'Не вдалося прочитати IP-адресу або токен доступу через BLE.',
      ),
    );
  }

  Future<String> _resolveLocalAccessIpAddress({
    required ControllerIpAddress wifiAddress,
    required String? fixedAccessIpAddress,
  }) async {
    if (fixedAccessIpAddress != null) {
      return fixedAccessIpAddress;
    }
    final resolvedIpAddress = await _mdnsControllerResolver.resolve(
      hostname: wifiAddress.hostname,
      localHostname: wifiAddress.localHostname,
    );
    if (resolvedIpAddress != null) {
      return resolvedIpAddress;
    }
    recordDiagnosticsIssue(
      diagnosticsLog: _diagnosticsLog,
      message: 'Використовуємо IP-адресу з BLE.',
      details: 'ipAddress=${wifiAddress.ipAddress}',
    );
    return wifiAddress.ipAddress;
  }

  Future<void> _savePairedHub(BleDiscoveredDevice device) async {
    final now = DateTime.now().toUtc();
    final activeHub = _session.activeWateringHub;
    final hub = activeHub == null
        ? _newHubForDevice(device, now)
        : activeHub.bleDeviceId == device.id || _session.isRecoveringExistingHub
            ? activeHub.copyWith(
                displayName: device.displayName,
                bleDeviceId: device.id,
                updatedAt: now,
              )
            : _newHubForDevice(device, now);
    await _onboardingStorage.saveActiveWateringHub(hub);
    _session.activeWateringHub = hub;
  }

  WateringHub _newHubForDevice(BleDiscoveredDevice device, DateTime now) {
    return WateringHub(
      id: _hubIdFromBleDeviceId(device.id),
      displayName: device.displayName,
      bleDeviceId: device.id,
      lastKnownIpAddress: null,
      lastKnownHostname: '',
      apiAccessToken: null,
      serverDeviceId: null,
      onboardingCompletedAt: null,
      createdAt: now,
      updatedAt: now,
    );
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
}
