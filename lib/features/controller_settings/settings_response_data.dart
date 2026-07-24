import '../../core/json_helpers.dart';
import 'controller_settings.dart';

class SettingsResponseData {
  const SettingsResponseData({
    required this.settings,
    required this.controllerCurrentTimestamp,
    required this.controllerCurrentTime,
    required this.syncedAt,
  });

  final ControllerSettings settings;
  final int? controllerCurrentTimestamp;
  final String? controllerCurrentTime;
  final DateTime syncedAt;

  factory SettingsResponseData.fromJson(Map<String, Object?> json) {
    return SettingsResponseData(
      settings: ControllerSettings.fromJson(
        readObject(json['settings'], 'settings'),
      ),
      controllerCurrentTimestamp: json['controllerCurrentTimestamp'] as int?,
      controllerCurrentTime: json['controllerCurrentTime'] as String?,
      syncedAt: DateTime.now().toUtc(),
    );
  }
}
