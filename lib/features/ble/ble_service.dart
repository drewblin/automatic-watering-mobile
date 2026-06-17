import 'ble_models.dart';

abstract interface class BleService {
  Stream<List<BleDiscoveredDevice>> get discoveredDevices;

  Stream<BleConnectionStatus> get connectionStatus;

  Future<BleAvailability> checkAvailability();

  Future<BleAvailability> requestPermissions();

  Future<void> startScan();

  Future<void> stopScan();

  Future<void> connect(BleDiscoveredDevice device);

  Future<BleDeviceServices> pairAndDiscoverServices({
    required BleDiscoveredDevice device,
    required String passkey,
  });

  Future<void> disconnect(String deviceId);

  Future<BleDeviceServices> discoverServices(String deviceId);

  Future<void> dispose();
}
