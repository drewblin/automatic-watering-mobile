import '../controller_settings/settings_response_data.dart';

String controllerTimeText(SettingsResponseData settings) {
  final currentTime = settings.controllerCurrentTime;
  if (currentTime != null) {
    return currentTime;
  }
  final timestamp = settings.controllerCurrentTimestamp;
  if (timestamp != null) {
    return formatDateTime(
      DateTime.fromMillisecondsSinceEpoch(
        timestamp * 1000,
        isUtc: true,
      ),
    );
  }
  return 'Час контролера не синхронізовано';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String formatNumber(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
