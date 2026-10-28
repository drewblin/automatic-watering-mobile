import 'dart:convert';

import 'package:automatic_watering_mobile/features/ble/ble_constants.dart';
import 'package:automatic_watering_mobile/features/ble/ble_models.dart';
import 'package:automatic_watering_mobile/features/ble/flutter_reactive_ble_service.dart';
import 'package:automatic_watering_mobile/features/onboarding/wifi_provisioning_models.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _BleTransport transport;
  late FlutterReactiveBleService service;

  setUp(() async {
    transport = _BleTransport();
    service = FlutterReactiveBleService(reactiveBle: transport);
    await service.connect(const BleDiscoveredDevice(
      id: 'hub',
      name: 'Automatic Watering Hub',
      rssi: null,
      isLikelyAutomaticWateringHub: true,
      advertisedServiceUuids: {},
    ));
  });

  tearDown(() => service.dispose());

  Future<SaveWifiSettingsResponse> save() => service.saveWifiSettings(
        deviceId: 'hub',
        credentials:
            const WifiCredentials(ssid: 'garden', password: 'password'),
      );

  test('Wi-Fi save reads the actual restart confirmation after writing',
      () async {
    expect((await save()).restartScheduled, isTrue);
    expect(transport.operations, ['write', 'read']);
    expect(
        transport.writtenPayload, {'ssid': 'garden', 'password': 'password'});
    expect(transport.writtenCharacteristic?.characteristicId.toString(),
        AutomaticWateringBleConstants.saveWifiSettings.uuid);
  });

  for (final response in [
    '{"success":false,"data":{},"error":"Save failed"}',
    '{"success":false,"data":{"restartScheduled":true},"error":"Save failed"}',
    '{"success":true,"data":{},"error":null}',
    '{"success":true,"data":{"restartScheduled":"true"},"error":null}',
    'invalid JSON',
  ]) {
    test('Wi-Fi save propagates rejected or malformed response $response',
        () async {
      transport.response = response;

      await expectLater(
          save(), throwsA(anyOf(isA<FormatException>(), isA<StateError>())));
    });
  }

  test('Wi-Fi save preserves an explicit negative restart confirmation',
      () async {
    transport.response =
        '{"success":true,"data":{"restartScheduled":false},"error":null}';

    expect((await save()).restartScheduled, isFalse);
  });

  test('Wi-Fi save propagates a read failure after the write', () async {
    final error = StateError('BLE disconnected before confirmation');
    transport.readError = error;

    await expectLater(save(), throwsA(same(error)));
    expect(transport.operations, ['write', 'read']);
  });

  test('Wi-Fi save stops when the write fails', () async {
    final error = StateError('BLE write failed');
    transport.writeError = error;

    await expectLater(save(), throwsA(same(error)));
    expect(transport.operations, ['write']);
  });
}

class _BleTransport implements FlutterReactiveBle {
  String response =
      '{"success":true,"data":{"restartScheduled":true},"error":null}';
  Object? readError;
  Object? writeError;
  final operations = <String>[];
  Object? writtenPayload;
  QualifiedCharacteristic? writtenCharacteristic;

  @override
  Stream<ConnectionStateUpdate> connectToDevice({
    required String id,
    Map<Uuid, List<Uuid>>? servicesWithCharacteristicsToDiscover,
    Duration? connectionTimeout,
  }) =>
      Stream.value(ConnectionStateUpdate(
        deviceId: id,
        connectionState: DeviceConnectionState.connected,
        failure: null,
      ));

  @override
  Future<void> writeCharacteristicWithResponse(
    QualifiedCharacteristic characteristic, {
    required List<int> value,
  }) async {
    operations.add('write');
    if (writeError case final error?) throw error;
    writtenCharacteristic = characteristic;
    writtenPayload = jsonDecode(utf8.decode(value));
  }

  @override
  Future<List<int>> readCharacteristic(
      QualifiedCharacteristic characteristic) async {
    operations.add('read');
    if (readError case final error?) throw error;
    return utf8.encode(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
