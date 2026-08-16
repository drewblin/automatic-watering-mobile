import 'package:flutter/foundation.dart';

import '../../core/json_helpers.dart';

enum WifiProvisioningOperation {
  readCurrentSettings,
  validateInput,
  saveSettings,
  reconnectBle,
  phoneWifiAutofill,
}

@immutable
class PhoneWifiNetwork {
  const PhoneWifiNetwork({
    required this.ssid,
    this.signalLevel,
  });

  final String ssid;
  final int? signalLevel;
}

@immutable
class PhoneWifiSnapshot {
  PhoneWifiSnapshot({
    required List<PhoneWifiNetwork> networks,
    this.currentSsid,
  }) : networks = List<PhoneWifiNetwork>.unmodifiable(networks);

  final List<PhoneWifiNetwork> networks;
  final String? currentSsid;
}

@immutable
class WifiCredentials {
  const WifiCredentials({
    required this.ssid,
    required this.password,
    this.openNetwork = false,
  });

  factory WifiCredentials.empty() {
    return const WifiCredentials(ssid: '', password: '');
  }

  factory WifiCredentials.fromControllerSettings(Object? data) {
    final root = readObject(data, 'data');
    final wifiSettings = readObject(root['wifiSettings'], 'wifiSettings');
    return WifiCredentials(
      ssid: readString(wifiSettings['ssid'], 'wifiSettings.ssid').trim(),
      password: '',
    );
  }

  final String ssid;
  final String password;
  final bool openNetwork;

  WifiCredentials copyWith({
    String? ssid,
    String? password,
    bool? openNetwork,
  }) {
    return WifiCredentials(
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      openNetwork: openNetwork ?? this.openNetwork,
    );
  }

  WifiCredentials get normalizedForSave {
    return WifiCredentials(
      ssid: ssid.trim(),
      password: openNetwork ? '' : password,
      openNetwork: openNetwork,
    );
  }

  WifiCredentials get sanitizedForState {
    return WifiCredentials(
      ssid: ssid.trim(),
      password: '',
      openNetwork: openNetwork,
    );
  }

  Map<String, String> validate() {
    final errors = <String, String>{};
    final normalizedSsid = ssid.trim();
    if (normalizedSsid.isEmpty) {
      errors['ssid'] = 'Введіть назву Wi-Fi мережі.';
    } else if (normalizedSsid.length > 32) {
      errors['ssid'] = 'Назва Wi-Fi мережі має містити не більше 32 символів.';
    }

    if (!openNetwork) {
      if (password.isEmpty) {
        errors['password'] =
            'Введіть пароль Wi-Fi або увімкніть відкриту мережу.';
      } else if (password.length < 8) {
        errors['password'] =
            'Пароль WPA/WPA2 має містити щонайменше 8 символів.';
      } else if (password.length > 63) {
        errors['password'] =
            'Пароль WPA/WPA2 має містити не більше 63 символів.';
      }
    }
    return Map.unmodifiable(errors);
  }

  Map<String, Object?> toBleJson() {
    final normalized = normalizedForSave;
    return {
      'ssid': normalized.ssid,
      'password': normalized.password,
    };
  }
}

@immutable
class SaveWifiSettingsResponse {
  const SaveWifiSettingsResponse({required this.restartScheduled});

  factory SaveWifiSettingsResponse.fromJson(Object? data) {
    final root = readObject(data, 'data');
    final restartScheduled = root['restartScheduled'];
    if (restartScheduled is bool) {
      return SaveWifiSettingsResponse(restartScheduled: restartScheduled);
    }
    throw const FormatException(
      'Missing or invalid boolean field: restartScheduled',
    );
  }

  final bool restartScheduled;
}

@immutable
class WifiProvisioningError {
  const WifiProvisioningError({
    required this.message,
    required this.operation,
  });

  final String message;
  final WifiProvisioningOperation operation;
}
