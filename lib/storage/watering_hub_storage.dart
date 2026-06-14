import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';

abstract interface class WateringHubStorage {
  Future<WateringHub?> readActiveWateringHub();

  Future<void> saveActiveWateringHub(WateringHub hub);

  Future<PlanSchema?> readPlanSchema(String wateringHubId);

  Future<void> savePlanSchema(PlanSchema planSchema);

  Future<void> clearWateringHubProfile(String wateringHubId);
}

abstract interface class WateringHubTokenStorage {
  Future<String?> readApiAccessToken(String wateringHubId);

  Future<void> saveApiAccessToken({
    required String wateringHubId,
    required String token,
  });

  Future<void> deleteApiAccessToken(String wateringHubId);
}
