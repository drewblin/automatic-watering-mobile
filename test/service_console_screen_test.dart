import 'dart:async';
import 'dart:convert';

import 'package:automatic_watering_mobile/features/ble/ble_constants.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_address_change_models.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/sensors/sensor_metric.dart';
import 'package:automatic_watering_mobile/features/service_console/ble_logs/ble_controller_logs_controller.dart';
import 'package:automatic_watering_mobile/features/service_console/modbus_address/modbus_address_change_controller.dart';
import 'package:automatic_watering_mobile/features/service_console/service_console_dependencies.dart';
import 'package:automatic_watering_mobile/features/service_console/service_console_screen.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows diagnostics empty state', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
      ),
    );

    expect(find.text('Сервісна консоль'), findsOneWidget);
    expect(find.text('Діагностика'), findsOneWidget);
    expect(tester.widget<Tab>(find.byType(Tab).last).text, 'Modbus адреса');
    expect(find.text('Діагностичних записів немає.'), findsOneWidget);
  });

  testWidgets('shows Modbus address tab and validates address range',
      (tester) async {
    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ),
    );

    await tester.tap(find.text('Modbus адреса'));
    await tester.pumpAndSettle();

    expect(find.text('Поточна адреса девайса'), findsOneWidget);
    expect(find.text('Нова адреса'), findsOneWidget);
    expect(find.text('Адреса register'), findsOneWidget);
    expect(find.text('Save register address'), findsOneWidget);
    expect(find.text('Save value'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '0');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await _tapChangeAddressFormButton(tester);
    await tester.pump();

    expect(find.text('Поточна адреса має бути від 1 до 247.'), findsOneWidget);
  });

  testWidgets('blocks equal Modbus current and new addresses', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ),
    );

    await tester.tap(find.text('Modbus адреса'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), '11');
    await _tapChangeAddressFormButton(tester);
    await tester.pump();

    expect(
      find.text('Нова адреса має відрізнятися від поточної.'),
      findsOneWidget,
    );
  });

  testWidgets('validates Modbus register address range', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ),
    );

    await tester.tap(find.text('Modbus адреса'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.enterText(find.byType(TextField).at(2), '65536');
    await _tapChangeAddressFormButton(tester);
    await tester.pump();

    expect(
      find.text('Адреса register має бути від 0 до 65535.'),
      findsOneWidget,
    );
  });

  testWidgets('requires Modbus save register fields together', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ),
    );

    await tester.tap(find.text('Modbus адреса'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.enterText(find.byType(TextField).at(3), '512');
    await _tapChangeAddressFormButton(tester);
    await tester.pump();

    expect(
      find.text(
        'Save register address і save value потрібно заповнювати разом.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('submits Modbus address change through API', (tester) async {
    final apiClient = FakeLocalControllerApiClient();

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        localControllerApiClient: apiClient,
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ),
    );

    await tester.tap(find.text('Modbus адреса'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await _tapChangeAddressFormButton(tester);
    await tester.pumpAndSettle();

    expect(apiClient.changedCurrentAddress, 11);
    expect(apiClient.changedNewAddress, 12);
    expect(apiClient.changedRegisterAddress, 256);
    expect(find.text('Адресу 11 змінено на 12.'), findsOneWidget);
  });

  testWidgets('submits Modbus address change with save register through API',
      (tester) async {
    final apiClient = FakeLocalControllerApiClient();

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        localControllerApiClient: apiClient,
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ),
    );

    await tester.tap(find.text('Modbus адреса'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.enterText(find.byType(TextField).at(3), '512');
    await tester.enterText(find.byType(TextField).at(4), '1');
    await _tapChangeAddressFormButton(tester);
    await tester.pumpAndSettle();

    expect(apiClient.changedCurrentAddress, 11);
    expect(apiClient.changedNewAddress, 12);
    expect(apiClient.changedRegisterAddress, 256);
    expect(apiClient.changedSaveRegisterAddress, 512);
    expect(apiClient.changedSaveValue, 1);
    expect(find.text('Адресу 11 змінено на 12.'), findsOneWidget);
  });

  testWidgets('shows Modbus API failure message', (tester) async {
    final apiClient = FakeLocalControllerApiClient(
      exception: const LocalControllerApiException(),
    );

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        localControllerApiClient: apiClient,
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ),
    );

    await tester.tap(find.text('Modbus адреса'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await _tapChangeAddressFormButton(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Контролер повернув помилку.'),
      findsOneWidget,
    );
  });

  testWidgets('renders diagnostics entries newest first with technical fields',
      (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog()
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 9),
          message: 'Старіша помилка',
          method: 'GET',
          host: '192.168.1.42',
          path: '/api/settings',
          statusCode: 500,
          responseBody: '{"success":false}',
          exceptionType: 'FormatException',
          details: 'Settings envelope failed',
        ),
      )
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 10),
          message: 'Новіша помилка',
          method: 'POST',
          host: 'controller.local',
          path: '/api/valves/open-for-time',
          statusCode: 400,
        ),
      );

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: diagnosticsLog,
        bleService: FakeBleService(),
      ),
    );

    final newerTop = tester.getTopLeft(find.text('Новіша помилка')).dy;
    final olderTop = tester.getTopLeft(find.text('Старіша помилка')).dy;
    expect(newerTop, lessThan(olderTop));
    expect(find.textContaining('Метод: POST'), findsOneWidget);
    expect(find.textContaining('Хост: controller.local'), findsOneWidget);
    expect(
      find.textContaining('Шлях: /api/valves/open-for-time'),
      findsOneWidget,
    );
    expect(find.textContaining('HTTP статус: 400'), findsOneWidget);
    expect(find.text('Тіло відповіді'), findsOneWidget);
    expect(find.text('Деталі'), findsOneWidget);
  });

  testWidgets('shows diagnostics details without masking local memory data',
      (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog()
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 10),
          message: 'Authorization: Bearer 0123456789abcdef0123456789abcdef',
          responseBody: '{"remoteLogSettings":{"token":"log-token"}}',
          details: 'apiAccessToken=controller-token&next=true',
        ),
      );

    expect(diagnosticsLog.entries.single.message, contains('0123456789abcdef'));

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: diagnosticsLog,
        bleService: FakeBleService(),
      ),
    );

    await tester.tap(find.text('Тіло відповіді'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Деталі'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0123456789abcdef'), findsOneWidget);
    expect(find.textContaining('log-token'), findsOneWidget);
    expect(find.textContaining('controller-token'), findsOneWidget);
  });

  testWidgets('clears diagnostics entries after confirmation', (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog()
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 10),
          message: 'Помилка комунікації',
        ),
      );

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: diagnosticsLog,
        bleService: FakeBleService(),
      ),
    );

    await tester.tap(find.byTooltip('Очистити'));
    await tester.pumpAndSettle();

    expect(find.text('Очистити діагностичний лог?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Очистити'));
    await tester.pumpAndSettle();

    expect(diagnosticsLog.entries, isEmpty);
    expect(find.text('Помилка комунікації'), findsNothing);
    expect(find.text('Діагностичних записів немає.'), findsOneWidget);
  });

  testWidgets('shows BLE logs tab empty state before onboarding completes',
      (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: diagnosticsLog,
      activeWateringHubListenable: FakeActiveWateringHubListenable(null),
    );
    await controller.syncWithActiveController();

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: diagnosticsLog,
        bleService: bleService,
        bleLogsController: controller,
      ),
    );

    await tester.tap(find.text('BLE логи'));
    await tester.pumpAndSettle();

    expect(find.text('BLE логів немає.'), findsOneWidget);

    expect(
      find.text(
        'Активний контролер ще не налаштовано. Завершіть onboarding, щоб читати BLE логи.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'shows BLE logs missing device id for incomplete controller profile',
      (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: diagnosticsLog,
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: '')),
    );
    await controller.syncWithActiveController();

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: diagnosticsLog,
        bleService: bleService,
        bleLogsController: controller,
      ),
    );

    await tester.tap(find.text('BLE логи'));
    await tester.pumpAndSettle();

    expect(find.text('BLE ID відсутній.'), findsOneWidget);
  });

  testWidgets('renders buffered BLE logs and live updates newest first',
      (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: diagnosticsLog,
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-42')),
    );
    await controller.syncWithActiveController();
    bleService.emitLog('before open\n');

    await tester.pumpWidget(
      _TestApp(
        diagnosticsLog: diagnosticsLog,
        bleService: bleService,
        bleLogsController: controller,
      ),
    );

    await tester.tap(find.text('BLE логи'));
    await tester.pumpAndSettle();
    expect(find.text('before open'), findsOneWidget);

    bleService.emitLog('while open\n');
    await tester.pump();

    expect(bleService.reconnectCalls, 1);
    expect(bleService.reconnectedDeviceId, 'ble-42');
    expect(find.text('while open'), findsOneWidget);

    final whileOpenTop = tester.getTopLeft(find.text('while open')).dy;
    final beforeOpenTop = tester.getTopLeft(find.text('before open')).dy;
    expect(whileOpenTop, lessThan(beforeOpenTop));

    await tester.tap(find.byTooltip('Очистити'));
    await tester.pump();

    expect(find.text('before open'), findsNothing);
    expect(find.text('while open'), findsNothing);
    expect(find.text('BLE логів немає.'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.diagnosticsLog,
    required this.bleService,
    this.bleLogsController,
    this.localControllerApiClient,
    this.activeWateringHub,
  });

  final DiagnosticsLog diagnosticsLog;
  final BleService bleService;
  final BleControllerLogsController? bleLogsController;
  final LocalControllerApiClient? localControllerApiClient;
  final WateringHub? activeWateringHub;

  @override
  Widget build(BuildContext context) {
    final apiClient =
        localControllerApiClient ?? FakeLocalControllerApiClient();
    return MaterialApp(
      home: ServiceConsoleScreen(
        dependencies: ServiceConsoleDependencies(
          diagnosticsLog: diagnosticsLog,
          bleLogsController: bleLogsController ??
              BleControllerLogsController(
                bleService: bleService,
                diagnosticsLog: diagnosticsLog,
                activeWateringHubListenable:
                    FakeActiveWateringHubListenable(null),
              ),
          modbusAddressChangeController: ModbusAddressChangeController(
            apiClient: apiClient,
            activeControllerAccessProvider: () =>
                activeWateringHub?.readyAccess,
          ),
        ),
      ),
    );
  }
}

WateringHub _hub({required String bleDeviceId}) {
  final now = DateTime.utc(2026, 8, 16, 10);
  return WateringHub(
    id: 'hub-1',
    displayName: 'Теплиця',
    bleDeviceId: bleDeviceId,
    lastKnownIpAddress: '192.168.1.42',
    apiAccessToken: 'token',
    serverDeviceId: null,
    onboardingCompletedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _tapChangeAddressFormButton(WidgetTester tester) {
  return tester.tap(find.widgetWithText(FilledButton, 'Змінити адресу'));
}

class FakeActiveWateringHubListenable extends ChangeNotifier
    implements ActiveWateringHubListenable {
  FakeActiveWateringHubListenable(this._activeWateringHub);

  final WateringHub? _activeWateringHub;

  @override
  WateringHub? get activeWateringHub => _activeWateringHub;
}

class FakeBleService implements BleService {
  final _logs = StreamController<List<int>>.broadcast(sync: true);
  int reconnectCalls = 0;
  String? reconnectedDeviceId;

  void emitLog(String message) {
    _logs.add(utf8.encode(message));
  }

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
  Future<void> reconnect(BleDiscoveredDevice device) async {
    reconnectCalls += 1;
    reconnectedDeviceId = device.id;
  }

  @override
  Future<BleDeviceServices> pairAndDiscoverServices(
    BleDiscoveredDevice device,
  ) async {
    return BleDeviceServices(
      deviceId: device.id,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids:
          AutomaticWateringBleConstants.expectedCharacteristicUuids,
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<BleDeviceServices> discoverServices(String deviceId) async {
    return BleDeviceServices(
      deviceId: deviceId,
      hasAutomaticWateringService: true,
      discoveredCharacteristicUuids:
          AutomaticWateringBleConstants.expectedCharacteristicUuids,
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
    return _logs.stream;
  }

  @override
  Future<void> dispose() async {
    await _logs.close();
  }
}

class FakeLocalControllerApiClient implements LocalControllerApiClient {
  FakeLocalControllerApiClient({this.exception});

  final LocalControllerApiException? exception;
  int? changedCurrentAddress;
  int? changedNewAddress;
  int? changedRegisterAddress;
  int? changedSaveRegisterAddress;
  int? changedSaveValue;

  @override
  Future<void> checkSettingsAccess({
    required String ipAddress,
    required String apiAccessToken,
  }) async {}

  @override
  Future<SettingsResponseData> getSettings({
    required String ipAddress,
    required String apiAccessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {}

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    return const [];
  }

  @override
  Future<void> openValveForTime({
    required String ipAddress,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) async {}

  @override
  Future<ModbusAddressChangeResult> changeModbusAddress({
    required String ipAddress,
    required String apiAccessToken,
    required ModbusAddressChangeRequest request,
  }) async {
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }
    changedCurrentAddress = request.currentAddress;
    changedNewAddress = request.newAddress;
    changedRegisterAddress = request.registerAddress;
    changedSaveRegisterAddress = request.saveRegisterAddress;
    changedSaveValue = request.saveValue;
    return ModbusAddressChangeResult(
      currentAddress: request.currentAddress,
      newAddress: request.newAddress,
      registerAddress: request.registerAddress,
    );
  }
}
