import '../local_controller/local_controller_api_client.dart';
import '../watering_hubs/watering_hub.dart';
import 'controller_settings.dart';
import 'settings_response_data.dart';

class ControllerSettingsRepository {
  const ControllerSettingsRepository({
    required LocalControllerApiClient apiClient,
  }) : _apiClient = apiClient;

  final LocalControllerApiClient _apiClient;

  Future<SettingsResponseData> syncSettings(ReadyWateringHubAccess access) {
    return _apiClient.getSettings(
      ipAddress: access.ipAddress,
      apiAccessToken: access.apiAccessToken,
    );
  }

  Future<void> saveSettings(
    ReadyWateringHubAccess access,
    ControllerSettings settings,
  ) async {
    await _apiClient.putSettings(
      ipAddress: access.ipAddress,
      apiAccessToken: access.apiAccessToken,
      settings: settings,
    );
  }
}
