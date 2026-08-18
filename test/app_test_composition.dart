import 'package:automatic_watering_mobile/app/app_controller.dart';
import 'package:automatic_watering_mobile/app/app_startup_service.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/app/active_watering_hub_listenable.dart';
import 'package:automatic_watering_mobile/app/onboarding_app_service.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_save_controller.dart';
import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/home/home_dashboard_controller.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/service_console/ble_logs/ble_controller_logs_controller.dart';
import 'package:automatic_watering_mobile/features/service_console/modbus_address/modbus_address_change_controller.dart';
import 'package:automatic_watering_mobile/features/service_console/service_console_dependencies.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

class TestAppComposition {
  TestAppComposition({
    InMemoryWateringHubStorage? wateringHubStorage,
    InMemoryWateringHubTokenStorage? tokenStorage,
    InMemoryDiagnosticsLog? diagnosticsLog,
    BleService? bleService,
    required LocalControllerApiClient localControllerApiClient,
  })  : wateringHubStorage = wateringHubStorage ?? InMemoryWateringHubStorage(),
        tokenStorage = tokenStorage ?? InMemoryWateringHubTokenStorage(),
        diagnosticsLog = diagnosticsLog ?? InMemoryDiagnosticsLog() {
    final stateStore = AppStateStore();
    final controllerSettingsRepository = ControllerSettingsRepository(
      apiClient: localControllerApiClient,
    );
    final startup = AppStartupService(
      stateStore: stateStore,
      wateringHubStorage: this.wateringHubStorage,
      tokenStorage: this.tokenStorage,
      controllerSettingsRepository: controllerSettingsRepository,
      diagnosticsLog: this.diagnosticsLog,
    );
    onboarding = OnboardingAppService(
      stateStore: stateStore,
      wateringHubStorage: this.wateringHubStorage,
      tokenStorage: this.tokenStorage,
    );
    appController = AppController(
      stateStore: stateStore,
      startupService: startup,
      serviceConsoleDependencies: ServiceConsoleDependencies(
        diagnosticsLog: this.diagnosticsLog,
        bleLogsController: BleControllerLogsController(
          bleService: bleService ?? _NoopBleService(),
          diagnosticsLog: this.diagnosticsLog,
          activeWateringHubListenable: AppStateActiveWateringHubListenable(
            stateStore,
          ),
          autoReconnect: false,
        ),
        modbusAddressChangeController: ModbusAddressChangeController(
          apiClient: localControllerApiClient,
          activeControllerAccessProvider: () =>
              stateStore.state.activeWateringHub?.readyAccess,
        ),
      ),
      settingsSaveController: ControllerSettingsSaveController(
        stateStore: stateStore,
        repository: controllerSettingsRepository,
        rebootDelay: Duration.zero,
        reconnectAttemptDelay: Duration.zero,
        reconnectTimeout: const Duration(seconds: 1),
      ),
      homeDashboardController: HomeDashboardController(
        stateStore: stateStore,
        settingsRepository: controllerSettingsRepository,
        apiClient: localControllerApiClient,
      ),
    );
  }

  final InMemoryWateringHubStorage wateringHubStorage;
  final InMemoryWateringHubTokenStorage tokenStorage;
  final InMemoryDiagnosticsLog diagnosticsLog;
  late final AppController appController;
  late final OnboardingAppService onboarding;
}

class _NoopBleService implements BleService {
  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices =>
      const Stream.empty();

  @override
  Future<BleAvailability> checkAvailability() async => BleAvailability.ready;

  @override
  Future<BleAvailability> requestPermissions() async => BleAvailability.ready;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(BleDiscoveredDevice device) async {}

  @override
  Future<void> reconnect(BleDiscoveredDevice device) async {}

  @override
  Future<BleDeviceServices> pairAndDiscoverServices(
    BleDiscoveredDevice device,
  ) async {
    return BleDeviceServices(
      deviceId: device.id,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids: const {},
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<BleDeviceServices> discoverServices(String deviceId) async {
    return BleDeviceServices(
      deviceId: deviceId,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids: const {},
    );
  }

  @override
  Future<WifiCredentials> readWifiSettings(String deviceId) async {
    return WifiCredentials.empty();
  }

  @override
  Future<ControllerIpAddress> readWifiIpAddress(String deviceId) async {
    return const ControllerIpAddress('192.168.1.42');
  }

  @override
  Future<ControllerApiAccessToken> readApiAccessToken(String deviceId) async {
    return const ControllerApiAccessToken('token');
  }

  @override
  Future<SaveWifiSettingsResponse> saveWifiSettings({
    required String deviceId,
    required WifiCredentials credentials,
  }) async {
    return const SaveWifiSettingsResponse(restartScheduled: true);
  }

  @override
  Stream<List<int>> subscribeToLogNotifications(String deviceId) {
    return const Stream.empty();
  }

  @override
  Future<void> dispose() async {}
}
