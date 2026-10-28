import 'dart:async';

import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_register_read_models.dart';
import 'package:automatic_watering_mobile/features/service_console/modbus_register_read/modbus_register_read_controller.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter_test/flutter_test.dart';

import 'service_console_screen_test.dart' show FakeLocalControllerApiClient;

void main() {
  late FakeLocalControllerApiClient apiClient;
  late ModbusRegisterReadController controller;
  late AppStateStore stateStore;

  setUp(() {
    apiClient = FakeLocalControllerApiClient();
    stateStore = AppStateStore();
    stateStore.setState(AppState.readyForOnboarding(activeWateringHub: _hub()));
    controller = ModbusRegisterReadController(
      apiClient: apiClient,
      stateStore: stateStore,
    );
  });

  tearDown(() {
    controller.dispose();
    stateStore.dispose();
  });

  for (final input in [
    (slave: '-1', register: '0', quantity: '1'),
    (slave: '256', register: '0', quantity: '1'),
    (slave: '1', register: '-1', quantity: '1'),
    (slave: '1', register: '65536', quantity: '1'),
    (slave: '1', register: '0', quantity: '0'),
    (slave: '1', register: '0', quantity: '65'),
    (slave: '1', register: '65535', quantity: '2'),
  ]) {
    test('forwards numeric read input $input for controller validation',
        () async {
      apiClient.readResult = _result();

      expect(
          await controller.submit(
            slaveAddressText: input.slave,
            registerAddressText: input.register,
            quantityText: input.quantity,
          ),
          isTrue);
      expect(apiClient.readRequests.single.toJson(), {
        'slaveAddress': int.parse(input.slave),
        'registerAddress': int.parse(input.register),
        'quantity': int.parse(input.quantity),
      });
      expect(controller.state.status, ModbusRegisterReadStatus.success);
    });
  }

  test('reads with active hub access and exposes returned addresses and values',
      () async {
    apiClient.readResult = _result();

    expect(await _submit(controller), isTrue);

    expect(apiClient.readHostname, 'watering-hub.local');
    expect(apiClient.readApiAccessToken, 'token');
    expect(apiClient.readRequests.single.toJson(),
        {'slaveAddress': 11, 'registerAddress': 256, 'quantity': 2});
    expect(controller.state.result?.slaveAddress, 11);
    expect(controller.state.result?.registerAddress, 256);
    expect(controller.state.result?.values, [123, 456]);
  });

  test('missing active access blocks read and is rechecked on retry', () async {
    stateStore.setState(AppState.readyForOnboarding(activeWateringHub: null));
    expect(await _submit(controller), isFalse);
    expect(controller.state.status, ModbusRegisterReadStatus.failure);
    expect(apiClient.readRequests, isEmpty);

    stateStore.setState(AppState.readyForOnboarding(activeWateringHub: _hub()));
    expect(await _submit(controller), isTrue);
    expect(apiClient.readRequests, hasLength(1));
  });

  test('uses updated controller access from app state for each read', () async {
    expect(await _submit(controller), isTrue);
    stateStore.setState(AppState.readyForOnboarding(
      activeWateringHub: _hub().copyWith(
        lastKnownHostname: 'other-hub.local',
        apiAccessToken: 'updated-token',
      ),
    ));

    expect(await _submit(controller), isTrue);
    expect(apiClient.readHostname, 'other-hub.local');
    expect(apiClient.readApiAccessToken, 'updated-token');
    expect(apiClient.readRequests, hasLength(2));
  });

  test('blocks duplicate submission while read is pending', () async {
    final completer = Completer<ModbusRegisterReadResult>();
    apiClient.readFuture = completer.future;
    final pending = _submit(controller);

    expect(controller.state.isSubmitting, isTrue);
    expect(await _submit(controller), isFalse);
    expect(apiClient.readRequests, hasLength(1));

    completer.complete(_result());
    expect(await pending, isTrue);
    expect(controller.state.isSubmitting, isFalse);
  });

  for (final error in [
    const LocalControllerConnectionException(),
    const LocalControllerApiException(),
    StateError('Unexpected failure'),
  ]) {
    test('clears stale result and allows retry after $error', () async {
      expect(await _submit(controller), isTrue);
      apiClient.readException = error;

      expect(await _submit(controller), isFalse);
      expect(controller.state.status, ModbusRegisterReadStatus.failure);
      expect(controller.state.isSubmitting, isFalse);
      expect(controller.state.result, isNull);
      expect(controller.state.message, 'Не вдалося прочитати регістри.');

      apiClient.readException = null;
      expect(await _submit(controller), isTrue);
      expect(controller.state.message, isNull);
      expect(apiClient.readRequests, hasLength(3));
    });
  }

  test('late completion after disposal does not notify listeners', () async {
    final completer = Completer<ModbusRegisterReadResult>();
    apiClient.readFuture = completer.future;
    final disposable = ModbusRegisterReadController(
      apiClient: apiClient,
      stateStore: stateStore,
    );
    var notifications = 0;
    disposable.addListener(() => notifications++);
    final pending = _submit(disposable);
    expect(notifications, 1);
    disposable.dispose();
    completer.complete(_result());

    expect(await pending, isFalse);
    expect(notifications, 1);
  });
}

Future<bool> _submit(ModbusRegisterReadController controller) =>
    controller.submit(
      slaveAddressText: '11',
      registerAddressText: '256',
      quantityText: '2',
    );

ModbusRegisterReadResult _result() => ModbusRegisterReadResult(
      status: 0,
      slaveAddress: 11,
      registerAddress: 256,
      quantity: 2,
      values: [123, 456],
    );

WateringHub _hub() => WateringHub(
      id: 'hub-1',
      displayName: 'Теплиця',
      bleDeviceId: 'ble-1',
      lastKnownHostname: 'watering-hub.local',
      apiAccessToken: 'token',
      serverDeviceId: null,
      onboardingCompletedAt: DateTime.utc(2026),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
