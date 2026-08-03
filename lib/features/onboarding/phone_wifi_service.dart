import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'wifi_provisioning_models.dart';

abstract interface class PhoneWifiService {
  Future<PhoneWifiSnapshot> readWifiSnapshot();
}

class PluginPhoneWifiService implements PhoneWifiService {
  PluginPhoneWifiService({
    NetworkInfo? networkInfo,
    WiFiScan? wifiScan,
  })  : _networkInfo = networkInfo ?? NetworkInfo(),
        _wifiScan = wifiScan ?? WiFiScan.instance;

  final NetworkInfo _networkInfo;
  final WiFiScan _wifiScan;

  @override
  Future<PhoneWifiSnapshot> readWifiSnapshot() async {
    await _requestWifiPermissions();

    final currentSsid = _normalizeSsid(await _networkInfo.getWifiName());
    final networks = await _readVisibleNetworks(currentSsid);
    return PhoneWifiSnapshot(
      currentSsid: currentSsid,
      networks: networks,
    );
  }

  Future<void> _requestWifiPermissions() async {
    final statuses = await [
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    final location = statuses[Permission.locationWhenInUse];
    final nearbyWifi = statuses[Permission.nearbyWifiDevices];
    if (location?.isGranted != true && nearbyWifi?.isGranted != true) {
      throw StateError('Wi-Fi permissions were not granted');
    }
  }

  Future<List<PhoneWifiNetwork>> _readVisibleNetworks(
    String? currentSsid,
  ) async {
    final canStartScan = await _wifiScan.canStartScan(askPermissions: true);
    if (canStartScan == CanStartScan.yes) {
      await _wifiScan.startScan();
    }

    final canGetResults = await _wifiScan.canGetScannedResults(
      askPermissions: true,
    );
    if (canGetResults != CanGetScannedResults.yes) {
      return [
        if (currentSsid != null) PhoneWifiNetwork(ssid: currentSsid),
      ];
    }

    final strongestBySsid = <String, PhoneWifiNetwork>{};
    for (final accessPoint in await _wifiScan.getScannedResults()) {
      final ssid = _normalizeSsid(accessPoint.ssid);
      if (ssid == null) {
        continue;
      }
      final network = PhoneWifiNetwork(
        ssid: ssid,
        signalLevel: accessPoint.level,
      );
      final previous = strongestBySsid[ssid];
      if (previous == null ||
          (network.signalLevel ?? -999) > (previous.signalLevel ?? -999)) {
        strongestBySsid[ssid] = network;
      }
    }

    if (currentSsid != null) {
      strongestBySsid.putIfAbsent(
        currentSsid,
        () => PhoneWifiNetwork(ssid: currentSsid),
      );
    }

    final networks = strongestBySsid.values.toList()
      ..sort((a, b) {
        if (a.ssid == currentSsid) {
          return -1;
        }
        if (b.ssid == currentSsid) {
          return 1;
        }
        return (b.signalLevel ?? -999).compareTo(a.signalLevel ?? -999);
      });
    return networks;
  }

  String? _normalizeSsid(String? ssid) {
    final trimmed = ssid?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == '<unknown ssid>' ||
        trimmed == '0x') {
      return null;
    }
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }
}
