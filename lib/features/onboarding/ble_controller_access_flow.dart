import '../../app/fatal_app_exception.dart';
import '../../app/onboarding_app_service.dart';
import '../../features/ble/ble_constants.dart';
import '../../features/ble/ble_models.dart';
import '../../features/ble/ble_service.dart';
import '../../features/local_controller/local_controller_api_client.dart';
import '../../features/watering_hubs/watering_hub.dart';
import 'ble_onboarding_errors.dart';
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
    required LocalControllerApiClient localControllerApiClient,
  })  : _session = session,
        _stateStore = stateStore,
        _bleService = bleService,
        _onboardingStorage = onboardingStorage,
        _localControllerApiClient = localControllerApiClient;

  final BleOnboardingSession _session;
  final BleOnboardingStateStore _stateStore;
  final BleService _bleService;
  final OnboardingAppService _onboardingStorage;
  final LocalControllerApiClient _localControllerApiClient;

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
    _stateStore.setState(
      ReadingControllerAccess(
        device: device,
        credentials: credentials,
      ),
    );

    try {
      if (!_session.isBleConnected) {
        await _bleService.reconnect(device);
        await _bleService.pairAndDiscoverServices(
          device: device,
          passkey: AutomaticWateringBleConstants.pairingPasskey,
        );
        _session.isBleConnected = true;
      }

      final ipAddress = await _bleService.readWifiIpAddress(device.id);
      _stateStore.setState(
        ReadingControllerAccess(
          device: device,
          credentials: credentials,
          ipAddress: ipAddress.value,
        ),
      );

      if (ipAddress.isPending) {
        _stateStore.setState(
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

      final token = await _bleService.readApiAccessToken(device.id);

      await _savePairedHub(device);
      final hub = _session.activeWateringHub!.copyWith(
        lastKnownIpAddress: ipAddress.value,
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
          ipAddress: ipAddress.value,
        ),
      );

      await _localControllerApiClient.checkSettingsAccess(
        ipAddress: ipAddress.value,
        apiAccessToken: token.value,
      );

      await _onboardingStorage.completeOnboarding(
        _session.activeWateringHub!,
      );
      _stateStore.setState(
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
      _session.isBleConnected = false;
      _stateStore.setState(
        ControllerAccessFailed(
          device: device,
          credentials: credentials,
          ipAddress: _stateStore.state.controllerIpAddress,
          error: ControllerAccessError(
            kind: ControllerAccessFailureKind.unexpectedResponse,
            message:
                'Не вдалося прочитати IP-адресу або токен доступу через BLE.',
            technicalReason: safeOnboardingTechnicalReason(error),
          ),
        ),
      );
    }
  }

  void _handleLocalControllerError(
    BleDiscoveredDevice device,
    WifiCredentials credentials,
    LocalControllerApiException error,
  ) {
    final kind = controllerAccessFailureKindFrom(error.kind);
    _stateStore.setState(
      ControllerAccessFailed(
        device: device,
        credentials: credentials,
        ipAddress: _stateStore.state.controllerIpAddress,
        error: ControllerAccessError(
          kind: kind,
          message: controllerAccessMessage(kind),
          technicalReason: error.message,
        ),
      ),
    );
  }

  Future<void> _savePairedHub(BleDiscoveredDevice device) async {
    final now = DateTime.now().toUtc();
    final activeHub = _session.activeWateringHub;
    final hub = activeHub?.bleDeviceId == device.id
        ? activeHub!.copyWith(
            displayName: device.displayName,
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
