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
  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final Map<String, BleDiscoveredDevice> _devices = {};
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  String? _connectedDeviceId;

  @override
  Stream<List<BleDiscoveredDevice>> get discoveredDevices {
    return _devicesController.stream;
  }

  @override
  Stream<BleConnectionStatus> get connectionStatus => _statusController.stream;

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
      _statusController.add(_statusFromAvailability(availability));
      return;
    }

    await stopScan();
    _devices.clear();
    _devicesController.add(const []);
    _statusController.add(BleConnectionStatus.scanning);

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
        _statusController.add(BleConnectionStatus.deviceFound);
      },
      onError: (Object error) {
        _statusController.add(BleConnectionStatus.error);
      },
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
    _statusController.add(BleConnectionStatus.connecting);

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
            _statusController.add(BleConnectionStatus.connecting);
          case DeviceConnectionState.connected:
            _connectedDeviceId = device.id;
            _statusController.add(BleConnectionStatus.pairingRequired);
            if (!completer.isCompleted) {
              completer.complete();
            }
          case DeviceConnectionState.disconnecting:
          case DeviceConnectionState.disconnected:
            if (_connectedDeviceId == device.id) {
              _connectedDeviceId = null;
            }
            _statusController.add(BleConnectionStatus.disconnected);
            if (!completer.isCompleted) {
              completer.completeError(
                StateError('BLE device disconnected before pairing'),
              );
            }
        }
      },
      onError: (Object error) {
        _statusController.add(BleConnectionStatus.error);
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    await completer.future;
  }

  @override
  Future<void> reconnect(BleDiscoveredDevice device) async {
    _statusController.add(BleConnectionStatus.reconnecting);
    await connect(device);
  }

  @override
  Future<BleDeviceServices> pairAndDiscoverServices({
    required BleDiscoveredDevice device,
    required String passkey,
  }) async {
    if (passkey != AutomaticWateringBleConstants.pairingPasskey) {
      _statusController.add(BleConnectionStatus.error);
      throw ArgumentError('Invalid BLE pairing passkey');
    }

    _statusController.add(BleConnectionStatus.pairing);
    final services = await discoverServices(device.id);
    if (!services.hasAutomaticWateringService) {
      _statusController.add(BleConnectionStatus.error);
      throw StateError('Expected Automatic Watering BLE service not found');
    }
    _statusController.add(BleConnectionStatus.connected);
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
    _statusController.add(BleConnectionStatus.disconnected);
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
    _ensureConnected(deviceId);
    final value = await _ble.readCharacteristic(
      _qualifiedCharacteristic(
        deviceId,
        AutomaticWateringBleConstants.wifiSettings.uuid,
      ),
    );
    final envelope = _decodeEnvelope<WifiCredentials>(
      value,
      WifiCredentials.fromControllerSettings,
    );
    if (!envelope.success) {
      throw StateError(envelope.error ?? 'Wi-Fi settings read failed');
    }
    return envelope.data;
  }

  @override
  Future<SaveWifiSettingsResponse> saveWifiSettings({
    required String deviceId,
    required WifiCredentials credentials,
  }) async {
    _ensureConnected(deviceId);
    final characteristic = _qualifiedCharacteristic(
      deviceId,
      AutomaticWateringBleConstants.saveWifiSettings.uuid,
    );
    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: utf8.encode(jsonEncode(credentials.toBleJson())),
    );
    final responseValue = await _ble.readCharacteristic(characteristic);
    final envelope = _decodeEnvelope<SaveWifiSettingsResponse>(
      responseValue,
      SaveWifiSettingsResponse.fromJson,
    );
    if (!envelope.success) {
      throw StateError(envelope.error ?? 'Wi-Fi settings save failed');
    }
    return envelope.data;
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await _connectionSubscription?.cancel();
    await _devicesController.close();
    await _statusController.close();
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

  BleConnectionStatus _statusFromAvailability(BleAvailability availability) {
    return switch (availability) {
      BleAvailability.ready => BleConnectionStatus.idle,
      BleAvailability.permissionRequired =>
        BleConnectionStatus.permissionRequired,
      BleAvailability.bluetoothDisabled =>
        BleConnectionStatus.bluetoothDisabled,
    };
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
