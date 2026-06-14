import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/plan/plan_schema.dart';
import '../features/watering_hubs/watering_hub.dart';
import 'watering_hub_storage.dart';

class SharedPreferencesWateringHubStorage implements WateringHubStorage {
  SharedPreferencesWateringHubStorage(this._preferences);

  static const _activeHubKey = 'watering_hubs.active';
  static const _planKeyPrefix = 'watering_hubs.plan.';

  final SharedPreferences _preferences;

  @override
  Future<WateringHub?> readActiveWateringHub() async {
    final rawJson = _preferences.getString(_activeHubKey);
    if (rawJson == null) {
      return null;
    }
    final decoded = jsonDecode(rawJson) as Map<String, Object?>;
    return WateringHub.fromJson(decoded);
  }

  @override
  Future<void> saveActiveWateringHub(WateringHub hub) async {
    await _preferences.setString(_activeHubKey, jsonEncode(hub.toJson()));
  }

  @override
  Future<PlanSchema?> readPlanSchema(String wateringHubId) async {
    final rawJson = _preferences.getString(_planKey(wateringHubId));
    if (rawJson == null) {
      return null;
    }
    final decoded = jsonDecode(rawJson) as Map<String, Object?>;
    return PlanSchema.fromJson(decoded);
  }

  @override
  Future<void> savePlanSchema(PlanSchema planSchema) async {
    await _preferences.setString(
      _planKey(planSchema.wateringHubId),
      jsonEncode(planSchema.toJson()),
    );
  }

  @override
  Future<void> clearWateringHubProfile(String wateringHubId) async {
    await _preferences.remove(_activeHubKey);
    await _preferences.remove(_planKey(wateringHubId));
  }

  String _planKey(String wateringHubId) => '$_planKeyPrefix$wateringHubId';
}
