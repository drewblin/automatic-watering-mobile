import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';

abstract interface class WateringHubStorage {
  Future<WateringHub?> readActiveWateringHub();

  Future<void> saveActiveWateringHub(WateringHub hub);

  Future<PlanSchema?> readPlanSchema(String wateringHubId);

  Future<void> savePlanSchema(PlanSchema planSchema);

  Future<void> clearWateringHubProfile(String wateringHubId);
}

class WateringHubStorageCorruptionException implements Exception {
  const WateringHubStorageCorruptionException({
    required this.message,
    required this.storageKey,
    required this.sourceError,
    this.wateringHubId,
  });

  final String message;
  final String storageKey;
  final Object sourceError;
  final String? wateringHubId;

  @override
  String toString() {
    return '$message (key: $storageKey, error: $sourceError)';
  }
}

abstract interface class WateringHubTokenStorage {
  Future<String?> readApiAccessToken(String wateringHubId);

  Future<void> saveApiAccessToken({
    required String wateringHubId,
    required String token,
  });

  Future<void> deleteApiAccessToken(String wateringHubId);
}
