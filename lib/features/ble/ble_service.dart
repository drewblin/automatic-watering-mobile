import 'ble_models.dart';
import '../onboarding/wifi_provisioning_models.dart';

abstract interface class BleService {
  Stream<List<BleDiscoveredDevice>> get discoveredDevices;

  Future<BleAvailability> checkAvailability();

  Future<BleAvailability> requestPermissions();

  Future<void> startScan();

  Future<void> stopScan();

  Future<void> connect(BleDiscoveredDevice device);

  Future<void> reconnect(BleDiscoveredDevice device);

  Future<BleDeviceServices> pairAndDiscoverServices({
    required BleDiscoveredDevice device,
    required String passkey,
  });

  Future<void> disconnect(String deviceId);

  Future<BleDeviceServices> discoverServices(String deviceId);

  Future<WifiCredentials> readWifiSettings(String deviceId);

  Future<SaveWifiSettingsResponse> saveWifiSettings({
    required String deviceId,
    required WifiCredentials credentials,
  });

  Future<void> dispose();
}
