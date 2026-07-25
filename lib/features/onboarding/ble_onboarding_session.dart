import '../../features/ble/ble_models.dart';
import '../../features/watering_hubs/watering_hub.dart';

class BleOnboardingSession {
  BleOnboardingSession();

  List<BleDiscoveredDevice> devices = const [];
  WateringHub? activeWateringHub;
  bool isBleConnected = false;
  bool isDisposed = false;
  int availabilityRequestId = 0;
}
