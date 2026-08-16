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
    try {
      final decoded = jsonDecode(rawJson) as Map<String, Object?>;
      return WateringHub.fromJson(decoded);
    } catch (error) {
      await _preferences.remove(_activeHubKey);
      throw WateringHubStorageCorruptionException(
        message: 'Saved watering hub profile is corrupted.',
        storageKey: _activeHubKey,
        sourceError: error,
        wateringHubId: _readWateringHubId(rawJson),
      );
    }
  }

  @override
  Future<void> saveActiveWateringHub(WateringHub hub) async {
    await _preferences.setString(_activeHubKey, jsonEncode(hub.toJson()));
  }

  @override
  Future<PlanSchema?> readPlanSchema(String wateringHubId) async {
    final key = _planKey(wateringHubId);
    final rawJson = _preferences.getString(key);
    if (rawJson == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawJson) as Map<String, Object?>;
      return PlanSchema.fromJson(decoded);
    } catch (error) {
      await _preferences.remove(key);
      throw WateringHubStorageCorruptionException(
        message: 'Saved watering plan schema is corrupted.',
        storageKey: key,
        sourceError: error,
        wateringHubId: wateringHubId,
      );
    }
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

  String? _readWateringHubId(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, Object?>) {
        final id = decoded['id'];
        return id is String && id.isNotEmpty ? id : null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
