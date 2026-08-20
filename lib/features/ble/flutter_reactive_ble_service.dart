import 'dart:async';
import 'dart:convert';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_constants.dart';
import 'ble_models.dart';
import 'ble_service.dart';
import '../onboarding/wifi_provisioning_models.dart';
import '../../core/api_envelope.dart';

class FlutterReactiveBleService implements BleService {
  FlutterReactiveBleService({FlutterReactiveBle? reactiveBle})
      : _ble = reactiveBle ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  final _devicesController =
      StreamController<List<BleDiscoveredDevice>>.broadcast();
  final Map<String, BleDiscoveredDevice> _devices = {};
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  String? _connectedDeviceId;

  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices {
    return _devicesController.stream;
  }

  @override
  Future<BleAvailability> checkAvailability() async {
    final status = _ble.status;
    if (status == BleStatus.poweredOff) {
      return BleAvailability.bluetoothDisabled;
    }
    if (status == BleStatus.unauthorized) {
      return BleAvailability.permissionRequired;
    }
    if (await _hasRequiredPermissions()) {
      return BleAvailability.ready;
    }
    return BleAvailability.permissionRequired;
  }

  @override
  Future<BleAvailability> requestPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();

    if (bluetoothScan.isPermanentlyDenied ||
        bluetoothConnect.isPermanentlyDenied) {
      return BleAvailability.permissionRequired;
    }

    return checkAvailability();
  }

  @override
  Future<void> startScan() async {
    final availability = await checkAvailability();
    if (availability != BleAvailability.ready) {
      return;
    }

    await stopScan();
    _devices.clear();
    _devicesController.add(const []);

    _scanSubscription = _ble.scanForDevices(
      withServices: [Uuid.parse(AutomaticWateringBleConstants.serviceUuid)],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        final mapped = _mapDevice(device);
        if (!mapped.isLikelyAutomaticWateringHub) {
          return;
        }
        _devices[mapped.id] = mapped;
        _devicesController.add(List.unmodifiable(_devices.values));
      },
      onError: _devicesController.addError,
    );
  }

  @override
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<void> connect(BleDiscoveredDevice device) async {
    await stopScan();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDeviceId = null;

    final completer = Completer<void>();
    _connectionSubscription = _ble
        .connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {
        Uuid.parse(AutomaticWateringBleConstants.serviceUuid):
            AutomaticWateringBleConstants.expectedCharacteristicUuids
                .map(Uuid.parse)
                .toList(),
      },
      connectionTimeout: const Duration(seconds: 20),
    )
        .listen(
      (update) {
        switch (update.connectionState) {
          case DeviceConnectionState.connecting:
            return;
          case DeviceConnectionState.connected:
            _connectedDeviceId = device.id;
            if (!completer.isCompleted) {
              completer.complete();
            }
          case DeviceConnectionState.disconnecting:
          case DeviceConnectionState.disconnected:
            if (_connectedDeviceId == device.id) {
              _connectedDeviceId = null;
            }
            if (!completer.isCompleted) {
              completer.completeError(
                StateError('BLE device disconnected before pairing'),
              );
            }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    try {
      await completer.future;
    } catch (_) {
      if (_connectionSubscription != null) {
        await _connectionSubscription?.cancel();
        _connectionSubscription = null;
      }
      if (_connectedDeviceId == device.id) {
        _connectedDeviceId = null;
      }
      rethrow;
    }
  }

  @override
  Future<void> reconnect(BleDiscoveredDevice device) async {
    await connect(device);
  }

  @override
  Future<BleDeviceServices> pairAndDiscoverServices(
    BleDiscoveredDevice device,
  ) async {
    final services = await discoverServices(device.id);
    if (!services.hasAutomaticWateringService) {
      throw StateError('Expected Automatic Watering BLE service not found');
    }
    return services;
  }

  @override
  Future<void> disconnect(String deviceId) async {
    if (_connectedDeviceId != deviceId) {
      return;
    }
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDeviceId = null;
  }

  @override
  Future<BleDeviceServices> discoverServices(String deviceId) async {
    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    final expectedServiceUuid = AutomaticWateringBleConstants.serviceUuid;
    final expectedService = services
        .where(
          (service) =>
              service.id.toString().toLowerCase() == expectedServiceUuid,
        )
        .firstOrNull;

    return BleDeviceServices(
      deviceId: deviceId,
      hasAutomaticWateringService: expectedService != null,
      discoveredCharacteristicUuids: expectedService == null
          ? const {}
          : expectedService.characteristics
              .map(
                (characteristic) => characteristic.id.toString().toLowerCase(),
              )
              .toSet(),
    );
  }

  @override
  Future<WifiCredentials> readWifiSettings(String deviceId) async {
    return _readEnvelopeCharacteristic(
      deviceId: deviceId,
      characteristicUuid: AutomaticWateringBleConstants.wifiSettings.uuid,
      parseData: WifiCredentials.fromControllerSettings,
      failureMessage: 'Wi-Fi settings read failed',
    );
  }

  @override
  Future<ControllerIpAddress> readWifiIpAddress(String deviceId) async {
    return _readEnvelopeCharacteristic(
      deviceId: deviceId,
      characteristicUuid: AutomaticWateringBleConstants.wifiIpAddress.uuid,
      parseData: ControllerIpAddress.fromJson,
      failureMessage: 'Wi-Fi IP address read failed',
    );
  }

  @override
  Future<ControllerApiAccessToken> readApiAccessToken(String deviceId) async {
    return _readEnvelopeCharacteristic(
      deviceId: deviceId,
      characteristicUuid: AutomaticWateringBleConstants.apiAccessToken.uuid,
      parseData: ControllerApiAccessToken.fromJson,
      failureMessage: 'API access token read failed',
    );
  }

  @override
  Future<SaveWifiSettingsResponse> saveWifiSettings({
    required String deviceId,
    required WifiCredentials credentials,
  }) async {
    return _writeJsonAndReadEnvelopeCharacteristic(
      deviceId: deviceId,
      characteristicUuid: AutomaticWateringBleConstants.saveWifiSettings.uuid,
      payload: credentials.toBleJson(),
      parseData: SaveWifiSettingsResponse.fromJson,
      failureMessage: 'Wi-Fi settings save failed',
      fallbackOnReadFailure:
          const SaveWifiSettingsResponse(restartScheduled: true),
    );
  }

  @override
  Stream<List<int>> subscribeToLogNotifications(String deviceId) {
    _ensureConnected(deviceId);
    return _ble.subscribeToCharacteristic(
      _qualifiedCharacteristic(
        deviceId,
        AutomaticWateringBleConstants.logNotifications.uuid,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await _connectionSubscription?.cancel();
    await _devicesController.close();
  }

  Future<bool> _hasRequiredPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.status;
    final bluetoothConnect = await Permission.bluetoothConnect.status;
    if (bluetoothScan.isDenied || bluetoothConnect.isDenied) {
      return false;
    }
    if (bluetoothScan.isPermanentlyDenied ||
        bluetoothConnect.isPermanentlyDenied) {
      return false;
    }
    return true;
  }

  BleDiscoveredDevice _mapDevice(DiscoveredDevice device) {
    final advertisedServiceUuids = device.serviceUuids
        .map((uuid) => uuid.toString().toLowerCase())
        .toSet();
    final name = device.name.trim();
    final hasExpectedName = name == AutomaticWateringBleConstants.deviceName;
    final advertisesService = advertisedServiceUuids.contains(
      AutomaticWateringBleConstants.serviceUuid,
    );

    return BleDiscoveredDevice(
      id: device.id,
      name: name,
      rssi: device.rssi,
      isLikelyAutomaticWateringHub: hasExpectedName || advertisesService,
      advertisedServiceUuids: advertisedServiceUuids,
    );
  }

  QualifiedCharacteristic _qualifiedCharacteristic(
    String deviceId,
    String characteristicUuid,
  ) {
    return QualifiedCharacteristic(
      characteristicId: Uuid.parse(characteristicUuid),
      serviceId: Uuid.parse(AutomaticWateringBleConstants.serviceUuid),
      deviceId: deviceId,
    );
  }

  void _ensureConnected(String deviceId) {
    if (_connectedDeviceId != deviceId) {
      throw StateError('BLE device is not connected');
    }
  }

  Future<T> _readEnvelopeCharacteristic<T>({
    required String deviceId,
    required String characteristicUuid,
    required T Function(Object? data) parseData,
    required String failureMessage,
  }) async {
    _ensureConnected(deviceId);
    final value = await _ble.readCharacteristic(
      _qualifiedCharacteristic(deviceId, characteristicUuid),
    );
    return _parseEnvelopeData(value, parseData, failureMessage);
  }

  Future<T> _writeJsonAndReadEnvelopeCharacteristic<T>({
    required String deviceId,
    required String characteristicUuid,
    required Map<String, Object?> payload,
    required T Function(Object? data) parseData,
    required String failureMessage,
    T? fallbackOnReadFailure,
  }) async {
    _ensureConnected(deviceId);
    final characteristic =
        _qualifiedCharacteristic(deviceId, characteristicUuid);
    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: utf8.encode(jsonEncode(payload)),
    );

    try {
      final responseValue = await _ble.readCharacteristic(characteristic);
      return _parseEnvelopeData(responseValue, parseData, failureMessage);
    } catch (_) {
      final fallback = fallbackOnReadFailure;
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }

  T _parseEnvelopeData<T>(
    List<int> value,
    T Function(Object? data) parseData,
    String failureMessage,
  ) {
    final envelope = _decodeEnvelope<T>(value, parseData);
    if (!envelope.success) {
      throw StateError(envelope.error ?? failureMessage);
    }
    return envelope.data;
  }

  ApiEnvelope<T> _decodeEnvelope<T>(
    List<int> value,
    T Function(Object? data) parseData,
  ) {
    final decoded = jsonDecode(utf8.decode(value));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('BLE response envelope must be an object');
    }
    return ApiEnvelope<T>.fromJson(decoded, parseData);
  }
}
