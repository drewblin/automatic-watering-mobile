import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';
import 'watering_hub_storage.dart';

class InMemoryWateringHubStorage implements WateringHubStorage {
  WateringHub? activeHub;
  final Map<String, PlanSchema> planSchemas = {};

  @override
  Future<WateringHub?> readActiveWateringHub() async => activeHub;

  @override
  Future<void> saveActiveWateringHub(WateringHub hub) async {
    activeHub = hub;
  }

  @override
  Future<PlanSchema?> readPlanSchema(String wateringHubId) async {
    return planSchemas[wateringHubId];
  }

  @override
  Future<void> savePlanSchema(PlanSchema planSchema) async {
    planSchemas[planSchema.wateringHubId] = planSchema;
  }

  @override
  Future<void> clearWateringHubProfile(String wateringHubId) async {
    if (activeHub?.id == wateringHubId) {
      activeHub = null;
    }
    planSchemas.remove(wateringHubId);
  }
}

class InMemoryWateringHubTokenStorage implements WateringHubTokenStorage {
  final Map<String, String> tokens = {};

  @override
  Future<String?> readApiAccessToken(String wateringHubId) async {
    return tokens[wateringHubId];
  }

  @override
  Future<void> saveApiAccessToken({
    required String wateringHubId,
    required String token,
  }) async {
    tokens[wateringHubId] = token;
  }

  @override
  Future<void> deleteApiAccessToken(String wateringHubId) async {
    tokens.remove(wateringHubId);
  }
}
