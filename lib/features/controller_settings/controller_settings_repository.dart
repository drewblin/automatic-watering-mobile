import '../local_controller/local_controller_api_client.dart';
import '../watering_hubs/watering_hub.dart';
import 'controller_settings.dart';
import 'settings_response_data.dart';

class ControllerSettingsRepository {
  const ControllerSettingsRepository({
    required LocalControllerApiClient apiClient,
  }) : _apiClient = apiClient;

  final LocalControllerApiClient _apiClient;

  Future<SettingsResponseData> syncSettings(WateringHub hub) async {
    final ipAddress = hub.lastKnownIpAddress;
    final token = hub.apiAccessToken;
    if (ipAddress == null || token == null) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.unexpectedResponse,
        'Controller access is incomplete',
      );
    }

    return _apiClient.getSettings(
      ipAddress: ipAddress,
      apiAccessToken: token,
    );
  }

  Future<void> saveSettings(
    WateringHub hub,
    ControllerSettings settings,
  ) async {
    await _apiClient.putSettings(
      ipAddress: hub.lastKnownIpAddress!,
      apiAccessToken: hub.apiAccessToken!,
      settings: settings,
    );
  }
}
