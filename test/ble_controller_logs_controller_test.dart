import 'dart:async';
import 'dart:convert';

import 'package:automatic_watering_mobile/features/ble/ble_constants.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/ble_service.dart';
import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:automatic_watering_mobile/features/service_console/ble_logs/ble_controller_logs_controller.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows no active controller without touching BLE', () async {
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable: FakeActiveWateringHubListenable(null),
    );

    await controller.syncWithActiveController();

    expect(
      controller.state.connectionState,
      BleControllerLogsConnectionState.noActiveController,
    );
    expect(
      controller.state.userMessage,
      'Активний контролер ще не налаштовано. Завершіть onboarding, щоб читати BLE логи.',
    );
    expect(bleService.startScanCalls, 0);
    expect(bleService.reconnectCalls, 0);
  });

  test('shows missing BLE device id without starting BLE scan', () async {
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: '')),
    );

    await controller.syncWithActiveController();

    expect(
      controller.state.connectionState,
      BleControllerLogsConnectionState.missingBleDeviceId,
    );
    expect(controller.state.userMessage, 'BLE ID відсутній.');
    expect(bleService.startScanCalls, 0);
    expect(bleService.reconnectCalls, 0);
  });

  test(
      'connects with active BLE device id and records notifications newest first',
      () async {
    var tick = 0;
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
      clock: () => DateTime.utc(2026, 8, 16, 10, 0, tick++),
    );

    await controller.syncWithActiveController();
    bleService.emitLog('old log\nnew log\n');

    expect(bleService.startScanCalls, 0);
    expect(bleService.reconnectCalls, 1);
    expect(bleService.reconnectedDeviceId, 'ble-1');
    expect(
      controller.state.connectionState,
      BleControllerLogsConnectionState.connected,
    );
    expect(
      controller.state.subscriptionState,
      BleControllerLogsSubscriptionState.subscribed,
    );
    expect(
      controller.state.records.map((record) => record.message),
      ['new log', 'old log'],
    );
    expect(
      controller.state.records.first.receivedAt,
      DateTime.utc(2026, 8, 16, 10, 0, 1),
    );
  });

  test('repeated sync with same active hub keeps existing BLE subscription',
      () async {
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
    );

    await controller.syncWithActiveController();
    await controller.syncWithActiveController();

    expect(bleService.reconnectCalls, 1);
    expect(bleService.disconnectCalls, 0);
  });

  test('listens to active hub changes and connects without external trigger',
      () async {
    final activeHub = FakeActiveWateringHubListenable(null);
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable: activeHub,
    );

    await controller.syncWithActiveController();
    activeHub.setActiveWateringHub(_hub(bleDeviceId: 'ble-2'));
    await controller.syncWithActiveController();

    expect(bleService.reconnectCalls, 1);
    expect(bleService.reconnectedDeviceId, 'ble-2');
    expect(
      controller.state.connectionState,
      BleControllerLogsConnectionState.connected,
    );
  });

  test('limits volatile records and clears without touching diagnostics',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: diagnosticsLog,
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
      maxRecords: 2,
    );

    await controller.syncWithActiveController();
    bleService
      ..emitLog('one\n')
      ..emitLog('two\n')
      ..emitLog('three\n');

    expect(
      controller.state.records.map((record) => record.message),
      ['three', 'two'],
    );

    controller.clear();

    expect(controller.state.records, isEmpty);
    expect(diagnosticsLog.entries, isEmpty);
  });

  test('logs invalid UTF-8 payload to diagnostics and shows short UI message',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: diagnosticsLog,
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
      autoReconnect: false,
    );

    await controller.syncWithActiveController();
    bleService.emitRaw([0xC3, 0x28]);

    expect(controller.state.records, isEmpty);
    expect(controller.state.userMessage, 'Отримано неочікуваний payload.');
    expect(diagnosticsLog.entries.single.message, contains('payload'));
    expect(diagnosticsLog.entries.single.details, contains('195'));
  });

  test('reassembles line-based chunks before recording a log', () async {
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
    );

    await controller.syncWithActiveController();
    bleService.emitLog('part');

    expect(controller.state.records, isEmpty);

    bleService.emitLog('ial line\nnext');

    expect(
      controller.state.records.map((record) => record.message),
      ['partial line'],
    );

    bleService.emitLog(' line\n');

    expect(
      controller.state.records.map((record) => record.message),
      ['next line', 'partial line'],
    );
  });

  test('disconnects BLE connection when disposed', () async {
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
    );

    await controller.syncWithActiveController();
    controller.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(bleService.disconnectCalls, 1);
    expect(bleService.disconnectedDeviceId, 'ble-1');
  });

  test('manual disconnect wins over late reconnect completion', () async {
    final reconnectCompleter = Completer<void>();
    final bleService = FakeBleService(reconnectCompleter: reconnectCompleter);
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: InMemoryDiagnosticsLog(),
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
    );

    final connectFuture = controller.syncWithActiveController();
    await Future<void>.delayed(Duration.zero);
    await controller.disconnect();

    reconnectCompleter.complete();
    await connectFuture;

    expect(controller.state.connectionState,
        BleControllerLogsConnectionState.idle);
    expect(
      controller.state.subscriptionState,
      BleControllerLogsSubscriptionState.idle,
    );
    expect(bleService.disconnectCalls, 2);
  });

  test('cleans up connection when subscription setup fails', () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final bleService = FakeBleService(failSubscribe: true);
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: diagnosticsLog,
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
    );

    await controller.syncWithActiveController();

    expect(
      controller.state.connectionState,
      BleControllerLogsConnectionState.disconnected,
    );
    expect(
      controller.state.subscriptionState,
      BleControllerLogsSubscriptionState.failed,
    );
    expect(
        controller.state.userMessage, 'Не вдалося підписатися на сповіщення.');
    expect(bleService.disconnectCalls, 1);
    expect(diagnosticsLog.entries.single.message, contains('підписатися'));
  });

  test('records subscription errors and reconnects automatically', () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final bleService = FakeBleService();
    final controller = BleControllerLogsController(
      bleService: bleService,
      diagnosticsLog: diagnosticsLog,
      activeWateringHubListenable:
          FakeActiveWateringHubListenable(_hub(bleDeviceId: 'ble-1')),
      reconnectDelay: Duration.zero,
    );

    await controller.syncWithActiveController();
    bleService.failLogs(StateError('link lost'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(bleService.reconnectCalls, 2);
    expect(
      controller.state.connectionState,
      BleControllerLogsConnectionState.connected,
    );
    expect(diagnosticsLog.entries.single.message, contains('BLE логи'));
  });
}

WateringHub _hub({required String bleDeviceId}) {
  final now = DateTime.utc(2026, 8, 16, 10);
  return WateringHub(
    id: 'hub-1',
    displayName: 'Теплиця',
    bleDeviceId: bleDeviceId,
    lastKnownIpAddress: '192.168.1.42',
    lastKnownHostname: 'watering-hub-a1b2c3.local',
    apiAccessToken: 'token',
    serverDeviceId: null,
    onboardingCompletedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

class FakeActiveWateringHubListenable extends ChangeNotifier
    implements ActiveWateringHubListenable {
  FakeActiveWateringHubListenable(this._activeWateringHub);

  WateringHub? _activeWateringHub;

  @override
  WateringHub? get activeWateringHub => _activeWateringHub;

  void setActiveWateringHub(WateringHub? hub) {
    _activeWateringHub = hub;
    notifyListeners();
  }
}

class FakeBleService implements BleService {
  FakeBleService({
    this.failSubscribe = false,
    this.reconnectCompleter,
  });

  final bool failSubscribe;
  final Completer<void>? reconnectCompleter;
  final _logs = StreamController<List<int>>.broadcast(sync: true);
  int startScanCalls = 0;
  int reconnectCalls = 0;
  int disconnectCalls = 0;
  String? reconnectedDeviceId;
  String? disconnectedDeviceId;

  void emitLog(String message) {
    emitRaw(utf8.encode(message));
  }

  void emitRaw(List<int> payload) {
    _logs.add(payload);
  }

  void failLogs(Object error) {
    _logs.addError(error);
  }

  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices =>
      const Stream.empty();

  @override
  Future<BleAvailability> checkAvailability() async => BleAvailability.ready;

  @override
  Future<BleAvailability> requestPermissions() async => BleAvailability.ready;

  @override
  Future<void> startScan() async {
    startScanCalls += 1;
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(BleDiscoveredDevice device) async {}

  @override
  Future<void> reconnect(BleDiscoveredDevice device) async {
    reconnectCalls += 1;
    reconnectedDeviceId = device.id;
    await reconnectCompleter?.future;
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
  Future<void> disconnect(String deviceId) async {
    disconnectCalls += 1;
    disconnectedDeviceId = deviceId;
  }

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
    if (failSubscribe) {
      throw StateError('subscribe failed');
    }
    return _logs.stream;
  }

  @override
  Future<void> dispose() async {
    await _logs.close();
  }
}
