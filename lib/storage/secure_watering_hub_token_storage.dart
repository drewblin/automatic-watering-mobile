import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'watering_hub_storage.dart';

class SecureWateringHubTokenStorage implements WateringHubTokenStorage {
  const SecureWateringHubTokenStorage(this._secureStorage);

  static const _tokenKeyPrefix = 'watering_hub.api_access_token.';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> readApiAccessToken(String wateringHubId) {
    return _secureStorage.read(key: _tokenKey(wateringHubId));
  }

  @override
  Future<void> saveApiAccessToken({
    required String wateringHubId,
    required String token,
  }) {
    return _secureStorage.write(key: _tokenKey(wateringHubId), value: token);
  }

  @override
  Future<void> deleteApiAccessToken(String wateringHubId) {
    return _secureStorage.delete(key: _tokenKey(wateringHubId));
  }

  String _tokenKey(String wateringHubId) => '$_tokenKeyPrefix$wateringHubId';
}
