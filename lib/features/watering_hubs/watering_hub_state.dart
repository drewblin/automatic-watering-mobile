// todo провести ревью потрібних статусів
enum WateringHubConnectionState {
  /// No active watering hub profile exists in local app storage.
  noDevice,

  /// A hub profile exists, but there is no verified active connection.
  offline,

  /// The app is trying to reach the hub through BLE or local HTTPS.
  connecting,

  /// BLE returned `0.0.0.0`, so the controller has no Wi-Fi IP yet.
  ipPending,

  /// The app has IP and token and is checking local HTTPS settings access.
  checkingLocalHttps,

  /// Local HTTPS access is confirmed and the controller accepted the token.
  online,

  /// IP and token are present, but the local HTTPS API is unavailable.
  httpsUnavailable,

  /// The controller rejected the token and it must be reread through BLE.
  tokenInvalid,

  /// BLE recovery is required to reread IP, token, or both.
  requiresBleRecovery,

  /// The app is reconnecting to the same BLE device after disconnect/reboot.
  reconnectingBle;

  static WateringHubConnectionState fromJson(Object? value) {
    if (value is String) {
      return WateringHubConnectionState.values.firstWhere(
        (state) => state.name == value,
        orElse: () => WateringHubConnectionState.offline,
      );
    }
    return WateringHubConnectionState.offline;
  }

  String toJson() => name;
}
