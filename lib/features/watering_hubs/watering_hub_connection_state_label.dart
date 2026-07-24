import 'watering_hub_state.dart';

extension WateringHubConnectionStateLabel on WateringHubConnectionState {
  String get label {
    return switch (this) {
      WateringHubConnectionState.noDevice => 'пристрій не додано',
      WateringHubConnectionState.offline => 'офлайн',
      WateringHubConnectionState.connecting => 'підключення',
      WateringHubConnectionState.ipPending => 'очікування IP-адреси',
      WateringHubConnectionState.checkingLocalHttps =>
        'перевірка локального HTTPS',
      WateringHubConnectionState.online => 'онлайн',
      WateringHubConnectionState.httpsUnavailable => 'HTTPS недоступний',
      WateringHubConnectionState.tokenInvalid => 'token недійсний',
      WateringHubConnectionState.requiresBleRecovery =>
        'потрібне відновлення через BLE',
      WateringHubConnectionState.reconnectingBle => 'повторне BLE-підключення',
    };
  }
}
