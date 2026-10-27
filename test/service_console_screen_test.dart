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
    expect(tester.widget<Tab>(find.byType(Tab).last).text, 'Modbus регістр');
    expect(find.text('Діагностичних записів немає.'), findsOneWidget);
  });

  testWidgets('shows Modbus register write form', (tester) async {
    await tester.pumpWidget(_TestApp(
      diagnosticsLog: InMemoryDiagnosticsLog(),
      bleService: FakeBleService(),
      activeWateringHub: _hub(bleDeviceId: 'ble-42'),
    ));

    await tester.tap(find.text('Modbus регістр'));
    await tester.pumpAndSettle();

    expect(find.text('Адреса пристрою'), findsOneWidget);
    expect(find.text('Адреса регістра'), findsOneWidget);
    expect(find.text('Значення'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.widgetWithText(FilledButton, 'Записати в регістр'),
        findsOneWidget);
  });

  for (final input in [
    (
      slave: '',
      register: '0',
      value: '12',
      error: 'Адреса пристрою має бути від 0 до 255.'
    ),
    (
      slave: '256',
      register: '0',
      value: '12',
      error: 'Адреса пристрою має бути від 0 до 255.'
    ),
    (
      slave: '11',
      register: '',
      value: '12',
      error: 'Адреса регістра має бути від 0 до 65535.'
    ),
    (
      slave: '11',
      register: '65536',
      value: '12',
      error: 'Адреса регістра має бути від 0 до 65535.'
    ),
    (
      slave: '11',
      register: '0',
      value: '',
      error: 'Значення має бути від 0 до 65535.'
    ),
    (
      slave: '11',
      register: '0',
      value: '65536',
      error: 'Значення має бути від 0 до 65535.'
    ),
  ]) {
    testWidgets('rejects invalid Modbus register write input $input',
        (tester) async {
      final apiClient = FakeLocalControllerApiClient();
      await tester.pumpWidget(_TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        localControllerApiClient: apiClient,
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ));

      await _fillRegisterWriteForm(tester,
          slave: input.slave, register: input.register, value: input.value);
      await _tapWriteRegisterFormButton(tester);
      await tester.pump();

      expect(find.text(input.error), findsOneWidget);
      expect(apiClient.writtenRequest, isNull);
    });
  }

  for (final input in [
    (slave: 0, register: 0, value: 0),
    (slave: 255, register: 65535, value: 65535),
    (slave: 11, register: 256, value: 11),
  ]) {
    testWidgets('writes arbitrary Modbus register values $input',
        (tester) async {
      final apiClient = FakeLocalControllerApiClient();
      await tester.pumpWidget(_TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        localControllerApiClient: apiClient,
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ));

      await _fillRegisterWriteForm(tester,
          slave: '${input.slave}',
          register: '${input.register}',
          value: '${input.value}');
      await _tapWriteRegisterFormButton(tester);
      await tester.pumpAndSettle();

      expect(apiClient.writtenRequest?.slaveAddress, input.slave);
      expect(apiClient.writtenRequest?.registerAddress, input.register);
      expect(apiClient.writtenRequest?.value, input.value);
      expect(
          find.text(
              'Значення ${input.value} записано в регістр ${input.register} пристрою ${input.slave}.'),
          findsOneWidget);
    });
  }

  for (final failure in [
    (
      exception: const LocalControllerApiException(),
      message: 'Не вдалося записати значення в регістр.'
    ),
    (
      exception: const LocalControllerConnectionException(),
      message: 'Не вдалося записати значення в регістр.'
    ),
  ]) {
    testWidgets(
        'shows Modbus register write failure ${failure.exception.runtimeType}',
        (tester) async {
      final apiClient =
          FakeLocalControllerApiClient(exception: failure.exception);
      await tester.pumpWidget(_TestApp(
        diagnosticsLog: InMemoryDiagnosticsLog(),
        bleService: FakeBleService(),
        localControllerApiClient: apiClient,
        activeWateringHub: _hub(bleDeviceId: 'ble-42'),
      ));

      await _fillRegisterWriteForm(tester,
          slave: '11', register: '256', value: '500');
      await _tapWriteRegisterFormButton(tester);
      await tester.pumpAndSettle();

      expect(find.text(failure.message), findsOneWidget);
    });
  }

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
          modbusRegisterWriteController: ModbusRegisterWriteController(
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
    lastKnownHostname: 'watering-hub-a1b2c3.local',
    apiAccessToken: 'token',
    serverDeviceId: null,
    onboardingCompletedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _fillRegisterWriteForm(
  WidgetTester tester, {
  required String slave,
  required String register,
  required String value,
}) async {
  await tester.tap(find.text('Modbus регістр'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), slave);
  await tester.enterText(find.byType(TextField).at(1), register);
  await tester.enterText(find.byType(TextField).at(2), value);
}

Future<void> _tapWriteRegisterFormButton(WidgetTester tester) {
  return tester.tap(find.widgetWithText(FilledButton, 'Записати в регістр'));
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
    return const ControllerIpAddress(
      '192.168.1.42',
      hostname: 'watering-hub-a1b2c3',
      localHostname: 'watering-hub-a1b2c3.local',
    );
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
  ModbusRegisterWriteRequest? writtenRequest;

  @override
  Future<void> checkSettingsAccess({
    required String hostname,
    required String apiAccessToken,
  }) async {}

  @override
  Future<SettingsResponseData> getSettings({
    required String hostname,
    required String apiAccessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> putSettings({
    required String hostname,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {}

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String hostname,
    required String apiAccessToken,
  }) async {
    return const [];
  }

  @override
  Future<void> closeAllValves({
    required String hostname,
    required String apiAccessToken,
  }) async {}

  @override
  Future<void> openValveForTime({
    required String hostname,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) async {}

  @override
  Future<ModbusRegisterWriteResult> writeModbusRegister({
    required String hostname,
    required String apiAccessToken,
    required ModbusRegisterWriteRequest request,
  }) async {
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }
    writtenRequest = request;
    return ModbusRegisterWriteResult(
      status: 0,
      slaveAddress: request.slaveAddress,
      value: request.value,
      registerAddress: request.registerAddress,
    );
  }
}
